import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onNumberTapped;
  final VoidCallback onBackspaceTapped;
  final bool showDecimalPoint;

  const NumericKeypad({
    super.key,
    required this.onNumberTapped,
    required this.onBackspaceTapped,
    this.showDecimalPoint = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 1; i <= 9; i++) _buildButton(context, i.toString()),
        showDecimalPoint
            ? _buildButton(context, '.')
            : const SizedBox.shrink(),
        _buildButton(context, '0'),
        _buildBackspace(context),
      ],
    );
  }

  Widget _buildButton(BuildContext context, String text) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onNumberTapped(text),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBackspace(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onBackspaceTapped,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.backspace_outlined, 
          color: Theme.of(context).colorScheme.error, 
          size: 28
        ),
      ),
    );
  }
}