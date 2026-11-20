import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/database/sync_engine.dart';
import 'core/layout/app_router.dart';
import 'core/network/supabase_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initializeIfConfigured();
  runApp(const ProviderScope(child: AppPixelRoot()));
}

class AppPixelRoot extends ConsumerWidget {
  const AppPixelRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(syncEngineProvider);

    return MaterialApp.router(
      title: 'Pixel App',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.oledDark,
      theme: AppTheme.oledDark,
      routerConfig: router,
    );
  }
}
