import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../constants/app_colors.dart';
import 'live_clock_badge.dart';

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
/// Incluye el logo oficial de Pixel App y un reloj en vivo siempre visible.
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
    final isExtended = width >= 1000;

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectBranch,
              extended: isExtended,
              labelType: isExtended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isExtended
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/pixel_logo.png',
                            width: 36,
                            height: 36,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pixel App',
                            style: GoogleFonts.pacifico(
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: AppColors.accentCyan,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      )
                    : Image.asset(
                        'assets/images/pixel_logo.png',
                        width: 38,
                        height: 38,
                      ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LiveClockBadge(compact: !isExtended),
                  ),
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
      body: Stack(
        children: [
          navigationShell,
          const Positioned(
            top: 8,
            right: 12,
            child: SafeArea(
              child: LiveClockBadge(compact: true),
            ),
          ),
        ],
      ),
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
