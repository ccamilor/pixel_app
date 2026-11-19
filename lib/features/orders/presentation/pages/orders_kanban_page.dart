import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/print_calculator.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../clients/data/repositories/client_repository.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../inventory/domain/entities/material_entity.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/entities/order_entity.dart';
import '../widgets/order_timer_widget.dart';

/// Tablero Kanban Interactivo Adaptativo (Multicolumna en iPad/Web, Pestañas en Android).
class OrdersKanbanPage extends ConsumerWidget {
  const OrdersKanbanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersStreamProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tablero de Pedidos (Kanban)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error cargando pedidos: $e')),
        data: (orders) {
          if (isWide) {
            return _WideKanbanBoard(orders: orders);
          }
          return _MobileKanbanTabs(orders: orders);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(context, ref),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Nuevo Pedido'),
      ),
    );
  }

  Future<void> _showCreateOrderDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final clients = ref.read(clientsStreamProvider).asData?.value ?? const [];
    final materials =
        ref.read(materialsStreamProvider).asData?.value ?? const [];

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero registra al menos un cliente en la pestaña "Clientes".',
          ),
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final manualPriceCtrl = TextEditingController();
    final initialPayCtrl = TextEditingController(text: '0');
    final designFeeCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController();
    final filePathCtrl = TextEditingController();
    final widthCtrl = TextEditingController(text: '50');
    final heightCtrl = TextEditingController(text: '30');
    final qtyCtrl = TextEditingController(text: '1');

    ClientEntity selectedClient = clients.first;
    MaterialEntity? selectedMaterial =
        materials.isNotEmpty ? materials.first : null;
    var pricingMode = PricingMode.manual;
    var finishingType = FinishingType.none;
    var priority = OrderPriority.medium;
    var payMethod = PaymentMethod.cash;
    var deductStock = false;
    var deadline = DateTime.now().add(const Duration(days: 2));
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
            suggestedSalePricePerM2:
                selectedMaterial?.suggestedSalePrice ?? 45000,
            wastePercentage: selectedMaterial?.defaultWastePercentage ?? 15,
            finishingType: finishingType,
          );
          final autoTotal = calc.totalPrice + designFee;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Nuevo Pedido'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<ClientEntity>(
                        initialValue: selectedClient,
                        decoration: const InputDecoration(labelText: 'Cliente *'),
                        items: clients
                            .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedClient = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título del trabajo * (Ej. Kit Calcomanías Pulsar)',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa una descripción'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<OrderPriority>(
                              initialValue: priority,
                              decoration: const InputDecoration(labelText: 'Prioridad'),
                              items: OrderPriority.values
                                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
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
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                  initialDate: deadline,
                                );
                                if (picked != null) {
                                  setDialogState(() => deadline = picked);
                                }
                              },
                              icon: const Icon(Icons.event),
                              label: Text(DateFormat('dd/MM/yyyy').format(deadline)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                      if (pricingMode == PricingMode.manual)
                        TextFormField(
                          controller: manualPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Precio Total (COP) *',
                            prefixText: r'$ ',
                          ),
                          validator: (v) {
                            if (pricingMode != PricingMode.manual) return null;
                            final parsed = double.tryParse(v ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Ingresa el precio total';
                            }
                            return null;
                          },
                        )
                      else ...[
                        if (materials.isNotEmpty)
                          DropdownButtonFormField<MaterialEntity>(
                            initialValue: selectedMaterial,
                            decoration: const InputDecoration(labelText: 'Material'),
                            items: materials
                                .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
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
                                decoration: const InputDecoration(labelText: 'Ancho (cm)'),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: heightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Alto (cm)'),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Cant.'),
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
                                decoration: const InputDecoration(labelText: 'Acabado'),
                                items: FinishingType.values
                                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
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
                                decoration: const InputDecoration(labelText: 'Cobro diseño'),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
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
                          Expanded(
                            child: DropdownButtonFormField<PaymentMethod>(
                              initialValue: payMethod,
                              decoration: const InputDecoration(labelText: 'Medio'),
                              items: PaymentMethod.values
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setDialogState(() => payMethod = v);
                              },
                            ),
                          ),
                        ],
                      ),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final finalPrice = pricingMode == PricingMode.manual
                      ? double.parse(manualPriceCtrl.text)
                      : autoTotal;
                  final initialPayment = double.tryParse(initialPayCtrl.text) ?? 0;

                  await ref.read(ordersRepositoryProvider).createOrder(
                        clientId: selectedClient.id,
                        title: titleCtrl.text,
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
                                      selectedMaterial?.defaultWastePercentage ?? 15,
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
                child: const Text('Crear Pedido'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WideKanbanBoard extends ConsumerWidget {
  const _WideKanbanBoard({required this.orders});
  final List<OrderEntity> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        for (final status in OrderStatus.values)
          SizedBox(
            width: 310,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _KanbanColumn(
                status: status,
                orders: orders.where((o) => o.status == status).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _MobileKanbanTabs extends StatelessWidget {
  const _MobileKanbanTabs({required this.orders});
  final List<OrderEntity> orders;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: OrderStatus.values.length,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.accentCyan,
            labelColor: AppColors.accentCyan,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [
              for (final status in OrderStatus.values)
                Tab(
                  text:
                      '${status.label} (${orders.where((o) => o.status == status).length})',
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final status in OrderStatus.values)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    child: _KanbanColumn(
                      status: status,
                      orders: orders.where((o) => o.status == status).toList(),
                      showHeader: false,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends ConsumerWidget {
  const _KanbanColumn({
    required this.status,
    required this.orders,
    this.showHeader = true,
  });

  final OrderStatus status;
  final List<OrderEntity> orders;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<OrderEntity>(
      onAcceptWithDetails: (details) {
        if (details.data.status != status) {
          ref.read(ordersRepositoryProvider).updateOrderWorkflow(
                orderId: details.data.id,
                status: status,
              );
        }
      },
      builder: (context, candidateData, _) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighlighted ? AppColors.accentCyan : AppColors.border,
              width: isHighlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          status.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primaryDeepBlue,
                        child: Text(
                          '${orders.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: orders.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin pedidos aquí',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Draggable<OrderEntity>(
                            data: order,
                            feedback: Material(
                              color: Colors.transparent,
                              child: SizedBox(
                                width: 280,
                                child: _OrderCard(order: order),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _OrderCard(order: order),
                            ),
                            child: _OrderCard(order: order),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});
  final OrderEntity order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(ordersRepositoryProvider);
    final deadlineStr = DateFormat('dd/MM').format(order.deadline);

    return Card(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                PopupMenuButton<OrderStatus>(
                  tooltip: 'Mover a otra columna',
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (nextStatus) => repo.updateOrderWorkflow(
                    orderId: order.id,
                    status: nextStatus,
                  ),
                  itemBuilder: (_) => OrderStatus.values
                      .map(
                        (s) => PopupMenuItem(
                          value: s,
                          child: Text('Mover a: ${s.label}'),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            Text(
              '${order.clientName} • Entrega: $deadlineStr',
              style: TextStyle(
                fontSize: 12,
                color: order.isOverdue ? AppColors.error : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (order.status == OrderStatus.design)
              FilterChip(
                selected: order.designApproved,
                label: Text(
                  order.designApproved
                      ? 'Diseño aprobado'
                      : 'Esperando aprobación',
                  style: const TextStyle(fontSize: 11),
                ),
                onSelected: (approved) => repo.updateOrderWorkflow(
                  orderId: order.id,
                  designApproved: approved,
                ),
              ),
            if (order.status == OrderStatus.printing)
              DropdownButton<PrintStage>(
                isExpanded: true,
                value: order.printStage,
                underline: const SizedBox.shrink(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.accentCyan,
                ),
                items: PrintStage.values
                    .map((s) => DropdownMenuItem(value: s, child: Text('Etapa: ${s.label}')))
                    .toList(),
                onChanged: (stage) {
                  if (stage != null) {
                    repo.updateOrderWorkflow(
                      orderId: order.id,
                      printStage: stage,
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
            OrderTimerWidget(order: order),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total: ${AppFormatters.currency(order.totalPrice)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        order.balanceDue > 0
                            ? 'Saldo: ${AppFormatters.currency(order.balanceDue)}'
                            : 'Pagado completo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: order.balanceDue > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                if (order.balanceDue > 0)
                  IconButton(
                    tooltip: 'Registrar abono',
                    icon: const Icon(
                      Icons.attach_money_rounded,
                      color: AppColors.accentCyan,
                    ),
                    onPressed: () => _showAddPaymentDialog(context, ref, order),
                  ),
                if (order.clientPhone.isNotEmpty)
                  IconButton(
                    tooltip: 'Enviar WhatsApp al cliente',
                    icon: const Icon(
                      Icons.chat_rounded,
                      color: AppColors.success,
                    ),
                    onPressed: () {
                      final msg = WhatsAppLauncher.buildOrderMessage(
                        clientName: order.clientName,
                        orderTitle: order.title,
                        status: order.status,
                        balanceDue: order.balanceDue,
                      );
                      WhatsAppLauncher.openChat(
                        phone: order.clientPhone,
                        message: msg,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    OrderEntity order,
  ) async {
    final amountCtrl = TextEditingController(
      text: order.balanceDue.toStringAsFixed(0),
    );
    final notesCtrl = TextEditingController();
    var method = PaymentMethod.cash;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Abono: ${order.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monto recibido (COP)',
                  prefixText: r'$ ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Medio de pago'),
                items: PaymentMethod.values
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => method = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                await ref.read(ordersRepositoryProvider).addPayment(
                      orderId: order.id,
                      amount: amount,
                      paymentMethod: method,
                      notes: notesCtrl.text,
                    );
                ref.invalidate(financeSummaryProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Registrar Abono'),
            ),
          ],
        ),
      ),
    );
  }
}
