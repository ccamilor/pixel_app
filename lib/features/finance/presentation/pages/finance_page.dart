import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/presentation/widgets/new_sale_dialog.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/entities/expense_entity.dart';
import '../widgets/add_expense_dialog.dart';

/// Módulo Financiero: arqueo Efectivo vs. Digital, cuentas por cobrar y gastos unificados.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financeSummaryProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Módulo Financiero',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error cargando resumen: $e'),
            data: (summary) => _FinanceSummaryHeader(summary: summary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Gastos Diarios Unificados (Negocio + Personal)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay gastos registrados.\nPulsa "+ Registrar Gasto" para anotar tu flujo diario.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  for (final expense in expenses) ...[
                    _ExpenseTile(
                      expense: expense,
                      onDelete: () => ref
                          .read(financeRepositoryProvider)
                          .deleteExpense(expense.id),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: Wrap(
        spacing: 10,
        children: [
          FloatingActionButton.extended(
            heroTag: 'finance_new_sale',
            backgroundColor: AppColors.primaryDeepBlue,
            foregroundColor: AppColors.accentCyan,
            onPressed: () => showNewSaleDialog(context, ref),
            icon: const Icon(Icons.point_of_sale_rounded),
            label: const Text('Nueva Venta'),
          ),
          FloatingActionButton.extended(
            heroTag: 'finance_new_expense',
            onPressed: () => showAddExpenseDialog(context, ref),
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Registrar Gasto'),
          ),
        ],
      ),
    );
  }
}

class _FinanceSummaryHeader extends StatelessWidget {
  const _FinanceSummaryHeader({required this.summary});
  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(
          title: 'Efectivo en Caja',
          value: AppFormatters.currency(summary.netCashInDrawer),
          subtitle:
              'Entradas: ${AppFormatters.currency(summary.cashIncome)} | Salidas: ${AppFormatters.currency(summary.cashExpenses)}',
          accent: AppColors.success,
          icon: Icons.payments_outlined,
        ),
        _MetricCard(
          title: 'Cuentas Digitales',
          value: AppFormatters.currency(summary.netDigitalBalance),
          subtitle: 'Nequi / Daviplata / Banco',
          accent: AppColors.accentCyan,
          icon: Icons.smartphone_rounded,
        ),
        _MetricCard(
          title: 'Por Cobrar (Saldos)',
          value: AppFormatters.currency(summary.totalReceivable),
          subtitle: 'Abonos pendientes de pedidos',
          accent: AppColors.warning,
          icon: Icons.pending_actions_rounded,
        ),
        _MetricCard(
          title: 'Gastos Totales',
          value: AppFormatters.currency(summary.totalExpenses),
          subtitle:
              'Negocio: ${AppFormatters.currency(summary.businessExpenses)} | Personal: ${AppFormatters.currency(summary.personalExpenses)}',
          accent: AppColors.error,
          icon: Icons.trending_down_rounded,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onDelete});

  final ExpenseEntity expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('dd/MM HH:mm').format(expense.date);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: expense.scope == ExpenseScope.business
              ? AppColors.primaryDeepBlue
              : AppColors.surfaceElevated,
          child: Icon(
            expense.scope == ExpenseScope.business
                ? Icons.storefront_rounded
                : Icons.person_outline,
            color: AppColors.accentCyan,
            size: 20,
          ),
        ),
        title: Text(
          '${expense.category}${expense.subcategory.isNotEmpty ? ' • ${expense.subcategory}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${expense.paymentMethod.label} • $dateLabel${expense.description.isNotEmpty ? ' • ${expense.description}' : ''}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '-${AppFormatters.currency(expense.amount)}',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.textMuted,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
