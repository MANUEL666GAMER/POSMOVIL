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

  Future<List<Product>> getProducts({String query = ''}) async {
    final select = _db.select(_db.products)
      ..where((p) => p.deletedAt.isNull()); // Regla: Solo productos activos

    if (query.isNotEmpty) {
      final searchTerm = '%$query%';
      select.where((p) => 
        p.name.like(searchTerm) | 
        (p.barcode.like(searchTerm))
      );
    }
    
    return await select.get();
  }

  Future<void> saveProduct({
    String? id, // Si es nulo, es uno nuevo
    required String name,
    required String? barcode,
    required String saleType,
    required int priceCents,
  }) async {
    final now = DateTime.now();
    
    if (id == null) {
      // Crear
      await _db.into(_db.products).insert(
        ProductsCompanion.insert(
          id: const Uuid().v4(),
          name: name,
          barcode: Value(barcode),
          saleType: saleType,
          priceCents: priceCents,
          createdAt: now,
          updatedAt: now,
        )
      );
    } else {
      // Editar
      await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          name: Value(name),
          barcode: Value(barcode),
          saleType: Value(saleType),
          priceCents: Value(priceCents),
          updatedAt: Value(now),
        )
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    // Regla de negocio: Borrado lógico
    await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        deletedAt: Value(DateTime.now()),
      )
    );
  }
}