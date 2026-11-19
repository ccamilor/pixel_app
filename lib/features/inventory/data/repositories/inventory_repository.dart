import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_enums.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/sync_engine.dart';
import '../../domain/entities/material_entity.dart';

/// Repositorio Offline-First de Inventario/Materiales con control de stock mínimo.
class InventoryRepository {
  InventoryRepository(this._db, this._syncEngine);

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  static const _uuid = Uuid();

  Stream<List<MaterialEntity>> watchMaterials() {
    return (_db.select(_db.materials)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch()
        .map((rows) => rows.map(_toEntity).toList());
  }

  Future<MaterialEntity> saveMaterial({
    String? id,
    required String name,
    required MaterialUnit unit,
    required double unitCost,
    required double suggestedSalePrice,
    required double defaultWastePercentage,
    required double stock,
    required double minStock,
  }) async {
    final now = DateTime.now().toUtc();
    final recordId = id ?? _uuid.v4();
    final unitDb = _unitToDb(unit);

    await _db.into(_db.materials).insertOnConflictUpdate(
      MaterialsCompanion(
        id: Value(recordId),
        name: Value(name.trim()),
        unit: Value(unitDb),
        unitCost: Value(unitCost),
        suggestedSalePrice: Value(suggestedSalePrice),
        defaultWastePercentage: Value(defaultWastePercentage),
        stock: Value(stock),
        minStock: Value(minStock),
        updatedAt: Value(now),
      ),
    );

    await _db.enqueueSync(
      entityTable: 'materials',
      recordId: recordId,
      operation: 'upsert',
      payload: {
        'id': recordId,
        'name': name.trim(),
        'unit': unitDb,
        'unit_cost': unitCost,
        'suggested_sale_price': suggestedSalePrice,
        'default_waste_percentage': defaultWastePercentage,
        'stock': stock,
        'min_stock': minStock,
        'updated_at': now.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();

    return MaterialEntity(
      id: recordId,
      name: name.trim(),
      unit: unit,
      unitCost: unitCost,
      suggestedSalePrice: suggestedSalePrice,
      defaultWastePercentage: defaultWastePercentage,
      stock: stock,
      minStock: minStock,
      updatedAt: now,
    );
  }

  /// Ajusta el stock actual (positivo para reposición, negativo para consumo de pedido).
  Future<void> adjustStock(String materialId, double delta) async {
    final existing =
        await (_db.select(_db.materials)
              ..where((t) => t.id.equals(materialId)))
            .getSingleOrNull();
    if (existing == null) return;

    final nextStock = (existing.stock + delta).clamp(0.0, double.infinity);
    final now = DateTime.now().toUtc();

    await (_db.update(_db.materials)..where((t) => t.id.equals(materialId)))
        .write(
          MaterialsCompanion(
            stock: Value(nextStock),
            updatedAt: Value(now),
          ),
        );

    await _db.enqueueSync(
      entityTable: 'materials',
      recordId: materialId,
      operation: 'upsert',
      payload: {
        'id': materialId,
        'name': existing.name,
        'unit': existing.unit,
        'unit_cost': existing.unitCost,
        'suggested_sale_price': existing.suggestedSalePrice,
        'default_waste_percentage': existing.defaultWastePercentage,
        'stock': nextStock,
        'min_stock': existing.minStock,
        'updated_at': now.toIso8601String(),
      },
    );

    _syncEngine.syncPendingChanges();
  }

  Future<void> deleteMaterial(String id) async {
    final now = DateTime.now().toUtc();
    await (_db.update(_db.materials)..where((t) => t.id.equals(id))).write(
      MaterialsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
    await _db.enqueueSync(
      entityTable: 'materials',
      recordId: id,
      operation: 'delete',
      payload: {'deleted_at': now.toIso8601String()},
    );
    _syncEngine.syncPendingChanges();
  }

  MaterialEntity _toEntity(Material row) {
    return MaterialEntity(
      id: row.id,
      name: row.name,
      unit: _unitFromDb(row.unit),
      unitCost: row.unitCost,
      suggestedSalePrice: row.suggestedSalePrice,
      defaultWastePercentage: row.defaultWastePercentage,
      stock: row.stock,
      minStock: row.minStock,
      updatedAt: row.updatedAt,
    );
  }

  String _unitToDb(MaterialUnit unit) {
    return switch (unit) {
      MaterialUnit.m2 => 'm2',
      MaterialUnit.cm2 => 'cm2',
      MaterialUnit.unit => 'unit',
      MaterialUnit.linearMeter => 'linear_meter',
    };
  }

  MaterialUnit _unitFromDb(String raw) {
    return switch (raw) {
      'cm2' => MaterialUnit.cm2,
      'unit' => MaterialUnit.unit,
      'linear_meter' => MaterialUnit.linearMeter,
      _ => MaterialUnit.m2,
    };
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(syncEngineProvider),
  );
});

final materialsStreamProvider = StreamProvider<List<MaterialEntity>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchMaterials();
});
