import 'package:intl/intl.dart';

class MoneyUtils {
  static final _format = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  /// Convierte centavos (int) a texto formateado (ej. $85.50)
  static String formatCents(int cents) {
    return _format.format(cents / 100);
  }

  /// Convierte un texto (ej. "85.50") a centavos (8550)
  static int parseToCents(String text) {
    if (text.trim().isEmpty) return 0;
    // Reemplazamos coma por punto por si el usuario se equivoca
    final normalized = text.replaceAll(',', '.');
    final parsed = double.tryParse(normalized) ?? 0.0;
    return (parsed * 100).round();
  }
}