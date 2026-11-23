import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../domain/cart_models.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(ref.read(databaseProvider));
});

class SalesRepository {
  final AppDatabase _db;
  SalesRepository(this._db);

  /// Guarda la venta completa y descuenta el inventario usando una transacción
  Future<void> saveSale(Cart cart, User cashier) async {
    await _db.transaction(() async {
      final saleId = const Uuid().v4();
      final now = DateTime.now();

      // 1. Crear el encabezado de la Venta (Sales)
      await _db.into(_db.sales).insert(
        SalesCompanion.insert(
          id: saleId,
          status: 'paid', // Venta completada y pagada
          userId: cashier.id,
          totalCents: Value(cart.totalCents),
          paymentMethod: const Value('cash'), // Efectivo por ahora
          paidAt: Value(now),
          createdAt: now,
          updatedAt: now,
        )
      );

      // 2. Insertar cada producto como un renglón y afectar inventario
      for (final item in cart.items) {
        final isWeight = item.product.saleType == 'weight';
        // Regla: Si es peso, multiplicamos por 1000 para guardar en gramos. 
        // Si es unidad, lo dejamos como piezas enteras.
        final int quantityToSave = isWeight 
            ? (item.quantity * 1000).round() 
            : item.quantity.round();

        // Renglón de la venta
        await _db.into(_db.saleItems).insert(
          SaleItemsCompanion.insert(
            id: const Uuid().v4(),
            saleId: saleId,
            productId: item.product.id,
            quantity: quantityToSave,
            unitPriceCents: item.product.priceCents,
            subtotalCents: item.subtotalCents,
            createdAt: now,
            updatedAt: now,
          )
        );

        // 3. Descuento automático de inventario (Kardex)
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            productId: item.product.id,
            type: 'sale',
            quantity: -quantityToSave, // Negativo porque es una salida de inventario
            reason: const Value('Venta desde caja'),
            userId: cashier.id,
            saleId: Value(saleId),
            createdAt: now,
            updatedAt: now,
          )
        );
      }
    });
  }
}