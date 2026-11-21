import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/print_calculator.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../inventory/domain/entities/material_entity.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/entities/order_entity.dart';

const String _customSaleOption = '__custom__';

/// Diálogo reutilizable para crear o EDITAR una Venta / Pedido con categorías y subdivisiones.
Future<void> showNewSaleDialog(
  BuildContext context,
  WidgetRef ref, {
  OrderEntity? order,
}) async {
  final isEditing = order != null;
  final clients = ref.read(clientsStreamProvider).asData?.value ?? const [];
  final materials = ref.read(materialsStreamProvider).asData?.value ?? const [];

  final titleCtrl = TextEditingController(text: order?.title ?? '');
  final manualPriceCtrl = TextEditingController(
    text: isEditing ? order.totalPrice.toStringAsFixed(0) : '',
  );
  final initialPayCtrl = TextEditingController(text: '0');
  final designFeeCtrl = TextEditingController(
    text: isEditing ? order.designFee.toStringAsFixed(0) : '0',
  );
  final notesCtrl = TextEditingController(text: order?.technicalNotes ?? '');
  final filePathCtrl = TextEditingController(text: order?.sourceFilePath ?? '');
  final widthCtrl = TextEditingController(text: '50');
  final heightCtrl = TextEditingController(text: '30');
  final qtyCtrl = TextEditingController(text: '1');
  final quickClientNameCtrl = TextEditingController();
  final quickClientPhoneCtrl = TextEditingController();

  ClientEntity? selectedClient;
  if (isEditing && clients.isNotEmpty) {
    selectedClient = clients.firstWhere(
      (c) => c.id == order.clientId,
      orElse: () => clients.first,
    );
  } else if (clients.isNotEmpty) {
    selectedClient = clients.first;
  }

  var createWalkInClient = !isEditing && clients.isEmpty;
  MaterialEntity? selectedMaterial =
      materials.isNotEmpty ? materials.first : null;
  var pricingMode = isEditing ? PricingMode.manual : PricingMode.manual;
  var finishingType = FinishingType.none;
  var priority = order?.priority ?? OrderPriority.medium;
  var payMethod = PaymentMethod.cash;
  var deductStock = false;
  var paidInFull = true;
  var deadline = order?.deadline ?? DateTime.now().add(const Duration(days: 1));

  // Categoría y subdivisión de la venta
  final initialCat = order?.category ?? defaultSaleCategories.keys.first;
  final isPresetCat = defaultSaleCategories.containsKey(initialCat);
  var selectedCatOption = isPresetCat ? initialCat : _customSaleOption;
  final customCatCtrl = TextEditingController(
    text: isPresetCat ? '' : initialCat,
  );

  final presetSubs =
      isPresetCat ? defaultSaleCategories[initialCat]! : const <String>[];
  final initialSub =
      order?.subcategory ?? (presetSubs.isNotEmpty ? presetSubs.first : '');
  final isPresetSub = isPresetCat && presetSubs.contains(initialSub);
  var selectedSubOption = isPresetSub
      ? initialSub
      : (initialSub.isNotEmpty
          ? _customSaleOption
          : (presetSubs.isNotEmpty ? presetSubs.first : _customSaleOption));
  final customSubCtrl = TextEditingController(
    text: isPresetSub ? '' : initialSub,
  );

  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final width = double.tryParse(widthCtrl.text) ?? 0;
        final height = double.tryParse(heightCtrl.text) ?? 0;
        final qty = int.tryParse(qtyCtrl.text) ?? 1;
        final designFee = double.tryParse(designFeeCtrl.text) ?? 0;

        final calc = PrintCalculator.calculateItem(
          widthCm: width,
          heightCm: height,
          quantity: qty,
          unitCostPerM2: selectedMaterial?.unitCost ?? 0,
          suggestedSalePricePerM2: selectedMaterial?.suggestedSalePrice ?? 45000,
          wastePercentage: selectedMaterial?.defaultWastePercentage ?? 15,
          finishingType: finishingType,
        );
        final autoTotal = calc.totalPrice + designFee;

        final currentSubs = selectedCatOption == _customSaleOption
            ? const <String>[]
            : (defaultSaleCategories[selectedCatOption] ?? const <String>[]);

        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit_rounded : Icons.point_of_sale_rounded,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 8),
              Text(isEditing ? 'Editar Venta / Pedido' : 'Nueva Venta / Pedido'),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (clients.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<ClientEntity>(
                              initialValue: selectedClient,
                              decoration: const InputDecoration(
                                labelText: 'Cliente',
                              ),
                              items: clients
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: createWalkInClient
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setDialogState(() => selectedClient = v);
                                      }
                                    },
                            ),
                          ),
                          if (!isEditing) ...[
                            const SizedBox(width: 8),
                            FilterChip(
                              selected: createWalkInClient,
                              label: const Text('Nuevo rápido'),
                              onSelected: (v) =>
                                  setDialogState(() => createWalkInClient = v),
                            ),
                          ],
                        ],
                      ),
                    if (createWalkInClient) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: quickClientNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nombre cliente (o "Cliente Mostrador")',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: quickClientPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'WhatsApp (opcional)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Concepto / Trabajo * (Ej. Calcomanía Tanque)',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa una descripción'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    // Categoría y Subdivisión de la Venta
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCatOption,
                            decoration: const InputDecoration(
                              labelText: 'Categoría Venta',
                            ),
                            items: [
                              ...defaultSaleCategories.keys.map(
                                (c) => DropdownMenuItem(value: c, child: Text(c)),
                              ),
                              const DropdownMenuItem(
                                value: _customSaleOption,
                                child: Text('+ Personalizada...'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setDialogState(() {
                                selectedCatOption = v;
                                if (v == _customSaleOption) {
                                  selectedSubOption = _customSaleOption;
                                } else {
                                  final subs =
                                      defaultSaleCategories[v] ?? const [];
                                  selectedSubOption = subs.isNotEmpty
                                      ? subs.first
                                      : _customSaleOption;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (currentSubs.isNotEmpty)
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  currentSubs.contains(selectedSubOption) ||
                                          selectedSubOption == _customSaleOption
                                      ? selectedSubOption
                                      : currentSubs.first,
                              decoration: const InputDecoration(
                                labelText: 'Subdivisión',
                              ),
                              items: [
                                ...currentSubs.map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: _customSaleOption,
                                  child: Text('+ Nueva...'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() => selectedSubOption = v);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                    if (selectedCatOption == _customSaleOption) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: customCatCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Categoría personalizada *',
                        ),
                        validator: (v) =>
                            selectedCatOption == _customSaleOption &&
                                    (v == null || v.trim().isEmpty)
                                ? 'Escribe la categoría'
                                : null,
                      ),
                    ],
                    if (selectedSubOption == _customSaleOption ||
                        currentSubs.isEmpty) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: customSubCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subdivisión personalizada (ej. Tanque MT-09)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<OrderPriority>(
                            initialValue: priority,
                            decoration: const InputDecoration(
                              labelText: 'Prioridad',
                            ),
                            items: OrderPriority.values
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setDialogState(() => priority = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                                initialDate: deadline,
                              );
                              if (picked != null) {
                                setDialogState(() => deadline = picked);
                              }
                            },
                            icon: const Icon(Icons.event),
                            label: Text(
                              DateFormat('dd/MM/yyyy').format(deadline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isEditing)
                      SegmentedButton<PricingMode>(
                        segments: const [
                          ButtonSegment(
                            value: PricingMode.manual,
                            label: Text('Precio Manual'),
                          ),
                          ButtonSegment(
                            value: PricingMode.auto,
                            label: Text('Calculadora m²'),
                          ),
                        ],
                        selected: {pricingMode},
                        onSelectionChanged: (s) =>
                            setDialogState(() => pricingMode = s.first),
                      ),
                    const SizedBox(height: 12),
                    if (pricingMode == PricingMode.manual || isEditing)
                      TextFormField(
                        controller: manualPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Valor de la Venta (COP) *',
                          prefixText: r'$ ',
                        ),
                        onChanged: (_) => setDialogState(() {}),
                        validator: (v) {
                          if (!isEditing && pricingMode != PricingMode.manual) {
                            return null;
                          }
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Ingresa el valor de la venta';
                          }
                          return null;
                        },
                      )
                    else ...[
                      if (materials.isNotEmpty)
                        DropdownButtonFormField<MaterialEntity>(
                          initialValue: selectedMaterial,
                          decoration: const InputDecoration(
                            labelText: 'Material',
                          ),
                          items: materials
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedMaterial = v),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: widthCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Ancho (cm)',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: heightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Alto (cm)',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cant.',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<FinishingType>(
                              initialValue: finishingType,
                              decoration: const InputDecoration(
                                labelText: 'Acabado',
                              ),
                              items: FinishingType.values
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(f.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() => finishingType = v);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: designFeeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cobro diseño',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: deductStock,
                        onChanged: (v) =>
                            setDialogState(() => deductStock = v ?? false),
                        title: Text(
                          'Descontar ${calc.billableAreaM2.toStringAsFixed(2)} m² del inventario',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDeepBlue.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.accentCyan),
                        ),
                        child: Text(
                          'Total calculado (con merma): ${AppFormatters.currency(autoTotal)}',
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (!isEditing) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: paidInFull,
                        activeThumbColor: AppColors.accentCyan,
                        title: const Text(
                          'Pagado en su totalidad ahora (entrada inmediata a caja)',
                          style: TextStyle(fontSize: 13),
                        ),
                        onChanged: (v) => setDialogState(() => paidInFull = v),
                      ),
                      Row(
                        children: [
                          if (!paidInFull) ...[
                            Expanded(
                              child: TextFormField(
                                controller: initialPayCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Abono inicial',
                                  prefixText: r'$ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: DropdownButtonFormField<PaymentMethod>(
                              initialValue: payMethod,
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
                                if (v != null) {
                                  setDialogState(() => payMethod = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: filePathCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ruta archivo PC (.cdr / .ai) opcional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notas técnicas / medidas',
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
                      .read(ordersRepositoryProvider)
                      .deleteOrder(order.id);
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
            FilledButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final finalCat = selectedCatOption == _customSaleOption
                    ? customCatCtrl.text.trim()
                    : selectedCatOption;
                final finalSub = (selectedSubOption == _customSaleOption ||
                        currentSubs.isEmpty)
                    ? customSubCtrl.text.trim()
                    : selectedSubOption;

                if (isEditing) {
                  await ref.read(ordersRepositoryProvider).updateOrderDetails(
                        orderId: order.id,
                        clientId: selectedClient?.id ?? order.clientId,
                        title: titleCtrl.text,
                        category: finalCat,
                        subcategory: finalSub,
                        deadline: deadline,
                        priority: priority,
                        totalPrice: double.parse(manualPriceCtrl.text),
                        designFee: designFee,
                        technicalNotes: notesCtrl.text,
                        sourceFilePath: filePathCtrl.text,
                      );
                  ref.invalidate(financeSummaryProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  return;
                }

                String clientId;
                if (createWalkInClient || selectedClient == null) {
                  final name = quickClientNameCtrl.text.trim().isEmpty
                      ? 'Cliente Mostrador'
                      : quickClientNameCtrl.text.trim();
                  final created = await ref
                      .read(clientRepositoryProvider)
                      .saveClient(
                        name: name,
                        phone: quickClientPhoneCtrl.text.trim(),
                      );
                  clientId = created.id;
                } else {
                  clientId = selectedClient!.id;
                }

                final finalPrice = pricingMode == PricingMode.manual
                    ? double.parse(manualPriceCtrl.text)
                    : autoTotal;
                final initialPayment = paidInFull
                    ? finalPrice
                    : (double.tryParse(initialPayCtrl.text) ?? 0);

                await ref.read(ordersRepositoryProvider).createOrder(
                      clientId: clientId,
                      title: titleCtrl.text,
                      category: finalCat,
                      subcategory: finalSub,
                      deadline: deadline,
                      priority: priority,
                      pricingMode: pricingMode,
                      designFee: designFee,
                      totalPrice: finalPrice,
                      initialPayment: initialPayment,
                      initialPaymentMethod: payMethod,
                      technicalNotes: notesCtrl.text,
                      sourceFilePath: filePathCtrl.text,
                      items: pricingMode == PricingMode.auto
                          ? [
                              OrderItemDraft(
                                materialId: selectedMaterial?.id,
                                description: titleCtrl.text,
                                widthCm: width,
                                heightCm: height,
                                quantity: qty,
                                wastePercentage:
                                    selectedMaterial?.defaultWastePercentage ??
                                        15,
                                finishingType: finishingType,
                                finishingSurcharge: calc.finishingSurcharge,
                                calculatedPrice: calc.totalPrice,
                                billableAreaM2: calc.billableAreaM2,
                                deductFromStock: deductStock,
                              ),
                            ]
                          : const [],
                    );
                ref.invalidate(financeSummaryProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(isEditing ? 'Guardar Cambios' : 'Registrar Venta'),
            ),
          ],
        );
      },
    ),
  );
}
