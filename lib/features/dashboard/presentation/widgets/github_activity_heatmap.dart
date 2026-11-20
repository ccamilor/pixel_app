import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../time_tracking/domain/entities/work_log_entity.dart';

enum HeatmapMetricMode {
  combined('Combinado'),
  hours('Solo Horas'),
  orders('Solo Entregas');

  const HeatmapMetricMode(this.label);
  final String label;
}

/// Mapa de Calor estilo GitHub (12 semanas) con etiquetas de días (Lun–Dom),
/// cabeceras de mes, resumen semanal y selección interactiva de cualquier día.
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
  static const List<String> _dayLabels = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];
  static const List<String> _monthShortEs = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  HeatmapMetricMode _mode = HeatmapMetricMode.combined;
  DateTime? _selectedDate;

  int _levelForDay(
    String key,
    Map<String, int> hoursByDay,
    Map<String, int> ordersByDay,
  ) {
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

    // Alinear el inicio exactamente al Lunes (weekday == 1) para que las filas correspondan a Lun..Dom
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final startMonday = currentWeekMonday.subtract(
      Duration(days: (widget.weeks - 1) * 7),
    );

    // Métricas rápidas de los últimos 7 días
    int activeDaysLast7 = 0;
    int minutesLast7 = 0;
    int ordersLast7 = 0;
    for (var i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final k = DateFormat('yyyy-MM-dd').format(d);
      final mins = hoursByDay[k] ?? 0;
      final ord = ordersByDay[k] ?? 0;
      if (mins > 0 || ord > 0) activeDaysLast7++;
      minutesLast7 += mins;
      ordersLast7 += ord;
    }

    final selected = _selectedDate ?? today;
    final selectedKey = DateFormat('yyyy-MM-dd').format(selected);
    final selectedMins = hoursByDay[selectedKey] ?? 0;
    final selectedOrders = ordersByDay[selectedKey] ?? 0;
    final selectedDayName = _dayLabels[selected.weekday - 1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Actividad Semanal (Mapa de Calor)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  'Últimos 7 días: $activeDaysLast7/7 activos',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.accentCyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Horas semana: ${AppFormatters.minutesToHoursLabel(minutesLast7)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Pedidos semana: $ordersLast7',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<HeatmapMetricMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                segments: HeatmapMetricMode.values
                    .map(
                      (m) => ButtonSegment(
                        value: m,
                        label: Text(
                          m.label,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Columna fija de etiquetas de días (Lun - Dom)
                  Padding(
                    padding: const EdgeInsets.only(top: 18, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final label in _dayLabels)
                          Container(
                            height: 18,
                            margin: const EdgeInsets.only(bottom: 4),
                            alignment: Alignment.centerRight,
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Columnas semanales con encabezado de mes
                  ...List.generate(widget.weeks, (weekIndex) {
                    final weekStart = startMonday.add(
                      Duration(days: weekIndex * 7),
                    );
                    final prevWeekStart = weekIndex > 0
                        ? startMonday.add(Duration(days: (weekIndex - 1) * 7))
                        : null;
                    final showMonth =
                        prevWeekStart == null ||
                        weekStart.month != prevWeekStart.month;

                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 16,
                            child: showMonth
                                ? Text(
                                    _monthShortEs[weekStart.month - 1],
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 2),
                          ...List.generate(7, (dayIndex) {
                            final date = weekStart.add(Duration(days: dayIndex));
                            final isFuture = date.isAfter(today);
                            final key = DateFormat('yyyy-MM-dd').format(date);
                            final level = isFuture
                                ? 0
                                : _levelForDay(key, hoursByDay, ordersByDay);
                            final mins = hoursByDay[key] ?? 0;
                            final ord = ordersByDay[key] ?? 0;
                            final isSelected = key == selectedKey;
                            final isToday =
                                date.year == today.year &&
                                date.month == today.month &&
                                date.day == today.day;

                            return Tooltip(
                              message: isFuture
                                  ? '${_dayLabels[dayIndex]} ${DateFormat('dd/MM').format(date)}'
                                  : '${_dayLabels[dayIndex]} ${DateFormat('dd/MM/yyyy').format(date)} • ${AppFormatters.minutesToHoursLabel(mins)} • $ord pedidos',
                              child: GestureDetector(
                                onTap: isFuture
                                    ? null
                                    : () => setState(() => _selectedDate = date),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: isFuture
                                        ? AppColors.background
                                        : AppColors.heatmapScale[level],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentCyan
                                          : isToday
                                              ? AppColors.textPrimary
                                              : level == 0
                                                  ? AppColors.border
                                                  : AppColors.accentCyan
                                                      .withValues(alpha: 0.35),
                                      width: isSelected || isToday ? 1.5 : 0.7,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Detalle del día seleccionado (o de hoy por defecto)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$selectedDayName ${DateFormat('dd/MM/yyyy').format(selected)}: '
                      '${AppFormatters.minutesToHoursLabel(selectedMins)} trabajadas • $selectedOrders pedidos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
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
