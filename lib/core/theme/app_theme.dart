import 'package:flutter/material.dart';
import 'pos_colors.dart';

class AppTheme {
  static ThemeData build(PosColors c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.canvas,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.brand,
        onPrimary: c.onBrand,
        secondary: c.accent,
        onSecondary: c.onAccent,
        error: c.danger,
        onError: c.onDanger,
        surface: c.card,
        onSurface: c.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.card,
        foregroundColor: c.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: c.ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1),
      cardTheme: CardThemeData(
        color: c.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: brightness == Brightness.dark
              ? BorderSide(color: c.line, width: 1)
              : BorderSide.none,
        ),
      ),
      extensions: [c],
    );
  }

  static ThemeData get lightTheme => build(PosColors.light, Brightness.light);
  static ThemeData get darkTheme => build(PosColors.dark, Brightness.dark);
}