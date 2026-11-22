import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/clients/presentation/pages/clients_inventory_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/finance/presentation/pages/finance_page.dart';
import '../../features/orders/presentation/pages/orders_kanban_page.dart';
import '../../features/stats/presentation/pages/statistics_page.dart';
import '../constants/app_routes.dart';
import 'responsive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ResponsiveShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.orders,
                builder: (context, state) => const OrdersKanbanPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.finance,
                builder: (context, state) => const FinancePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stats,
                builder: (context, state) => const StatisticsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clientsInventory,
                builder: (context, state) => const ClientsInventoryPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
