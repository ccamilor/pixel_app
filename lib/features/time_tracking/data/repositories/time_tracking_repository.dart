import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';
import '../../domain/entities/work_log_entity.dart';

/// Repositorio Offline-First de Control de Jornada Laboral y Pausas Múltiples.
class TimeTrackingRepository {
  TimeTrackingRepository(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  static const _uuid = Uuid();

  static String dateKeyOf(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Stream<List<WorkLogEntity>> watchAllWorkLogs() {
    final logsStream = (_db.select(_db.workLogs)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.dateKey)]))
        .watch();

    return logsStream.asyncMap((logs) async {
      final allBreaks = await (_db.select(_db.workBreaks)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
          .get();

      final breaksByLog = <String, List<WorkBreakEntity>>{};
      for (final row in allBreaks) {
        breaksByLog.putIfAbsent(row.workLogId, () => []).add(_toBreakEntity(row));
      }

      return logs
          .map((row) => _toLogEntity(row, breaksByLog[row.id] ?? const []))
          .toList();
    });
  }

  Stream<WorkLogEntity?> watchTodayWorkLog() {
    final todayKey = dateKeyOf(DateTime.now());
    return watchAllWorkLogs().map((logs) {
      for (final log in logs) {
        if (log.dateKey == todayKey) return log;
      }
      return null;
    });
  }

