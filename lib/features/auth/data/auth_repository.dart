import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/crypto_utils.dart';
import '../../../core/permissions/permission_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(databaseProvider));
});

class AuthRepository {
  final AppDatabase _db;
  AuthRepository(this._db);

  Future<List<User>> getActiveUsers() async {
    return await (_db.select(_db.users)..where((u) => u.isActive.equals(true))).get();
  }

  Future<User> createUser({required String name, required String pin, required AppRole role}) async {
    const uuid = Uuid();
    final id = uuid.v4();
    final salt = uuid.v4(); // Usamos un UUID nuevo como sal
    final pinHash = CryptoUtils.hashPin(pin, salt);
    final now = DateTime.now();

    final companion = UsersCompanion.insert(
      id: id,
      name: name,
      pinHash: pinHash,
      pinSalt: salt,
      role: role.name,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.users).insert(companion);
    return (await (_db.select(_db.users)..where((u) => u.id.equals(id))).getSingle());
  }

  Future<User?> verifyPin(User user, String enteredPin) async {
    final expectedHash = user.pinHash;
    final generatedHash = CryptoUtils.hashPin(enteredPin, user.pinSalt);
    
    if (expectedHash == generatedHash) {
      return user;
    }
    return null;
  }
}