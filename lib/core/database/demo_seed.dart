import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../permissions/permission_service.dart';
import 'app_database.dart';

class DemoSeed {
  static Future<void> seedFruteriaDonaLupe(
    AppDatabase db,
    AuthRepository authRepo,
    SettingsRepository settingsRepo,
  ) async {
    final now = DateTime.now();
    const uuid = Uuid();

    // 1. Datos del negocio
    await settingsRepo.saveSetting('business_name', 'Frutería Doña Lupe');
    await settingsRepo.saveSetting('business_owner', 'Guadalupe Hernández');
    await settingsRepo.saveSetting('business_phone', '55 1234 5678');
    await settingsRepo.saveSetting('business_address', 'Mercado Hidalgo, local 14, Col. Centro');
    await settingsRepo.saveSetting('ticket_message', '¡Gracias por su compra! Vuelva pronto.');

    // 2. Usuarios (Lupe Admin 1234, Pedro Cajero 5678, Rosa Cajera 2468)
    await authRepo.createUser(name: 'Lupe', pin: '1234', role: AppRole.admin);
    await authRepo.createUser(name: 'Pedro', pin: '5678', role: AppRole.cashier);
    await authRepo.createUser(name: 'Rosa', pin: '2468', role: AppRole.cashier);

    final users = await authRepo.getActiveUsers();
    final adminId = users.first.id;

    // 3. Categorías
    final catFrutas = uuid.v4();
    final catVerduras = uuid.v4();
    final catAbarrotes = uuid.v4();
    final catBebidas = uuid.v4();

    for (final entry in {
      catFrutas: 'Frutas',
      catVerduras: 'Verduras',
      catAbarrotes: 'Abarrotes',
      catBebidas: 'Bebidas',
    }.entries) {
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: entry.key,
              name: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // 4. Catálogo de 16 productos (precios/costos en centavos; stock de peso en gramos)
    final productsData = [
      ('Manzana', 'weight', 3800, 2600, catFrutas, 24500, 5000, null),
      ('Plátano', 'weight', 2200, 1400, catFrutas, 3200, 5000, null),
      ('Jitomate', 'weight', 2800, 1900, catVerduras, 15000, 5000, null),
      ('Limón', 'weight', 2500, 1600, catFrutas, 8400, 4000, null),
      ('Coca-Cola 600 ml', 'unit', 2000, 1400, catBebidas, 36, 12, '7501055300075'),
      ('Pan blanco', 'unit', 4500, 3600, catAbarrotes, 2, 4, '7441029500011'),
      ('Huevo', 'unit', 350, 240, catAbarrotes, 0, 30, null),
      ('Leche 1 L', 'unit', 2800, 2200, catAbarrotes, 18, 6, '7501020515343'),
      ('Aguacate', 'weight', 7000, 5200, catVerduras, 6500, 3000, null),
      ('Cebolla', 'weight', 2400, 1500, catVerduras, 12000, 4000, null),
      ('Naranja', 'weight', 1800, 1100, catFrutas, 30000, 8000, null),
      ('Zanahoria', 'weight', 2000, 1200, catVerduras, 9000, 3000, null),
      ('Agua 1 L', 'unit', 1400, 800, catBebidas, 24, 10, '7501086801046'),
      ('Arroz 1 kg', 'unit', 3200, 2400, catAbarrotes, 14, 5, '7501052401010'),
      ('Frijol 1 kg', 'unit', 3800, 2900, catAbarrotes, 11, 5, '7501052402017'),
      ('Uva verde', 'weight', 6500, 4600, catFrutas, 4800, 2000, null),
    ];

    for (final p in productsData) {
      final prodId = uuid.v4();
      await db.into(db.products).insert(
            ProductsCompanion.insert(
              id: prodId,
              name: p.$1,
              saleType: p.$2,
              priceCents: p.$3,
              costCents: Value(p.$4),
              categoryId: Value(p.$5),
              minStock: Value(p.$7),
              barcode: Value(p.$8),
              createdAt: now,
              updatedAt: now,
            ),
          );

      if (p.$6 > 0) {
        await db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                id: uuid.v4(),
                productId: prodId,
                type: 'purchase',
                quantity: p.$6,
                reason: const Value('Existencia inicial'),
                userId: adminId,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    }
  }
}