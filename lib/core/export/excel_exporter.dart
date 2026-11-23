import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/inventory/domain/product_with_stock.dart';
import '../../features/reports/domain/report_models.dart';

class ExcelExporter {
  static Future<File> generateSalesReport({
    required DateTimeRange range,
    required DashboardMetrics metrics,
    required List<SaleWithUser> sales,
    required List<SaleDetailRow> saleDetails,
    required List<TopProduct> topProducts,
    required List<ProductWithStock> inventory,
    required List<CashCloseWithUser> cashCloses,
  }) async {
    final excel = Excel.createExcel();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final dateTimeFmt = DateFormat('dd/MM/yyyy HH:mm');

    // Estilos de encabezado compatibles con excel ^3.0.0
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#2E7D32',
      fontColorHex: '#FFFFFF',
    );

    // 1. HOJA: RESUMEN
    final sheetResumen = excel['Resumen'];
    excel.setDefaultSheet('Resumen');

    _appendRow(sheetResumen, ['Concepto', 'Valor'], style: headerStyle);
    _appendRow(sheetResumen, ['Periodo', '${dateFmt.format(range.start)} al ${dateFmt.format(range.end)}']);
    _appendRow(sheetResumen, ['Total de Tickets', metrics.totalSalesCount]);
    _appendRow(sheetResumen, ['Ingresos Totales (\$)', metrics.totalRevenueCents / 100]);
    _appendRow(sheetResumen, ['Ganancia Estimada (\$)', metrics.totalProfitCents / 100]);

    // 2. HOJA: VENTAS
    final sheetVentas = excel['Ventas'];
    _appendRow(sheetVentas, ['Folio', 'Fecha', 'Cajero', 'Método de Pago', 'Total (\$)'], style: headerStyle);
    for (final item in sales) {
      _appendRow(sheetVentas, [
        item.sale.id.substring(0, 8).toUpperCase(),
        dateTimeFmt.format(item.sale.createdAt),
        item.userName,
        item.sale.paymentMethod ?? 'Efectivo',
        item.sale.totalCents / 100,
      ]);
    }

    // 3. HOJA: DETALLE DE VENTAS
    final sheetDetalle = excel['Detalle de ventas'];
    _appendRow(sheetDetalle, ['Folio Venta', 'Fecha', 'Producto', 'Cantidad / Peso', 'Unidad', 'Precio Unit. (\$)', 'Subtotal (\$)'], style: headerStyle);
    for (final d in saleDetails) {
      final isWeight = d.product.saleType == 'weight';
      _appendRow(sheetDetalle, [
        d.saleId.substring(0, 8).toUpperCase(),
        dateTimeFmt.format(d.date),
        d.product.name,
        isWeight ? d.quantity / 1000 : d.quantity,
        isWeight ? 'kg' : 'pza',
        d.unitPriceCents / 100,
        d.subtotalCents / 100,
      ]);
    }

    // 4. HOJA: MÁS VENDIDOS
    final sheetTop = excel['Más vendidos'];
    _appendRow(sheetTop, ['Producto', 'Cantidad / Kilos Vendidos', 'Unidad', 'Total Generado (\$)'], style: headerStyle);
    for (final t in topProducts) {
      final isWeight = t.product.saleType == 'weight';
      _appendRow(sheetTop, [
        t.product.name,
        isWeight ? t.totalQuantity / 1000 : t.totalQuantity,
        isWeight ? 'kg' : 'pza',
        t.totalRevenueCents / 100,
      ]);
    }

    // 5. HOJA: INVENTARIO
    final sheetInv = excel['Inventario'];
    _appendRow(sheetInv, ['Producto', 'Código', 'Existencia Actual', 'Unidad', 'Stock Mínimo', 'Estado'], style: headerStyle);
    for (final inv in inventory) {
      final isWeight = inv.product.saleType == 'weight';
      final isLow = inv.currentStock <= inv.product.minStock;
      _appendRow(sheetInv, [
        inv.product.name,
        inv.product.barcode ?? '',
        isWeight ? inv.currentStock / 1000 : inv.currentStock,
        isWeight ? 'kg' : 'pza',
        isWeight ? inv.product.minStock / 1000 : inv.product.minStock,
        inv.currentStock <= 0 ? 'AGOTADO' : (isLow ? 'STOCK BAJO' : 'NORMAL'),
      ]);
    }

    // 6. HOJA: CORTES DE CAJA
    final sheetCortes = excel['Cortes de caja'];
    _appendRow(sheetCortes, ['Usuario', 'Apertura', 'Cierre', 'Fondo Inicial (\$)', 'Esperado (\$)', 'Contado (\$)', 'Diferencia (\$)'], style: headerStyle);
    for (final c in cashCloses) {
      _appendRow(sheetCortes, [
        c.userName,
        dateTimeFmt.format(c.cashClose.openedAt),
        c.cashClose.closedAt != null ? dateTimeFmt.format(c.cashClose.closedAt!) : 'Abierto',
        c.cashClose.openingFloatCents / 100,
        (c.cashClose.expectedCashCents ?? 0) / 100,
        (c.cashClose.countedCashCents ?? 0) / 100,
        (c.cashClose.differenceCents ?? 0) / 100,
      ]);
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('No se pudo generar el archivo Excel');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'reporte_ventas_${dateFmt.format(range.start)}_a_${dateFmt.format(range.end)}.xlsx';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    return file;
  }

  static void _appendRow(Sheet sheet, List<dynamic> values, {CellStyle? style}) {
    sheet.appendRow(values);

    if (style != null) {
      final lastRowIndex = sheet.maxRows - 1;
      for (int col = 0; col < values.length; col++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: lastRowIndex)).cellStyle = style;
      }
    }
  }
}