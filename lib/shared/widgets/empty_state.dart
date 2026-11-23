import 'package:flutter/material.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              expand: false,
            ),
          ]
        ],
      ),
    );
  }
}