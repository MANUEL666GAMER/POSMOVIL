import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/permission_gate.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/product_tile.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import 'product_form_screen.dart'; // Pantalla que crearemos abajo
import '../../../../core/database/app_database.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsListProvider);
    final currentUser = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchField(
              hint: 'Buscar por nombre o código...',
              onChanged: (val) => ref.read(productSearchQueryProvider.notifier).state = val,
              // onScanPressed: () {} // TODO: Activar escáner de cámara en Fase 2
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(productsListProvider)),
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: 'No hay productos que coincidan.',
                    actionLabel: 'Agregar Producto',
                    onAction: () => _goToForm(context, null),
                  );
                }
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductTile(
                      product: product,
                      onTap: () => _goToForm(context, product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        currentRole: currentUser != null ? AppRole.fromString(currentUser.role) : AppRole.cashier,
        requiredPermission: AppPermission.manageProducts,
        child: FloatingActionButton.extended(
          onPressed: () => _goToForm(context, null),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo'),
        ),
      ),
    );
  }

  void _goToForm(BuildContext context, Product? product) {
    // Para simplificar la navegación sin saturar el router central, usamos un Navigator push 
    // convencional para formularios modales de un solo uso.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }
}