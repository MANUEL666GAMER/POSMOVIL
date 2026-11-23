import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/cart_models.dart';
import '../../../../core/database/app_database.dart';

class SalesState {
  final List<Cart> carts;
  final int activeCartIndex;

  SalesState({required this.carts, required this.activeCartIndex});
  
  Cart get activeCart => carts[activeCartIndex];
}

class SalesNotifier extends StateNotifier<SalesState> {
  SalesNotifier() : super(SalesState(
    carts: [Cart(name: 'Cliente 1')], 
    activeCartIndex: 0,
  ));

  void addTab() {
    final newCarts = [...state.carts, Cart(name: 'Cliente ${state.carts.length + 1}')];
    state = SalesState(carts: newCarts, activeCartIndex: newCarts.length - 1);
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.carts.length) {
      state = SalesState(carts: state.carts, activeCartIndex: index);
    }
  }

  void closeTab(int index) {
    if (state.carts.length == 1) {
      // Si es la última pestaña, solo la vaciamos
      state = SalesState(carts: [Cart(name: 'Cliente 1')], activeCartIndex: 0);
      return;
    }
    
    final newCarts = [...state.carts]..removeAt(index);
    final newIndex = state.activeCartIndex >= newCarts.length 
        ? newCarts.length - 1 
        : state.activeCartIndex;
        
    state = SalesState(carts: newCarts, activeCartIndex: newIndex);
  }

  void addProduct(Product product, {double quantity = 1.0}) {
    final activeCart = state.activeCart;
    
    // Si es por pieza, buscamos si ya existe para sumar cantidad
    if (product.saleType == 'unit') {
      final existingIndex = activeCart.items.indexWhere((item) => item.product.id == product.id);
      if (existingIndex >= 0) {
        final existingItem = activeCart.items[existingIndex];
        final updatedItems = [...activeCart.items];
        updatedItems[existingIndex] = CartItem(
          id: existingItem.id,
          product: product, 
          quantity: existingItem.quantity + quantity
        );
        _updateActiveCart(activeCart.copyWith(items: updatedItems));
        return;
      }
    }
    
    // Si es peso o no existe, agregamos nuevo renglón
    final newItem = CartItem(product: product, quantity: quantity);
    _updateActiveCart(activeCart.copyWith(items: [...activeCart.items, newItem]));
  }

  void removeItem(String itemId) {
    final activeCart = state.activeCart;
    final updatedItems = activeCart.items.where((item) => item.id != itemId).toList();
    _updateActiveCart(activeCart.copyWith(items: updatedItems));
  }

  void clearActiveCart() {
    _updateActiveCart(state.activeCart.copyWith(items: []));
  }

  void _updateActiveCart(Cart updatedCart) {
    final newCarts = [...state.carts];
    newCarts[state.activeCartIndex] = updatedCart;
    state = SalesState(carts: newCarts, activeCartIndex: state.activeCartIndex);
  }
}

final salesProvider = StateNotifierProvider<SalesNotifier, SalesState>((ref) {
  return SalesNotifier();
});