import 'package:app_pixel/main.dart';
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
    await tester.pumpWidget(const ProviderScope(child: AppPixelRoot()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Principal'), findsWidgets);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('Usa NavigationBar en pantallas móviles (< 600px)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AppPixelRoot()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
