import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(databaseProvider));
});

class ProductsRepository {
  final AppDatabase _db;
  ProductsRepository(this._db);

  Future<List<Product>> getAllProducts({String? query}) async {
    final stmt = _db.select(_db.products)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm(expression: p.name)]);

    final results = await stmt.get();
    if (query == null || query.trim().isEmpty) return results;

    final q = query.trim().toLowerCase();
    return results.where((p) {
      final matchName = p.name.toLowerCase().contains(q);
      final matchCode = p.barcode?.toLowerCase().contains(q) ?? false;
      return matchName || matchCode;
    }).toList();
  }

  Future<void> createProduct({
    required String name,
    required String saleType,
    required int priceCents,
    int? costCents,
    String? categoryId,
    String? barcode,
    required int minStock,
    int initialStock = 0,
    required String userId,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      final productId = const Uuid().v4();

      await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              id: productId,
              name: name,
              saleType: saleType,
              priceCents: priceCents,
              costCents: Value(costCents),
              categoryId: Value(categoryId),
              barcode: Value(barcode),
              minStock: Value(minStock),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (initialStock > 0) {
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: const Uuid().v4(),
                productId: productId,
                type: 'purchase',
                quantity: initialStock,
                reason: const Value('Existencia inicial'),
                userId: userId,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required String saleType,
    required int priceCents,
    int? costCents,
    String? categoryId,
    String? barcode,
    required int minStock,
  }) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        saleType: Value(saleType),
        priceCents: Value(priceCents),
        costCents: Value(costCents),
        categoryId: Value(categoryId),
        barcode: Value(barcode),
        minStock: Value(minStock),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteProduct(String id) async {
    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
  Future<List<Product>> getProducts({String? query}) {
    return getAllProducts(query: query);
  }

}

