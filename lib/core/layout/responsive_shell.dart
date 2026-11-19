import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';

/// Destino principal del shell adaptativo.
class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_NavDestination> _destinations = [
  _NavDestination(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  _NavDestination(
    label: 'Pedidos',
    icon: Icons.view_kanban_outlined,
    selectedIcon: Icons.view_kanban,
  ),
  _NavDestination(
    label: 'Finanzas',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  _NavDestination(
    label: 'Clientes',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
];

/// Shell adaptativo: NavigationBar en Android (< 600px) y NavigationRail en iPad/Web (>= 600px).
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  static const double tabletBreakpoint = 600;

  void _onSelectBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideScreen = width >= tabletBreakpoint;

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectBranch,
              extended: width >= 1000,
              labelType:
                  width >= 1000 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Icon(
                  Icons.bolt_rounded,
                  color: AppColors.accentCyan,
                  size: 30,
                ),
              ),
              destinations: [
                for (final item in _destinations)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelectBranch,
          destinations: [
            for (final item in _destinations)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}
