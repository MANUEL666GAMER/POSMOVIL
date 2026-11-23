import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/products_repository.dart';

// Guarda el texto del buscador
final productSearchQueryProvider = StateProvider<String>((ref) => '');

// Escucha el buscador y actualiza la lista automáticamente
final productsListProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final query = ref.watch(productSearchQueryProvider);
  final repo = ref.read(productsRepositoryProvider);
  return await repo.getProducts(query: query);
});