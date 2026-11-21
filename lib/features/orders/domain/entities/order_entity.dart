import '../../../../core/constants/app_enums.dart';

/// Entidad de dominio para Pedidos / Ventas (Cabecera).
class OrderEntity {
  const OrderEntity({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    required this.title,
    required this.category,
    required this.subcategory,
    required this.status,
    required this.designApproved,
    required this.printStage,
    required this.technicalNotes,
    this.sourceFilePath,
    required this.referenceImages,
    required this.timeInvestedMinutes,
    this.activeTimerStartedAt,
    required this.timerMode,
    required this.pomodoroSessionsCompleted,
    required this.deadline,
    required this.priority,
    required this.pricingMode,
    required this.designFee,
    required this.totalPrice,
    required this.amountPaid,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String title;
  final String category;
  final String subcategory;
  final OrderStatus status;
  final bool designApproved;
  final PrintStage printStage;
  final String technicalNotes;
  final String? sourceFilePath;
  final List<String> referenceImages;
  final int timeInvestedMinutes;
  final DateTime? activeTimerStartedAt;
  final TimerMode timerMode;
  final int pomodoroSessionsCompleted;
  final DateTime deadline;
  final OrderPriority priority;
  final PricingMode pricingMode;
  final double designFee;
  final double totalPrice;
  final double amountPaid;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get balanceDue => (totalPrice - amountPaid).clamp(0, double.infinity);
  bool get isTimerRunning => activeTimerStartedAt != null;
  bool get isOverdue =>
      status != OrderStatus.delivered && deadline.isBefore(DateTime.now());
}

/// Entidad de dominio para un ítem de medida/material dentro de un pedido.
class OrderItemEntity {
  const OrderItemEntity({
    required this.id,
    required this.orderId,
    this.materialId,
    required this.description,
    required this.widthCm,
    required this.heightCm,
    required this.quantity,
    required this.wastePercentage,
    required this.finishingType,
    required this.finishingSurcharge,
    required this.calculatedPrice,
    required this.deductedFromStock,
  });

  final String id;
  final String orderId;
  final String? materialId;
  final String description;
  final double widthCm;
  final double heightCm;
  final int quantity;
  final double wastePercentage;
  final FinishingType finishingType;
  final double finishingSurcharge;
  final double calculatedPrice;
  final bool deductedFromStock;
}

/// Entidad de dominio para cada abono/pago registrado en un pedido.
class OrderPaymentEntity {
  const OrderPaymentEntity({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.notes,
    required this.paymentDate,
  });

  final String id;
  final String orderId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? notes;
  final DateTime paymentDate;
}
