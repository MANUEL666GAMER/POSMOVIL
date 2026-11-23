import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';

class CartItem {
  final String id;
  final Product product;
  final double quantity; // 1.0 para piezas, 0.5 para medio kilo, etc.

  CartItem({
    String? id,
    required this.product,
    required this.quantity,
  }) : id = id ?? const Uuid().v4();

  int get subtotalCents => (product.priceCents * quantity).round();
}

class Cart {
  final String id;
  final String name; // Ej: "Cliente 1"
  final List<CartItem> items;

  Cart({
    String? id,
    required this.name,
    this.items = const [],
  }) : id = id ?? const Uuid().v4();

  int get totalCents => items.fold(0, (sum, item) => sum + item.subtotalCents);
  
  Cart copyWith({String? name, List<CartItem>? items}) {
    return Cart(
      id: id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }
}