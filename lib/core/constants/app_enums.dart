/// Enums compartidos del dominio según la especificación relacional.
enum OrderStatus {
  pending('Pendiente'),
  design('En Diseño'),
  printing('En Impresión'),
  ready('Listo para Entrega'),
  delivered('Entregado');

  const OrderStatus(this.label);
  final String label;
}

enum PrintStage {
  none('Sin iniciar'),
  printing('Imprimiendo'),
  cutting('Cortando'),
  laminating('Laminando'),
  done('Finalizado');

  const PrintStage(this.label);
  final String label;
}

enum OrderPriority {
  low('Baja'),
  medium('Media'),
  high('Alta');

  const OrderPriority(this.label);
  final String label;
}

enum PricingMode {
  manual('Manual'),
  auto('Calculadora');

  const PricingMode(this.label);
  final String label;
}

enum TimerMode {
  stopwatch('Cronómetro'),
  pomodoro('Pomodoro');

  const TimerMode(this.label);
  final String label;
}

enum PaymentMethod {
  cash('Efectivo'),
  nequi('Nequi'),
  daviplata('Daviplata'),
  bancolombia('Bancolombia'),
  transfer('Transferencia'),
  other('Otro');

  const PaymentMethod(this.label);
  final String label;

  bool get isCash => this == PaymentMethod.cash;
}

enum ExpenseScope {
  business('Negocio'),
  personal('Personal');

  const ExpenseScope(this.label);
  final String label;
}

enum WorkBreakType {
  lunch('Almuerzo'),
  personalBreak('Descanso personal'),
  businessErrand('Diligencia del negocio');

  const WorkBreakType(this.label);
  final String label;
}

enum MaterialUnit {
  m2('m²'),
  cm2('cm²'),
  unit('Unidad'),
  linearMeter('Metro lineal');

  const MaterialUnit(this.label);
  final String label;
}

enum FinishingType {
  none('Sin acabado'),
  matteLaminate('Laminado mate'),
  glossLaminate('Laminado brillante'),
  dieCut('Troquelado / Plotter'),
  reflective('Reflectivo');

  const FinishingType(this.label);
  final String label;
}
