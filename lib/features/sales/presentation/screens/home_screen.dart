import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/permission_gate.dart';
import '../../../../shared/widgets/product_tile.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cash_close/presentation/providers/cash_close_provider.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../data/sales_repository.dart';
import '../providers/sales_provider.dart';
import '../widgets/checkout_dialog.dart';
import '../widgets/weight_input_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _handleProductTapped(BuildContext context, WidgetRef ref, dynamic product) async {
    if (product.saleType == 'weight') {
      final weight = await WeightInputSheet.show(context, product);
      if (weight != null) {
        ref.read(salesProvider.notifier).addProduct(product, quantity: weight);
      }
    } else {
      ref.read(salesProvider.notifier).addProduct(product);
    }
  }

  Future<void> _processCheckout(BuildContext context, WidgetRef ref) async {
    // 1. Verificamos si la caja está abierta primero
    final activeShift = await ref.read(activeShiftProvider.future);
    if (activeShift == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes abrir tu turno en "Caja" antes de poder cobrar'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final activeCart = ref.read(salesProvider).activeCart;
    if (activeCart.items.isEmpty) return;

    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(totalCents: activeCart.totalCents),
    );

    if (success == true) {
      final currentUser = ref.read(authStateProvider);

      if (currentUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: No hay sesión activa')),
          );
        }
        return;
      }

      try {
        // 1. Guardar la venta y descontar stock en BD
        await ref.read(salesRepositoryProvider).saveSale(activeCart, currentUser);

        // 2. Limpiar el carrito
        ref.read(salesProvider.notifier).clearActiveCart();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Venta cobrada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesProvider);
    final productsAsync = ref.watch(productsListProvider);
    final currentUser = ref.watch(authStateProvider);
    final userRole = currentUser != null
        ? AppRole.fromString(currentUser.role)
        : AppRole.cashier;
    final activeCart = salesState.activeCart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Turno y Corte de Caja',
            onPressed: () => context.push('/cash-close'),
          ),
          IconButton(
            icon: const Icon(Icons.inventory),
            tooltip: 'Catálogo de Productos',
            onPressed: () => context.push('/products'),
          ),
          IconButton(
            icon: const Icon(Icons.warehouse),
            tooltip: 'Inventario',
            onPressed: () => context.push('/inventory'),
          ),
          PermissionGate(
            currentRole: userRole,
            requiredPermission: AppPermission.viewReports,
            child: IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Reportes y Cortes',
              onPressed: () => context.push('/reports'),
            ),
          ),
          PermissionGate(
            currentRole: userRole,
            requiredPermission: AppPermission.manageSettings,
            child: IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Configuración y Respaldo',
              onPressed: () => context.push('/settings'),
            ),
          ),
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              ref.read(authStateProvider.notifier).state = null;
              context.go('/login');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // PANEL IZQUIERDO: Pestañas y Carrito
          Expanded(
            flex: 4,
            child: Column(
              children: [
                // Pestañas de clientes
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(salesState.carts.length, (index) {
                              final cart = salesState.carts[index];
                              final isActive = index == salesState.activeCartIndex;
                              return InkWell(
                                onTap: () => ref.read(salesProvider.notifier).switchTab(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isActive
                                            ? Theme.of(context).colorScheme.primary
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        cart.name,
                                        style: TextStyle(
                                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => ref.read(salesProvider.notifier).closeTab(index),
                                        child: const Icon(Icons.close, size: 16),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'Nuevo cliente',
                        onPressed: () => ref.read(salesProvider.notifier).addTab(),
                      )
                    ],
                  ),
                ),

                // Lista de productos en carrito
                Expanded(
                  child: activeCart.items.isEmpty
                      ? const Center(child: Text('Carrito vacío'))
                      : ListView.builder(
                          itemCount: activeCart.items.length,
                          itemBuilder: (context, index) {
                            final item = activeCart.items[index];
                            return ListTile(
                              title: Text(item.product.name),
                              subtitle: Text(
                                '${item.quantity} ${item.product.saleType == 'weight' ? 'kg' : 'pza'} x ${MoneyUtils.formatCents(item.product.priceCents)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    MoneyUtils.formatCents(item.subtotalCents),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => ref.read(salesProvider.notifier).removeItem(item.id),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // Resumen y botón de pago
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(
                            MoneyUtils.formatCents(activeCart.totalCents),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: activeCart.items.isEmpty
                              ? null
                              : () => _processCheckout(context, ref),
                          child: const Text(
                            'COBRAR',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // PANEL DERECHO: Buscador y Catálogo Rápido
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SearchField(
                    hint: 'Buscar producto...',
                    onChanged: (val) => ref.read(productSearchQueryProvider.notifier).state = val,
                  ),
                ),
                Expanded(
                  child: productsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (products) => GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ProductTile(
                          product: product,
                          onTap: () => _handleProductTapped(context, ref, product),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}