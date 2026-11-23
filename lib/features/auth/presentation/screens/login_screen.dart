import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/auth_repository.dart';
import '../providers/auth_provider.dart';

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
  String _businessName = 'Mi Negocio';
  final GlobalKey<State<PinInput>> _pinKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
  }

  Future<void> _loadBusinessName() async {
    final name = await ref.read(settingsRepositoryProvider).getSetting('business_name');
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _businessName = name);
    }
  }

  Future<void> _handlePinCompleted(String pin) async {
    if (_selectedUser == null) return;
    setState(() => _pinError = null);

    final repo = ref.read(authRepositoryProvider);
    final validUser = await repo.verifyPin(_selectedUser!, pin);

    if (validUser != null) {
      ref.read(authStateProvider.notifier).state = validUser;
      if (mounted) context.go('/dashboard');
    } else {
      setState(() => _pinError = 'PIN incorrecto, intenta de nuevo');
      (_pinKey.currentState as dynamic)?.clearPin();
    }
  }

  String _roleLabel(String role) {
    return AppRole.fromString(role) == AppRole.admin ? 'Administrador' : 'Cajero';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 1024;

          if (isTablet) {
            return Row(
              children: [
                // Panel de marca izquierdo (44 %)
                Expanded(
                  flex: 44,
                  child: _BrandHeroPanel(
                    businessName: _businessName,
                    isCompact: false,
                  ),
                ),
                // Panel derecho: selección o PIN
                Expanded(
                  flex: 56,
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: _buildAuthContent(c, usersAsync),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Celular: franja superior + contenido abajo
          return Column(
            children: [
              _BrandHeroPanel(
                businessName: _businessName,
                isCompact: true,
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _buildAuthContent(c, usersAsync),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuthContent(PosColors c, AsyncValue<List<User>> usersAsync) {
    // PASO 2: Ingreso de PIN del usuario seleccionado
    if (_selectedUser != null) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  setState(() {
                    _selectedUser = null;
                    _pinError = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text(
                  'Cambiar de usuario',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 38,
              backgroundColor: c.brand,
              child: Text(
                _selectedUser!.name[0].toUpperCase(),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.onBrand),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hola, ${_selectedUser!.name}',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Escribe tu PIN de 4 números',
              style: TextStyle(fontSize: 17, color: c.muted),
            ),
            const SizedBox(height: 20),
            PinInput(
              key: _pinKey,
              title: '',
              errorText: _pinError,
              onPinCompleted: _handlePinCompleted,
            ),
          ],
        ),
      );
    }

    // PASO 1: "¿Quién va a usar la caja?"
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Quién va a usar la caja?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.ink),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca tu nombre para entrar',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, color: c.muted),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: usersAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (users) {
              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No hay usuarios registrados.', style: TextStyle(fontSize: 17)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/onboarding'),
                        child: const Text('Ir al asistente inicial'),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 176,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isAdmin = AppRole.fromString(user.role) == AppRole.admin;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedUser = user;
                        _pinError = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(20),
                        border: c.cardBorder ?? Border.all(color: c.line),
                        boxShadow: c.shadowCard,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 38, // 76 px de diámetro
                            backgroundColor: isAdmin ? c.brand : c.info,
                            child: Text(
                              user.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            _roleLabel(user.role),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BrandHeroPanel extends StatelessWidget {
  final String businessName;
  final bool isCompact;

  const _BrandHeroPanel({
    required this.businessName,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return Container(
      width: double.infinity,
      color: c.hero,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: CircleAvatar(radius: 100, backgroundColor: c.heroDeep),
          ),
          Positioned(
            left: -50,
            bottom: -60,
            child: CircleAvatar(radius: 110, backgroundColor: c.heroDeep),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: isCompact ? 20 : 48,
              ),
              child: isCompact
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Punto de venta',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 44),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Punto de venta',
                          style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          businessName,
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Vende rápido, cuida tu mercancía y guarda tus cuentas seguras.',
                          style: TextStyle(color: Colors.white, fontSize: 20, height: 1.4),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}