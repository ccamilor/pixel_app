import 'package:material_ui/material_ui.dart';

import '../../../../core/layout/module_placeholder_view.dart';

class ClientsInventoryPage extends StatelessWidget {
  const ClientsInventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderView(
      title: 'Clientes e Inventario',
      subtitle:
          'Directorio con datos de moto/vehículo, catálogo de materiales m² y alertas de stock mínimo.',
      icon: Icons.inventory_2_rounded,
      phaseBadge: 'Listo para Fase 3',
    );
  }
}
