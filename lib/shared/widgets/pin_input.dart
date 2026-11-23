import 'package:flutter/material.dart';
import 'numeric_keypad.dart';

class PinInput extends StatefulWidget {
  final void Function(String) onPinCompleted;
  final int pinLength;
  final String title;
  final String? errorText;

  const PinInput({
    super.key,
    required this.onPinCompleted,
    this.pinLength = 4,
    this.title = 'Ingresa tu PIN',
    this.errorText,
  });

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  String _currentPin = '';

  void _handleNumberTapped(String number) {
    if (_currentPin.length < widget.pinLength) {
      setState(() {
        _currentPin += number;
      });

      if (_currentPin.length == widget.pinLength) {
        widget.onPinCompleted(_currentPin);
      }
    }
  }

  void _handleBackspaceTapped() {
    if (_currentPin.isNotEmpty) {
      setState(() {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      });
    }
  }

  /// Método público (usando GlobalKey) para limpiar el PIN si hay un error desde afuera
  void clearPin() {
    setState(() {
      _currentPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        
        // Puntos indicadores del PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.pinLength, (index) {
            final isFilled = index < _currentPin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                border: isFilled ? null : Border.all(color: theme.colorScheme.outline),
              ),
            );
          }),
        ),
        
        if (widget.errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.errorText!,
            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
          ),
        ],
        
        const SizedBox(height: 48),
        
        // Teclado numérico
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: NumericKeypad(
            onNumberTapped: _handleNumberTapped,
            onBackspaceTapped: _handleBackspaceTapped,
          ),
        ),
      ],
    );
  }
}