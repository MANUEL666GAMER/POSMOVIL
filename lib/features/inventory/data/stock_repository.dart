import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../domain/product_with_stock.dart';

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(ref.read(databaseProvider));
});

class StockRepository {
  final AppDatabase _db;
  StockRepository(this._db);

  /// Calcula el inventario actual agrupando y sumando los movimientos
  Future<List<ProductWithStock>> getInventory({String query = ''}) async {
    final stockSum = _db.stockMovements.quantity.sum();
    
    final select = _db.select(_db.products).join([
      leftOuterJoin(
        _db.stockMovements, 
        _db.stockMovements.productId.equalsExp(_db.products.id)
      )
    ]);
    
    select.addColumns([stockSum]);
    select.groupBy([_db.products.id]);
    
    // Solo productos activos
    select.where(_db.products.deletedAt.isNull());

    if (query.isNotEmpty) {
      final searchTerm = '%$query%';
      select.where(
        _db.products.name.like(searchTerm) | 
        _db.products.barcode.like(searchTerm)
      );
    }

    final results = await select.get();

    return results.map((row) {
      final product = row.readTable(_db.products);
      final currentStock = row.read(stockSum) ?? 0;
      return ProductWithStock(product: product, currentStock: currentStock);
    }).toList();
  }

  /// Registra una entrada o salida manual (compra, merma, ajuste)
  Future<void> addManualMovement({
    required String productId,
    required String type, // 'purchase', 'adjustment', 'waste'
    required double quantityInput, // Lo que el usuario teclea (ej. 1.5 kg o 5 pzas)
    required String reason,
    required User user,
    required bool isWeight,
  }) async {
    // Si es peso, convertimos a gramos. Si es negativo (merma), lo volvemos negativo.
    int finalQuantity = isWeight ? (quantityInput * 1000).round() : quantityInput.round();
    
    if (type == 'waste' || type == 'adjustment_out') {
      finalQuantity = -finalQuantity.abs();
    } else {
      finalQuantity = finalQuantity.abs();
    }

    final now = DateTime.now();
    await _db.into(_db.stockMovements).insert(
      StockMovementsCompanion.insert(
        id: const Uuid().v4(),
        productId: productId,
        type: type,
        quantity: finalQuantity,
        reason: Value(reason),
        userId: user.id,
        createdAt: now,
        updatedAt: now,
      )
    );
  }
}