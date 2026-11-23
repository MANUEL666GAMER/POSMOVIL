import 'package:flutter/material.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/app_button.dart';

class CheckoutDialog extends StatefulWidget {
  final int totalCents;

  const CheckoutDialog({super.key, required this.totalCents});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _cashController = TextEditingController();
  int _cashReceivedCents = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changeCents = _cashReceivedCents - widget.totalCents;
    final isSufficient = _cashReceivedCents >= widget.totalCents;

    return AlertDialog(
      title: const Text('Cobrar Venta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Total a cobrar', style: theme.textTheme.titleMedium),
          Text(
            MoneyUtils.formatCents(widget.totalCents),
            style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _cashController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Efectivo recibido',
              prefixIcon: Icon(Icons.attach_money),
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              setState(() {
                _cashReceivedCents = MoneyUtils.parseToCents(val);
              });
            },
          ),
          const SizedBox(height: 24),
          if (_cashReceivedCents > 0) ...[
            Text('Cambio', style: theme.textTheme.titleMedium),
            Text(
              isSufficient ? MoneyUtils.formatCents(changeCents) : 'Falta dinero',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: isSufficient ? Colors.green : Colors.red,
              ),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        AppButton(
          label: 'Confirmar Venta',
          onPressed: isSufficient ? () => Navigator.pop(context, true) : null,
        ),
      ],
    );
  }
}