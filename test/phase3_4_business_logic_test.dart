import 'package:app_pixel/core/constants/app_enums.dart';
import 'package:app_pixel/core/database/app_database.dart';
import 'package:app_pixel/core/database/sync_engine.dart';
import 'package:app_pixel/core/network/connectivity_service.dart';
import 'package:app_pixel/core/utils/print_calculator.dart';
import 'package:app_pixel/core/utils/whatsapp_launcher.dart';
import 'package:app_pixel/features/clients/data/repositories/client_repository.dart';
import 'package:app_pixel/features/finance/data/repositories/finance_repository.dart';
import 'package:app_pixel/features/inventory/data/repositories/inventory_repository.dart';
import 'package:app_pixel/features/orders/data/repositories/orders_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncEngine syncEngine;
  late ClientRepository clientRepo;
  late InventoryRepository inventoryRepo;
  late FinanceRepository financeRepo;
  late OrdersRepository ordersRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    syncEngine = SyncEngine(
      database: db,
      connectivity: ConnectivityService(),
      remoteAdapter: null,
    );
    clientRepo = ClientRepository(db, syncEngine);
    inventoryRepo = InventoryRepository(db, syncEngine);
    financeRepo = FinanceRepository(db, syncEngine);
    ordersRepo = OrdersRepository(db, syncEngine, inventoryRepo);
  });

  tearDown(() async {
    await db.close();
  });

  test('PrintCalculator calcula m², merma y acabado correctamente', () {
    final result = PrintCalculator.calculateItem(
      widthCm: 100,
      heightCm: 100,
      quantity: 1,
      unitCostPerM2: 20000,
      suggestedSalePricePerM2: 50000,
      wastePercentage: 10,
      finishingType: FinishingType.matteLaminate,
    );

    expect(result.netAreaM2, closeTo(1.0, 0.001));
    expect(result.billableAreaM2, closeTo(1.1, 0.001));
    expect(result.suggestedBasePrice, closeTo(55000, 0.1));
    expect(result.finishingSurcharge, closeTo(13200, 0.1));
    expect(result.totalPrice, closeTo(68200, 0.1));
  });

  test('WhatsAppLauncher normaliza teléfonos colombianos y genera plantilla por estado', () {
    expect(WhatsAppLauncher.sanitizePhone('300-123 4567'), '573001234567');
    final msg = WhatsAppLauncher.buildOrderMessage(
      clientName: 'Carlos',
      orderTitle: 'Calcomanías MT-09',
      status: OrderStatus.ready,
      balanceDue: 35000,
    );
    expect(msg, contains('Carlos'));
    expect(msg, contains('Calcomanías MT-09'));
    expect(msg, contains('35.000'));
  });

  test('Flujo completo: Cliente + Material + Pedido con descuento stock + Abonos + Arqueo + Pomodoro', () async {
    final client = await clientRepo.saveClient(
      name: 'Juan Moto',
      phone: '3015551234',
      vehicleInfo: 'Pulsar NS200',
    );
    final material = await inventoryRepo.saveMaterial(
      name: 'Vinilo Reflectivo',
      unit: MaterialUnit.m2,
      unitCost: 22000,
      suggestedSalePrice: 60000,
      defaultWastePercentage: 15,
      stock: 10.0,
      minStock: 2.0,
    );

    final orderId = await ordersRepo.createOrder(
      clientId: client.id,
      title: 'Kit Tanque Pulsar',
      deadline: DateTime.now().add(const Duration(days: 1)),
      pricingMode: PricingMode.auto,
      totalPrice: 90000,
      initialPayment: 40000,
      initialPaymentMethod: PaymentMethod.cash,
      items: [
        OrderItemDraft(
          materialId: material.id,
          description: 'Laterales',
          widthCm: 100,
          heightCm: 100,
          quantity: 1,
          wastePercentage: 15,
          finishingType: FinishingType.none,
          finishingSurcharge: 0,
          calculatedPrice: 69000,
          billableAreaM2: 1.15,
          deductFromStock: true,
        ),
      ],
    );

    // Verificar descuento automático de inventario
    final matsAfter = await inventoryRepo.watchMaterials().first;
    expect(matsAfter.first.stock, closeTo(8.85, 0.01));

    // Registrar segundo abono por Nequi y un gasto en efectivo
    await ordersRepo.addPayment(
      orderId: orderId,
      amount: 30000,
      paymentMethod: PaymentMethod.nequi,
    );
    await financeRepo.addExpense(
      amount: 15000,
      scope: ExpenseScope.personal,
      paymentMethod: PaymentMethod.cash,
      category: 'Alimentación',
      subcategory: 'Almuerzo',
      description: 'Corrientazo',
    );

    // Verificar arqueo Efectivo vs Digital y Cuentas por Cobrar
    final summary = await financeRepo.getFinanceSummary();
    expect(summary.cashIncome, 40000);
    expect(summary.digitalIncome, 30000);
    expect(summary.cashExpenses, 15000);
    expect(summary.netCashInDrawer, 25000);
    expect(summary.netDigitalBalance, 30000);
    expect(summary.totalReceivable, 20000);

    // Verificar Timer Pomodoro (+25m y 1 sesión completada)
    await ordersRepo.startTimer(orderId: orderId, mode: TimerMode.pomodoro);
    await ordersRepo.stopTimer(
      orderId: orderId,
      completedPomodoroCycle: true,
      overrideMinutes: 25,
    );
    final orders = await ordersRepo.watchOrders().first;
    expect(orders.first.timeInvestedMinutes, 25);
    expect(orders.first.pomodoroSessionsCompleted, 1);
  });
}
