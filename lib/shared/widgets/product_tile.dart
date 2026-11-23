import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  // TODO: Agregar parámetro existencia e inventario en Fase 2

  const ProductTile({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeight = product.saleType == 'weight';
    
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isWeight ? Icons.scale : Icons.inventory_2,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(product.barcode ?? 'Sin código'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            MoneyUtils.formatCents(product.priceCents),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 16,
            ),
          ),
          Text(
            isWeight ? 'por kg' : 'por pza',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}