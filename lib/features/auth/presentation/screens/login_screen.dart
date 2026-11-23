import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../../shared/widgets/user_avatar_tile.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'package:go_router/go_router.dart'; // Para el siguiente paso

final usersListProvider = FutureProvider<List<User>>((ref) {
  final repo = ref.read(authRepositoryProvider);
  return repo.getActiveUsers();
});

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  User? _selectedUser;
  String? _pinError;
  final GlobalKey<State<PinInput>> _pinKey = GlobalKey();

  Future<void> _handlePinCompleted(String pin) async {
    if (_selectedUser == null) return;
    
    setState(() => _pinError = null);
    
    final repo = ref.read(authRepositoryProvider);
    final validUser = await repo.verifyPin(_selectedUser!, pin);
    
    if (validUser != null) {
      // Iniciar sesión exitosamente
      ref.read(authStateProvider.notifier).state = validUser;
      context.go('/products');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenido, ${validUser.name}')),
      );
    } else {
      // PIN incorrecto
      setState(() => _pinError = 'PIN incorrecto. Intenta de nuevo.');
      // Limpiar el teclado
      (_pinKey.currentState as dynamic)?.clearPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                // Columna Izquierda: Lista de Usuarios
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Quién eres?', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 24),
                        Expanded(
                          child: usersAsync.when(
                            loading: () => const LoadingView(),
                            error: (e, st) => ErrorView(message: e.toString()),
                            data: (users) {
                              if (users.isEmpty) {
                                return const Center(child: Text('No hay usuarios. Ve al Asistente Inicial.'));
                              }
                              return ListView.separated(
                                itemCount: users.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  return UserAvatarTile(
                                    name: user.name,
                                    role: AppRole.fromString(user.role),
                                    isSelected: _selectedUser?.id == user.id,
                                    onTap: () {
                                      setState(() {
                                        _selectedUser = user;
                                        _pinError = null;
                                        (_pinKey.currentState as dynamic)?.clearPin();
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const VerticalDivider(width: 1),
                
                // Columna Derecha: Ingreso de PIN
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: _selectedUser == null
                          ? const Text('Selecciona un usuario para entrar')
                          : PinInput(
                              key: _pinKey,
                              title: 'PIN de ${_selectedUser!.name}',
                              errorText: _pinError,
                              onPinCompleted: _handlePinCompleted,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}