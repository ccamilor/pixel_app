import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'app_tables.dart';

part 'app_database.g.dart';

/// Base de datos local Offline-First en Drift (SQLite nativo en Android, WASM en Web/iPad).
@DriftDatabase(
  tables: [
    Clients,
    Materials,
    Orders,
    OrderItems,
    OrderPayments,
    Expenses,
    WorkLogs,
    WorkBreaks,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? _openDefaultConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openDefaultConnection() {
    return driftDatabase(
      name: 'app_pixel_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  /// Registra una mutación en la cola de sincronización Offline-First.
  Future<int> enqueueSync({
    required String entityTable,
    required String recordId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        entityTable: entityTable,
        recordId: recordId,
        operation: operation,
        payloadJson: jsonEncode(payload),
      ),
    );
  }

  /// Obtiene las operaciones pendientes ordenadas cronológicamente (FIFO).
  Future<List<SyncQueueData>> getPendingSyncItems({int limit = 50}) {
    return (select(syncQueue)
          ..orderBy([(t) => OrderingTerm.asc(t.id)])
          ..limit(limit))
        .get();
  }

  /// Elimina un ítem ya sincronizado exitosamente con Supabase.
  Future<int> removeSyncItem(int queueId) {
    return (delete(syncQueue)..where((t) => t.id.equals(queueId))).go();
  }

  /// Registra un intento fallido de sincronización para reintento posterior.
  Future<int> markSyncRetry(int queueId, String errorMessage) {
    return customUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? WHERE id = ?',
      variables: [Variable.withString(errorMessage), Variable.withInt(queueId)],
      updates: {syncQueue},
    );
  }

  /// Stream reactivo con la cantidad de operaciones pendientes por sincronizar.
  Stream<int> watchPendingSyncCount() {
    final countExp = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([countExp]);
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }
}
