import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.read(databaseProvider));
});

class SettingsRepository {
  final AppDatabase _db;
  SettingsRepository(this._db);

  Future<void> saveSetting(String key, String value) async {
    final now = DateTime.now();
    await _db.into(_db.settings).insertOnConflictUpdate(
      SettingsCompanion(
        key: Value(key),
        value: Value(value),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<String?> getSetting(String key) async {
    final query = _db.select(_db.settings)..where((s) => s.key.equals(key));
    final result = await query.getSingleOrNull();
    return result?.value;
  }
}