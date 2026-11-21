import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/database/sync_engine.dart';
import 'core/layout/app_router.dart';
import 'core/network/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/finance/data/repositories/finance_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initializeIfConfigured();
  runApp(const ProviderScope(child: AppPixelRoot()));
}

class AppPixelRoot extends ConsumerStatefulWidget {
  const AppPixelRoot({super.key});

  @override
  ConsumerState<AppPixelRoot> createState() => _AppPixelRootState();
}

class _AppPixelRootState extends ConsumerState<AppPixelRoot>
    with WidgetsBindingObserver {
  StreamSubscription<DateTime>? _syncSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app (ej. después de usar Nicegram/Telegram), sincroniza de inmediato
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(syncEngineProvider).syncAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final syncEngine = ref.watch(syncEngineProvider);

    _syncSub ??= syncEngine.onSyncCompleted.listen((_) {
      if (mounted) {
        ref.invalidate(financeSummaryProvider);
      }
    });

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
