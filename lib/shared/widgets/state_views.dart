import 'package:flutter/material.dart';
import 'app_button.dart';

class LoadingView extends StatelessWidget {
  final String? message;

  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              AppButton(
                label: 'Reintentar',
                icon: Icons.refresh,
                variant: AppButtonVariant.secondary,
                expand: false,
                onPressed: onRetry,
              ),
            ]
          ],
        ),
      ),
    );
  }
}