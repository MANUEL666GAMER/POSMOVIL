import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/pin_input.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/theme_toggle_button.dart';
import '../../../../shared/widgets/user_avatar_tile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../backup/services/drive_backup_service.dart';
import '../../data/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _businessController = TextEditingController();
  String _lastBackup = 'Nunca';
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(settingsRepositoryProvider);
    final name = await repo.getSetting('business_name') ?? '';
    final backup = await repo.getSetting('last_backup_at') ?? 'Nunca';
    if (mounted) {
      setState(() {
        _businessController.text = name;
        _lastBackup = backup;
      });
    }
  }

  Future<void> _saveBusinessName() async {
    if (_businessController.text.trim().isEmpty) return;
    await ref.read(settingsRepositoryProvider).saveSetting(
      'business_name',
      _businessController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre del negocio actualizado'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _showCreateUserDialog() async {
    final nameCtrl = TextEditingController();
    AppRole selectedRole = AppRole.cashier;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTextField(label: 'Nombre', controller: nameCtrl, prefixIcon: Icons.person),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppRole>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: AppRole.cashier, child: Text('Cajero')),
                    DropdownMenuItem(value: AppRole.admin, child: Text('Administrador')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                PinInput(
                  title: 'Asigna un PIN de 4 dígitos',
                  onPinCompleted: (pin) async {
                    if (nameCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Escribe el nombre primero')),
                      );
                      return;
                    }
                    await ref.read(authRepositoryProvider).createUser(
                      name: nameCtrl.text.trim(),
                      pin: pin,
                      role: selectedRole,
                    );
                    ref.invalidate(usersListProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await ref.read(driveBackupServiceProvider).backupDatabase();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo subido a Google Drive'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo respaldar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _runRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text('Esto reemplazará todos los datos actuales con la última copia de Google Drive. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBackingUp = true);
    try {
      await ref.read(driveBackupServiceProvider).restoreLatestBackup();
      if (!mounted) return;
      ref.read(authStateProvider.notifier).state = null;
      context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        actions: const [ThemeToggleButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Datos del Negocio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'Nombre de la tienda', controller: _businessController)),
              const SizedBox(width: 12),
              AppButton(label: 'Guardar', expand: false, onPressed: _saveBusinessName),
            ],
          ),

          const Divider(height: 40),

          const Text('Respaldo en Google Drive', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Último respaldo: $_lastBackup'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton(
                label: 'Respaldar ahora',
                icon: Icons.cloud_upload,
                expand: false,
                isLoading: _isBackingUp,
                onPressed: _runBackup,
              ),
              AppButton(
                label: 'Restaurar copia',
                icon: Icons.cloud_download,
                variant: AppButtonVariant.outline,
                expand: false,
                isLoading: _isBackingUp,
                onPressed: _runRestore,
              ),
            ],
          ),

          const Divider(height: 40),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Usuarios y Cajeros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              AppButton(
                label: 'Agregar Usuario',
                icon: Icons.person_add,
                expand: false,
                onPressed: _showCreateUserDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          usersAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(message: e.toString()),
            data: (users) => Column(
              children: users.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: UserAvatarTile(
                  name: u.name,
                  role: AppRole.fromString(u.role),
                  onTap: () {},
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}