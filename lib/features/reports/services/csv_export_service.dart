import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';

class CsvExportService {
  static Future<void> exportSales(List<Sale> sales) async {
    if (sales.isEmpty) throw Exception('No hay ventas para exportar');

    // Crear el encabezado del CSV
    final buffer = StringBuffer();
    buffer.writeln('ID Venta,Fecha,Estado,Total,Metodo de Pago');

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    // Llenar las filas
    for (final sale in sales) {
      final dateStr = dateFormat.format(sale.createdAt);
      final totalStr = MoneyUtils.formatCents(sale.totalCents).replaceAll(',', ''); // Limpiar comas para CSV
      buffer.writeln('${sale.id},$dateStr,${sale.status},$totalStr,${sale.paymentMethod}');
    }

    // Guardar en el dispositivo
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/ventas_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    // Compartir el archivo (para que el usuario lo mande por WhatsApp, Correo, etc.)
    await Share.shareXFiles([XFile(path)], text: 'Reporte de Ventas POS');
  }
}