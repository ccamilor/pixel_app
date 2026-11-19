import 'package:app_pixel/core/constants/app_enums.dart';
import 'package:app_pixel/core/database/app_database.dart';
import 'package:app_pixel/core/database/sync_engine.dart';
import 'package:app_pixel/core/network/connectivity_service.dart';
import 'package:app_pixel/features/time_tracking/data/repositories/time_tracking_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TimeTrackingRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final syncEngine = SyncEngine(
      database: db,
      connectivity: ConnectivityService(),
      remoteAdapter: null,
    );
    repo = TimeTrackingRepository(db, syncEngine);
  });

  tearDown(() async {
    await db.close();
  });

  test('Control de jornada registra apertura, pausas múltiples y cierre neto', () async {
    final openAt = DateTime.now().subtract(const Duration(hours: 3));
    final log = await repo.openWorkDay(customOpenTime: openAt);

    expect(log.isOpen, isTrue);

    await repo.startBreak(
      workLogId: log.id,
      type: WorkBreakType.lunch,
      notes: 'Almuerzo',
    );
    final withBreak = await repo.watchTodayWorkLog().first;
    expect(withBreak?.activeBreak?.type, WorkBreakType.lunch);

    await repo.endBreak(withBreak!.activeBreak!.id, log.id);
    await repo.startBreak(
      workLogId: log.id,
      type: WorkBreakType.businessErrand,
      notes: 'Compra de vinilo reflectivo',
    );

    await repo.closeWorkDay(log.id);
    final closed = await repo.watchTodayWorkLog().first;

    expect(closed?.isOpen, isFalse);
    expect(closed?.breaks.length, 2);
    expect(closed!.totalWorkedMinutes, greaterThanOrEqualTo(175));
  });
}
