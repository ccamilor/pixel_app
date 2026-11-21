import 'package:app_pixel/core/database/app_database.dart';
import 'package:app_pixel/core/database/sync_engine.dart';
import 'package:app_pixel/features/clients/domain/entities/client_entity.dart';
import 'package:app_pixel/features/clients/data/repositories/client_repository.dart';
import 'package:app_pixel/features/finance/data/repositories/finance_repository.dart';
import 'package:app_pixel/features/finance/domain/entities/expense_entity.dart';
import 'package:app_pixel/features/inventory/data/repositories/inventory_repository.dart';
import 'package:app_pixel/features/inventory/domain/entities/material_entity.dart';
import 'package:app_pixel/features/orders/data/repositories/orders_repository.dart';
import 'package:app_pixel/features/orders/domain/entities/order_entity.dart';
import 'package:app_pixel/features/reminders/data/repositories/daily_reminders_repository.dart';
import 'package:app_pixel/features/time_tracking/data/repositories/time_tracking_repository.dart';
import 'package:app_pixel/features/time_tracking/domain/entities/work_log_entity.dart';
import 'package:app_pixel/main.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  List<dynamic> buildOverrides(AppDatabase testDb) => [
    appDatabaseProvider.overrideWithValue(testDb),
    pendingSyncCountProvider.overrideWith((_) => Stream.value(0)),
    todayWorkLogProvider.overrideWith((_) => Stream<WorkLogEntity?>.value(null)),
    allWorkLogsProvider.overrideWith((_) => Stream.value(const <WorkLogEntity>[])),
    ordersStreamProvider.overrideWith((_) => Stream.value(const <OrderEntity>[])),
    clientsStreamProvider.overrideWith((_) => Stream.value(const <ClientEntity>[])),
    materialsStreamProvider.overrideWith((_) => Stream.value(const <MaterialEntity>[])),
    todayRemindersProvider.overrideWith((_) => Stream.value(const <DailyReminderEntity>[])),
    financeSummaryProvider.overrideWith(
      (_) async => const FinanceSummary(
        totalIncome: 0,
        cashIncome: 0,
        digitalIncome: 0,
        totalExpenses: 0,
        businessExpenses: 0,
        personalExpenses: 0,
        cashExpenses: 0,
        digitalExpenses: 0,
        totalReceivable: 0,
      ),
    ),
  ];

  testWidgets('Renderiza AppPixelRoot con tema OLED y navegación adaptativa', (
    tester,
  ) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    addTearDown(testDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(testDb).cast(),
        child: const AppPixelRoot(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pixel App'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Control de Jornada Laboral'), findsOneWidget);
  });

  testWidgets('Usa NavigationBar en pantallas móviles (< 600px)', (
    tester,
  ) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    addTearDown(testDb.close);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOverrides(testDb).cast(),
        child: const AppPixelRoot(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
