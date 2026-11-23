import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/stock_repository.dart';

class StockMovementDialog extends ConsumerStatefulWidget {
  final Product product;
  final VoidCallback onSuccess;

  const StockMovementDialog({
    super.key, 
    required this.product,
    required this.onSuccess,
  });

  @override
  ConsumerState<StockMovementDialog> createState() => _StockMovementDialogState();
}

class _StockMovementDialogState extends ConsumerState<StockMovementDialog> {
  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();
  String _type = 'purchase'; // purchase, waste
  bool _isLoading = false;

  Future<void> _save() async {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) return;

    final user = ref.read(authStateProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(stockRepositoryProvider).addManualMovement(
        productId: widget.product.id,
        type: _type,
        quantityInput: quantity,
        reason: _reasonController.text.trim().isEmpty ? 'Ajuste manual' : _reasonController.text.trim(),
        user: user,
        isWeight: widget.product.saleType == 'weight',
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeight = widget.product.saleType == 'weight';

    return AlertDialog(
      title: Text('Ajuste: ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Tipo de movimiento', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'purchase', child: Text('Entrada (Compra/Proveedor)')),
                DropdownMenuItem(value: 'waste', child: Text('Salida (Merma/Dañado)')),
              ],
              onChanged: (val) => setState(() => _type = val!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isWeight ? 'Cantidad (Kilos)' : 'Cantidad (Piezas)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        AppButton(
          label: 'Guardar',
          isLoading: _isLoading,
          onPressed: _save,
        ),
      ],
    );
  }
}