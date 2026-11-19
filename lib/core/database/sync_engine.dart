import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/connectivity_service.dart';
import '../network/supabase_config.dart';
import 'app_database.dart';

/// Estado observable del motor de sincronización Offline-First.
enum SyncStatus { idle, syncing, offline, unconfigured, error }

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
  Future<void> upsert(String table, Map<String, dynamic> payload);
  Future<void> softDelete(String table, String recordId, DateTime deletedAt);
}

class SupabaseRemoteSyncAdapter implements RemoteSyncAdapter {
  SupabaseRemoteSyncAdapter(this._client);
  final SupabaseClient _client;

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
}

/// Motor de sincronización Offline-First: procesa `sync_queue` hacia Supabase cuando hay red.
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
  bool _isSyncing = false;

  /// Inicia la escucha automática de reconexión para vaciar la cola en segundo plano.
  void startAutoSync() {
    _connectivitySub?.cancel();
    _connectivitySub = connectivity.onStatusChanged.listen((online) {
      if (online) {
        unawaited(syncPendingChanges());
      }
    });
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
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
            final deletedAt =
                deletedAtStr != null
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
    remoteAdapter:
        supabaseClient != null
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
