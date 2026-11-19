import 'package:app_pixel/core/database/app_database.dart';
import 'package:app_pixel/core/database/sync_engine.dart';
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

  testWidgets('Renderiza AppPixelRoot con tema OLED y navegación adaptativa', (
    tester,
  ) async {
    final testDb = AppDatabase(NativeDatabase.memory());
    addTearDown(testDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(testDb)],
        child: const AppPixelRoot(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Principal'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
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
        overrides: [appDatabaseProvider.overrideWithValue(testDb)],
        child: const AppPixelRoot(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
