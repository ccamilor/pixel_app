import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/entities/expense_entity.dart';

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(context, ref),
        icon: const Icon(Icons.remove_circle_outline),
        label: const Text('Registrar Gasto'),
      ),
    );
  }

  Future<void> _showAddExpenseDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var scope = ExpenseScope.business;
    var paymentMethod = PaymentMethod.cash;
    var category = defaultExpenseCategories.keys.first;
    var subcategory = defaultExpenseCategories[category]!.first;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final subcategories = defaultExpenseCategories[category] ?? const ['General'];
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Registrar Gasto'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monto (COP) *',
                        prefixText: r'$ ',
                      ),
                      validator: (v) {
                        final parsed = double.tryParse(v ?? '');
                        if (parsed == null || parsed <= 0) {
                          return 'Ingresa un monto válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ExpenseScope>(
                      segments: const [
                        ButtonSegment(
                          value: ExpenseScope.business,
                          label: Text('Negocio'),
                        ),
                        ButtonSegment(
                          value: ExpenseScope.personal,
                          label: Text('Personal'),
                        ),
                      ],
                      selected: {scope},
                      onSelectionChanged: (s) =>
                          setDialogState(() => scope = s.first),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod>(
                      initialValue: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Medio de pago',
                      ),
                      items: PaymentMethod.values
                          .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => paymentMethod = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: defaultExpenseCategories.keys
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            category = v;
                            subcategory = defaultExpenseCategories[v]!.first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: subcategories.contains(subcategory)
                          ? subcategory
                          : subcategories.first,
                      decoration: const InputDecoration(labelText: 'Subcategoría'),
                      items: subcategories
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => subcategory = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nota / Detalle (opcional)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  await ref.read(financeRepositoryProvider).addExpense(
                        amount: double.parse(amountCtrl.text),
                        scope: scope,
                        paymentMethod: paymentMethod,
                        category: category,
                        subcategory: subcategory,
                        description: descCtrl.text,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
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
