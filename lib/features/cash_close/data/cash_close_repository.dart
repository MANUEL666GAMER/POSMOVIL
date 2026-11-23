import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

final cashCloseRepositoryProvider = Provider<CashCloseRepository>((ref) {
  return CashCloseRepository(ref.read(databaseProvider));
});

class CashCloseRepository {
  final AppDatabase _db;
  CashCloseRepository(this._db);

  /// Obtiene el turno abierto actualmente para un usuario
  Future<CashClose?> getActiveShift(String userId) async {
    final query = _db.select(_db.cashCloses)
      ..where((c) => c.userId.equals(userId) & c.closedAt.isNull());
    return await query.getSingleOrNull();
  }

  /// Abre un nuevo turno
  Future<void> openShift({
    required String userId,
    required int openingFloatCents,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.cashCloses).insert(
      CashClosesCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        openedAt: now,
        openingFloatCents: openingFloatCents,
        createdAt: now,
        updatedAt: now,
      )
    );
  }

  /// Cierra el turno actual, sumando las ventas realizadas
  Future<void> closeShift({
    required CashClose activeShift,
    required int countedCashCents,
  }) async {
    await _db.transaction(() async {
      final now = DateTime.now();

      // 1. Obtener todas las ventas pagadas de este usuario que no tienen corte asignado
      final salesQuery = _db.select(_db.sales)
        ..where((s) => s.userId.equals(activeShift.userId) & 
                       s.cashCloseId.isNull() & 
                       s.status.equals('paid'));
      
      final unassignedSales = await salesQuery.get();

      // 2. Sumar el total de esas ventas
      final totalSalesCents = unassignedSales.fold<int>(
        0, (sum, sale) => sum + sale.totalCents
      );

      // 3. Calcular esperados y diferencias
      final expectedCashCents = activeShift.openingFloatCents + totalSalesCents;
      final differenceCents = countedCashCents - expectedCashCents;

      // 4. Actualizar el registro del Corte de Caja
      await (_db.update(_db.cashCloses)..where((c) => c.id.equals(activeShift.id))).write(
        CashClosesCompanion(
          closedAt: Value(now),
          expectedCashCents: Value(expectedCashCents),
          countedCashCents: Value(countedCashCents),
          differenceCents: Value(differenceCents),
          updatedAt: Value(now),
        )
      );

      // 5. Vincular las ventas a este corte para que no se sumen en el siguiente
      for (final sale in unassignedSales) {
        await (_db.update(_db.sales)..where((s) => s.id.equals(sale.id))).write(
          SalesCompanion(
            cashCloseId: Value(activeShift.id),
            updatedAt: Value(now),
          )
        );
      }
    });
  }
}