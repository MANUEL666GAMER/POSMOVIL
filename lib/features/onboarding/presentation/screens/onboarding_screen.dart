import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../settings/data/settings_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  
  bool _isLoading = false;

  void _nextPage() {
    FocusScope.of(context).unfocus();
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishSetup(String pin) async {
    setState(() => _isLoading = true);

    try {
      // 1. Guardar nombre del negocio
      await ref.read(settingsRepositoryProvider).saveSetting(
        'business_name', 
        _businessNameController.text.trim(),
      );

      // 2. Crear primer usuario Administrador
      await ref.read(authRepositoryProvider).createUser(
        name: _adminNameController.text.trim(),
        pin: pin,
        role: AppRole.admin,
      );

      if (!mounted) return;
      
      // 3. Ir a la pantalla de Login
      context.go('/login');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Evitar arrastrar
              children: [
                // Paso 1: Negocio
                _buildStepPanel(
                  title: '¡Bienvenido a POS Fácil!',
                  subtitle: 'Para empezar, ¿cómo se llama tu negocio?',
                  content: AppTextField(
                    label: 'Nombre del negocio',
                    controller: _businessNameController,
                    prefixIcon: Icons.storefront,
                  ),
                  onNext: _nextPage,
                  isNextDisabled: () => _businessNameController.text.trim().isEmpty,
                ),
                
                // Paso 2: Administrador
                _buildStepPanel(
                  title: 'Cuenta de Administrador',
                  subtitle: 'Tú tendrás acceso a los reportes y configuración. ¿Cuál es tu nombre?',
                  content: AppTextField(
                    label: 'Tu nombre',
                    controller: _adminNameController,
                    prefixIcon: Icons.person,
                  ),
                  onNext: _nextPage,
                  isNextDisabled: () => _adminNameController.text.trim().isEmpty,
                ),
                
                // Paso 3: PIN
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: _isLoading 
                      ? const CircularProgressIndicator()
                      : PinInput(
                          title: 'Crea tu PIN de 4 dígitos',
                          onPinCompleted: _finishSetup,
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

  Widget _buildStepPanel({
    required String title,
    required String subtitle,
    required Widget content,
    required VoidCallback onNext,
    required bool Function() isNextDisabled,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(subtitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 32),
          content,
          const SizedBox(height: 32),
          AppButton(
            label: 'Siguiente',
            icon: Icons.arrow_forward,
            onPressed: () {
              if (isNextDisabled()) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor llena este campo')));
                return;
              }
              onNext();
            },
          ),
        ],
      ),
    );
  }
}