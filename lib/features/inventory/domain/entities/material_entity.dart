import '../../../../core/constants/app_enums.dart';

/// Entidad de dominio para Materiales e Insumos.
class MaterialEntity {
  const MaterialEntity({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitCost,
    required this.suggestedSalePrice,
    required this.defaultWastePercentage,
    required this.stock,
    required this.minStock,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final MaterialUnit unit;
  final double unitCost;
  final double suggestedSalePrice;
  final double defaultWastePercentage;
  final double stock;
  final double minStock;
  final DateTime updatedAt;

  bool get isLowStock => stock <= minStock;
}
