import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../../finance/data/repositories/finance_repository.dart';
import '../../../finance/domain/entities/expense_entity.dart';
import '../../../orders/data/repositories/orders_repository.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../../../time_tracking/data/repositories/time_tracking_repository.dart';
import '../../../time_tracking/domain/entities/work_log_entity.dart';

enum _StatsRange {
  week('Esta Semana'),
  month('Este Mes'),
  all('Todo');

  const _StatsRange(this.label);
  final String label;
}

/// Centro completo de Estadísticas: Horarios trabajados, almuerzos/descansos,
/// ventas por categoría, gastos por categoría y edición manual de jornadas.
class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends ConsumerState<StatisticsPage> {
  _StatsRange _range = _StatsRange.month;

  bool _inRange(DateTime date) {
    final now = DateTime.now();
    return switch (_range) {
      _StatsRange.week => now.difference(date).inDays < 7,
      _StatsRange.month => date.year == now.year && date.month == now.month,
      _StatsRange.all => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(allWorkLogsProvider);
    final ordersAsync = ref.watch(ordersStreamProvider);
    final expensesAsync = ref.watch(expensesStreamProvider);

    final allLogs = logsAsync.asData?.value ?? const <WorkLogEntity>[];
    final allOrders = ordersAsync.asData?.value ?? const <OrderEntity>[];
    final allExpenses = expensesAsync.asData?.value ?? const <ExpenseEntity>[];

    final logs = allLogs.where((l) => _inRange(l.openTime)).toList();
    final orders = allOrders.where((o) => _inRange(o.createdAt)).toList();
    final expenses = allExpenses.where((e) => _inRange(e.date)).toList();

    // Métricas de tiempo y productividad
    final totalWorkedMin = logs.fold<int>(0, (s, l) => s + l.liveWorkedMinutes);
    final totalBreakMin = logs.fold<int>(0, (s, l) => s + l.totalBreakMinutes);
    final lunchMin = logs.fold<int>(
      0,
      (s, l) =>
          s +
          l.breaks
              .where((b) => b.type == WorkBreakType.lunch)
              .fold<int>(0, (bs, b) => bs + b.durationMinutes),
    );
    final errandMin = logs.fold<int>(
      0,
      (s, l) =>
          s +
          l.breaks
              .where((b) => b.type == WorkBreakType.businessErrand)
              .fold<int>(0, (bs, b) => bs + b.durationMinutes),
    );
    final totalPomodoros =
        orders.fold<int>(0, (s, o) => s + o.pomodoroSessionsCompleted);
    final totalProductionMin =
        orders.fold<int>(0, (s, o) => s + o.timeInvestedMinutes);

    // Métricas financieras
    final totalBilled = orders.fold<double>(0, (s, o) => s + o.totalPrice);
    final totalPaid = orders.fold<double>(0, (s, o) => s + o.amountPaid);
    final totalReceivable = orders.fold<double>(0, (s, o) => s + o.balanceDue);
    final deliveredCount =
        orders.where((o) => o.status == OrderStatus.delivered).length;

    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final businessExpenses = expenses
        .where((e) => e.scope == ExpenseScope.business)
        .fold<double>(0, (s, e) => s + e.amount);
    final personalExpenses = expenses
        .where((e) => e.scope == ExpenseScope.personal)
        .fold<double>(0, (s, e) => s + e.amount);
    final netProfit = totalPaid - totalExpenses;

    // Agrupaciones por categoría
    final salesByCategory = <String, double>{};
    for (final o in orders) {
      salesByCategory[o.category] =
          (salesByCategory[o.category] ?? 0) + o.totalPrice;
    }
    final expensesByCategory = <String, double>{};
    for (final e in expenses) {
      expensesByCategory[e.category] =
          (expensesByCategory[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estadísticas Completas',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => _showEditWorkLogDialog(context, ref),
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Agregar Jornada'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          SegmentedButton<_StatsRange>(
            showSelectedIcon: false,
            segments: _StatsRange.values
                .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                .toList(),
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 16),

          // Bloque 1: Horarios, Descansos y Productividad
          const _SectionTitle(
            icon: Icons.access_time_filled_rounded,
            title: 'Horarios Trabajados, Almuerzos y Descansos',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChipCard(
                label: 'Días Trabajados',
                value: '${logs.length}',
                accent: AppColors.accentCyan,
              ),
              _StatChipCard(
                label: 'Horas Netas Laboradas',
                value: AppFormatters.minutesToHoursLabel(totalWorkedMin),
                accent: AppColors.success,
              ),
              _StatChipCard(
                label: 'Almuerzos',
                value: AppFormatters.minutesToHoursLabel(lunchMin),
                accent: AppColors.warning,
              ),
              _StatChipCard(
                label: 'Descansos Totales',
                value: AppFormatters.minutesToHoursLabel(totalBreakMin),
                accent: AppColors.textSecondary,
              ),
              _StatChipCard(
                label: 'Diligencias Negocio',
                value: AppFormatters.minutesToHoursLabel(errandMin),
                accent: AppColors.primaryBlue,
              ),
              _StatChipCard(
                label: 'Tiempo en Pedidos / 🍅',
                value:
                    '${AppFormatters.minutesToHoursLabel(totalProductionMin)} • $totalPomodoros🍅',
                accent: AppColors.accentCyanMuted,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Bloque 2: Ventas, Gastos y Ganancia Neta
          const _SectionTitle(
            icon: Icons.bar_chart_rounded,
            title: 'Ventas, Gastos y Balance del Periodo',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChipCard(
                label: 'Total Facturado (${orders.length})',
                value: AppFormatters.currency(totalBilled),
                accent: AppColors.accentCyan,
              ),
              _StatChipCard(
                label: 'Recaudado Real',
                value: AppFormatters.currency(totalPaid),
                accent: AppColors.success,
              ),
              _StatChipCard(
                label: 'Gastos Totales',
                value: AppFormatters.currency(totalExpenses),
                subtitle:
                    'Negocio: ${AppFormatters.currency(businessExpenses)} • Personal: ${AppFormatters.currency(personalExpenses)}',
                accent: AppColors.error,
              ),
              _StatChipCard(
                label: 'Ganancia Neta',
                value: AppFormatters.currency(netProfit),
                accent: netProfit >= 0 ? AppColors.success : AppColors.error,
              ),
              _StatChipCard(
                label: 'Por Cobrar',
                value: AppFormatters.currency(totalReceivable),
                accent: AppColors.warning,
              ),
              _StatChipCard(
                label: 'Entregados',
                value: '$deliveredCount / ${orders.length}',
                accent: AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Bloque 3: Desglose por Categoría (Ventas vs Gastos)
          LayoutBuilder(
            builder: (context, constraints) {
              final salesCard = _CategoryBreakdownCard(
                title: 'Ventas por Categoría',
                data: salesByCategory,
                accent: AppColors.accentCyan,
              );
              final expensesCard = _CategoryBreakdownCard(
                title: 'Gastos por Categoría',
                data: expensesByCategory,
                accent: AppColors.error,
              );
              if (constraints.maxWidth >= 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: salesCard),
                    const SizedBox(width: 12),
                    Expanded(child: expensesCard),
                  ],
                );
              }
              return Column(
                children: [
                  salesCard,
                  const SizedBox(height: 12),
                  expensesCard,
                ],
              );
            },
          ),
          const SizedBox(height: 22),

          // Bloque 4: Historial Editable de Jornadas Laborales
          const _SectionTitle(
            icon: Icons.edit_calendar_rounded,
            title: 'Historial de Horarios Trabajados (Editable)',
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No hay jornadas registradas en este periodo.\nUsa "Agregar Jornada" arriba para cargar un día manualmente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            for (final log in logs) ...[
              Card(
                child: ListTile(
                  onTap: () => _showEditWorkLogDialog(context, ref, log: log),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryDeepBlue,
                    child: Text(
                      log.dateKey.substring(8),
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    '${log.dateKey} • Neto: ${AppFormatters.minutesToHoursLabel(log.liveWorkedMinutes)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Apertura: ${DateFormat('HH:mm').format(log.openTime)}'
                    '${log.closeTime != null ? ' • Cierre: ${DateFormat('HH:mm').format(log.closeTime!)}' : ' • En curso'}'
                    ' • Descansos: ${AppFormatters.minutesToHoursLabel(log.totalBreakMinutes)}'
                    '${log.notes != null && log.notes!.isNotEmpty ? '\n${log.notes}' : ''}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar horas trabajadas',
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.accentCyan,
                        ),
                        onPressed: () =>
                            _showEditWorkLogDialog(context, ref, log: log),
                      ),
                      IconButton(
                        tooltip: 'Eliminar jornada',
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => ref
                            .read(timeTrackingRepositoryProvider)
                            .deleteWorkLog(log.id),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _showEditWorkLogDialog(
    BuildContext context,
    WidgetRef ref, {
    WorkLogEntity? log,
  }) async {
    final isEditing = log != null;
    var selectedDate =
        log != null ? DateTime.parse(log.dateKey) : DateTime.now();
    var openTime = TimeOfDay.fromDateTime(
      log?.openTime ?? DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 8, 30),
    );
    TimeOfDay? closeTime = log?.closeTime != null
        ? TimeOfDay.fromDateTime(log!.closeTime!)
        : (isEditing ? null : const TimeOfDay(hour: 18, minute: 30));

    final breakCtrl = TextEditingController(
      text: '${log?.totalBreakMinutes ?? 60}',
    );
    final manualWorkedCtrl = TextEditingController(
      text: isEditing ? '${log.totalWorkedMinutes}' : '',
    );
    final notesCtrl = TextEditingController(text: log?.notes ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          DateTime combine(DateTime d, TimeOfDay t) =>
              DateTime(d.year, d.month, d.day, t.hour, t.minute);

          final openDt = combine(selectedDate, openTime);
          final closeDt =
              closeTime != null ? combine(selectedDate, closeTime!) : null;
          final breaksMin = int.tryParse(breakCtrl.text) ?? 0;
          final autoWorked = closeDt != null
              ? (closeDt.difference(openDt).inMinutes - breaksMin).clamp(0, 1440)
              : 0;

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                const Icon(Icons.edit_calendar_rounded, color: AppColors.accentCyan),
                const SizedBox(width: 8),
                Text(isEditing ? 'Editar Jornada (${log.dateKey})' : 'Agregar Jornada'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEditing)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Fecha'),
                        trailing: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              initialDate: selectedDate,
                            );
                            if (picked != null) {
                              setDialogState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hora de apertura'),
                      trailing: OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: openTime,
                          );
                          if (picked != null) {
                            setDialogState(() => openTime = picked);
                          }
                        },
                        child: Text(openTime.format(ctx)),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hora de cierre'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: closeTime ??
                                    const TimeOfDay(hour: 18, minute: 30),
                              );
                              if (picked != null) {
                                setDialogState(() => closeTime = picked);
                              }
                            },
                            child: Text(
                              closeTime != null ? closeTime!.format(ctx) : 'Sin cerrar',
                            ),
                          ),
                          if (closeTime != null)
                            IconButton(
                              tooltip: 'Dejar jornada abierta',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setDialogState(() => closeTime = null),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: breakCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutos de almuerzo / descansos',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: manualWorkedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Minutos trabajados (opcional, auto: $autoWorked min)',
                        helperText:
                            'Déjalo vacío para calcular automático (${AppFormatters.minutesToHoursLabel(autoWorked)})',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notas del día'),
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
                  final overrideMin = int.tryParse(manualWorkedCtrl.text.trim());
                  await ref.read(timeTrackingRepositoryProvider).saveWorkLogManual(
                        id: log?.id,
                        date: selectedDate,
                        openTime: openDt,
                        closeTime: closeDt,
                        totalBreakMinutes: breaksMin,
                        overrideWorkedMinutes: overrideMin,
                        notes: notesCtrl.text,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentCyan, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _StatChipCard extends StatelessWidget {
  const _StatChipCard({
    required this.label,
    required this.value,
    required this.accent,
    this.subtitle,
  });

  final String label;
  final String value;
  final Color accent;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({
    required this.title,
    required this.data,
    required this.accent,
  });

  final String title;
  final Map<String, double> data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = entries.isNotEmpty ? entries.first.value : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text(
                'Sin registros en este periodo.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              )
            else
              for (final entry in entries) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      AppFormatters.currency(entry.value),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: maxVal > 0 ? (entry.value / maxVal).clamp(0.0, 1.0) : 0,
                  backgroundColor: AppColors.surfaceElevated,
                  color: accent,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
