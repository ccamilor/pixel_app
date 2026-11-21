import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/entities/order_entity.dart';
import '../widgets/new_sale_dialog.dart';
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
        onPressed: () => showNewSaleDialog(context, ref),
        icon: const Icon(Icons.point_of_sale_rounded),
        label: const Text('Nueva Venta'),
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
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Editar venta / subdivisión',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: AppColors.accentCyan,
                  ),
                  onPressed: () =>
                      showNewSaleDialog(context, ref, order: order),
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
              '${order.category}${order.subcategory.isNotEmpty ? ' • ${order.subcategory}' : ''}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accentCyanMuted,
              ),
            ),
            const SizedBox(height: 2),
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
