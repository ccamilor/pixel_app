import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../data/repositories/finance_repository.dart';

/// Diálogo reutilizable para registrar un Gasto (Negocio o Personal) desde Dashboard o Finanzas.
Future<void> showAddExpenseDialog(BuildContext context, WidgetRef ref) async {
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
        final subcategories =
            defaultExpenseCategories[category] ?? const ['General'];
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.remove_circle_outline, color: AppColors.error),
              SizedBox(width: 8),
              Text('Registrar Gasto'),
            ],
          ),
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
                        .map(
                          (m) =>
                              DropdownMenuItem(value: m, child: Text(m.label)),
                        )
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
                    decoration: const InputDecoration(
                      labelText: 'Subcategoría',
                    ),
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
                ref.invalidate(financeSummaryProvider);
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
