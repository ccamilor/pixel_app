import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/database/sync_engine.dart';
import '../../../../core/network/supabase_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/widgets/cloud_sync_dialog.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../finance/presentation/widgets/add_expense_dialog.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../orders/data/repositories/orders_repository.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/presentation/widgets/new_sale_dialog.dart';
import '../../../time_tracking/data/repositories/time_tracking_repository.dart';
import '../../../time_tracking/domain/entities/work_log_entity.dart';
import '../widgets/github_activity_heatmap.dart';

/// Dashboard Principal: Control de Jornada, Mapa de Calor GitHub, Arqueo de Caja y Alertas.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayLogAsync = ref.watch(todayWorkLogProvider);
    final allLogsAsync = ref.watch(allWorkLogsProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final financeAsync = ref.watch(financeSummaryProvider);
    final materialsAsync = ref.watch(materialsStreamProvider);
    final pendingSyncAsync = ref.watch(pendingSyncCountProvider);

    final orders = ordersAsync.asData?.value ?? const [];
    final activeOrders =
        orders.where((o) => o.status != OrderStatus.delivered).length;
    final now = DateTime.now();
    final todayOrders = orders.where((o) {
      final created = o.createdAt;
      return created.year == now.year &&
          created.month == now.month &&
          created.day == now.day;
    }).toList();
    final todaySalesTotal =
        todayOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final lowStockMaterials = (materialsAsync.asData?.value ?? const [])
        .where((m) => m.isLowStock)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (MediaQuery.sizeOf(context).width < 600) ...[
              Image.asset(
                'assets/images/pixel_logo.png',
                width: 30,
                height: 30,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                'Pixel App',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.pacifico(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentCyan,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (MediaQuery.sizeOf(context).width >= 480) ...[
              const SizedBox(width: 10),
              const Text(
                '• Dashboard',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          pendingSyncAsync.when(
            data: (count) {
              final authUser =
                  ref.watch(authStateProvider).asData?.value ??
                  SupabaseConfig.clientOrNull?.auth.currentUser;
              final isCloudActive =
                  SupabaseConfig.isConfigured && authUser != null;

              final label = !SupabaseConfig.isConfigured
                  ? 'Modo Local'
                  : !isCloudActive
                      ? 'Conectar Nube'
                      : count == 0
                          ? 'Sincronizado'
                          : '$count en cola';

              final accentColor = !SupabaseConfig.isConfigured
                  ? AppColors.textSecondary
                  : !isCloudActive
                      ? AppColors.warning
                      : count == 0
                          ? AppColors.success
                          : AppColors.accentCyan;

              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: ActionChip(
                  onPressed: () => showCloudSyncDialog(context, ref),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.surfaceElevated,
                  side: BorderSide(color: accentColor),
                  avatar: Icon(
                    !isCloudActive
                        ? Icons.cloud_off_outlined
                        : count == 0
                            ? Icons.cloud_done_outlined
                            : Icons.sync_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                  label: Text(
                    label,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          todayLogAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error jornada: $e'),
            data: (todayLog) => _WorkShiftCard(todayLog: todayLog),
          ),
          const SizedBox(height: 16),
          financeAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) {
              final topRowCards = [
                _QuickStatCard(
                  label: 'Ventas del Día (${todayOrders.length})',
                  value: AppFormatters.currency(todaySalesTotal),
                  color: AppColors.success,
                  icon: Icons.point_of_sale_rounded,
                  onTap: () => context.go(AppRoutes.orders),
                ),
                _QuickStatCard(
                  label: 'Pedidos Activos',
                  value: '$activeOrders',
                  color: AppColors.primaryBlue,
                  icon: Icons.view_kanban_outlined,
                  onTap: () => context.go(AppRoutes.orders),
                ),
                _QuickStatCard(
                  label: 'Por Cobrar',
                  value: AppFormatters.currency(summary.totalReceivable),
                  color: AppColors.warning,
                  icon: Icons.pending_actions_rounded,
                  onTap: () => context.go(AppRoutes.orders),
                ),
              ];

              final bottomRowCards = [
                _QuickStatCard(
                  label: 'Dinero Total',
                  value: AppFormatters.currency(summary.netTotalBalance),
                  color: AppColors.accentCyan,
                  icon: Icons.account_balance_wallet_rounded,
                  highlighted: true,
                  onTap: () => context.go(AppRoutes.finance),
                ),
                _QuickStatCard(
                  label: 'Cuenta Digital',
                  value: AppFormatters.currency(summary.netDigitalBalance),
                  color: AppColors.accentCyanMuted,
                  icon: Icons.smartphone_rounded,
                  onTap: () => context.go(AppRoutes.finance),
                ),
                _QuickStatCard(
                  label: 'Efectivo',
                  value: AppFormatters.currency(summary.netCashInDrawer),
                  color: AppColors.success,
                  icon: Icons.payments_outlined,
                  onTap: () => context.go(AppRoutes.finance),
                ),
              ];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatRowGrid(cards: topRowCards),
                  const SizedBox(height: 12),
                  _StatRowGrid(cards: bottomRowCards),
                  if (lowStockMaterials > 0) ...[
                    const SizedBox(height: 12),
                    _QuickStatCard(
                      label: 'Alertas Stock Bajo',
                      value: '$lowStockMaterials',
                      color: AppColors.error,
                      icon: Icons.warning_amber_rounded,
                      fullWidth: true,
                      onTap: () => context.go(AppRoutes.clientsInventory),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _TodaySalesSection(todayOrders: todayOrders),
          const SizedBox(height: 16),
          GithubActivityHeatmap(
            workLogs: allLogsAsync.asData?.value ?? const [],
            orders: orders,
          ),
        ],
      ),
    );
  }
}

class _WorkShiftCard extends ConsumerWidget {
  const _WorkShiftCard({required this.todayLog});
  final WorkLogEntity? todayLog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(timeTrackingRepositoryProvider);
    final activeBreak = todayLog?.activeBreak;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: todayLog != null && todayLog!.isOpen
              ? AppColors.accentCyan
              : AppColors.border,
          width: todayLog != null && todayLog!.isOpen ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time_filled_rounded,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Control de Jornada Laboral',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (todayLog != null)
                  Text(
                    'Neto: ${AppFormatters.minutesToHoursLabel(todayLog!.liveWorkedMinutes)}',
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (todayLog == null) ...[
              const Text(
                'Aún no has registrado la apertura del local hoy.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => repo.openWorkDay(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar Jornada Ahora'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showNewSaleDialog(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryDeepBlue,
                      foregroundColor: AppColors.accentCyan,
                    ),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('Nueva Venta'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showAddExpenseDialog(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.6),
                      ),
                    ),
                    icon: const Icon(Icons.remove_circle_outline),
                    label: const Text('Agregar Gasto'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Apertura: ${DateFormat('hh:mm a').format(todayLog!.openTime)}'
                '${todayLog!.closeTime != null ? ' • Cierre: ${DateFormat('hh:mm a').format(todayLog!.closeTime!)}' : ' • Local Abierto'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (activeBreak != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle, color: AppColors.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'En pausa: ${activeBreak.type.label} (${activeBreak.durationMinutes} min)',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () =>
                            repo.endBreak(activeBreak.id, todayLog!.id),
                        child: const Text('Reanudar'),
                      ),
                    ],
                  ),
                ),
              ],
              if (todayLog!.isOpen && activeBreak == null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => showNewSaleDialog(context, ref),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('Nueva Venta'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showAddExpenseDialog(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Agregar Gasto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => repo.startBreak(
                        workLogId: todayLog!.id,
                        type: WorkBreakType.lunch,
                      ),
                      icon: const Icon(Icons.restaurant_rounded, size: 18),
                      label: const Text('Almuerzo'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => repo.startBreak(
                        workLogId: todayLog!.id,
                        type: WorkBreakType.businessErrand,
                        notes: 'Diligencia del negocio',
                      ),
                      icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                      label: const Text('Diligencia'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => repo.closeWorkDay(todayLog!.id),
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Cerrar Jornada'),
                    ),
                  ],
                ),
              ] else if (!todayLog!.isOpen) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => showNewSaleDialog(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDeepBlue,
                        foregroundColor: AppColors.accentCyan,
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                      label: const Text('Nueva Venta'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showAddExpenseDialog(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.6),
                        ),
                      ),
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      label: const Text('Agregar Gasto'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TodaySalesSection extends ConsumerWidget {
  const _TodaySalesSection({required this.todayOrders});
  final List<OrderEntity> todayOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = todayOrders.fold<double>(0, (sum, o) => sum + o.totalPrice);
    final collected =
        todayOrders.fold<double>(0, (sum, o) => sum + o.amountPaid);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ventas del Día',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Facturado: ${AppFormatters.currency(total)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            if (todayOrders.isEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Aún no has registrado ventas hoy. Pulsa "Nueva Venta" para comenzar.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Recaudado hoy: ${AppFormatters.currency(collected)} • ${todayOrders.length} ${todayOrders.length == 1 ? 'venta' : 'ventas'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              const Divider(),
              for (final order in todayOrders) ...[
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => showNewSaleDialog(context, ref, order: order),
                  title: Text(
                    order.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${order.category}${order.subcategory.isNotEmpty ? ' • ${order.subcategory}' : ''} • ${order.clientName} • ${DateFormat('hh:mm a').format(order.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.currency(order.totalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        order.balanceDue > 0
                            ? 'Saldo: ${AppFormatters.currency(order.balanceDue)}'
                            : 'Pagado',
                        style: TextStyle(
                          fontSize: 11,
                          color: order.balanceDue > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRowGrid extends StatelessWidget {
  const _StatRowGrid({required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i < cards.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.highlighted = false,
    this.fullWidth = false,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool highlighted;
  final bool fullWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: highlighted ? color : AppColors.border,
            width: highlighted ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
