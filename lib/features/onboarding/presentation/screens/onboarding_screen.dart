import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/database/demo_seed.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../backup/services/drive_backup_service.dart';
import '../../../settings/data/settings_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0; // 0 a 4 (1 de 5 ... 5 de 5)
  final _businessController = TextEditingController();
  final _ownerController = TextEditingController();
  String _pin = '';
  String _businessType = 'Frutas y verduras';
  String? _googleEmail;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _businessController.addListener(() => setState(() {}));
    _ownerController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _businessController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_step == 0) return _businessController.text.trim().isNotEmpty;
    if (_step == 1) return _ownerController.text.trim().isNotEmpty && _pin.length == 4;
    return true;
  }

  Future<void> _connectGoogleDrive() async {
    try {
      final account = await ref.read(driveBackupServiceProvider).signIn();
      if (account != null && mounted) {
        setState(() => _googleEmail = account.email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo conectar ahora: $e')),
        );
      }
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isSaving = true);
    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final authRepo = ref.read(authRepositoryProvider);

      await settingsRepo.saveSetting('business_name', _businessController.text.trim());
      await settingsRepo.saveSetting('business_owner', _ownerController.text.trim());
      await settingsRepo.saveSetting('business_type', _businessType);

      await authRepo.createUser(
        name: _ownerController.text.trim(),
        pin: _pin,
        role: AppRole.admin,
      );

      ref.invalidate(usersListProvider);
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _loadDemoData() async {
    setState(() => _isSaving = true);
    try {
      await DemoSeed.seedFruteriaDonaLupe(
        ref.read(databaseProvider),
        ref.read(authRepositoryProvider),
        ref.read(settingsRepositoryProvider),
      );
      ref.invalidate(usersListProvider);
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra de progreso de 5 segmentos
                  Row(
                    children: List.generate(5, (index) {
                      final active = index <= _step;
                      return Expanded(
                        child: Container(
                          height: 8,
                          margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                          decoration: BoxDecoration(
                            color: active ? c.brand : c.line,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_step + 1} de 5',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.muted),
                      ),
                      if (_step == 0)
                        TextButton(
                          onPressed: _isSaving ? null : _loadDemoData,
                          child: Text(
                            'Cargar datos de ejemplo',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.brand),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Contenido del paso activo
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildStepContent(c),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botones del pie
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 64),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () => setState(() => _step--),
                            child: const Text('Atrás', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 64),
                            backgroundColor: c.brand,
                            foregroundColor: c.onBrand,
                            disabledBackgroundColor: c.brandDisabled,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: (!_canContinue || _isSaving)
                              ? null
                              : () {
                                  if (_step < 4) {
                                    setState(() => _step++);
                                  } else {
                                    _finishOnboarding();
                                  }
                                },
                          child: Text(
                            _step == 4 ? 'Empezar' : 'Siguiente',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(PosColors c) {
    switch (_step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cómo se llama tu negocio?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink)),
            const SizedBox(height: 8),
            Text('Aparecerá en tus tickets.', style: TextStyle(fontSize: 17, color: c.muted)),
            const SizedBox(height: 24),
            TextField(
              controller: _businessController,
              autofocus: true,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: 'Ej. Frutería Doña Lupe',
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        );

      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Quién es el encargado?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink)),
            const SizedBox(height: 8),
            Text('Tu nombre y un PIN de 4 números para entrar.', style: TextStyle(fontSize: 17, color: c.muted)),
            const SizedBox(height: 20),
            TextField(
              controller: _ownerController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ej. Lupe',
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 20),
            PinInput(
              title: _pin.length == 4 ? 'PIN listo (••••)' : 'Elige tu PIN de 4 números',
              onPinCompleted: (pin) => setState(() => _pin = pin),
            ),
          ],
        );

      case 2:
        final options = [
          ('Frutas y verduras', Icons.eco_rounded),
          ('Abarrotes', Icons.shopping_basket_rounded),
          ('Un poco de todo', Icons.storefront_rounded),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Qué vendes?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink)),
            const SizedBox(height: 20),
            ...options.map((opt) {
              final selected = _businessType == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _businessType = opt.$1),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 76,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: selected ? c.brandSoft : c.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2.5 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(opt.$2, size: 32, color: selected ? c.brand : c.ink),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            opt.$1,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: selected ? c.brandDark : c.ink),
                          ),
                        ),
                        if (selected) Icon(Icons.check_circle_rounded, color: c.brand, size: 28),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        );

      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guarda una copia en Google Drive', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.ink)),
            const SizedBox(height: 8),
            Text(
              'Si cambias de celular, tus productos y ventas estarán a salvo.',
              style: TextStyle(fontSize: 17, color: c.muted),
            ),
            const SizedBox(height: 28),
            if (_googleEmail != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.brandLine),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, color: c.brand, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Conectado: $_googleEmail',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.brandDark),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 64,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _connectGoogleDrive,
                  icon: const Icon(Icons.cloud_upload_rounded, size: 28),
                  label: const Text('Conectar con mi cuenta de Google', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _step = 4),
                child: Text('Más tarde', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.muted)),
              ),
            ),
          ],
        );

      default:
        return Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
              child: Icon(Icons.check_circle_rounded, color: c.brand, size: 64),
            ),
            const SizedBox(height: 24),
            Text(
              '¡Listo! Vamos a vender',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.ink),
            ),
            const SizedBox(height: 12),
            Text(
              'Todo está preparado para ${_businessController.text.trim()}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: c.muted),
            ),
          ],
        );
    }
  }
}