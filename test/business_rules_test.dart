import 'package:flutter_test/flutter_test.dart';
import 'package:pos_movil/core/database/app_database.dart';
import 'package:pos_movil/core/permissions/permission_service.dart';
import 'package:pos_movil/core/utils/money.dart';
import 'package:pos_movil/features/sales/domain/cart_models.dart';

void main() {
  group('Reglas de Negocio - POS Fácil', () {
    test('Conversión y formateo de centavos exacto', () {
      expect(MoneyUtils.parseToCents('85.50'), 8550);
      expect(MoneyUtils.parseToCents('19,99'), 1999);
      expect(MoneyUtils.formatCents(8550), contains('85.50'));
    });

    test('Cálculo de carrito por pieza y por peso (kilos)', () {
      final now = DateTime.now();
      final manzana = Product(
        id: '1',
        name: 'Manzana Roja',
        saleType: 'weight',
        priceCents: 4500, // $45.00 el kg
        minStock: 1000,
        createdAt: now,
        updatedAt: now,
      );
      final refresco = Product(
        id: '2',
        name: 'Refresco 600ml',
        saleType: 'unit',
        priceCents: 1800, // $18.00 la pieza
        minStock: 5,
        createdAt: now,
        updatedAt: now,
      );

      final cart = Cart(
        name: 'Cliente 1',
        items: [
          CartItem(product: manzana, quantity: 1.5), // 1.5 kg * $45 = $67.50 (6750)
          CartItem(product: refresco, quantity: 2),  // 2 pzas * $18 = $36.00 (3600)
        ],
      );

      expect(cart.totalCents, 10350); // $103.50 total
    });

    test('Permisos de Cajero vs Administrador', () {
      expect(PermissionService.can(AppRole.cashier, AppPermission.sell), isTrue);
      expect(PermissionService.can(AppRole.cashier, AppPermission.ownCashClose), isTrue);
      expect(PermissionService.can(AppRole.cashier, AppPermission.viewReports), isFalse);
      expect(PermissionService.can(AppRole.cashier, AppPermission.manageProducts), isFalse);
      expect(PermissionService.can(AppRole.cashier, AppPermission.viewCosts), isFalse);

      expect(PermissionService.can(AppRole.admin, AppPermission.viewReports), isTrue);
      expect(PermissionService.can(AppRole.admin, AppPermission.exportReports), isTrue);
      expect(PermissionService.can(AppRole.admin, AppPermission.manageSettings), isTrue);
    });
  });
}