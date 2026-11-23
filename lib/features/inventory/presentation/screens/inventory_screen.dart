import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';
import '../../domain/product_with_stock.dart';
import '../widgets/stock_movement_dialog.dart';

final inventoryListProvider = FutureProvider.autoDispose<List<ProductWithStock>>((ref) {
  return ref.read(stockRepositoryProvider).getInventory();
});

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _onlyLowStock = false;

  String _formatStock(ProductWithStock item) {
    final isWeight = item.product.saleType == 'weight';
    if (isWeight) {
      return '${(item.currentStock / 1000).toStringAsFixed(3)} kg';
    }
    return '${item.currentStock} pzas';
  }

  String _formatMinStock(ProductWithStock item) {
    final isWeight = item.product.saleType == 'weight';
    if (isWeight) {
      return '${(item.product.minStock / 1000).toStringAsFixed(2)} kg';
    }
    return '${item.product.minStock} pzas';
  }

  void _openMovementDialog(ProductWithStock item) {
    showDialog(
      context: context,
      builder: (_) => StockMovementDialog(
        product: item.product,
        onSuccess: () => ref.invalidate(inventoryListProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final inventoryAsync = ref.watch(inventoryListProvider);
    final user = ref.watch(authStateProvider);
    final role = user != null ? AppRole.fromString(user.role) : AppRole.cashier;
    final isAdmin = PermissionService.can(role, AppPermission.manageInventory);
    

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text('Inventario'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: inventoryAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (items) {
              final outCount = items.where((i) => i.currentStock <= 0).length;
              final lowCount = items.where((i) => i.currentStock > 0 && i.currentStock <= i.product.minStock).length;
              final okCount = items.where((i) => i.currentStock > i.product.minStock).length;

              final sorted = List<ProductWithStock>.from(items)
                ..sort((a, b) {
                  int rank(ProductWithStock x) {
                    if (x.currentStock <= 0) return 0;
                    if (x.currentStock <= x.product.minStock) return 1;
                    return 2;
                  }
                  final r = rank(a).compareTo(rank(b));
                  return r != 0 ? r : a.product.name.compareTo(b.product.name);
                });

              final filtered = _onlyLowStock
                  ? sorted.where((i) => i.currentStock <= i.product.minStock).toList()
                  : sorted;

              return Column(
                children: [
                  if (!isAdmin)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.infoSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: c.info),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Solo consulta. El administrador registra entradas y ajustes.',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(child: _SummaryPill(label: 'Normal', count: okCount, color: c.ok, bg: c.brandSoft)),
                        const SizedBox(width: 10),
                        Expanded(child: _SummaryPill(label: 'Se acaba', count: lowCount, color: c.accent, bg: c.accentSoft)),
                        const SizedBox(width: 10),
                        Expanded(child: _SummaryPill(label: 'Agotado', count: outCount, color: c.danger, bg: c.dangerSoft)),
                      ],
                    ),
                  ),

                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Material(
                      color: c.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: c.line),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          'Solo lo que se acaba',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink),
                        ),
                        value: _onlyLowStock,
                        onChanged: (v) => setState(() => _onlyLowStock = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              _onlyLowStock ? '¡Todo está bien surtido!' : 'No hay productos en inventario',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.muted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final isOut = item.currentStock <= 0;
                              final isLow = !isOut && item.currentStock <= item.product.minStock;

                              final statusColor = isOut
                                  ? c.danger
                                  : isLow
                                      ? c.accent
                                      : c.ok;
                              final statusBg = isOut
                                  ? c.dangerSoft
                                  : isLow
                                      ? c.accentSoft
                                      : c.brandSoft;
                              final statusLabel = isOut
                                  ? 'Agotado'
                                  : isLow
                                      ? 'Poco'
                                      : 'Normal';

                              return InkWell(
                                onTap: isAdmin ? () => _openMovementDialog(item) : null,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: c.cardBorder ?? Border.all(color: c.line),
                                    boxShadow: c.shadowCard,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.name,
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Aviso al bajar de ${_formatMinStock(item)}',
                                              style: TextStyle(fontSize: 14, color: c.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatStock(item),
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: statusColor,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusBg,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.circle, size: 8, color: statusColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 8),
                                        Icon(Icons.edit_rounded, size: 20, color: c.faint),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bg;

  const _SummaryPill({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}