import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

final cashCloseRepositoryProvider = Provider<CashCloseRepository>((ref) {
  return CashCloseRepository(ref.read(databaseProvider));
});

class FloatChangeWithUser {
  final CashFloatChange change;
  final String userName;
  FloatChangeWithUser(this.change, this.userName);
}

class OpenShiftWithUser {
  final CashClose shift;
  final User user;
  OpenShiftWithUser(this.shift, this.user);
}

class CashCloseRepository {
  final AppDatabase _db;
  CashCloseRepository(this._db);

  /// Obtiene el turno abierto de un usuario específico
  Future<CashClose?> getActiveShift(String userId) async {
    final query = _db.select(_db.cashCloses)
      ..where((c) => c.userId.equals(userId) & c.closedAt.isNull());
    return await query.getSingleOrNull();
  }

  /// Obtiene todos los turnos abiertos (para selector de turnos del Administrador)
  Future<List<OpenShiftWithUser>> getAllOpenShifts() async {
    final query = _db.select(_db.cashCloses).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.cashCloses.userId)),
    ])
      ..where(_db.cashCloses.closedAt.isNull())
      ..orderBy([OrderingTerm.asc(_db.cashCloses.openedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return OpenShiftWithUser(
        row.readTable(_db.cashCloses),
        row.readTable(_db.users),
      );
    }).toList();
  }

  /// Obtiene las ventas pagadas aún no asignadas a un corte del dueño del turno
  Future<List<Sale>> getUnassignedSales(String userId) async {
    final query = _db.select(_db.sales)
      ..where((s) =>
          s.userId.equals(userId) &
          s.cashCloseId.isNull() &
          s.status.equals('paid'))
      ..orderBy([(s) => OrderingTerm.desc(s.paidAt)]);
    return await query.get();
  }

  /// Obtiene el historial de cambios de fondo inicial de un turno
  Future<List<FloatChangeWithUser>> getFloatChanges(String cashCloseId) async {
    final query = _db.select(_db.cashFloatChanges).join([
      innerJoin(_db.users, _db.users.id.equalsExp(_db.cashFloatChanges.userId)),
    ])
      ..where(_db.cashFloatChanges.cashCloseId.equals(cashCloseId))
      ..orderBy([OrderingTerm.asc(_db.cashFloatChanges.changedAt)]);

    final rows = await query.get();
    return rows.map((row) {
      return FloatChangeWithUser(
        row.readTable(_db.cashFloatChanges),
        row.readTable(_db.users).name,
      );
    }).toList();
  }

  /// Abre un turno nuevo (validando que no exista otro abierto para ese usuario)
  Future<void> openShift({
    required String userId,
    required int openingFloatCents,
  }) async {
    final existing = await getActiveShift(userId);
    if (existing != null) {
      throw Exception('Ya tienes un turno abierto');
    }
    final now = DateTime.now();
    await _db.into(_db.cashCloses).insert(
      CashClosesCompanion.insert(
        id: const Uuid().v4(),
        userId: userId,
        openedAt: now,
        openingFloatCents: openingFloatCents,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Corrige el fondo inicial mientras el turno sigue abierto, exigiendo motivo
  Future<void> changeOpeningFloat({
    required CashClose shift,
    required int newFloatCents,
    required String reason,
    required String modifiedByUserId,
  }) async {
    if (shift.closedAt != null) {
      throw Exception('Este turno ya se cerró');
    }
    if (reason.trim().isEmpty) {
      throw Exception('Escribe el motivo del cambio');
    }
    if (newFloatCents == shift.openingFloatCents) return;

    await _db.transaction(() async {
      final now = DateTime.now();

      await _db.into(_db.cashFloatChanges).insert(
        CashFloatChangesCompanion.insert(
          id: const Uuid().v4(),
          cashCloseId: shift.id,
          changedAt: now,
          fromCents: shift.openingFloatCents,
          toCents: newFloatCents,
          reason: reason.trim(),
          userId: modifiedByUserId,
        ),
      );

      await (_db.update(_db.cashCloses)..where((c) => c.id.equals(shift.id))).write(
        CashClosesCompanion(
          openingFloatCents: Value(newFloatCents),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Cierra el turno actual y guarda el resumen inmutable
  Future<CashClose> closeShift({
    required CashClose activeShift,
    required int countedCashCents,
    required String closedByUserId,
    Map<int, int>? denominations,
  }) async {
    if (activeShift.closedAt != null) {
      throw Exception('Este turno ya se cerró');
    }

    return await _db.transaction(() async {
      final now = DateTime.now();
      final sales = await getUnassignedSales(activeShift.userId);

      int sumByMethod(String method) => sales
          .where((s) => (s.paymentMethod ?? 'cash') == method)
          .fold<int>(0, (sum, s) => sum + s.totalCents);

      final cashCents = sumByMethod('cash');
      final cardCents = sumByMethod('card');
      final transferCents = sumByMethod('transfer');
      final expectedCents = activeShift.openingFloatCents + cashCents;
      final diffCents = countedCashCents - expectedCents;

      final denomJson = denominations != null && denominations.isNotEmpty
          ? jsonEncode(denominations.map((k, v) => MapEntry(k.toString(), v)))
          : null;

      await (_db.update(_db.cashCloses)..where((c) => c.id.equals(activeShift.id))).write(
        CashClosesCompanion(
          closedAt: Value(now),
          closedBy: Value(closedByUserId),
          cashSalesCents: Value(cashCents),
          cardSalesCents: Value(cardCents),
          transferSalesCents: Value(transferCents),
          salesCount: Value(sales.length),
          expectedCashCents: Value(expectedCents),
          countedCashCents: Value(countedCashCents),
          differenceCents: Value(diffCents),
          denominationsJson: Value(denomJson),
          updatedAt: Value(now),
        ),
      );

      for (final sale in sales) {
        await (_db.update(_db.sales)..where((s) => s.id.equals(sale.id))).write(
          SalesCompanion(
            cashCloseId: Value(activeShift.id),
            updatedAt: Value(now),
          ),
        );
      }

      return activeShift.copyWith(
        closedAt: Value(now),
        closedBy: Value(closedByUserId),
        cashSalesCents: cashCents,
        cardSalesCents: cardCents,
        transferSalesCents: transferCents,
        salesCount: sales.length,
        expectedCashCents: Value(expectedCents),
        countedCashCents: Value(countedCashCents),
        differenceCents: Value(diffCents),
        denominationsJson: Value(denomJson),
        updatedAt: now,
      );
    });
  }
}