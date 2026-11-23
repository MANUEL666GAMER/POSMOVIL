import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Más adelante conectaremos esto con un provider para alternar el tema (settings)
    return MaterialApp.router(
      title: 'POS MOVIL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Automático por defecto según el OS
      routerConfig: goRouter,
    );
  }
}