import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';

// Almacena el usuario autenticado actual. Nulo si nadie ha iniciado sesión.
final authStateProvider = StateProvider<User?>((ref) => null);