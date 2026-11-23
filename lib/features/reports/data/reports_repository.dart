import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../domain/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.read(databaseProvider));
});

class ReportsRepository {
  final AppDatabase _db;
  ReportsRepository(this._db);

  Future<DashboardMetrics> getMetrics(DateTime start, DateTime end) async {
    final salesQuery = _db.select(_db.sales)
      ..where((s) => s.createdAt.isBetweenValues(start, end) & s.status.equals('paid'));
    final sales = await salesQuery.get();
    final totalRevenue = sales.fold<int>(0, (sum, sale) => sum + sale.totalCents);

    // Cálculo de ganancia estimada
    int totalCost = 0;
    if (sales.isNotEmpty) {
      final saleIds = sales.map((s) => s.id).toList();
      final itemsQuery = _db.select(_db.saleItems).join([
        innerJoin(_db.products, _db.products.id.equalsExp(_db.saleItems.productId))
      ])..where(_db.saleItems.saleId.isIn(saleIds));

      final rows = await itemsQuery.get();
      for (final row in rows) {
        final item = row.readTable(_db.saleItems);
        final prod = row.readTable(_db.products);
        final unitCost = prod.costCents ?? 0;
        if (prod.saleType == 'weight') {
          totalCost += ((item.quantity / 1000) * unitCost).round();
        } else {
          totalCost += item.quantity * unitCost;
        }
      }
    }

    return DashboardMetrics(
      totalSalesCount: sales.length,
      totalRevenueCents: totalRevenue,
      totalProfitCents: totalRevenue - totalCost,
    );
  }

  Future<List<TopProduct>> getTopProducts(DateTime start, DateTime end) async {
    final validSales = _db.select(_db.sales)
      ..where((s) => s.createdAt.isBetweenValues(start, end) & s.status.equals('paid'));
    final validSaleIds = (await validSales.get()).map((s) => s.id).toList();

    if (validSaleIds.isEmpty) return [];

    final sumQty = _db.saleItems.quantity.sum();
    final sumSubtotal = _db.saleItems.subtotalCents.sum();

    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.saleItems.productId))
    ])
      ..where(_db.saleItems.saleId.isIn(validSaleIds))
      ..addColumns([sumQty, sumSubtotal])
      ..groupBy([_db.saleItems.productId])
      ..orderBy([OrderingTerm(expression: sumSubtotal, mode: OrderingMode.desc)])
      ..limit(10);

    final results = await query.get();
    return results.map((row) {
      return TopProduct(
        product: row.readTable(_db.products),
        totalQuantity: row.read(sumQty) ?? 0,
        totalRevenueCents: row.read(sumSubtotal) ?? 0,
      );
    }).toList();
  }

  Future<List<SaleWithUser>> getSalesWithUser(DateTime start, DateTime end) async {
    final query = _db.select(_db.sales).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.sales.userId))
    ])..where(_db.sales.createdAt.isBetweenValues(start, end) & _db.sales.status.equals('paid'));

    final rows = await query.get();
    return rows.map((r) => SaleWithUser(
      sale: r.readTable(_db.sales),
      userName: r.readTable(_db.users).name,
    )).toList();
  }

  Future<List<SaleDetailRow>> getSaleDetails(DateTime start, DateTime end) async {
    final query = _db.select(_db.saleItems).join([
      innerJoin(_db.sales, _db.sales.id.equalsExp(_db.saleItems.saleId)),
      innerJoin(_db.products, _db.products.id.equalsExp(_db.saleItems.productId)),
    ])..where(_db.sales.createdAt.isBetweenValues(start, end) & _db.sales.status.equals('paid'));

    final rows = await query.get();
    return rows.map((r) {
      final sale = r.readTable(_db.sales);
      final item = r.readTable(_db.saleItems);
      final prod = r.readTable(_db.products);
      return SaleDetailRow(
        saleId: sale.id,
        date: sale.createdAt,
        product: prod,
        quantity: item.quantity,
        unitPriceCents: item.unitPriceCents,
        subtotalCents: item.subtotalCents,
      );
    }).toList();
  }

  Future<List<CashCloseWithUser>> getCashClosesHistory(DateTime start, DateTime end) async {
    final query = _db.select(_db.cashCloses).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.cashCloses.userId))
    ])
      ..where(_db.cashCloses.openedAt.isBetweenValues(start, end))
      ..orderBy([OrderingTerm(expression: _db.cashCloses.openedAt, mode: OrderingMode.desc)]);

    final rows = await query.get();
    final List<CashCloseWithUser> list = [];

    for (final r in rows) {
      final cc = r.readTable(_db.cashCloses);
      final user = r.readTable(_db.users);
      
      final salesCountQuery = _db.select(_db.sales)..where((s) => s.cashCloseId.equals(cc.id));
      final count = (await salesCountQuery.get()).length;

      list.add(CashCloseWithUser(cashClose: cc, userName: user.name, salesCount: count));
    }
    return list;
  }
}