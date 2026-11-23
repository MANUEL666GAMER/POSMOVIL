import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/product_tile.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../cash_close/presentation/providers/cash_close_provider.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../domain/cart_models.dart';
import '../providers/sales_provider.dart';
import '../screens/scanner_screen.dart';
import '../widgets/checkout_dialog.dart';
import '../widgets/weight_input_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _handleProductTapped(
    BuildContext context,
    WidgetRef ref,
    Product product, {
    int? currentStock,
  }) async {
    if (currentStock != null && currentStock <= 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} aparece agotado en inventario'),
          backgroundColor: context.pos.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (product.saleType == 'weight') {
      final weight = await WeightInputSheet.show(context, product);
      if (weight != null) {
        ref.read(salesProvider.notifier).addProduct(product, quantity: weight);
      }
    } else {
      ref.read(salesProvider.notifier).addProduct(product);
    }
  }

  Future<void> _confirmCloseTab(BuildContext context, WidgetRef ref, int index, Cart cart) async {
    if (cart.items.isEmpty) {
      ref.read(salesProvider.notifier).closeTab(index);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Cancelar la venta de "${cart.name}"?'),
        content: const Text('Se quitarán todos sus productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, regresar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.pos.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar venta'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(salesProvider.notifier).closeTab(index);
    }
  }

  Future<void> _processCheckout(BuildContext context, WidgetRef ref) async {
    final c = context.pos;
    // 1. Verificar turno abierto
    final activeShift = await ref.read(activeShiftProvider.future);
    if (activeShift == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Abre tu turno en Corte de caja antes de cobrar'),
            backgroundColor: c.accent,
            action: SnackBarAction(
              label: 'Abrir turno',
              textColor: c.onAccent,
              onPressed: () => context.push('/cash-close'),
            ),
          ),
        );
      }
      return;
    }

    final activeCart = ref.read(salesProvider).activeCart;
    if (activeCart.items.isEmpty) return;

    // CheckoutDialog guarda la venta, descuenta stock y muestra el ticket
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CheckoutDialog(totalCents: activeCart.totalCents),
    );

    if (success == true) {
      ref.invalidate(inventoryListProvider);
    }
  }

  void _openMobileCartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, sheetRef, _) {
          final cart = sheetRef.watch(salesProvider).activeCart;
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: _CartPanel(
              cart: cart,
              isSheet: true,
              onCheckout: () {
                Navigator.pop(ctx);
                _processCheckout(context, ref);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pos;
    final salesState = ref.watch(salesProvider);
    final productsAsync = ref.watch(productsListProvider);
    final activeCart = salesState.activeCart;
    final inventoryItems = ref.watch(inventoryListProvider).valueOrNull ?? [];
    final stockMap = {for (final i in inventoryItems) i.product.id: i.currentStock};

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => context.go('/dashboard'),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Atrás', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        title: const Text('Vender'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => context.push('/cash-close'),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Corte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // BARRA DE PESTAÑAS DE VENTAS ABIERTAS
          Container(
            color: c.card,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(salesState.carts.length, (index) {
                        final cart = salesState.carts[index];
                        final isActive = index == salesState.activeCartIndex;
                        final hasItems = cart.items.isNotEmpty;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => ref.read(salesProvider.notifier).switchTab(index),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isActive ? c.brandSoft : c.canvas,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isActive ? c.brand : c.line,
                                  width: isActive ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: hasItems ? c.accent : c.faint,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cart.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                                      color: isActive ? c.brandDark : c.ink,
                                    ),
                                  ),
                                  if (hasItems) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      MoneyUtils.formatCents(cart.totalCents),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: c.brandDark,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                  if (salesState.carts.length > 1) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _confirmCloseTab(context, ref, index, cart),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.close_rounded, size: 18, color: c.muted),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                // Botón "+ Nueva venta"
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: BorderSide(color: c.brandLine, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => ref.read(salesProvider.notifier).addTab(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nueva', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: c.line),

          // CONTENIDO RESPONSIVE: Celular vs Tableta
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 1024;
                final crossAxisCount = constraints.maxWidth >= 1280 ? 3 : 2;

                final catalogView = Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: SearchField(
                              hint: 'Buscar producto o código...',
                              onChanged: (val) =>
                                  ref.read(productSearchQueryProvider.notifier).state = val,
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 56),
                              backgroundColor: c.brandSoft,
                              foregroundColor: c.brandDark,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScannerScreen()),
                              );
                              if (result is Product && context.mounted) {
                                _handleProductTapped(
                                  context,
                                  ref,
                                  result,
                                  currentStock: stockMap[result.id],
                                );
                              } else if (result is String &&
                                  result.startsWith('NEW:') &&
                                  context.mounted) {
                                context.push('/products');
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                            label: const Text(
                              'Escanear',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: productsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Error: $e')),
                        data: (products) {
                          if (products.isEmpty) {
                            return Center(
                              child: Text(
                                'No se encontraron productos',
                                style: TextStyle(fontSize: 17, color: c.muted),
                              ),
                            );
                          }
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisExtent: 172,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final currentStock = stockMap[product.id];
                              final qtyInCart = activeCart.items
                                  .where((i) => i.product.id == product.id)
                                  .fold<double>(0, (sum, i) => sum + i.quantity);

                              return ProductTile(
                                product: product,
                                quantityInCart: qtyInCart,
                                currentStock: currentStock,
                                onTap: () => _handleProductTapped(
                                  context,
                                  ref,
                                  product,
                                  currentStock: currentStock,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );

                // En tableta: dos columnas fijas
                if (isTablet) {
                  return Row(
                    children: [
                      Expanded(child: catalogView),
                      VerticalDivider(width: 1, color: c.line),
                      SizedBox(
                        width: constraints.maxWidth >= 1280 ? 440 : 400,
                        child: _CartPanel(
                          cart: activeCart,
                          isSheet: false,
                          onCheckout: () => _processCheckout(context, ref),
                        ),
                      ),
                    ],
                  );
                }

                // En celular: catálogo + barra inferior verde de 72 px
                final totalItemsCount = activeCart.items.length;
                final hasItems = totalItemsCount > 0;

                return Column(
                  children: [
                    Expanded(child: catalogView),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: InkWell(
                          onTap: hasItems ? () => _openMobileCartSheet(context, ref) : null,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: hasItems ? c.brand : c.track,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: hasItems
                                  ? [
                                      BoxShadow(
                                        color: c.brand.withValues(alpha: 0.35),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (hasItems) ...[
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$totalItemsCount ${totalItemsCount == 1 ? 'producto' : 'productos'}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: c.onBrand.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      Text(
                                        MoneyUtils.formatCents(activeCart.totalCents),
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: c.onBrand,
                                          fontFeatures: const [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Ver / Cobrar',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: c.onBrand,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.expand_less_rounded, color: c.onBrand, size: 28),
                                    ],
                                  ),
                                ] else
                                  Expanded(
                                    child: Text(
                                      'Toca un producto para agregarlo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: c.muted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  final Cart cart;
  final bool isSheet;
  final VoidCallback onCheckout;

  const _CartPanel({
    required this.cart,
    required this.isSheet,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pos;

    return Container(
      color: c.card,
      child: Column(
        children: [
          // Encabezado del carrito
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cart.name} (${cart.items.length})',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.ink),
                ),
                if (isSheet)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: c.line),

          // Lista de artículos
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aún no hay productos.\nToca un producto para agregarlo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, color: c.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => Divider(height: 20, color: c.line),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final isWeight = item.product.saleType == 'weight';

                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isWeight
                                      ? '${item.quantity.toStringAsFixed(3)} kg × ${MoneyUtils.formatCents(item.product.priceCents)}'
                                      : '${MoneyUtils.formatCents(item.product.priceCents)} c/u',
                                  style: TextStyle(fontSize: 15, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          if (!isWeight) ...[
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: c.canvas,
                                minimumSize: const Size(44, 44),
                              ),
                              icon: const Icon(Icons.remove_rounded),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  ref
                                      .read(salesProvider.notifier)
                                      .addProduct(item.product, quantity: -1);
                                } else {
                                  ref.read(salesProvider.notifier).removeItem(item.id);
                                }
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${item.quantity.round()}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: c.ink,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: c.brandSoft,
                                foregroundColor: c.brandDark,
                                minimumSize: const Size(44, 44),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              onPressed: () =>
                                  ref.read(salesProvider.notifier).addProduct(item.product, quantity: 1),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                side: BorderSide(color: c.accentLine),
                                backgroundColor: c.accentSoft,
                                foregroundColor: c.accentDark,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final newWeight = await WeightInputSheet.show(
                                  context,
                                  item.product,
                                  initialWeightKg: item.quantity,
                                );
                                if (newWeight != null) {
                                  ref.read(salesProvider.notifier).removeItem(item.id);
                                  ref
                                      .read(salesProvider.notifier)
                                      .addProduct(item.product, quantity: newWeight);
                                }
                              },
                              icon: const Icon(Icons.edit_rounded, size: 16),
                              label: Text(
                                '${item.quantity.toStringAsFixed(3)} kg',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                          const SizedBox(width: 12),
                          Text(
                            MoneyUtils.formatCents(item.subtotalCents),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: c.ink,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                            onPressed: () => ref.read(salesProvider.notifier).removeItem(item.id),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Total y botón gigante COBRAR (72 px)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.card,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.ink),
                    ),
                    Text(
                      MoneyUtils.formatCents(cart.totalCents),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: c.brand,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 72,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.brand,
                      foregroundColor: c.onBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: cart.items.isEmpty ? null : onCheckout,
                    child: Text(
                      cart.items.isEmpty
                          ? 'COBRAR'
                          : 'COBRAR ${MoneyUtils.formatCents(cart.totalCents)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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