import 'package:material_ui/material_ui.dart';

import '../../../../core/layout/module_placeholder_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderView(
      title: 'Dashboard Principal',
      subtitle:
          'Control de jornada, mapa de calor estilo GitHub y arqueo de caja Efectivo vs. Digital.',
      icon: Icons.dashboard_rounded,
      phaseBadge: 'Listo para Fase 5',
    );
  }
}
