import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/permission_gate.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';
import '../widgets/stock_movement_dialog.dart';

final inventorySearchProvider = StateProvider<String>((ref) => '');

final inventoryListProvider = FutureProvider.autoDispose((ref) {
  final query = ref.watch(inventorySearchProvider);
  return ref.read(stockRepositoryProvider).getInventory(query: query);
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInventory = ref.watch(inventoryListProvider);
    final user = ref.watch(authStateProvider);
    final role = user != null ? AppRole.fromString(user.role) : AppRole.cashier;

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchField(
              hint: 'Buscar producto en inventario...',
              onChanged: (val) => ref.read(inventorySearchProvider.notifier).state = val,
            ),
          ),
          Expanded(
            child: asyncInventory.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(inventoryListProvider)),
              data: (items) {
                if (items.isEmpty) return const Center(child: Text('No hay productos registrados.'));

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isWeight = item.product.saleType == 'weight';
                    
                    // Convertimos para mostrar al usuario (si está en gramos, lo mostramos en kilos)
                    final displayStock = isWeight 
                        ? (item.currentStock / 1000).toStringAsFixed(3) + ' kg'
                        : '${item.currentStock} pzas';

                    // Color de alerta si hay poco stock
                    final isLowStock = item.currentStock <= item.product.minStock;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isLowStock ? Colors.red.shade100 : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.inventory_2, color: isLowStock ? Colors.red : null),
                      ),
                      title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Stock mínimo: ${isWeight ? (item.product.minStock / 1000).toStringAsFixed(1) + ' kg' : '${item.product.minStock} pzas'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayStock,
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: isLowStock ? Colors.red : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PermissionGate(
                            currentRole: role,
                            requiredPermission: AppPermission.manageInventory,
                            child: IconButton(
                              icon: const Icon(Icons.add_box),
                              tooltip: 'Ajustar Inventario',
                              color: Theme.of(context).colorScheme.primary,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => StockMovementDialog(
                                    product: item.product,
                                    onSuccess: () => ref.invalidate(inventoryListProvider),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}