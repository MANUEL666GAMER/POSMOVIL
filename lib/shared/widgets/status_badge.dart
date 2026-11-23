import 'package:flutter/material.dart';

enum StatusBadgeType { normal, lowStock, outOfStock, surplus, shortage }

class StatusBadge extends StatelessWidget {
  final String text;
  final StatusBadgeType type;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (type) {
      case StatusBadgeType.normal:
        backgroundColor = Colors.green.shade600;
        break;
      case StatusBadgeType.lowStock:
        backgroundColor = Colors.orange.shade600;
        break;
      case StatusBadgeType.outOfStock:
        backgroundColor = Colors.red.shade600;
        break;
      case StatusBadgeType.surplus:
        backgroundColor = Colors.blue.shade600;
        break;
      case StatusBadgeType.shortage:
        backgroundColor = Colors.deepPurple.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}