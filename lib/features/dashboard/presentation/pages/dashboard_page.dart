import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/database/sync_engine.dart';
import '../../../../core/utils/formatters.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../inventory/data/repositories/inventory_repository.dart';
import '../../../orders/data/repositories/orders_repository.dart';
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
    final lowStockMaterials = (materialsAsync.asData?.value ?? const [])
        .where((m) => m.isLowStock)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard Principal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          pendingSyncAsync.when(
            data: (count) => Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Chip(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.surfaceElevated,
                side: BorderSide(
                  color: count == 0 ? AppColors.success : AppColors.accentCyan,
                ),
                avatar: Icon(
                  count == 0 ? Icons.cloud_done_outlined : Icons.sync_rounded,
                  size: 16,
                  color: count == 0 ? AppColors.success : AppColors.accentCyan,
                ),
                label: Text(
                  count == 0 ? 'Sincronizado' : '$count en cola',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
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
            data: (summary) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickStatCard(
                  label: 'Efectivo Físico',
                  value: AppFormatters.currency(summary.netCashInDrawer),
                  color: AppColors.success,
                  icon: Icons.payments_outlined,
                ),
                _QuickStatCard(
                  label: 'Cuentas Digitales',
                  value: AppFormatters.currency(summary.netDigitalBalance),
                  color: AppColors.accentCyan,
                  icon: Icons.smartphone_rounded,
                ),
                _QuickStatCard(
                  label: 'Pedidos Activos',
                  value: '$activeOrders',
                  color: AppColors.primaryBlue,
                  icon: Icons.view_kanban_outlined,
                ),
                _QuickStatCard(
                  label: 'Por Cobrar',
                  value: AppFormatters.currency(summary.totalReceivable),
                  color: AppColors.warning,
                  icon: Icons.pending_actions_rounded,
                ),
                if (lowStockMaterials > 0)
                  _QuickStatCard(
                    label: 'Alertas Stock Bajo',
                    value: '$lowStockMaterials',
                    color: AppColors.error,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),
          ),
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
              FilledButton.icon(
                onPressed: () => repo.openWorkDay(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar Jornada Ahora'),
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
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
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
    );
  }
}
