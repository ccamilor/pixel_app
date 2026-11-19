import '../constants/app_enums.dart';

/// Resultado detallado del cálculo de precio y consumo de material para un ítem.
class PrintCalculationResult {
  const PrintCalculationResult({
    required this.netAreaM2,
    required this.billableAreaM2,
    required this.materialCost,
    required this.suggestedBasePrice,
    required this.finishingSurcharge,
    required this.totalPrice,
  });

  final double netAreaM2;
  final double billableAreaM2;
  final double materialCost;
  final double suggestedBasePrice;
  final double finishingSurcharge;
  final double totalPrice;
}

/// Calculadora de impresión digital / vinilos (m², merma, acabados y diseño).
abstract final class PrintCalculator {
  static double defaultFinishingSurchargePerM2(FinishingType type) {
    return switch (type) {
      FinishingType.none => 0,
      FinishingType.matteLaminate => 12000,
      FinishingType.glossLaminate => 12000,
      FinishingType.dieCut => 15000,
      FinishingType.reflective => 25000,
    };
  }

  /// Calcula el consumo de material (incluyendo merma) y el precio sugerido del ítem.
  static PrintCalculationResult calculateItem({
    required double widthCm,
    required double heightCm,
    required int quantity,
    required double unitCostPerM2,
    required double suggestedSalePricePerM2,
    required double wastePercentage,
    required FinishingType finishingType,
    double? customFinishingSurcharge,
  }) {
    final safeQty = quantity < 1 ? 1 : quantity;
    final netAreaM2 = ((widthCm * heightCm) / 10000.0) * safeQty;
    final wasteMultiplier = 1.0 + (wastePercentage / 100.0);
    final billableAreaM2 = netAreaM2 * wasteMultiplier;

    final materialCost = billableAreaM2 * unitCostPerM2;
    final suggestedBasePrice = billableAreaM2 * suggestedSalePricePerM2;
    final finishingSurcharge =
        customFinishingSurcharge ??
        (billableAreaM2 * defaultFinishingSurchargePerM2(finishingType));
    final totalPrice = suggestedBasePrice + finishingSurcharge;

    return PrintCalculationResult(
      netAreaM2: netAreaM2,
      billableAreaM2: billableAreaM2,
      materialCost: materialCost,
      suggestedBasePrice: suggestedBasePrice,
      finishingSurcharge: finishingSurcharge,
      totalPrice: totalPrice,
    );
  }
}
