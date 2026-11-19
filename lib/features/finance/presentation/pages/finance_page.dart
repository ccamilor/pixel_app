import 'package:material_ui/material_ui.dart';

import '../../../../core/layout/module_placeholder_view.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholderView(
      title: 'Módulo Financiero',
      subtitle:
          'Gastos unificados (Negocio / Personal), abonos y arqueo separado por medio de pago.',
      icon: Icons.account_balance_wallet_rounded,
      phaseBadge: 'Listo para Fase 3',
    );
  }
}
