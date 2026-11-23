import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/permission_gate.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import 'product_form_screen.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';


class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  void _openForm(BuildContext context, {Product? product}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pos;
    final productsAsync = ref.watch(productsListProvider);
    final user = ref.watch(authStateProvider);
    final role = user != null ? AppRole.fromString(user.role) : AppRole.cashier;
    final isAdmin = PermissionService.can(role, AppPermission.manageProducts);
    final inventoryItems = ref.watch(inventoryListProvider).valueOrNull ?? [];
    final stockMap = {for (final i in inventoryItems) i.product.id: i.currentStock};


    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: const Text('Productos'),
      ),
      floatingActionButton: PermissionGate(
        currentRole: role,
        requiredPermission: AppPermission.manageProducts,
        child: SizedBox(
          height: 64,
          child: FloatingActionButton.extended(
            backgroundColor: c.brand,
            foregroundColor: c.onBrand,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add_rounded, size: 28),
            label: const Text(
              'Agregar producto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 896),
          child: Column(
            children: [
              // Aviso de solo lectura para cajeros
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
                          'Solo consulta. Pide al administrador cambiar precios.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Buscador
              Padding(
                padding: const EdgeInsets.all(16),
                child: SearchField(
                  hint: 'Buscar por nombre o código...',
                  onChanged: (val) =>
                      ref.read(productSearchQueryProvider.notifier).state = val,
                ),
              ),

              // Lista de productos
              Expanded(
                child: productsAsync.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(message: e.toString()),
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay productos registrados',
                          style: TextStyle(fontSize: 17, color: c.muted),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final isWeight = p.saleType == 'weight';

                        return InkWell(
                          onTap: isAdmin ? () => _openForm(context, product: p) : null,
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
                                // Icono / avatar de producto (56 px)
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: isWeight ? c.accentSoft : c.brandSoft,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    isWeight ? Icons.scale_rounded : Icons.shopping_bag_rounded,
                                    color: isWeight ? c.accentDark : c.brandDark,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Nombre y etiqueta de venta
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: c.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isWeight ? c.accentSoft : c.canvas,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isWeight ? 'Por kg' : 'Por pieza',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: isWeight ? c.accentDark : c.muted,
                                              ),
                                            ),
                                          ),
                                          if (p.barcode != null && p.barcode!.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              p.barcode!,
                                              style: TextStyle(fontSize: 14, color: c.faint),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Precio (22 px tabular)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      MoneyUtils.formatCents(p.priceCents),
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: c.brand,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    if (isAdmin && p.costCents != null)
                                      Text(
                                        'Costo: ${MoneyUtils.formatCents(p.costCents!)}',
                                        style: TextStyle(fontSize: 13, color: c.muted),
                                      ),
                                  ],
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded, color: c.faint),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}