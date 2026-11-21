import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';
import '../../domain/entities/expense_entity.dart';

/// Categorías predefinidas para agilizar el registro diario.
const Map<String, List<String>> defaultExpenseCategories = {
  'Alimentación': ['Almuerzo', 'Desayuno', 'Café / Merienda', 'Mercado'],
  'Insumos': ['Vinilos', 'Laminado', 'Tintas', 'Transfer / Cuchillas'],
  'Servicios Local': ['Energía', 'Internet', 'Arriendo', 'Mantenimiento'],
  'Transporte': ['Gasolina', 'Domicilios', 'Pasajes'],
  'Gastos Personales': ['Salud', 'Ropa', 'Ocio', 'Otros'],
};

/// Repositorio Offline-First de Finanzas (gastos unificados + arqueo por método de pago).
class FinanceRepository {
  FinanceRepository(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  static const _uuid = Uuid();

  Stream<List<ExpenseEntity>> watchExpenses() {
    return (_db.select(_db.expenses)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  /// Calcula el arqueo real cruzando pagos de pedidos (`order_payments`) vs gastos (`expenses`).
  Stream<FinanceSummary> watchFinanceSummary() {
    final paymentsStream = (_db.select(_db.orderPayments)
          ..where((t) => t.deletedAt.isNull()))
        .watch();
    final expensesStream = (_db.select(_db.expenses)
          ..where((t) => t.deletedAt.isNull()))
        .watch();
    final ordersStream = (_db.select(_db.orders)
          ..where((t) => t.deletedAt.isNull()))
        .watch();

    return paymentsStream.asyncMap((payments) async {
      final expenses = await expensesStream.first;
      final orders = await ordersStream.first;
      return _computeSummary(payments, expenses, orders);
    });
  }

  Future<FinanceSummary> getFinanceSummary() async {
    final payments = await (_db.select(_db.orderPayments)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final expenses = await (_db.select(_db.expenses)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    final orders = await (_db.select(_db.orders)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    return _computeSummary(payments, expenses, orders);
  }

  FinanceSummary _computeSummary(
    List<OrderPayment> payments,
    List<Expense> expenses,
    List<Order> orders,
  ) {
    double cashIncome = 0;
    double digitalIncome = 0;
    for (final p in payments) {
      if (p.paymentMethod == 'cash') {
        cashIncome += p.amount;
      } else {
        digitalIncome += p.amount;
      }
    }

    double businessExpenses = 0;
    double personalExpenses = 0;
    double cashExpenses = 0;
    double digitalExpenses = 0;

    for (final e in expenses) {
      if (e.scope == 'personal') {
        personalExpenses += e.amount;
      } else {
        businessExpenses += e.amount;
      }

      if (e.paymentMethod == 'cash') {
        cashExpenses += e.amount;
      } else {
        digitalExpenses += e.amount;
      }
    }

    double receivable = 0;
    for (final o in orders) {
      final balance = o.totalPrice - o.amountPaid;
      if (balance > 0) receivable += balance;
    }

    return FinanceSummary(
      totalIncome: cashIncome + digitalIncome,
      cashIncome: cashIncome,
      digitalIncome: digitalIncome,
      totalExpenses: businessExpenses + personalExpenses,
      businessExpenses: businessExpenses,
      personalExpenses: personalExpenses,
      cashExpenses: cashExpenses,
      digitalExpenses: digitalExpenses,
      totalReceivable: receivable,
    );
  }

  Future<void> addExpense({
    required double amount,
    required ExpenseScope scope,
    required PaymentMethod paymentMethod,
    required String category,
    required String subcategory,
    required String description,
    DateTime? date,
    String source = 'app',
  }) async {
    await saveExpense(
      amount: amount,
      scope: scope,
      paymentMethod: paymentMethod,
      category: category,
      subcategory: subcategory,
      description: description,
      date: date,
      source: source,
    );
  }

  /// Crea o actualiza un gasto (permitiendo modificar monto, categoría, subdivisión, medio o ámbito).
  Future<void> saveExpense({
    String? id,
    required double amount,
    required ExpenseScope scope,
    required PaymentMethod paymentMethod,
    required String category,
    required String subcategory,
    required String description,
    DateTime? date,
    String source = 'app',
  }) async {
    final now = DateTime.now().toUtc();
    final expenseDate = (date ?? now).toUtc();
    final recordId = id ?? _uuid.v4();
    final scopeDb = scope == ExpenseScope.personal ? 'personal' : 'business';
    final methodDb = paymentMethodToDb(paymentMethod);

    await _db.into(_db.expenses).insertOnConflictUpdate(
      ExpensesCompanion(
        id: Value(recordId),
        amount: Value(amount),
        scope: Value(scopeDb),
        paymentMethod: Value(methodDb),
        category: Value(category.trim()),
        subcategory: Value(subcategory.trim()),
        description: Value(description.trim()),
        date: Value(expenseDate),
        source: Value(source),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'expenses',
      recordId: recordId,
      operation: 'upsert',
      payload: {
        'id': recordId,
        'amount': amount,
        'scope': scopeDb,
        'payment_method': methodDb,
        'category': category.trim(),
        'subcategory': subcategory.trim(),
        'description': description.trim(),
        'date': expenseDate.toIso8601String(),
        'source': source,
        'updated_at': now.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();
  }

  Future<void> deleteExpense(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _db.enqueueSync(
      entityTable: 'expenses',
      recordId: id,
      operation: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );
    _syncEngine.syncPendingChanges();
  }

  ExpenseEntity _toEntity(Expense row) {
    return ExpenseEntity(
      id: row.id,
      amount: row.amount,
      scope: row.scope == 'personal' ? ExpenseScope.personal : ExpenseScope.business,
      paymentMethod: paymentMethodFromDb(row.paymentMethod),
      category: row.category,
      subcategory: row.subcategory,
      description: row.description,
      date: row.date.toLocal(),
      source: row.source,
    );
  }
}

String paymentMethodToDb(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'cash',
    PaymentMethod.nequi => 'nequi',
    PaymentMethod.daviplata => 'daviplata',
    PaymentMethod.bancolombia => 'bancolombia',
    PaymentMethod.transfer => 'transfer',
    PaymentMethod.other => 'other',
  };
}

PaymentMethod paymentMethodFromDb(String raw) {
  return switch (raw) {
    'nequi' => PaymentMethod.nequi,
    'daviplata' => PaymentMethod.daviplata,
    'bancolombia' => PaymentMethod.bancolombia,
    'transfer' => PaymentMethod.transfer,
    'other' => PaymentMethod.other,
    _ => PaymentMethod.cash,
  };
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
  );
});

final expensesStreamProvider = StreamProvider<List<ExpenseEntity>>((ref) {
  return ref.watch(financeRepositoryProvider).watchExpenses();
});

final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) {
  ref.watch(expensesStreamProvider);
  return ref.watch(financeRepositoryProvider).getFinanceSummary();
});
