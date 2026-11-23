import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/app_button.dart';

class WeightInputSheet extends StatefulWidget {
  final Product product;

  const WeightInputSheet({super.key, required this.product});

  static Future<double?> show(BuildContext context, Product product) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: WeightInputSheet(product: product),
      ),
    );
  }

  @override
  State<WeightInputSheet> createState() => _WeightInputSheetState();
}

class _WeightInputSheetState extends State<WeightInputSheet> {
  final _controller = TextEditingController();
  double _calculatedCost = 0.0;

  void _updateCost(String value) {
    final weight = double.tryParse(value) ?? 0.0;
    setState(() {
      _calculatedCost = (widget.product.priceCents / 100) * weight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pesar: ${widget.product.name}', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Precio: ${MoneyUtils.formatCents(widget.product.priceCents)} / kg', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Cantidad en KG (ej. 1.5 para kilo y medio)',
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
            onChanged: _updateCost,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Total: \$${_calculatedCost.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Agregar al carrito',
              onPressed: () {
                final weight = double.tryParse(_controller.text);
                if (weight != null && weight > 0) {
                  Navigator.of(context).pop(weight);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}