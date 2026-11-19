import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';
import '../../domain/entities/client_entity.dart';

/// Repositorio Offline-First de Clientes (escribe en Drift y encola en SyncQueue).
class ClientRepository {
  ClientRepository(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  static const _uuid = Uuid();

  Stream<List<ClientEntity>> watchClients({String query = ''}) {
    final normalized = query.trim().toLowerCase();
    return (_db.select(_db.clients)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) {
          final entities = rows.map(_toEntity).toList();
          if (normalized.isEmpty) return entities;
          return entities.where((c) {
            return c.name.toLowerCase().contains(normalized) ||
                c.phone.toLowerCase().contains(normalized) ||
                (c.vehicleInfo?.toLowerCase().contains(normalized) ?? false);
          }).toList();
        });
  }

  Future<ClientEntity> saveClient({
    String? id,
    required String name,
    required String phone,
    String? documentId,
    String? vehicleInfo,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc();
    final recordId = id ?? _uuid.v4();

    await _db.into(_db.clients).insertOnConflictUpdate(
      ClientsCompanion(
        id: Value(recordId),
        name: Value(name.trim()),
        phone: Value(phone.trim()),
        documentId: Value(documentId?.trim().isEmpty ?? true ? null : documentId?.trim()),
        vehicleInfo: Value(vehicleInfo?.trim().isEmpty ?? true ? null : vehicleInfo?.trim()),
        notes: Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'clients',
      recordId: recordId,
      operation: 'upsert',
      payload: {
        'id': recordId,
        'name': name.trim(),
        'phone': phone.trim(),
        'document_id': documentId?.trim().isEmpty ?? true ? null : documentId?.trim(),
        'vehicle_info': vehicleInfo?.trim().isEmpty ?? true ? null : vehicleInfo?.trim(),
        'notes': notes?.trim().isEmpty ?? true ? null : notes?.trim(),
        'updated_at': now.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();

    return ClientEntity(
      id: recordId,
      name: name.trim(),
      phone: phone.trim(),
      documentId: documentId,
      vehicleInfo: vehicleInfo,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> deleteClient(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.clients)..where((t) => t.id.equals(id))).write(
      ClientsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'clients',
      recordId: id,
      operation: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );

    _syncEngine.syncPendingChanges();
  }

  ClientEntity _toEntity(Client row) {
    return ClientEntity(
      id: row.id,
      name: row.name,
      documentId: row.documentId,
      phone: row.phone,
      vehicleInfo: row.vehicleInfo,
      notes: row.notes,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  return ClientRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
  );
});

final clientsStreamProvider = StreamProvider<List<ClientEntity>>((ref) {
  return ref.watch(clientRepositoryProvider).watchClients();
});
