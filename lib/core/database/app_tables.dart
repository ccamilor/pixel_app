import 'package:drift/drift.dart';

/// Tabla de Clientes.
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get documentId => text().nullable()();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get vehicleInfo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Materiales / Insumos.
class Materials extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get unit => text().withDefault(const Constant('m2'))();
  RealColumn get unitCost => real().withDefault(const Constant(0.0))();
  RealColumn get suggestedSalePrice => real().withDefault(const Constant(0.0))();
  RealColumn get defaultWastePercentage => real().withDefault(const Constant(15.0))();
  RealColumn get stock => real().withDefault(const Constant(0.0))();
  RealColumn get minStock => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Pedidos (Cabecera).
class Orders extends Table {
  TextColumn get id => text()();
  TextColumn get clientId => text().references(Clients, #id)();
  TextColumn get title => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  BoolColumn get designApproved => boolean().withDefault(const Constant(false))();
  TextColumn get printStage => text().withDefault(const Constant('none'))();
  TextColumn get technicalNotes => text().withDefault(const Constant(''))();
  TextColumn get sourceFilePath => text().nullable()();
  TextColumn get referenceImagesJson => text().withDefault(const Constant('[]'))();
  IntColumn get timeInvestedMinutes => integer().withDefault(const Constant(0))();
  DateTimeColumn get activeTimerStartedAt => dateTime().nullable()();
  TextColumn get timerMode => text().withDefault(const Constant('stopwatch'))();
  IntColumn get pomodoroSessionsCompleted => integer().withDefault(const Constant(0))();
  DateTimeColumn get deadline => dateTime()();
  TextColumn get priority => text().withDefault(const Constant('medium'))();
  TextColumn get pricingMode => text().withDefault(const Constant('manual'))();
  RealColumn get designFee => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real().withDefault(const Constant(0.0))();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Ítems y Medidas del Pedido.
class OrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  TextColumn get materialId => text().nullable().references(Materials, #id)();
  TextColumn get description => text()();
  RealColumn get widthCm => real().withDefault(const Constant(0.0))();
  RealColumn get heightCm => real().withDefault(const Constant(0.0))();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  RealColumn get wastePercentage => real().withDefault(const Constant(15.0))();
  TextColumn get finishingType => text().withDefault(const Constant('none'))();
  RealColumn get finishingSurcharge => real().withDefault(const Constant(0.0))();
  RealColumn get calculatedPrice => real().withDefault(const Constant(0.0))();
  BoolColumn get deductedFromStock => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Historial de Abonos y Pagos de Pedidos.
class OrderPayments extends Table {
  TextColumn get id => text()();
  TextColumn get orderId => text().references(Orders, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Gastos Diarios Unificados (Negocio + Personal).
class Expenses extends Table {
  TextColumn get id => text()();
  RealColumn get amount => real()();
  TextColumn get scope => text().withDefault(const Constant('business'))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get category => text()();
  TextColumn get subcategory => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get source => text().withDefault(const Constant('app'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Control de Jornada Diaria.
class WorkLogs extends Table {
  TextColumn get id => text()();
  TextColumn get dateKey => text().unique()(); // Formato YYYY-MM-DD
  DateTimeColumn get openTime => dateTime()();
  DateTimeColumn get closeTime => dateTime().nullable()();
  IntColumn get totalWorkedMinutes => integer().withDefault(const Constant(0))();
  IntColumn get totalBreakMinutes => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tabla de Pausas y Diligencias de la Jornada.
class WorkBreaks extends Table {
  TextColumn get id => text()();
  TextColumn get workLogId => text().references(WorkLogs, #id)();
  TextColumn get type => text().withDefault(const Constant('lunch'))();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Cola local transaccional para sincronización Offline-First con Supabase.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityTable => text()();
  TextColumn get recordId => text()();
  TextColumn get operation => text()(); // 'upsert' | 'delete'
  TextColumn get payloadJson => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
