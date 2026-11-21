import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';

/// Entidad de dominio para Recordatorios Personales del Día.
class DailyReminderEntity {
  const DailyReminderEntity({
    required this.id,
    required this.dateKey,
    required this.title,
    required this.isDone,
    required this.createdAt,
  });

  final String id;
  final String dateKey;
  final String title;
  final bool isDone;
  final DateTime createdAt;
}

/// Repositorio Offline-First de Recordatorios Personales (filtrados únicamente por el día actual).
class DailyRemindersRepository {
  DailyRemindersRepository(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  static const _uuid = Uuid();

  static String todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Stream<List<DailyReminderEntity>> watchTodayReminders() {
    final key = todayKey();
    return (_db.select(_db.dailyReminders)
          ..where((t) => t.dateKey.equals(key) & t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.isDone),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (r) => DailyReminderEntity(
                  id: r.id,
                  dateKey: r.dateKey,
                  title: r.title,
                  isDone: r.isDone,
                  createdAt: r.createdAt.toLocal(),
                ),
              )
              .toList(),
        );
  }

  Future<void> addReminder(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now().toUtc();
    final key = todayKey();
    final id = _uuid.v4();

    await _db.into(_db.dailyReminders).insert(
      DailyRemindersCompanion.insert(
        id: id,
        dateKey: key,
        title: trimmed,
        isDone: const Value(false),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'daily_reminders',
      recordId: id,
      operation: 'upsert',
      payload: {
        'id': id,
        'date_key': key,
        'title': trimmed,
        'is_done': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
    );
    _syncEngine.syncPendingChanges();
  }

  Future<void> toggleDone(DailyReminderEntity reminder) async {
    final now = DateTime.now().toUtc();
    final nextDone = !reminder.isDone;

    await (_db.update(_db.dailyReminders)
          ..where((t) => t.id.equals(reminder.id)))
        .write(
          DailyRemindersCompanion(
            isDone: Value(nextDone),
            updatedAt: Value(now),
          ),
        );

    await _db.enqueueSync(
      entityTable: 'daily_reminders',
      recordId: reminder.id,
      operation: 'upsert',
      payload: {
        'id': reminder.id,
        'date_key': reminder.dateKey,
        'title': reminder.title,
        'is_done': nextDone,
        'updated_at': now.toIso8601String(),
      },
    );
    _syncEngine.syncPendingChanges();
  }

  Future<void> deleteReminder(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.dailyReminders)..where((t) => t.id.equals(id))).write(
      DailyRemindersCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _db.enqueueSync(
      entityTable: 'daily_reminders',
      recordId: id,
      operation: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );
    _syncEngine.syncPendingChanges();
  }
}

final dailyRemindersRepositoryProvider = Provider<DailyRemindersRepository>((ref) {
  return DailyRemindersRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
  );
});

final todayRemindersProvider = StreamProvider<List<DailyReminderEntity>>((ref) {
  return ref.watch(dailyRemindersRepositoryProvider).watchTodayReminders();
});
