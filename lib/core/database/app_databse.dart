import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- Tablas ---

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();
  TextColumn get role => text()(); // 'admin' o 'cashier'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Products extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get barcode => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get saleType => text()(); // 'unit' o 'weight'
  IntColumn get priceCents => integer()();
  IntColumn get costCents => integer().nullable()();
  IntColumn get minStock => integer().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get type => text()(); // 'purchase', 'sale', 'adjustment', 'waste'
  IntColumn get quantity => integer()(); // piezas o gramos
  TextColumn get reason => text().nullable()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get saleId => text().nullable().references(Sales, #id)();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get status => text()(); // 'open', 'paid', 'cancelled'
  TextColumn get label => text().nullable()(); // Ej. "Cliente 2"
  TextColumn get userId => text().references(Users, #id)();
  IntColumn get totalCents => integer().withDefault(const Constant(0))();
  TextColumn get paymentMethod => text().nullable()(); // 'cash', 'card', 'transfer'
  IntColumn get cashReceivedCents => integer().nullable()();
  IntColumn get changeCents => integer().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  TextColumn get cashCloseId => text().nullable().references(CashCloses, #id)();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SaleItems extends Table {
  TextColumn get id => text()();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  IntColumn get quantity => integer()(); // piezas o gramos
  IntColumn get unitPriceCents => integer()();
  IntColumn get subtotalCents => integer()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CashCloses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  DateTimeColumn get openedAt => dateTime()();
  DateTimeColumn get closedAt => dateTime().nullable()();
  IntColumn get openingFloatCents => integer()();
  IntColumn get expectedCashCents => integer().nullable()();
  IntColumn get countedCashCents => integer().nullable()();
  IntColumn get differenceCents => integer().nullable()();
  TextColumn get totalsByMethod => text().nullable()(); // JSON con totales por método
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// --- Configuración de la base de datos ---

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pos_facil.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [
  Users,
  Categories,
  Products,
  StockMovements,
  Sales,
  SaleItems,
  CashCloses,
  Settings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Manejo de futuras migraciones
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}