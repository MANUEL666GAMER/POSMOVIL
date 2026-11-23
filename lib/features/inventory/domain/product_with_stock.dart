import '../../../../core/database/app_database.dart';

class ProductWithStock {
  final Product product;
  final int currentStock; // en piezas o gramos (según el tipo)

  ProductWithStock({
    required this.product,
    required this.currentStock,
  });
}