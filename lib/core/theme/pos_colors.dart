import 'package:flutter/material.dart';

@immutable
class PosColors extends ThemeExtension<PosColors> {
  final Color canvas;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color faint;
  final Color track;

  final Color brand;
  final Color brandDark;
  final Color brandSoft;
  final Color brandLine;
  final Color brandDisabled;
  final Color onBrand;

  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color accentLine;
  final Color onAccent;

  final Color danger;
  final Color dangerSoft;
  final Color onDanger;

  final Color info;
  final Color infoSoft;
  final Color ok;

  final Color inverse;
  final Color onInverse;
  final Color hero;
  final Color heroDeep;

  final List<BoxShadow> shadowCard;
  final BoxBorder? cardBorder;

  const PosColors({
    required this.canvas,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.faint,
    required this.track,
    required this.brand,
    required this.brandDark,
    required this.brandSoft,
    required this.brandLine,
    required this.brandDisabled,
    required this.onBrand,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.accentLine,
    required this.onAccent,
    required this.danger,
    required this.dangerSoft,
    required this.onDanger,
    required this.info,
    required this.infoSoft,
    required this.ok,
    required this.inverse,
    required this.onInverse,
    required this.hero,
    required this.heroDeep,
    required this.shadowCard,
    required this.cardBorder,
  });

  static const light = PosColors(
    canvas: Color(0xFFF7F7F7),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1C1C1C),
    muted: Color(0xFF5C665E),
    line: Color(0xFFE6E8E3),
    faint: Color(0xFF8F998F),
    track: Color(0xFFD3D8D0),
    brand: Color(0xFF2E7D32),
    brandDark: Color(0xFF1B5E20),
    brandSoft: Color(0xFFE8F5E9),
    brandLine: Color(0xFFC8E6C9),
    brandDisabled: Color(0xFF9FB9A1),
    onBrand: Color(0xFFFFFFFF),
    accent: Color(0xFFF57C00),
    accentDark: Color(0xFFA65200),
    accentSoft: Color(0xFFFFF3E0),
    accentLine: Color(0xFFFFD59E),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC62828),
    dangerSoft: Color(0xFFFDECEA),
    onDanger: Color(0xFFFFFFFF),
    info: Color(0xFF1565C0),
    infoSoft: Color(0xFFE3F2FD),
    ok: Color(0xFF43A047),
    inverse: Color(0xFF1C1C1C),
    onInverse: Color(0xFFFFFFFF),
    hero: Color(0xFF2E7D32),
    heroDeep: Color(0xFF1B5E20),
    shadowCard: [
      BoxShadow(color: Color(0x0D1C1C1C), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x1A1C1C1C), blurRadius: 18, spreadRadius: -6, offset: Offset(0, 6)),
    ],
    cardBorder: null,
  );

  static const dark = PosColors(
    canvas: Color(0xFF121212),
    card: Color(0xFF1E1E1E),
    ink: Color(0xFFF2F2F2),
    muted: Color(0xFFB0B0B0),
    line: Color(0xFF2C2C2C),
    faint: Color(0xFF808080),
    track: Color(0xFF3A3A3A),
    brand: Color(0xFF66BB6A),
    brandDark: Color(0xFF81C784),
    brandSoft: Color(0xFF1B2E1C),
    brandLine: Color(0xFF2F4A31),
    brandDisabled: Color(0xFF34453A),
    onBrand: Color(0xFF0B1F0C),
    accent: Color(0xFFFFB74D),
    accentDark: Color(0xFFFFCC80),
    accentSoft: Color(0xFF33260F),
    accentLine: Color(0xFF5C4318),
    onAccent: Color(0xFF2B1A00),
    danger: Color(0xFFFF6B6B),
    dangerSoft: Color(0xFF3A1C1C),
    onDanger: Color(0xFF1F0000),
    info: Color(0xFF64B5F6),
    infoSoft: Color(0xFF14263A),
    ok: Color(0xFF66BB6A),
    inverse: Color(0xFFF2F2F2),
    onInverse: Color(0xFF121212),
    hero: Color(0xFF1B3A1D),
    heroDeep: Color(0xFF102612),
    shadowCard: [],
    cardBorder: Border.fromBorderSide(BorderSide(color: Color(0xFF2C2C2C), width: 1)),
  );

  @override
  PosColors copyWith({Color? brand}) => this;

  @override
  PosColors lerp(ThemeExtension<PosColors>? other, double t) {
    if (other is! PosColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension PosThemeContext on BuildContext {
  PosColors get pos => Theme.of(this).extension<PosColors>() ?? PosColors.light;
}