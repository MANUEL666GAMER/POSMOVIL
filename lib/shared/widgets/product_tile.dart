import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/pos_colors.dart';
import '../../core/utils/money.dart';

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final double quantityInCart;
  final int? currentStock;

  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
    this.quantityInCart = 0,
    this.currentStock,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final isWeight = product.saleType == 'weight';
    final inCart = quantityInCart > 0;
    final isOutOfStock = currentStock != null && currentStock! <= 0;
    final isLowStock = currentStock != null && !isOutOfStock && currentStock! <= product.minStock;

    String stockText = '';
    if (currentStock != null) {
      stockText = isWeight
          ? '${(currentStock! / 1000).toStringAsFixed(2)} kg'
          : '$currentStock pzas';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inCart ? c.brandSoft : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? c.brand : c.line,
            width: inCart ? 2.5 : 1,
          ),
          boxShadow: c.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fila superior: Icono + badges (cantidad en carrito / Agotado / por kg)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isWeight ? c.accentSoft : c.brandSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isWeight ? Icons.scale_rounded : Icons.inventory_2_rounded,
                    color: isWeight ? c.accentDark : c.brandDark,
                    size: 24,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (inCart)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isWeight
                              ? '${quantityInCart.toStringAsFixed(2)} kg'
                              : '×${quantityInCart.round()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: c.onBrand,
                          ),
                        ),
                      ),
                    if (isOutOfStock) ...[
                      if (inCart) const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.dangerSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Agotado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.danger,
                          ),
                        ),
                      ),
                    ] else if (!inCart && isWeight)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'por kg',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.accentDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Nombre del producto
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: c.ink,
              ),
            ),

            const SizedBox(height: 4),

            // Fila inferior: Precio grande + Existencia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  MoneyUtils.formatCents(product.priceCents),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: c.brand,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (currentStock != null && !isOutOfStock)
                  Text(
                    stockText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isLowStock ? c.accentDark : c.muted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}