import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../time_tracking/domain/entities/work_log_entity.dart';

enum HeatmapMetricMode {
  combined('Combinado'),
  hours('Solo Horas'),
  orders('Solo Entregas');

  const HeatmapMetricMode(this.label);
  final String label;
}

/// Mapa de Calor estilo GitHub (12 semanas) en tonos OLED azul/cian con selector de métrica.
class GithubActivityHeatmap extends StatefulWidget {
  const GithubActivityHeatmap({
    required this.workLogs,
    required this.orders,
    this.weeks = 12,
    super.key,
  });

  final List<WorkLogEntity> workLogs;
  final List<OrderEntity> orders;
  final int weeks;

  @override
  State<GithubActivityHeatmap> createState() => _GithubActivityHeatmapState();
}

class _GithubActivityHeatmapState extends State<GithubActivityHeatmap> {
  HeatmapMetricMode _mode = HeatmapMetricMode.combined;

  int _levelForDay(String key, Map<String, int> hoursByDay, Map<String, int> ordersByDay) {
    final mins = hoursByDay[key] ?? 0;
    final count = ordersByDay[key] ?? 0;

    return switch (_mode) {
      HeatmapMetricMode.hours => _scoreMinutes(mins),
      HeatmapMetricMode.orders => _scoreOrders(count),
      HeatmapMetricMode.combined =>
        ((_scoreMinutes(mins) + _scoreOrders(count)) / 2).ceil().clamp(0, 4),
    };
  }

  int _scoreMinutes(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 180) return 1;
    if (minutes < 360) return 2;
    if (minutes < 480) return 3;
    return 4;
  }

  int _scoreOrders(int count) {
    if (count <= 0) return 0;
    if (count == 1) return 1;
    if (count == 2) return 2;
    if (count <= 4) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final hoursByDay = <String, int>{};
    for (final log in widget.workLogs) {
      hoursByDay[log.dateKey] = log.liveWorkedMinutes;
    }

    final ordersByDay = <String, int>{};
    for (final order in widget.orders) {
      final key = DateFormat('yyyy-MM-dd').format(order.updatedAt);
      ordersByDay[key] = (ordersByDay[key] ?? 0) + 1;
    }

    final today = DateTime.now();
    final totalDays = widget.weeks * 7;
    final startDate = today.subtract(Duration(days: totalDays - 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                const Text(
                  'Actividad Semanal (Mapa de Calor)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                SegmentedButton<HeatmapMetricMode>(
                  showSelectedIcon: false,
                  segments: HeatmapMetricMode.values
                      .map(
                        (m) => ButtonSegment(
                          value: m,
                          label: Text(m.label, style: const TextStyle(fontSize: 11)),
                        ),
                      )
                      .toList(),
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(widget.weeks, (weekIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      children: List.generate(7, (dayIndex) {
                        final date = startDate.add(
                          Duration(days: (weekIndex * 7) + dayIndex),
                        );
                        final key = DateFormat('yyyy-MM-dd').format(date);
                        final level = _levelForDay(key, hoursByDay, ordersByDay);
                        final mins = hoursByDay[key] ?? 0;
                        final ord = ordersByDay[key] ?? 0;

                        return Tooltip(
                          message:
                              '${DateFormat('dd/MM/yyyy').format(date)} • ${(mins / 60).toStringAsFixed(1)}h • $ord pedidos',
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: AppColors.heatmapScale[level],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: level == 0
                                    ? AppColors.border
                                    : AppColors.accentCyan.withValues(alpha: 0.25),
                                width: 0.7,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Menos ',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                for (final color in AppColors.heatmapScale)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                  ),
                const Text(
                  ' Más',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
