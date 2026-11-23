import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/export/excel_exporter.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/capture_boundary.dart';
import '../../../../shared/widgets/cash_close_receipt.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../inventory/data/stock_repository.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/reports_repository.dart';
import '../../domain/report_models.dart';

final dateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final now = DateTime.now();
  return DateTimeRange(
    start: DateTime(now.year, now.month, now.day),
    end: DateTime(now.year, now.month, now.day, 23, 59, 59),
  );
});

final dashboardMetricsProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(dateRangeProvider);
  return ref.read(reportsRepositoryProvider).getMetrics(range.start, range.end);
});

final topProductsProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(dateRangeProvider);
  return ref.read(reportsRepositoryProvider).getTopProducts(range.start, range.end);
});

final cashClosesHistoryProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(dateRangeProvider);
  return ref.read(reportsRepositoryProvider).getCashClosesHistory(range.start, range.end);
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _selectDateRange() async {
    final currentRange = ref.read(dateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: currentRange,
    );
    if (picked != null) {
      ref.read(dateRangeProvider.notifier).state = DateTimeRange(
        start: picked.start,
        end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isExporting = true);
    try {
      final range = ref.read(dateRangeProvider);
      final repo = ref.read(reportsRepositoryProvider);
      final stockRepo = ref.read(stockRepositoryProvider);

      final metrics = await repo.getMetrics(range.start, range.end);
      final sales = await repo.getSalesWithUser(range.start, range.end);
      final details = await repo.getSaleDetails(range.start, range.end);
      final top = await repo.getTopProducts(range.start, range.end);
      final inventory = await stockRepo.getInventory();
      final closes = await repo.getCashClosesHistory(range.start, range.end);

      final file = await ExcelExporter.generateSalesReport(
        range: range,
        metrics: metrics,
        sales: sales,
        saleDetails: details,
        topProducts: top,
        inventory: inventory,
        cashCloses: closes,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Listo! Tu reporte está en Excel'), backgroundColor: Colors.green),
      );

      await Share.shareXFiles([XFile(file.path)], text: 'Reporte de Ventas POS Fácil');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showReceiptModal(CashCloseWithUser item) async {
    final businessName = await ref.read(settingsRepositoryProvider).getSetting('business_name') ?? 'Mi Negocio';
    final captureKey = GlobalKey();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: SingleChildScrollView(
          child: CaptureBoundary(
            boundaryKey: captureKey,
            child: CashCloseReceipt(
              businessName: businessName,
              userName: item.userName,
              cashClose: item.cashClose,
              salesCount: item.salesCount,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          AppButton(
            label: 'Enviar captura',
            icon: Icons.share,
            expand: false,
            onPressed: () async {
              final pngBytes = await CaptureBoundary.capturePng(captureKey);
              if (pngBytes != null) {
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/corte_${item.cashClose.id.substring(0, 6)}.png');
                await file.writeAsBytes(pngBytes);
                await Share.shareXFiles([XFile(file.path)], text: 'Corte de Caja - ${item.userName}');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(dateRangeProvider);
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final topProductsAsync = ref.watch(topProductsProvider);
    final closesAsync = ref.watch(cashClosesHistoryProvider);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reportes y Cortes'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.bar_chart), text: 'Resumen y Productos'),
              Tab(icon: Icon(Icons.point_of_sale), text: 'Historial de Cortes'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isExporting
                  ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()))
                  : FilledButton.icon(
                      onPressed: _exportExcel,
                      icon: const Icon(Icons.table_view),
                      label: const Text('Descargar Excel'),
                    ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: _selectDateRange,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Periodo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  child: Text('${dateFormat.format(range.start)} - ${dateFormat.format(range.end)}'),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // PESTAÑA 1: RESUMEN Y MÁS VENDIDOS
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      metricsAsync.when(
                        loading: () => const LoadingView(),
                        error: (e, _) => ErrorView(message: e.toString()),
                        data: (m) => Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _StatCard(title: 'Ingresos', value: MoneyUtils.formatCents(m.totalRevenueCents), color: Colors.green),
                            _StatCard(title: 'Ganancia Est.', value: MoneyUtils.formatCents(m.totalProfitCents), color: Colors.teal),
                            _StatCard(title: 'Ventas', value: '${m.totalSalesCount}', color: Colors.blue),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Más Vendidos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      topProductsAsync.when(
                        loading: () => const LoadingView(),
                        error: (e, _) => ErrorView(message: e.toString()),
                        data: (products) {
                          if (products.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Text('Sin ventas en este periodo.'));
                          return Column(
                            children: products.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final isWeight = item.product.saleType == 'weight';
                              final qty = isWeight ? '${(item.totalQuantity / 1000).toStringAsFixed(2)} kg' : '${item.totalQuantity} pzas';
                              return ListTile(
                                leading: CircleAvatar(child: Text('#${idx + 1}')),
                                title: Text(item.product.name),
                                subtitle: Text('Vendido: $qty'),
                                trailing: Text(MoneyUtils.formatCents(item.totalRevenueCents), style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),

                  // PESTAÑA 2: HISTORIAL DE CORTES
                  closesAsync.when(
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(message: e.toString()),
                    data: (closes) {
                      if (closes.isEmpty) return const Center(child: Text('No hay cortes registrados en este periodo.'));
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: closes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = closes[index];
                          final cc = item.cashClose;
                          final diff = cc.differenceCents ?? 0;

                          return Card(
                            child: ListTile(
                              title: Text('${item.userName} • ${DateFormat('dd/MM HH:mm').format(cc.openedAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Esperado: ${MoneyUtils.formatCents(cc.expectedCashCents ?? 0)} | Contado: ${MoneyUtils.formatCents(cc.countedCashCents ?? 0)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (cc.closedAt == null)
                                    const StatusBadge(text: 'Abierto', type: StatusBadgeType.normal)
                                  else
                                    StatusBadge(
                                      text: diff == 0 ? 'Cuadra' : (diff > 0 ? '+${MoneyUtils.formatCents(diff)}' : MoneyUtils.formatCents(diff)),
                                      type: diff == 0 ? StatusBadgeType.normal : (diff > 0 ? StatusBadgeType.surplus : StatusBadgeType.shortage),
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long),
                                    tooltip: 'Ver y compartir comprobante',
                                    onPressed: () => _showReceiptModal(item),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}