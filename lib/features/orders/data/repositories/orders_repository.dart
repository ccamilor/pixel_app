import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../domain/entities/order_entity.dart';

/// Repositorio Offline-First de Pedidos, Ítems, Abonos y Timer/Pomodoro.
class OrdersRepository {
  OrdersRepository(this._db, this._syncEngine, this._inventoryRepository);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  final InventoryRepository _inventoryRepository;
  static const _uuid = Uuid();

  Stream<List<OrderEntity>> watchOrders() {
    final query = _db.select(_db.orders).join([
      leftOuterJoin(_db.clients, _db.clients.id.equalsExp(_db.orders.clientId)),
    ])
      ..where(_db.orders.deletedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.orders.deadline)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final order = row.readTable(_db.orders);
        final client = row.readTableOrNull(_db.clients);
        return _toOrderEntity(order, client);
      }).toList();
    });
  }

  Stream<List<OrderItemEntity>> watchOrderItems(String orderId) {
    return (_db.select(_db.orderItems)
          ..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull()))
        .watch()
        .map((rows) => rows.map(_toItemEntity).toList());
  }

  Stream<List<OrderPaymentEntity>> watchOrderPayments(String orderId) {
    return (_db.select(_db.orderPayments)
          ..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.paymentDate)]))
        .watch()
        .map((rows) => rows.map(_toPaymentEntity).toList());
  }

  Future<String> createOrder({
    required String clientId,
    required String title,
    required DateTime deadline,
    OrderPriority priority = OrderPriority.medium,
    PricingMode pricingMode = PricingMode.manual,
    double designFee = 0,
    required double totalPrice,
    double initialPayment = 0,
    PaymentMethod initialPaymentMethod = PaymentMethod.cash,
    String technicalNotes = '',
    String? sourceFilePath,
    List<String> referenceImages = const [],
    List<OrderItemDraft> items = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final orderId = _uuid.v4();
    final imagesJson = jsonEncode(referenceImages);

    await _db.into(_db.orders).insert(
      OrdersCompanion.insert(
        id: orderId,
        clientId: clientId,
        title: title.trim(),
        status: const Value('pending'),
        technicalNotes: Value(technicalNotes.trim()),
        sourceFilePath: Value(
          sourceFilePath?.trim().isEmpty ?? true ? null : sourceFilePath?.trim(),
        ),
        referenceImagesJson: Value(imagesJson),
        deadline: deadline.toUtc(),
        priority: Value(_priorityToDb(priority)),
        pricingMode: Value(pricingMode == PricingMode.auto ? 'auto' : 'manual'),
        designFee: Value(designFee),
        totalPrice: Value(totalPrice),
        amountPaid: Value(initialPayment),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'orders',
      recordId: orderId,
      operation: 'upsert',
      payload: {
        'id': orderId,
        'client_id': clientId,
        'title': title.trim(),
        'status': 'pending',
        'design_approved': false,
        'print_stage': 'none',
        'technical_notes': technicalNotes.trim(),
        'source_file_path':
            sourceFilePath?.trim().isEmpty ?? true ? null : sourceFilePath?.trim(),
        'reference_images': referenceImages,
        'deadline': deadline.toUtc().toIso8601String(),
        'priority': _priorityToDb(priority),
        'pricing_mode': pricingMode == PricingMode.auto ? 'auto' : 'manual',
        'design_fee': designFee,
        'total_price': totalPrice,
        'amount_paid': initialPayment,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );

    for (final item in items) {
      final itemId = _uuid.v4();
      await _db.into(_db.orderItems).insert(
        OrderItemsCompanion.insert(
          id: itemId,
          orderId: orderId,
          materialId: Value(item.materialId),
          description: item.description.trim(),
          widthCm: Value(item.widthCm),
          heightCm: Value(item.heightCm),
          quantity: Value(item.quantity),
          wastePercentage: Value(item.wastePercentage),
          finishingType: Value(_finishingToDb(item.finishingType)),
          finishingSurcharge: Value(item.finishingSurcharge),
          calculatedPrice: Value(item.calculatedPrice),
          deductedFromStock: Value(item.deductFromStock),
          updatedAt: Value(now),
        ),
      );

      if (item.deductFromStock && item.materialId != null && item.billableAreaM2 > 0) {
        await _inventoryRepository.adjustStock(
          item.materialId!,
          -item.billableAreaM2,
        );
      }

      await _db.enqueueSync(
        entityTable: 'order_items',
        recordId: itemId,
        operation: 'upsert',
        payload: {
          'id': itemId,
          'order_id': orderId,
          'material_id': item.materialId,
          'description': item.description.trim(),
          'width_cm': item.widthCm,
          'height_cm': item.heightCm,
          'quantity': item.quantity,
          'waste_percentage': item.wastePercentage,
          'finishing_type': _finishingToDb(item.finishingType),
          'finishing_surcharge': item.finishingSurcharge,
          'calculated_price': item.calculatedPrice,
          'deducted_from_stock': item.deductFromStock,
          'updated_at': now.toIso8601String(),
        },
      );
    }

    if (initialPayment > 0) {
      await _insertPaymentRecord(
        orderId: orderId,
        amount: initialPayment,
        method: initialPaymentMethod,
        notes: 'Abono inicial',
        now: now,
      );
    }

    _syncEngine.syncPendingChanges();
    return orderId;
  }

  /// Mueve una tarjeta entre columnas del Kanban o actualiza sus subestados.
  Future<void> updateOrderWorkflow({
    required String orderId,
    OrderStatus? status,
    bool? designApproved,
    PrintStage? printStage,
  }) async {
    final now = DateTime.now().toUtc();
    final companion = OrdersCompanion(
      status: status != null ? Value(_statusToDb(status)) : const Value.absent(),
      designApproved:
          designApproved != null ? Value(designApproved) : const Value.absent(),
      printStage:
          printStage != null ? Value(_printStageToDb(printStage)) : const Value.absent(),
      updatedAt: Value(now),
    );

    await (_db.update(_db.orders)..where((t) => t.id.equals(orderId)))
        .write(companion);

    final updated =
        await (_db.select(_db.orders)..where((t) => t.id.equals(orderId)))
            .getSingleOrNull();
    if (updated != null) {
      await _enqueueOrderUpsert(updated);
    }
    _syncEngine.syncPendingChanges();
  }

  /// Registra un nuevo abono y recalcula `amount_paid` en la cabecera del pedido.
  Future<void> addPayment({
    required String orderId,
    required double amount,
    required PaymentMethod paymentMethod,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    await _insertPaymentRecord(
      orderId: orderId,
      amount: amount,
      method: paymentMethod,
      notes: notes,
      now: now,
    );

    final payments = await (_db.select(_db.orderPayments)
          ..where((t) => t.orderId.equals(orderId) & t.deletedAt.isNull()))
        .get();
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);

    await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(amountPaid: Value(totalPaid), updatedAt: Value(now)),
    );

    final updated =
        await (_db.select(_db.orders)..where((t) => t.id.equals(orderId)))
            .getSingleOrNull();
    if (updated != null) {
      await _enqueueOrderUpsert(updated);
    }
    _syncEngine.syncPendingChanges();
  }

  /// Inicia el cronómetro libre o Pomodoro en vivo para un pedido.
  Future<void> startTimer({
    required String orderId,
    required TimerMode mode,
  }) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        activeTimerStartedAt: Value(now),
        timerMode: Value(mode == TimerMode.pomodoro ? 'pomodoro' : 'stopwatch'),
        updatedAt: Value(now),
      ),
    );
    final updated =
        await (_db.select(_db.orders)..where((t) => t.id.equals(orderId)))
            .getSingleOrNull();
    if (updated != null) await _enqueueOrderUpsert(updated);
  }

  /// Pausa el cronómetro o completa una sesión Pomodoro sumando minutos al pedido.
  Future<void> stopTimer({
    required String orderId,
    bool completedPomodoroCycle = false,
    int? overrideMinutes,
  }) async {
    final existing =
        await (_db.select(_db.orders)..where((t) => t.id.equals(orderId)))
            .getSingleOrNull();
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    int addedMinutes = overrideMinutes ?? 0;
    if (overrideMinutes == null && existing.activeTimerStartedAt != null) {
      final elapsed = now.difference(existing.activeTimerStartedAt!).inMinutes;
      addedMinutes = elapsed < 1 ? 1 : elapsed;
    }

    final nextMinutes = existing.timeInvestedMinutes + addedMinutes;
    final nextPomodoros =
        existing.pomodoroSessionsCompleted + (completedPomodoroCycle ? 1 : 0);

    await (_db.update(_db.orders)..where((t) => t.id.equals(orderId))).write(
      OrdersCompanion(
        activeTimerStartedAt: const Value(null),
        timeInvestedMinutes: Value(nextMinutes),
        pomodoroSessionsCompleted: Value(nextPomodoros),
        updatedAt: Value(now),
      ),
    );

    final updated =
        await (_db.select(_db.orders)..where((t) => t.id.equals(orderId)))
            .getSingleOrNull();
    if (updated != null) await _enqueueOrderUpsert(updated);
    _syncEngine.syncPendingChanges();
  }

  Future<void> _insertPaymentRecord({
    required String orderId,
    required double amount,
    required PaymentMethod method,
    required String? notes,
    required DateTime now,
  }) async {
    final paymentId = _uuid.v4();
    final methodDb = paymentMethodToDb(method);

    await _db.into(_db.orderPayments).insert(
      OrderPaymentsCompanion.insert(
        id: paymentId,
        orderId: orderId,
        amount: amount,
        paymentMethod: Value(methodDb),
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
        paymentDate: Value(now),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'order_payments',
      recordId: paymentId,
      operation: 'upsert',
      payload: {
        'id': paymentId,
        'order_id': orderId,
        'amount': amount,
        'payment_method': methodDb,
        'notes': notes,
        'payment_date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
  }

  Future<void> _enqueueOrderUpsert(Order row) {
    return _db.enqueueSync(
      entityTable: 'orders',
      recordId: row.id,
      operation: 'upsert',
      payload: {
        'id': row.id,
        'client_id': row.clientId,
        'title': row.title,
        'status': row.status,
        'design_approved': row.designApproved,
        'print_stage': row.printStage,
        'technical_notes': row.technicalNotes,
        'source_file_path': row.sourceFilePath,
        'reference_images': jsonDecode(row.referenceImagesJson),
        'time_invested_minutes': row.timeInvestedMinutes,
        'active_timer_started_at':
            row.activeTimerStartedAt?.toUtc().toIso8601String(),
        'timer_mode': row.timerMode,
        'pomodoro_sessions_completed': row.pomodoroSessionsCompleted,
        'deadline': row.deadline.toUtc().toIso8601String(),
        'priority': row.priority,
        'pricing_mode': row.pricingMode,
        'design_fee': row.designFee,
        'total_price': row.totalPrice,
        'amount_paid': row.amountPaid,
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  OrderEntity _toOrderEntity(Order row, Client? client) {
    final decodedImages =
        (jsonDecode(row.referenceImagesJson) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
    return OrderEntity(
      id: row.id,
      clientId: row.clientId,
      clientName: client?.name ?? 'Cliente',
      clientPhone: client?.phone ?? '',
      title: row.title,
      status: _statusFromDb(row.status),
      designApproved: row.designApproved,
      printStage: _printStageFromDb(row.printStage),
      technicalNotes: row.technicalNotes,
      sourceFilePath: row.sourceFilePath,
      referenceImages: decodedImages,
      timeInvestedMinutes: row.timeInvestedMinutes,
      activeTimerStartedAt: row.activeTimerStartedAt?.toLocal(),
      timerMode:
          row.timerMode == 'pomodoro' ? TimerMode.pomodoro : TimerMode.stopwatch,
      pomodoroSessionsCompleted: row.pomodoroSessionsCompleted,
      deadline: row.deadline.toLocal(),
      priority: _priorityFromDb(row.priority),
      pricingMode:
          row.pricingMode == 'auto' ? PricingMode.auto : PricingMode.manual,
      designFee: row.designFee,
      totalPrice: row.totalPrice,
      amountPaid: row.amountPaid,
      createdAt: row.createdAt.toLocal(),
      updatedAt: row.updatedAt.toLocal(),
    );
  }

  OrderItemEntity _toItemEntity(OrderItem row) {
    return OrderItemEntity(
      id: row.id,
      orderId: row.orderId,
      materialId: row.materialId,
      description: row.description,
      widthCm: row.widthCm,
      heightCm: row.heightCm,
      quantity: row.quantity,
      wastePercentage: row.wastePercentage,
      finishingType: _finishingFromDb(row.finishingType),
      finishingSurcharge: row.finishingSurcharge,
      calculatedPrice: row.calculatedPrice,
      deductedFromStock: row.deductedFromStock,
    );
  }

  OrderPaymentEntity _toPaymentEntity(OrderPayment row) {
    return OrderPaymentEntity(
      id: row.id,
      orderId: row.orderId,
      amount: row.amount,
      paymentMethod: paymentMethodFromDb(row.paymentMethod),
      notes: row.notes,
      paymentDate: row.paymentDate.toLocal(),
    );
  }

  String _statusToDb(OrderStatus status) => status.name;

  OrderStatus _statusFromDb(String raw) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OrderStatus.pending,
    );
  }

  String _printStageToDb(PrintStage stage) => stage.name;

  PrintStage _printStageFromDb(String raw) {
    return PrintStage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PrintStage.none,
    );
  }

  String _priorityToDb(OrderPriority priority) => priority.name;

  OrderPriority _priorityFromDb(String raw) {
    return OrderPriority.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => OrderPriority.medium,
    );
  }

  String _finishingToDb(FinishingType type) {
    return switch (type) {
      FinishingType.none => 'none',
      FinishingType.matteLaminate => 'matte_laminate',
      FinishingType.glossLaminate => 'gloss_laminate',
      FinishingType.dieCut => 'die_cut',
      FinishingType.reflective => 'reflective',
    };
  }

  FinishingType _finishingFromDb(String raw) {
    return switch (raw) {
      'matte_laminate' => FinishingType.matteLaminate,
      'gloss_laminate' => FinishingType.glossLaminate,
      'die_cut' => FinishingType.dieCut,
      'reflective' => FinishingType.reflective,
      _ => FinishingType.none,
    };
  }
}

/// DTO temporal para crear ítems desde el formulario de nuevo pedido.
class OrderItemDraft {
  const OrderItemDraft({
    this.materialId,
    required this.description,
    required this.widthCm,
    required this.heightCm,
    required this.quantity,
    required this.wastePercentage,
    required this.finishingType,
    required this.finishingSurcharge,
    required this.calculatedPrice,
    required this.billableAreaM2,
    required this.deductFromStock,
  });

  final String? materialId;
  final String description;
  final double widthCm;
  final double heightCm;
  final int quantity;
  final double wastePercentage;
  final FinishingType finishingType;
  final double finishingSurcharge;
  final double calculatedPrice;
  final double billableAreaM2;
  final bool deductFromStock;
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
    ref.watch(inventoryRepositoryProvider),
  );
});

final ordersStreamProvider = StreamProvider<List<OrderEntity>>((ref) {
  return ref.watch(ordersRepositoryProvider).watchOrders();
});

final orderPaymentsProvider =
    StreamProvider.family<List<OrderPaymentEntity>, String>((ref, orderId) {
      return ref.watch(ordersRepositoryProvider).watchOrderPayments(orderId);
    });

final orderItemsProvider =
    StreamProvider.family<List<OrderItemEntity>, String>((ref, orderId) {
      return ref.watch(ordersRepositoryProvider).watchOrderItems(orderId);
    });
