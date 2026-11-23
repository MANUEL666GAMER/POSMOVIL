import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

class CashCloseReceipt extends StatelessWidget {
  final String businessName;
  final String userName;
  final CashClose cashClose;
  final int salesCount;

  const CashCloseReceipt({
    super.key,
    required this.businessName,
    required this.userName,
    required this.cashClose,
    required this.salesCount,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    
    final diff = cashClose.differenceCents ?? 0;
    final String statusText = diff == 0
        ? 'CUADRA EXACTO'
        : diff > 0
            ? 'SOBRANTE (+${MoneyUtils.formatCents(diff)})'
            : 'FALTANTE (${MoneyUtils.formatCents(diff)})';
            
    final Color statusColor = diff == 0
        ? Colors.green.shade800
        : diff > 0
            ? Colors.blue.shade800
            : Colors.red.shade800;

    // Forzamos tema claro y fondo blanco para que se lea bien al enviarse por WhatsApp
    return Container(
      width: 380,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'sans-serif'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              businessName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const SizedBox(height: 4),
            const Text(
              'COMPROBANTE DE CORTE DE CAJA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const Divider(color: Colors.black26, height: 24, thickness: 1),
            
            _row('Cajero / Usuario:', userName),
            _row('Fecha:', dateFmt.format(cashClose.openedAt)),
            _row('Apertura:', timeFmt.format(cashClose.openedAt)),
            _row('Cierre:', cashClose.closedAt != null ? timeFmt.format(cashClose.closedAt!) : 'Abierto'),
            _row('Ventas realizadas:', '$salesCount tickets'),
            
            const Divider(color: Colors.black26, height: 24, thickness: 1),
            
            _row('Fondo inicial:', MoneyUtils.formatCents(cashClose.openingFloatCents)),
            _row(
              'Efectivo esperado:', 
              MoneyUtils.formatCents(cashClose.expectedCashCents ?? 0),
              isBold: true,
            ),
            _row(
              'Efectivo contado:', 
              MoneyUtils.formatCents(cashClose.countedCashCents ?? 0),
              isBold: true,
            ),
            
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                border: Border.all(color: statusColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Generado por POS Fácil',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}