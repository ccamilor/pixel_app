import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/repositories/orders_repository.dart';
import '../../domain/entities/order_entity.dart';

/// Cronómetro en vivo con selector de Modo Libre (Stopwatch) o Modo Pomodoro (25/5 min).
class OrderTimerWidget extends ConsumerStatefulWidget {
  const OrderTimerWidget({required this.order, super.key});

  final OrderEntity order;

  @override
  ConsumerState<OrderTimerWidget> createState() => _OrderTimerWidgetState();
}

class _OrderTimerWidgetState extends ConsumerState<OrderTimerWidget> {
  static const int pomodoroWorkMinutes = 25;
  Timer? _ticker;
  TimerMode _selectedMode = TimerMode.stopwatch;
  bool _pomodoroBreakActive = false;
  int _breakSecondsLeft = 5 * 60;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.order.timerMode;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant OrderTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.activeTimerStartedAt !=
            widget.order.activeTimerStartedAt ||
        oldWidget.order.timerMode != widget.order.timerMode) {
      _selectedMode = widget.order.timerMode;
      _syncTicker();
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.order.isTimerRunning || _pomodoroBreakActive) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_pomodoroBreakActive) {
          if (_breakSecondsLeft <= 1) {
            setState(() {
              _pomodoroBreakActive = false;
              _breakSecondsLeft = 5 * 60;
            });
            _ticker?.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Descanso Pomodoro terminado. ¡Listo para el siguiente bloque!'),
              ),
            );
          } else {
            setState(() => _breakSecondsLeft--);
          }
          return;
        }

        if (_selectedMode == TimerMode.pomodoro &&
            widget.order.activeTimerStartedAt != null) {
          final elapsedSeconds =
              DateTime.now().difference(widget.order.activeTimerStartedAt!).inSeconds;
          if (elapsedSeconds >= pomodoroWorkMinutes * 60) {
            _completePomodoroBlock();
            return;
          }
        }
        setState(() {});
      });
    }
  }

  Future<void> _completePomodoroBlock() async {
    _ticker?.cancel();
    await ref.read(ordersRepositoryProvider).stopTimer(
          orderId: widget.order.id,
          completedPomodoroCycle: true,
          overrideMinutes: pomodoroWorkMinutes,
        );
    if (!mounted) return;
    final nextCycle = widget.order.pomodoroSessionsCompleted + 1;
    final isLongBreak = nextCycle % 4 == 0;
    setState(() {
      _pomodoroBreakActive = true;
      _breakSecondsLeft = (isLongBreak ? 15 : 5) * 60;
    });
    _syncTicker();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '¡Pomodoro #$nextCycle completado (+25m)! Descanso ${isLongBreak ? "largo (15m)" : "corto (5m)"} iniciado.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatClock(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final m = (safe ~/ 60).toString().padLeft(2, '0');
    final s = (safe % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.order.isTimerRunning;
    final elapsedSeconds = running
        ? DateTime.now().difference(widget.order.activeTimerStartedAt!).inSeconds
        : 0;

    final liveDisplay = _pomodoroBreakActive
        ? 'Descanso ${_formatClock(_breakSecondsLeft)}'
        : running
            ? (_selectedMode == TimerMode.pomodoro
                ? _formatClock((pomodoroWorkMinutes * 60) - elapsedSeconds)
                : _formatClock(elapsedSeconds))
            : AppFormatters.minutesToHoursLabel(widget.order.timeInvestedMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: running || _pomodoroBreakActive
              ? AppColors.accentCyan
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _selectedMode == TimerMode.pomodoro
                ? Icons.av_timer_rounded
                : Icons.timer_outlined,
            size: 16,
            color: running ? AppColors.accentCyan : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveDisplay,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: running || _pomodoroBreakActive
                        ? AppColors.accentCyan
                        : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_selectedMode.label}${widget.order.pomodoroSessionsCompleted > 0 ? ' • ${widget.order.pomodoroSessionsCompleted}🍅' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!running && !_pomodoroBreakActive)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: _selectedMode == TimerMode.stopwatch
                  ? 'Cambiar a Pomodoro (25/5)'
                  : 'Cambiar a Cronómetro libre',
              icon: Icon(
                _selectedMode == TimerMode.pomodoro
                    ? Icons.local_fire_department_rounded
                    : Icons.swap_horiz_rounded,
                size: 18,
                color: _selectedMode == TimerMode.pomodoro
                    ? AppColors.warning
                    : AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _selectedMode = _selectedMode == TimerMode.stopwatch
                      ? TimerMode.pomodoro
                      : TimerMode.stopwatch;
                });
              },
            ),
          if (_pomodoroBreakActive)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Saltar descanso',
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              color: AppColors.accentCyan,
              onPressed: () {
                _ticker?.cancel();
                setState(() {
                  _pomodoroBreakActive = false;
                  _breakSecondsLeft = 5 * 60;
                });
              },
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: running ? 'Pausar y guardar tiempo' : 'Iniciar timer',
              icon: Icon(
                running ? Icons.pause_circle_filled : Icons.play_circle_fill,
                size: 22,
                color: running ? AppColors.warning : AppColors.accentCyan,
              ),
              onPressed: () async {
                final repo = ref.read(ordersRepositoryProvider);
                if (running) {
                  await repo.stopTimer(orderId: widget.order.id);
                } else {
                  await repo.startTimer(
                    orderId: widget.order.id,
                    mode: _selectedMode,
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}
