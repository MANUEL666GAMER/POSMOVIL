import '../../../../core/database/app_database.dart';

class DashboardMetrics {
  final int totalSalesCount;
  final int totalRevenueCents;
  final int totalProfitCents;

  DashboardMetrics({
    required this.totalSalesCount,
    required this.totalRevenueCents,
    required this.totalProfitCents,
  });
}

class TopProduct {
  final Product product;
  final int totalQuantity;
  final int totalRevenueCents;

  TopProduct({
    required this.product,
    required this.totalQuantity,
    required this.totalRevenueCents,
  });
}

class SaleWithUser {
  final Sale sale;
  final String userName;
  SaleWithUser({required this.sale, required this.userName});
}

class SaleDetailRow {
  final String saleId;
  final DateTime date;
  final Product product;
  final int quantity;
  final int unitPriceCents;
  final int subtotalCents;

  SaleDetailRow({
    required this.saleId,
    required this.date,
    required this.product,
    required this.quantity,
    required this.unitPriceCents,
    required this.subtotalCents,
  });
}

class CashCloseWithUser {
  final CashClose cashClose;
  final String userName;
  final int salesCount;

  CashCloseWithUser({
    required this.cashClose,
    required this.userName,
    required this.salesCount,
  });
}