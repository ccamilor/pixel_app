import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';
import '../network/live_widgets_service.dart';

/// Panel inferior izquierdo en barra lateral (iPad/Web) y compacto en Android:
/// En modo extendido muestra 3 cuadros apilados del mismo ancho:
/// 1) Fútbol (América de Cali + Ligas Europeas, solo horario 24H si no ha iniciado)
/// 2) Clima y Ubicación
/// 3) Reloj 24H centrado
class LiveClockBadge extends ConsumerStatefulWidget {
  const LiveClockBadge({this.compact = false, super.key});

  final bool compact;

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

  void _openDetailsModal(BuildContext context, {required bool openSportsFirst}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _LiveInfoDialog(openSportsFirst: openSportsFirst),
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

    // En modo compacto (móvil o NavigationRail colapsado) mostramos un bloque compacto centrado con accesos rápidos
    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _openDetailsModal(context, openSportsFirst: false),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.cloud_outlined,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _openDetailsModal(context, openSportsFirst: true),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.sports_soccer_rounded,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              timeStr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              dateStr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // Modo barra lateral extendida: 3 tarjetas del mismo ancho (208px) aprovechando el espacio vertical
    const double panelWidth = 212;

    return SizedBox(
      width: panelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1) Tarjeta de Fútbol (América de Cali + Ligas Europeas)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetailsModal(context, openSportsFirst: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      const SizedBox(height: 5),
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
                      const SizedBox(height: 3),
                      Text(
                        top.hasStarted
                            ? '${top.subDetail} • +${matches.length - 1} partidos'
                            : 'Hora: ${top.subDetail} • Ver todos (${matches.length})',
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

          // 2) Tarjeta de Clima y Ubicación
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openDetailsModal(context, openSportsFirst: false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: _cardDecoration(borderColor: AppColors.border),
              child: weatherAsync.when(
                loading: () => const Text(
                  'Cargando clima...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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

          // 3) Tarjeta de Reloj 24H centrado aprovechando el ancho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timeStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
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
    );
  }
}

/// Modal expandido para ver el detalle completo del Clima y el marcador de América de Cali + Ligas Europeas.
class _LiveInfoDialog extends ConsumerStatefulWidget {
  const _LiveInfoDialog({required this.openSportsFirst});
  final bool openSportsFirst;

  @override
  ConsumerState<_LiveInfoDialog> createState() => _LiveInfoDialogState();
}

class _LiveInfoDialogState extends ConsumerState<_LiveInfoDialog> {
  late bool _showSports;
  final _cityCtrl = TextEditingController();
  bool _savingCity = false;

  @override
  void initState() {
    super.initState();
    _showSports = widget.openSportsFirst;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
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
        const SnackBar(content: Text('No se encontró esa ciudad. Intenta otro nombre.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherInfoProvider);
    final sportsAsync = ref.watch(sportsFeedProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(
            _showSports ? Icons.sports_soccer_rounded : Icons.cloud_rounded,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _showSports ? 'América de Cali & Europa' : 'Clima y Ubicación',
            ),
          ),
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
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.cloud_outlined, size: 16),
                  label: Text('Clima'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.sports_soccer_rounded, size: 16),
                  label: Text('Fútbol'),
                ),
              ],
              selected: {_showSports},
              onSelectionChanged: (s) => setState(() => _showSports = s.first),
            ),
            const SizedBox(height: 14),
            if (!_showSports)
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
                              hintText: 'Cambiar ciudad (Ej. Cali, Palmira, Jamundí)',
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
                                m.hasStarted ? m.subDetail : m.subDetail,
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