  /// Registra la apertura del local (puede usarse la hora actual o una hora pasada).
  Future<WorkLogEntity> openWorkDay({DateTime? customOpenTime, String? notes}) async {
    final nowLocal = customOpenTime ?? DateTime.now();
    final key = dateKeyOf(nowLocal);

    final existing = await (_db.select(_db.workLogs)
          ..where((t) => t.dateKey.equals(key) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      final breaks = await _getBreaksForLog(existing.id);
      return _toLogEntity(existing, breaks);
    }

    final id = _uuid.v4();
    final openUtc = nowLocal.toUtc();
    final updatedUtc = DateTime.now().toUtc();

    await _db.into(_db.workLogs).insert(
      WorkLogsCompanion.insert(
        id: id,
        dateKey: key,
        openTime: openUtc,
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
        updatedAt: Value(updatedUtc),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'work_logs',
      recordId: id,
      operation: 'upsert',
      payload: {
        'id': id,
        'date': key,
        'open_time': openUtc.toIso8601String(),
        'close_time': null,
        'total_worked_minutes': 0,
        'total_break_minutes': 0,
        'notes': notes,
        'updated_at': updatedUtc.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();

    return WorkLogEntity(
      id: id,
      dateKey: key,
      openTime: nowLocal,
      totalWorkedMinutes: 0,
      totalBreakMinutes: 0,
      notes: notes,
      breaks: const [],
    );
  }

  /// Inicia una pausa (almuerzo, descanso personal o diligencia del negocio).
  Future<void> startBreak({
    required String workLogId,
    required WorkBreakType type,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final nowUtc = DateTime.now().toUtc();
    final typeDb = _breakTypeToDb(type);

    await _db.into(_db.workBreaks).insert(
      WorkBreaksCompanion.insert(
        id: id,
        workLogId: workLogId,
        type: Value(typeDb),
        startTime: nowUtc,
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
        updatedAt: Value(nowUtc),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'work_breaks',
      recordId: id,
      operation: 'upsert',
      payload: {
        'id': id,
        'work_log_id': workLogId,
        'type': typeDb,
        'start_time': nowUtc.toIso8601String(),
        'end_time': null,
        'notes': notes,
        'updated_at': nowUtc.toIso8601String(),
      },
    );

    // Tocar work_logs para disparar el stream reactivo
    await (_db.update(_db.workLogs)..where((t) => t.id.equals(workLogId)))
        .write(WorkLogsCompanion(updatedAt: Value(nowUtc)));

    _syncEngine.syncPendingChanges();
  }

  /// Finaliza una pausa activa.
  Future<void> endBreak(String breakId, String workLogId) async {
    final nowUtc = DateTime.now().toUtc();
    await (_db.update(_db.workBreaks)..where((t) => t.id.equals(breakId))).write(
      WorkBreaksCompanion(endTime: Value(nowUtc), updatedAt: Value(nowUtc)),
    );

    final row = await (_db.select(_db.workBreaks)
          ..where((t) => t.id.equals(breakId)))
        .getSingleOrNull();
    if (row != null) {
      await _db.enqueueSync(
        entityTable: 'work_breaks',
        recordId: breakId,
        operation: 'upsert',
        payload: {
          'id': row.id,
          'work_log_id': row.workLogId,
          'type': row.type,
          'start_time': row.startTime.toUtc().toIso8601String(),
          'end_time': nowUtc.toIso8601String(),
          'notes': row.notes,
          'updated_at': nowUtc.toIso8601String(),
        },
      );
    }

    await (_db.update(_db.workLogs)..where((t) => t.id.equals(workLogId)))
        .write(WorkLogsCompanion(updatedAt: Value(nowUtc)));

    _syncEngine.syncPendingChanges();
  }

  /// Cierra la jornada diaria cerrando primero cualquier pausa abierta y calculando minutos netos.
  Future<void> closeWorkDay(String workLogId) async {
    final log = await (_db.select(_db.workLogs)
          ..where((t) => t.id.equals(workLogId)))
        .getSingleOrNull();
    if (log == null) return;

    final nowUtc = DateTime.now().toUtc();
    final breaks = await _getBreaksForLog(workLogId);

    for (final b in breaks) {
      if (b.isActive) {
        await endBreak(b.id, workLogId);
      }
    }

    final closedBreaks = await _getBreaksForLog(workLogId);
    final personalBreakMinutes = closedBreaks
        .where((b) => b.type != WorkBreakType.businessErrand)
        .fold<int>(0, (sum, b) => sum + b.durationMinutes);
    final grossMinutes = nowUtc.difference(log.openTime.toUtc()).inMinutes;
    final netWorked =
        (grossMinutes - personalBreakMinutes).clamp(0, 24 * 60);

    await (_db.update(_db.workLogs)..where((t) => t.id.equals(workLogId))).write(
      WorkLogsCompanion(
        closeTime: Value(nowUtc),
        totalWorkedMinutes: Value(netWorked),
        totalBreakMinutes: Value(personalBreakMinutes),
        updatedAt: Value(nowUtc),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'work_logs',
      recordId: workLogId,
      operation: 'upsert',
      payload: {
        'id': log.id,
        'date': log.dateKey,
        'open_time': log.openTime.toUtc().toIso8601String(),
        'close_time': nowUtc.toIso8601String(),
        'total_worked_minutes': netWorked,
        'total_break_minutes': personalBreakMinutes,
        'notes': log.notes,
        'updated_at': nowUtc.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();
  }

  Future<List<WorkBreakEntity>> _getBreaksForLog(String workLogId) async {
    final rows = await (_db.select(_db.workBreaks)
          ..where((t) => t.workLogId.equals(workLogId) & t.deletedAt.isNull()))
        .get();
    return rows.map(_toBreakEntity).toList();
  }

  WorkLogEntity _toLogEntity(WorkLog row, List<WorkBreakEntity> breaks) {
    return WorkLogEntity(
      id: row.id,
      dateKey: row.dateKey,
      openTime: row.openTime.toLocal(),
      closeTime: row.closeTime?.toLocal(),
      totalWorkedMinutes: row.totalWorkedMinutes,
      totalBreakMinutes: row.totalBreakMinutes,
      notes: row.notes,
      breaks: breaks,
    );
  }

  WorkBreakEntity _toBreakEntity(WorkBreak row) {
    return WorkBreakEntity(
      id: row.id,
      workLogId: row.workLogId,
      type: _breakTypeFromDb(row.type),
      startTime: row.startTime.toLocal(),
      endTime: row.endTime?.toLocal(),
      notes: row.notes,
    );
  }

  String _breakTypeToDb(WorkBreakType type) {
    return switch (type) {
      WorkBreakType.lunch => 'lunch',
      WorkBreakType.personalBreak => 'personal_break',
      WorkBreakType.businessErrand => 'business_errand',
    };
  }

  WorkBreakType _breakTypeFromDb(String raw) {
    return switch (raw) {
      'personal_break' => WorkBreakType.personalBreak,
      'business_errand' => WorkBreakType.businessErrand,
      _ => WorkBreakType.lunch,
    };
  }
}

final timeTrackingRepositoryProvider = Provider<TimeTrackingRepository>((ref) {
  return TimeTrackingRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
  );
});

final allWorkLogsProvider = StreamProvider<List<WorkLogEntity>>((ref) {
  return ref.watch(timeTrackingRepositoryProvider).watchAllWorkLogs();
});

final todayWorkLogProvider = StreamProvider<WorkLogEntity?>((ref) {
  return ref.watch(timeTrackingRepositoryProvider).watchTodayWorkLog();
});
