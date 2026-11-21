import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/reminders/data/repositories/daily_reminders_repository.dart';
import '../constants/app_colors.dart';
import '../network/live_widgets_service.dart';

enum _ModalTab { weather, sports, reminders }

/// Panel de widgets en vivo:
/// - En barra lateral extendida (iPad/PC): 4 tarjetas del mismo ancho (Recordatorios de Hoy, Fútbol, Clima, Reloj 24H).
/// - En barra superior móvil (`mobileBar = true`): franja limpia sin superposición con Reloj 24H + accesos a Clima, Fútbol y Recordatorios.
/// - En NavigationRail colapsado (`compact = true`): bloque vertical compacto.
class LiveClockBadge extends ConsumerStatefulWidget {
  const LiveClockBadge({
    this.compact = false,
    this.mobileBar = false,
    super.key,
  });

  final bool compact;
  final bool mobileBar;

  @override
  ConsumerState<LiveClockBadge> createState() => _LiveClockBadgeState();
}

class _LiveClockBadgeState extends ConsumerState<LiveClockBadge> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openDetailsModal(BuildContext context, _ModalTab initialTab) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _LiveInfoDialog(initialTab: initialTab),
    );
  }

  BoxDecoration _cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.surfaceElevated.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? AppColors.accentCyan.withValues(alpha: 0.4),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.background.withValues(alpha: 0.75),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_now);
    final dateStr = DateFormat('dd/MM/yyyy').format(_now);
    final weatherAsync = ref.watch(weatherInfoProvider);
    final sportsAsync = ref.watch(sportsFeedProvider);
    final remindersAsync = ref.watch(todayRemindersProvider);
    final reminders = remindersAsync.asData?.value ?? const [];
    final pendingReminders = reminders.where((r) => !r.isDone).length;

    // 1) Franja superior limpia para iPhone / Android vertical (cero superposiciones, cero overflow en 360px+)
    if (widget.mobileBar) {
      final weatherTemp = weatherAsync.asData?.value != null
          ? '${weatherAsync.asData!.value.temperatureC.toStringAsFixed(0)}°'
          : '';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 14,
              color: AppColors.accentCyan,
            ),
            const SizedBox(width: 4),
            Text(
              DateFormat('HH:mm').format(_now),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                DateFormat('dd/MM').format(_now),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            _MobileMiniPill(
              icon: Icons.cloud_outlined,
              label: weatherTemp,
              onTap: () => _openDetailsModal(context, _ModalTab.weather),
            ),
            const SizedBox(width: 5),
            _MobileMiniPill(
              icon: Icons.sports_soccer_rounded,
              label: '',
              onTap: () => _openDetailsModal(context, _ModalTab.sports),
            ),
            const SizedBox(width: 5),
            _MobileMiniPill(
              icon: Icons.checklist_rounded,
              label: pendingReminders > 0 ? '$pendingReminders' : 'Hoy',
              highlighted: pendingReminders > 0,
              onTap: () => _openDetailsModal(context, _ModalTab.reminders),
            ),
          ],
        ),
      );
    }

    // 2) Modo compacto para NavigationRail angosto (600px - 999px)
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 4,
              children: [
                InkWell(
                  onTap: () => _openDetailsModal(context, _ModalTab.reminders),
                  child: Icon(
                    Icons.checklist_rounded,
                    size: 14,
                    color: pendingReminders > 0
                        ? AppColors.warning
                        : AppColors.accentCyan,
                  ),
                ),
                InkWell(
                  onTap: () => _openDetailsModal(context, _ModalTab.weather),
                  child: const Icon(
                    Icons.cloud_outlined,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                ),
                InkWell(
                  onTap: () => _openDetailsModal(context, _ModalTab.sports),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    size: 14,
                    color: AppColors.accentCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(_now),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    // 3) Modo barra lateral extendida (iPad horizontal / PC): 4 tarjetas apiladas del mismo ancho
    const double panelWidth = 212;

    return SizedBox(
      width: panelWidth,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) Tarjeta de Recordatorios Personales del Día
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetailsModal(context, _ModalTab.reminders),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: _cardDecoration(
                  borderColor: pendingReminders > 0
                      ? AppColors.warning.withValues(alpha: 0.7)
                      : AppColors.border,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 14,
                          color: pendingReminders > 0
                              ? AppColors.warning
                              : AppColors.accentCyan,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'HOY ($pendingReminders pend.)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: pendingReminders > 0
                                  ? AppColors.warning
                                  : AppColors.accentCyan,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.add_circle_outline,
                          size: 15,
                          color: AppColors.accentCyan,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (reminders.isEmpty)
                      const Text(
                        'Sin recordatorios hoy • Toca +',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      )
                    else
                      for (final r in reminders.take(2))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(
                                r.isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked,
                                size: 12,
                                color: r.isDone
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    decoration: r.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: r.isDone
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2) Tarjeta de Fútbol (América de Cali + Ligas Europeas)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetailsModal(context, _ModalTab.sports),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: _cardDecoration(borderColor: AppColors.border),
                child: sportsAsync.when(
                  loading: () => const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_soccer_rounded,
                        size: 14,
                        color: AppColors.accentCyan,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Cargando fútbol...',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  error: (_, _) => const Text(
                    'Fútbol sin conexión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.sports_soccer_rounded,
                                size: 14,
                                color: AppColors.accentCyan,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'América & Europa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Sin partidos hoy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }

                    final top = matches.first;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sports_soccer_rounded,
                              size: 13,
                              color: top.isAmericaDeCali
                                  ? AppColors.error
                                  : AppColors.accentCyan,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                top.isAmericaDeCali
                                    ? 'AMÉRICA DE CALI'
                                    : top.league.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: top.isAmericaDeCali
                                      ? AppColors.error
                                      : AppColors.accentCyan,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          top.headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          top.hasStarted
                              ? '${top.subDetail} • +${matches.length - 1} partidos'
                              : '${top.subDetail} • Ver todos (${matches.length})',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 3) Tarjeta de Clima y Ubicación
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openDetailsModal(context, _ModalTab.weather),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: _cardDecoration(borderColor: AppColors.border),
                child: weatherAsync.when(
                  loading: () => const Text(
                    'Cargando clima...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  error: (_, _) => const Text(
                    'Clima sin conexión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  data: (w) => Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.cloud_outlined,
                            size: 16,
                            color: AppColors.accentCyan,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${w.temperatureC.toStringAsFixed(0)}°C',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentCyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        w.conditionLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              w.locationLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 4) Tarjeta de Reloj 24H centrado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: AppColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileMiniPill extends StatelessWidget {
  const _MobileMiniPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppColors.warning : AppColors.accentCyan;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal unificado: Clima + Fútbol (América de Cali y Europa) + Recordatorios Personales de Hoy.
class _LiveInfoDialog extends ConsumerStatefulWidget {
  const _LiveInfoDialog({required this.initialTab});
  final _ModalTab initialTab;

  @override
  ConsumerState<_LiveInfoDialog> createState() => _LiveInfoDialogState();
}

class _LiveInfoDialogState extends ConsumerState<_LiveInfoDialog> {
  late _ModalTab _tab;
  final _cityCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController();
  bool _savingCity = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _reminderCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCity() async {
    if (_cityCtrl.text.trim().isEmpty) return;
    setState(() => _savingCity = true);
    final ok = await LiveWidgetsService.setManualCity(_cityCtrl.text);
    if (!mounted) return;
    setState(() => _savingCity = false);
    if (ok) {
      _cityCtrl.clear();
      ref.invalidate(weatherInfoProvider);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró esa ciudad. Intenta otro nombre.'),
        ),
      );
    }
  }

  Future<void> _addReminder() async {
    final text = _reminderCtrl.text.trim();
    if (text.isEmpty) return;
    await ref.read(dailyRemindersRepositoryProvider).addReminder(text);
    _reminderCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherInfoProvider);
    final sportsAsync = ref.watch(sportsFeedProvider);
    final remindersAsync = ref.watch(todayRemindersProvider);

    final title = switch (_tab) {
      _ModalTab.weather => 'Clima y Ubicación',
      _ModalTab.sports => 'América de Cali & Europa',
      _ModalTab.reminders => 'Recordatorios de Hoy',
    };

    final icon = switch (_tab) {
      _ModalTab.weather => Icons.cloud_rounded,
      _ModalTab.sports => Icons.sports_soccer_rounded,
      _ModalTab.reminders => Icons.checklist_rounded,
    };

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(icon, color: AppColors.accentCyan),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
          if (_tab != _ModalTab.reminders)
            IconButton(
              tooltip: 'Actualizar ahora',
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: () {
                ref.invalidate(weatherInfoProvider);
                ref.invalidate(sportsFeedProvider);
              },
            ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_ModalTab>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _ModalTab.reminders,
                  icon: Icon(Icons.checklist_rounded, size: 15),
                  label: Text('Hoy', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: _ModalTab.weather,
                  icon: Icon(Icons.cloud_outlined, size: 15),
                  label: Text('Clima', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: _ModalTab.sports,
                  icon: Icon(Icons.sports_soccer_rounded, size: 15),
                  label: Text('Fútbol', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 14),
            if (_tab == _ModalTab.reminders)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reminderCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Nuevo recordatorio solo para hoy...',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addReminder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addReminder,
                        child: const Text('Añadir'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: remindersAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Text('Error: $e'),
                      data: (items) {
                        if (items.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'No tienes recordatorios para hoy.\nEl bot de Telegram te preguntará a las 2:00 PM y 8:00 PM si ya los completaste.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final item = items[i];
                            return Card(
                              color: AppColors.background,
                              child: ListTile(
                                dense: true,
                                leading: Checkbox(
                                  value: item.isDone,
                                  activeColor: AppColors.success,
                                  onChanged: (_) => ref
                                      .read(dailyRemindersRepositoryProvider)
                                      .toggleDone(item),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    decoration: item.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: item.isDone
                                        ? AppColors.textMuted
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () => ref
                                      .read(dailyRemindersRepositoryProvider)
                                      .deleteReminder(item.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              )
            else if (_tab == _ModalTab.weather)
              weatherAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Text(
                  'No se pudo obtener el clima (modo offline): $e',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                data: (w) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      color: AppColors.background,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wb_sunny_outlined,
                              size: 42,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${w.temperatureC.toStringAsFixed(1)} °C',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accentCyan,
                                    ),
                                  ),
                                  Text(
                                    w.conditionLabel,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        w.locationLabel,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Cambiar ciudad (Ej. Cali, Palmira)',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _saveCity(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _savingCity ? null : _saveCity,
                          child: Text(_savingCity ? '...' : 'Fijar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          await LiveWidgetsService.clearManualCity();
                          ref.invalidate(weatherInfoProvider);
                        },
                        icon: const Icon(Icons.my_location_rounded, size: 16),
                        label: const Text(
                          'Usar ubicación GPS automática',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: sportsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Text(
                    'Sin conexión al marcador deportivo: $e',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay partidos programados hoy en Liga BetPlay (América de Cali) ni en las principales ligas europeas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final m = matches[i];
                        return Card(
                          color: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: m.isAmericaDeCali
                                  ? AppColors.error
                                  : AppColors.border,
                              width: m.isAmericaDeCali ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            title: Text(
                              m.headline,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              '${m.isAmericaDeCali ? "🔴 AMÉRICA DE CALI • " : ""}${m.league}',
                              style: TextStyle(
                                fontSize: 11,
                                color: m.isAmericaDeCali
                                    ? AppColors.error
                                    : AppColors.textSecondary,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: m.hasStarted
                                      ? AppColors.accentCyan
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                m.subDetail,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: m.hasStarted
                                      ? AppColors.accentCyan
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
