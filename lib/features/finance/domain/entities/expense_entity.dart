import '../../../../core/constants/app_enums.dart';

/// Entidad de dominio para Gastos Diarios Unificados (Negocio y Personal).
class ExpenseEntity {
  const ExpenseEntity({
    required this.id,
    required this.amount,
    required this.scope,
    required this.paymentMethod,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.date,
    required this.source,
  });

  final String id;
  final double amount;
  final ExpenseScope scope;
  final PaymentMethod paymentMethod;
  final String category;
  final String subcategory;
  final String description;
  final DateTime date;
  final String source;
}

/// Resumen financiero unificado con arqueo separado (Efectivo vs. Cuentas Digitales).
class FinanceSummary {
  const FinanceSummary({
    required this.totalIncome,
    required this.cashIncome,
    required this.digitalIncome,
    required this.totalExpenses,
    required this.businessExpenses,
    required this.personalExpenses,
    required this.cashExpenses,
    required this.digitalExpenses,
    required this.totalReceivable,
  });

  final double totalIncome;
  final double cashIncome;
  final double digitalIncome;
  final double totalExpenses;
  final double businessExpenses;
  final double personalExpenses;
  final double cashExpenses;
  final double digitalExpenses;
  final double totalReceivable;

  double get netCashInDrawer => cashIncome - cashExpenses;
  double get netDigitalBalance => digitalIncome - digitalExpenses;
  double get netTotalBalance => totalIncome - totalExpenses;
}
