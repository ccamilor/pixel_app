import 'dart:async';

import 'package:app_pixel/core/database/app_database.dart';
import 'package:app_pixel/core/database/sync_engine.dart';
import 'package:app_pixel/core/network/connectivity_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivityService extends ConnectivityService {
  _FakeConnectivityService({required this.online});
  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get hasConnection async => online;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;
}

class _FakeRemoteSyncAdapter implements RemoteSyncAdapter {
  final List<Map<String, dynamic>> upserted = [];
  final List<String> deletedIds = [];
  final Map<String, List<Map<String, dynamic>>> remoteTables = {};
  bool shouldFail = false;
  bool authenticated = true;

  @override
  bool get isAuthenticated => authenticated;

  @override
  Future<void> upsert(String table, Map<String, dynamic> payload) async {
    if (shouldFail) throw Exception('Simulated network error');
    upserted.add({'table': table, 'payload': payload});
  }

  @override
  Future<void> softDelete(
    String table,
    String recordId,
    DateTime deletedAt,
  ) async {
    if (shouldFail) throw Exception('Simulated delete error');
    deletedIds.add('$table:$recordId');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTable(String table) async {
    if (shouldFail) throw Exception('Simulated fetch error');
    return remoteTables[table] ?? const [];
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Inserta cliente y encola mutación en sync_queue Offline-First', () async {
    await db.into(db.clients).insert(
      ClientsCompanion.insert(
        id: 'client-1',
        name: 'Juan Pérez',
      ),
    );
    await db.enqueueSync(
      entityTable: 'clients',
      recordId: 'client-1',
      operation: 'upsert',
      payload: {'id': 'client-1', 'name': 'Juan Pérez'},
    );

    final clients = await db.select(db.clients).get();
    final pending = await db.getPendingSyncItems();

    expect(clients.length, 1);
    expect(clients.first.name, 'Juan Pérez');
    expect(pending.length, 1);
    expect(pending.first.entityTable, 'clients');
  });

  test('SyncEngine sincroniza la cola FIFO al estar online y limpia sync_queue', () async {
    final connectivity = _FakeConnectivityService(online: true);
    final remote = _FakeRemoteSyncAdapter();
    final engine = SyncEngine(
      database: db,
      connectivity: connectivity,
      remoteAdapter: remote,
    );

    await db.enqueueSync(
      entityTable: 'expenses',
      recordId: 'exp-1',
      operation: 'upsert',
      payload: {'id': 'exp-1', 'amount': 15000.0, 'payment_method': 'nequi'},
    );
    await db.enqueueSync(
      entityTable: 'expenses',
      recordId: 'exp-2',
      operation: 'delete',
      payload: {'deleted_at': DateTime.utc(2026, 11, 19).toIso8601String()},
    );

    final snapshot = await engine.syncPendingChanges();

    expect(snapshot.status, SyncStatus.idle);
    expect(snapshot.pendingCount, 0);
    expect(remote.upserted.length, 1);
    expect(remote.deletedIds, ['expenses:exp-2']);
  });

  test('SyncEngine conserva la cola intacta cuando no hay internet', () async {
    final connectivity = _FakeConnectivityService(online: false);
    final remote = _FakeRemoteSyncAdapter();
    final engine = SyncEngine(
      database: db,
      connectivity: connectivity,
      remoteAdapter: remote,
    );

    await db.enqueueSync(
      entityTable: 'materials',
      recordId: 'mat-1',
      operation: 'upsert',
      payload: {'id': 'mat-1', 'name': 'Vinilo Reflectivo'},
    );

    final snapshot = await engine.syncPendingChanges();

    expect(snapshot.status, SyncStatus.offline);
    expect(snapshot.pendingCount, 1);
    expect(remote.upserted, isEmpty);
  });

  test('SyncEngine pullFromRemote descarga clientes y gastos de Supabase a Drift local', () async {
    final connectivity = _FakeConnectivityService(online: true);
    final remote = _FakeRemoteSyncAdapter();
    remote.remoteTables['clients'] = [
      {
        'id': 'remote-client-1',
        'name': 'Cliente iPad',
        'phone': '3009998877',
        'created_at': DateTime.utc(2026, 11, 20).toIso8601String(),
        'updated_at': DateTime.utc(2026, 11, 20).toIso8601String(),
      },
    ];
    remote.remoteTables['expenses'] = [
      {
        'id': 'remote-exp-1',
        'amount': 22000,
        'scope': 'personal',
        'payment_method': 'nequi',
        'category': 'Alimentación',
        'subcategory': 'Almuerzo',
        'description': 'Registrado por Telegram',
        'date': DateTime.utc(2026, 11, 20).toIso8601String(),
        'source': 'telegram',
        'updated_at': DateTime.utc(2026, 11, 20).toIso8601String(),
      },
    ];

    final engine = SyncEngine(
      database: db,
      connectivity: connectivity,
      remoteAdapter: remote,
    );

    final snapshot = await engine.pullFromRemote();
    final localClients = await db.select(db.clients).get();
    final localExpenses = await db.select(db.expenses).get();

    expect(snapshot.status, SyncStatus.idle);
    expect(localClients.length, 1);
    expect(localClients.first.name, 'Cliente iPad');
    expect(localExpenses.length, 1);
    expect(localExpenses.first.source, 'telegram');
  });
}
