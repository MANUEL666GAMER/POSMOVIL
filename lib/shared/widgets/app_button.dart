import 'package:flutter/material.dart';

enum AppButtonVariant { primary, secondary, danger, outline }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color getBackgroundColor() {
      switch (variant) {
        case AppButtonVariant.primary:
          return theme.colorScheme.primary;
        case AppButtonVariant.secondary:
          return theme.colorScheme.secondary;
        case AppButtonVariant.danger:
          return theme.colorScheme.error;
        case AppButtonVariant.outline:
          return Colors.transparent;
      }
    }

    Color getForegroundColor() {
      if (variant == AppButtonVariant.outline) {
        return theme.colorScheme.primary;
      }
      return theme.colorScheme.onPrimary;
    }

    Widget buttonContent = isLoading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: getForegroundColor(),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          );

    final style = ElevatedButton.styleFrom(
      backgroundColor: getBackgroundColor(),
      foregroundColor: getForegroundColor(),
      elevation: variant == AppButtonVariant.outline ? 0 : 2,
      side: variant == AppButtonVariant.outline
          ? BorderSide(color: theme.colorScheme.primary, width: 2)
          : BorderSide.none,
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: style,
        child: buttonContent,
      ),
    );
  }
}