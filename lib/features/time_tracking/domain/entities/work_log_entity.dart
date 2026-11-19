import '../../../../core/constants/app_enums.dart';

/// Entidad de dominio para una pausa o salida durante la jornada laboral.
class WorkBreakEntity {
  const WorkBreakEntity({
    required this.id,
    required this.workLogId,
    required this.type,
    required this.startTime,
    this.endTime,
    this.notes,
  });

  final String id;
  final String workLogId;
  final WorkBreakType type;
  final DateTime startTime;
  final DateTime? endTime;
  final String? notes;

  bool get isActive => endTime == null;

  int get durationMinutes {
    final end = endTime ?? DateTime.now();
    final mins = end.difference(startTime).inMinutes;
    return mins < 0 ? 0 : mins;
  }
}

/// Entidad de dominio para la jornada diaria con múltiples pausas/diligencias.
class WorkLogEntity {
  const WorkLogEntity({
    required this.id,
    required this.dateKey,
    required this.openTime,
    this.closeTime,
    required this.totalWorkedMinutes,
    required this.totalBreakMinutes,
    this.notes,
    required this.breaks,
  });

  final String id;
  final String dateKey;
  final DateTime openTime;
  final DateTime? closeTime;
  final int totalWorkedMinutes;
  final int totalBreakMinutes;
  final String? notes;
  final List<WorkBreakEntity> breaks;

  bool get isOpen => closeTime == null;

  WorkBreakEntity? get activeBreak {
    for (final b in breaks) {
      if (b.isActive) return b;
    }
    return null;
  }

  /// Minutos netos trabajados al instante (descontando pausas personales/almuerzo).
  int get liveWorkedMinutes {
    if (!isOpen) return totalWorkedMinutes;
    final gross = DateTime.now().difference(openTime).inMinutes;
    final personalBreaks = breaks
        .where((b) => b.type != WorkBreakType.businessErrand)
        .fold<int>(0, (sum, b) => sum + b.durationMinutes);
    final net = gross - personalBreaks;
    return net < 0 ? 0 : net;
  }
}
