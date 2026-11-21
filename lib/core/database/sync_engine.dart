import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/connectivity_service.dart';
import '../network/supabase_config.dart';
import 'app_database.dart';

/// Estado observable del motor de sincronización Offline-First.
enum SyncStatus { idle, syncing, offline, unconfigured, unauthenticated, error }

class SyncSnapshot {
  const SyncSnapshot({
    required this.status,
    required this.pendingCount,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncStatus status;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? lastError;
}

/// Contrato remoto para desacoplar SyncEngine de Supabase y permitir tests unitarios.
abstract interface class RemoteSyncAdapter {
  bool get isAuthenticated;
  Future<void> upsert(String table, Map<String, dynamic> payload);
  Future<void> softDelete(String table, String recordId, DateTime deletedAt);
  Future<List<Map<String, dynamic>>> fetchTable(String table);
  /// Suscribe un canal Realtime (WebSocket) para recibir cambios al instante (< 1s).
  void subscribeToChanges(void Function() onRemoteChange);
  Future<void> unsubscribeFromChanges();
}

class SupabaseRemoteSyncAdapter implements RemoteSyncAdapter {
  SupabaseRemoteSyncAdapter(this._client);
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  Future<void> upsert(String table, Map<String, dynamic> payload) async {
    await _client.from(table).upsert(payload);
  }

  @override
  Future<void> softDelete(
    String table,
    String recordId,
    DateTime deletedAt,
  ) async {
    await _client
        .from(table)
        .update({
          'deleted_at': deletedAt.toUtc().toIso8601String(),
          'updated_at': deletedAt.toUtc().toIso8601String(),
        })
        .eq('id', recordId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTable(String table) async {
    final rows = await _client.from(table).select();
    return (rows as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  void subscribeToChanges(void Function() onRemoteChange) {
    if (_channel != null) return;
    _channel = _client
        .channel('pixel_app_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          callback: (_) => onRemoteChange(),
        )
        .subscribe();
  }

  @override
  Future<void> unsubscribeFromChanges() async {
    final ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
  }
}

/// Motor de sincronización Bidireccional Offline-First:
/// 1) PUSH: procesa `sync_queue` hacia Supabase en orden FIFO.
/// 2) PULL: descarga cambios desde Supabase (Android <-> iPad <-> Bots) hacia Drift local.
class SyncEngine {
  SyncEngine({
    required this.database,
    required this.connectivity,
    this.remoteAdapter,
  });

  final AppDatabase database;
  final ConnectivityService connectivity;
  final RemoteSyncAdapter? remoteAdapter;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _periodicTimer;
  Timer? _realtimeDebounce;
  bool _isSyncing = false;
  final _syncCompletedController = StreamController<DateTime>.broadcast();

  /// Emite una marca de tiempo cada vez que finaliza un ciclo Push+Pull exitoso.
  Stream<DateTime> get onSyncCompleted => _syncCompletedController.stream;

  /// Inicia sincronización automática:
  /// 1) Al abrir la app, 2) Realtime WebSocket (< 1s ante cambios remotos),
  /// 3) Al reconectar internet, y 4) Respaldo silencioso cada 60s.
  void startAutoSync({
    Duration pollInterval = const Duration(seconds: 60),
  }) {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();

    // 1. Sincronización inicial al abrir la app
    unawaited(syncAll());

    // 2. Canal Realtime WebSocket (actualización instantánea al cambiar cualquier tabla en Supabase)
    remoteAdapter?.subscribeToChanges(() {
      _realtimeDebounce?.cancel();
      _realtimeDebounce = Timer(const Duration(milliseconds: 350), () {
        unawaited(syncAll());
      });
    });

    // 3. Sincronización al recuperar conexión a internet
    _connectivitySub = connectivity.onStatusChanged.listen((online) {
      if (online) {
        unawaited(syncAll());
      }
    });

    // 4. Respaldo silencioso cada 60s por si el socket se suspende en segundo plano
    _periodicTimer = Timer.periodic(pollInterval, (_) {
      unawaited(syncAll());
    });
  }

  Future<void> dispose() async {
    _realtimeDebounce?.cancel();
    _periodicTimer?.cancel();
    await _connectivitySub?.cancel();
    await remoteAdapter?.unsubscribeFromChanges();
    await _syncCompletedController.close();
  }

  /// Ejecuta PUSH de la cola pendiente seguido de PULL desde Supabase.
  Future<SyncSnapshot> syncAll() async {
    final pushResult = await syncPendingChanges();
    if (pushResult.status != SyncStatus.idle) {
      return pushResult;
    }
    final pullResult = await pullFromRemote();
    if (pullResult.status == SyncStatus.idle && !_syncCompletedController.isClosed) {
      _syncCompletedController.add(DateTime.now());
    }
    return pullResult;
  }

  /// Procesa en orden FIFO todas las operaciones encoladas en `sync_queue`.
  Future<SyncSnapshot> syncPendingChanges() async {
    final pendingBefore = (await database.getPendingSyncItems()).length;

    if (remoteAdapter == null) {
      return SyncSnapshot(
        status: SyncStatus.unconfigured,
        pendingCount: pendingBefore,
      );
    }

    if (!remoteAdapter!.isAuthenticated) {
      return SyncSnapshot(
        status: SyncStatus.unauthenticated,
        pendingCount: pendingBefore,
      );
    }

    if (_isSyncing) {
      return SyncSnapshot(
        status: SyncStatus.syncing,
        pendingCount: pendingBefore,
      );
    }

    final online = await connectivity.hasConnection;
    if (!online) {
      return SyncSnapshot(
        status: SyncStatus.offline,
        pendingCount: pendingBefore,
      );
    }

    _isSyncing = true;
    String? lastError;

    try {
      final items = await database.getPendingSyncItems();
      for (final item in items) {
        try {
          final payload =
              jsonDecode(item.payloadJson) as Map<String, dynamic>;

          if (item.operation == 'delete') {
            final deletedAtStr = payload['deleted_at'] as String?;
            final deletedAt = deletedAtStr != null
                ? DateTime.parse(deletedAtStr)
                : DateTime.now().toUtc();
            await remoteAdapter!.softDelete(
              item.entityTable,
              item.recordId,
              deletedAt,
            );
          } else {
            await remoteAdapter!.upsert(item.entityTable, payload);
          }

          await database.removeSyncItem(item.id);
        } catch (error) {
          lastError = error.toString();
          await database.markSyncRetry(item.id, lastError);
          break;
        }
      }

      final remaining = (await database.getPendingSyncItems()).length;
      return SyncSnapshot(
        status: lastError == null ? SyncStatus.idle : SyncStatus.error,
        pendingCount: remaining,
        lastSyncedAt: lastError == null ? DateTime.now() : null,
        lastError: lastError,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Descarga las 8 tablas desde Supabase y hace upsert local en Drift respetando llaves foráneas.
  Future<SyncSnapshot> pullFromRemote() async {
    final pending = (await database.getPendingSyncItems()).length;
    if (remoteAdapter == null) {
      return SyncSnapshot(status: SyncStatus.unconfigured, pendingCount: pending);
    }
    if (!remoteAdapter!.isAuthenticated) {
      return SyncSnapshot(
        status: SyncStatus.unauthenticated,
        pendingCount: pending,
      );
    }
    final online = await connectivity.hasConnection;
    if (!online) {
      return SyncSnapshot(status: SyncStatus.offline, pendingCount: pending);
    }

    try {
      // Orden respetando dependencias FK: clients & materials -> orders -> order_items & order_payments -> expenses -> work_logs -> work_breaks
      final clientsRows = await remoteAdapter!.fetchTable('clients');
      for (final r in clientsRows) {
        await database.into(database.clients).insertOnConflictUpdate(
          ClientsCompanion(
            id: Value(r['id'] as String),
            name: Value((r['name'] ?? '') as String),
            documentId: Value(r['document_id'] as String?),
            phone: Value((r['phone'] ?? '') as String),
            vehicleInfo: Value(r['vehicle_info'] as String?),
            notes: Value(r['notes'] as String?),
            createdAt: Value(_parseTs(r['created_at']) ?? DateTime.now().toUtc()),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final materialsRows = await remoteAdapter!.fetchTable('materials');
      for (final r in materialsRows) {
        await database.into(database.materials).insertOnConflictUpdate(
          MaterialsCompanion(
            id: Value(r['id'] as String),
            name: Value((r['name'] ?? '') as String),
            unit: Value((r['unit'] ?? 'm2') as String),
            unitCost: Value(_toDouble(r['unit_cost'])),
            suggestedSalePrice: Value(_toDouble(r['suggested_sale_price'])),
            defaultWastePercentage: Value(_toDouble(r['default_waste_percentage'], 15)),
            stock: Value(_toDouble(r['stock'])),
            minStock: Value(_toDouble(r['min_stock'])),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final ordersRows = await remoteAdapter!.fetchTable('orders');
      for (final r in ordersRows) {
        final rawImages = r['reference_images'];
        final imagesJson = rawImages is String
            ? rawImages
            : jsonEncode(rawImages ?? const <String>[]);
        await database.into(database.orders).insertOnConflictUpdate(
          OrdersCompanion(
            id: Value(r['id'] as String),
            clientId: Value(r['client_id'] as String),
            title: Value((r['title'] ?? '') as String),
            category: Value((r['category'] ?? 'Impresión Digital') as String),
            subcategory: Value((r['subcategory'] ?? '') as String),
            status: Value((r['status'] ?? 'pending') as String),
            designApproved: Value((r['design_approved'] ?? false) as bool),
            printStage: Value((r['print_stage'] ?? 'none') as String),
            technicalNotes: Value((r['technical_notes'] ?? '') as String),
            sourceFilePath: Value(r['source_file_path'] as String?),
            referenceImagesJson: Value(imagesJson),
            timeInvestedMinutes: Value(_toInt(r['time_invested_minutes'])),
            activeTimerStartedAt: Value(_parseTs(r['active_timer_started_at'])),
            timerMode: Value((r['timer_mode'] ?? 'stopwatch') as String),
            pomodoroSessionsCompleted: Value(_toInt(r['pomodoro_sessions_completed'])),
            deadline: Value(_parseTs(r['deadline']) ?? DateTime.now().toUtc()),
            priority: Value((r['priority'] ?? 'medium') as String),
            pricingMode: Value((r['pricing_mode'] ?? 'manual') as String),
            designFee: Value(_toDouble(r['design_fee'])),
            totalPrice: Value(_toDouble(r['total_price'])),
            amountPaid: Value(_toDouble(r['amount_paid'])),
            createdAt: Value(_parseTs(r['created_at']) ?? DateTime.now().toUtc()),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final itemsRows = await remoteAdapter!.fetchTable('order_items');
      for (final r in itemsRows) {
        await database.into(database.orderItems).insertOnConflictUpdate(
          OrderItemsCompanion(
            id: Value(r['id'] as String),
            orderId: Value(r['order_id'] as String),
            materialId: Value(r['material_id'] as String?),
            description: Value((r['description'] ?? '') as String),
            widthCm: Value(_toDouble(r['width_cm'])),
            heightCm: Value(_toDouble(r['height_cm'])),
            quantity: Value(_toInt(r['quantity'], 1)),
            wastePercentage: Value(_toDouble(r['waste_percentage'], 15)),
            finishingType: Value((r['finishing_type'] ?? 'none') as String),
            finishingSurcharge: Value(_toDouble(r['finishing_surcharge'])),
            calculatedPrice: Value(_toDouble(r['calculated_price'])),
            deductedFromStock: Value((r['deducted_from_stock'] ?? false) as bool),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final paymentsRows = await remoteAdapter!.fetchTable('order_payments');
      for (final r in paymentsRows) {
        await database.into(database.orderPayments).insertOnConflictUpdate(
          OrderPaymentsCompanion(
            id: Value(r['id'] as String),
            orderId: Value(r['order_id'] as String),
            amount: Value(_toDouble(r['amount'])),
            paymentMethod: Value((r['payment_method'] ?? 'cash') as String),
            notes: Value(r['notes'] as String?),
            paymentDate: Value(_parseTs(r['payment_date']) ?? DateTime.now().toUtc()),
            createdAt: Value(_parseTs(r['created_at']) ?? DateTime.now().toUtc()),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final expensesRows = await remoteAdapter!.fetchTable('expenses');
      for (final r in expensesRows) {
        await database.into(database.expenses).insertOnConflictUpdate(
          ExpensesCompanion(
            id: Value(r['id'] as String),
            amount: Value(_toDouble(r['amount'])),
            scope: Value((r['scope'] ?? 'business') as String),
            paymentMethod: Value((r['payment_method'] ?? 'cash') as String),
            category: Value((r['category'] ?? 'General') as String),
            subcategory: Value((r['subcategory'] ?? '') as String),
            description: Value((r['description'] ?? '') as String),
            date: Value(_parseTs(r['date']) ?? DateTime.now().toUtc()),
            source: Value((r['source'] ?? 'app') as String),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final logsRows = await remoteAdapter!.fetchTable('work_logs');
      for (final r in logsRows) {
        await database.into(database.workLogs).insertOnConflictUpdate(
          WorkLogsCompanion(
            id: Value(r['id'] as String),
            dateKey: Value((r['date'] ?? '') as String),
            openTime: Value(_parseTs(r['open_time']) ?? DateTime.now().toUtc()),
            closeTime: Value(_parseTs(r['close_time'])),
            totalWorkedMinutes: Value(_toInt(r['total_worked_minutes'])),
            totalBreakMinutes: Value(_toInt(r['total_break_minutes'])),
            notes: Value(r['notes'] as String?),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final breaksRows = await remoteAdapter!.fetchTable('work_breaks');
      for (final r in breaksRows) {
        await database.into(database.workBreaks).insertOnConflictUpdate(
          WorkBreaksCompanion(
            id: Value(r['id'] as String),
            workLogId: Value(r['work_log_id'] as String),
            type: Value((r['type'] ?? 'lunch') as String),
            startTime: Value(_parseTs(r['start_time']) ?? DateTime.now().toUtc()),
            endTime: Value(_parseTs(r['end_time'])),
            notes: Value(r['notes'] as String?),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      final remindersRows = await remoteAdapter!.fetchTable('daily_reminders');
      for (final r in remindersRows) {
        await database.into(database.dailyReminders).insertOnConflictUpdate(
          DailyRemindersCompanion(
            id: Value(r['id'] as String),
            dateKey: Value((r['date_key'] ?? '') as String),
            title: Value((r['title'] ?? '') as String),
            isDone: Value((r['is_done'] ?? false) as bool),
            createdAt: Value(_parseTs(r['created_at']) ?? DateTime.now().toUtc()),
            updatedAt: Value(_parseTs(r['updated_at']) ?? DateTime.now().toUtc()),
            deletedAt: Value(_parseTs(r['deleted_at'])),
          ),
        );
      }

      return SyncSnapshot(
        status: SyncStatus.idle,
        pendingCount: (await database.getPendingSyncItems()).length,
        lastSyncedAt: DateTime.now(),
      );
    } catch (error) {
      return SyncSnapshot(
        status: SyncStatus.error,
        pendingCount: pending,
        lastError: error.toString(),
      );
    }
  }

  DateTime? _parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    return DateTime.tryParse(raw.toString())?.toUtc();
  }

  double _toDouble(dynamic raw, [double fallback = 0]) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? fallback;
  }

  int _toInt(dynamic raw, [int fallback = 0]) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString()) ?? fallback;
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final supabaseClient = SupabaseConfig.clientOrNull;

  final engine = SyncEngine(
    database: db,
    connectivity: connectivity,
    remoteAdapter: supabaseClient != null
        ? SupabaseRemoteSyncAdapter(supabaseClient)
        : null,
  );

  engine.startAutoSync();
  ref.onDispose(engine.dispose);
  return engine;
});

final pendingSyncCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).watchPendingSyncCount();
});
