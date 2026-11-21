import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../data/repositories/finance_repository.dart';
import '../../domain/entities/expense_entity.dart';

const String _customOption = '__custom__';

/// Diálogo reutilizable para crear o EDITAR un Gasto (con categorías y subdivisiones personalizadas).
Future<void> showAddExpenseDialog(
  BuildContext context,
  WidgetRef ref, {
  ExpenseEntity? expense,
}) async {
  final isEditing = expense != null;
  final amountCtrl = TextEditingController(
    text: isEditing ? expense.amount.toStringAsFixed(0) : '',
  );
  final descCtrl = TextEditingController(text: expense?.description ?? '');

  var scope = expense?.scope ?? ExpenseScope.business;
  var paymentMethod = expense?.paymentMethod ?? PaymentMethod.cash;

  final initialCat = expense?.category ?? defaultExpenseCategories.keys.first;
  final isPresetCat = defaultExpenseCategories.containsKey(initialCat);
  var selectedCatOption = isPresetCat ? initialCat : _customOption;
  final customCatCtrl = TextEditingController(
    text: isPresetCat ? '' : initialCat,
  );

  final presetSubs =
      isPresetCat ? defaultExpenseCategories[initialCat]! : const <String>[];
  final initialSub =
      expense?.subcategory ?? (presetSubs.isNotEmpty ? presetSubs.first : '');
  final isPresetSub =
      isPresetCat && presetSubs.contains(initialSub);
  var selectedSubOption =
      isPresetSub ? initialSub : (initialSub.isNotEmpty ? _customOption : (presetSubs.isNotEmpty ? presetSubs.first : _customOption));
  final customSubCtrl = TextEditingController(
    text: isPresetSub ? '' : initialSub,
  );

  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final currentSubs = selectedCatOption == _customOption
            ? const <String>[]
            : (defaultExpenseCategories[selectedCatOption] ?? const <String>[]);

        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_rounded : Icons.remove_circle_outline,
                color: isEditing ? AppColors.accentCyan : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Gasto' : 'Registrar Gasto'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
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
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => paymentMethod = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCatOption,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                      items: [
                        ...defaultExpenseCategories.keys.map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        ),
                        const DropdownMenuItem(
                          value: _customOption,
                          child: Text('+ Personalizada...'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          selectedCatOption = v;
                          if (v == _customOption) {
                            selectedSubOption = _customOption;
                          } else {
                            final subs = defaultExpenseCategories[v] ?? const [];
                            selectedSubOption =
                                subs.isNotEmpty ? subs.first : _customOption;
                          }
                        });
                      },
                    ),
                    if (selectedCatOption == _customOption) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: customCatCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la categoría *',
                        ),
                        validator: (v) =>
                            selectedCatOption == _customOption &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Escribe la categoría'
                                : null,
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (currentSubs.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: currentSubs.contains(selectedSubOption) ||
                                selectedSubOption == _customOption
                            ? selectedSubOption
                            : currentSubs.first,
                        decoration: const InputDecoration(
                          labelText: 'Subdivisión / Subcategoría',
                        ),
                        items: [
                          ...currentSubs.map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          ),
                          const DropdownMenuItem(
                            value: _customOption,
                            child: Text('+ Nueva subdivisión...'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => selectedSubOption = v);
                          }
                        },
                      ),
                    if (selectedSubOption == _customOption ||
                        currentSubs.isEmpty) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: customSubCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subdivisión personalizada (ej. Vinilo 3M, Cena)',
                        ),
                      ),
                    ],
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
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(financeRepositoryProvider)
                      .deleteExpense(expense.id);
                  ref.invalidate(financeSummaryProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Eliminar'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final finalCat = selectedCatOption == _customOption
                    ? customCatCtrl.text.trim()
                    : selectedCatOption;
                final finalSub = (selectedSubOption == _customOption ||
                        currentSubs.isEmpty)
                    ? customSubCtrl.text.trim()
                    : selectedSubOption;

                await ref.read(financeRepositoryProvider).saveExpense(
                      id: expense?.id,
                      amount: double.parse(amountCtrl.text),
                      scope: scope,
                      paymentMethod: paymentMethod,
                      category: finalCat,
                      subcategory: finalSub,
                      description: descCtrl.text,
                      date: expense?.date,
                      source: expense?.source ?? 'app',
                    );
                ref.invalidate(financeSummaryProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Guardar Cambios' : 'Guardar'),
            ),
          ],
        );
      },
    ),
  );
}
