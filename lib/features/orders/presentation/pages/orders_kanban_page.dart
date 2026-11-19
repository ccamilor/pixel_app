import 'package:material_ui/material_ui.dart';

import '../../../../core/layout/module_placeholder_view.dart';

class OrdersKanbanPage extends StatelessWidget {
  const OrdersKanbanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderView(
      title: 'Tablero de Pedidos (Kanban)',
      subtitle:
          'Flujo Diseño -> Impresión -> Entrega, calculadora m², cronómetro + Pomodoro y WhatsApp directo.',
      icon: Icons.view_kanban_rounded,
      phaseBadge: 'Listo para Fase 4',
    );
  }
}
