import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cash_close/presentation/providers/cash_close_provider.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../../settings/data/settings_repository.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _businessName = 'Mi Negocio';
  String _lastBackup = 'Sin respaldo aún';

  @override
  void initState() {
    super.initState();
    _loadHeaderInfo();
  }

  Future<void> _loadHeaderInfo() async {
    final repo = ref.read(settingsRepositoryProvider);
    final name = await repo.getSetting('business_name');
    final backup = await repo.getSetting('last_backup_at');
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _businessName = name;
        if (backup != null && backup.isNotEmpty) _lastBackup = backup;
      });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _showAppearanceSheet(BuildContext context) {
    final current = ref.read(themeModeProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Apariencia', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            _themeOption(
              ctx,
              title: 'Claro',
              subtitle: 'Fondo blanco, ideal de día',
              icon: Icons.light_mode_rounded,
              selected: current == ThemeMode.light,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            _themeOption(
              ctx,
              title: 'Oscuro',
              subtitle: 'Cansa menos la vista de noche',
              icon: Icons.dark_mode_rounded,
              selected: current == ThemeMode.dark,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
            _themeOption(
              ctx,
              title: 'Automático',
              subtitle: 'Igual que tu celular',
              icon: Icons.smartphone_rounded,
              selected: current == ThemeMode.system,
              onTap: () {
                ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final c = context.pos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: selected ? c.brand : c.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.ink)),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: c.muted)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: c.brand, size: 28),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tus ventas abiertas se quedan guardadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, regresar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ref.read(authStateProvider.notifier).state = null;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final user = ref.watch(authStateProvider);
    final role = user != null ? AppRole.fromString(user.role) : AppRole.cashier;
    final shiftAsync = ref.watch(activeShiftProvider);
    final salesState = ref.watch(salesProvider);
    final productsAsync = ref.watch(productsListProvider);
    final inventoryAsync = ref.watch(inventoryListProvider);
    final themeMode = ref.watch(themeModeProvider);

    final openSalesCount = salesState.carts.where((cart) => cart.items.isNotEmpty).length;
    final productCount = productsAsync.valueOrNull?.length ?? 0;

    final lowStockItems = inventoryAsync.valueOrNull
            ?.where((i) => i.currentStock <= i.product.minStock)
            .toList() ??
        [];

    final themeLabel = themeMode == ThemeMode.light
        ? 'Claro'
        : themeMode == ThemeMode.dark
            ? 'Oscuro'
            : 'Auto';
    final themeIcon = themeMode == ThemeMode.light
        ? Icons.light_mode_rounded
        : themeMode == ThemeMode.dark
            ? Icons.dark_mode_rounded
            : Icons.smartphone_rounded;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.storefront_rounded, color: c.brand, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _businessName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () => _showAppearanceSheet(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(themeIcon, size: 22, color: c.ink),
                  Text(themeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: c.brand,
            child: Text(
              (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
              style: TextStyle(color: c.onBrand, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1152),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Saludo y estado de caja
              Text(_greeting(), style: TextStyle(fontSize: 17, color: c.muted, fontWeight: FontWeight.w600)),
              Text(
                'Hola, ${user?.name ?? 'Usuario'}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.ink),
              ),
              const SizedBox(height: 8),
              shiftAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (shift) {
                  final isOpen = shift != null;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOpen ? c.brandSoft : c.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isOpen ? c.brandLine : c.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 10, color: isOpen ? c.ok : c.faint),
                          const SizedBox(width: 8),
                          Text(
                            isOpen
                                ? 'Caja abierta desde ${DateFormat('h:mm a').format(shift.openedAt)}'
                                : 'Caja cerrada',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isOpen ? c.brandDark : c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Aviso naranja de stock bajo
              if (lowStockItems.isNotEmpty) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => context.push('/inventory'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.accentLine),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: c.accent, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${lowStockItems.length} productos se están acabando',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.accentDark),
                              ),
                              Text(
                                lowStockItems.take(3).map((e) => e.product.name).join(', '),
                                style: TextStyle(fontSize: 15, color: c.accentDark),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: c.accentDark),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Cuadrícula de botones grandes (24 px radio)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 900;
                  final isAdmin = PermissionService.can(role, AppPermission.viewReports);

                  final cards = <Widget>[
                    _MenuTile(
                      title: 'Vender',
                      subtitle: openSalesCount > 0 ? '$openSalesCount ventas abiertas' : 'Cobrar a un cliente',
                      icon: Icons.point_of_sale_rounded,
                      isPrimary: true,
                      onTap: () => context.push('/home'),
                    ),
                    _MenuTile(
                      title: 'Productos',
                      subtitle: '$productCount productos',
                      icon: Icons.shopping_bag_rounded,
                      onTap: () => context.push('/products'),
                    ),
                    _MenuTile(
                      title: 'Inventario',
                      subtitle: lowStockItems.isNotEmpty ? '${lowStockItems.length} por surtir' : 'Todo surtido',
                      icon: Icons.inventory_2_rounded,
                      onTap: () => context.push('/inventory'),
                    ),
                    _MenuTile(
                      title: 'Corte de caja',
                      subtitle: shiftAsync.valueOrNull != null ? 'Cerrar mi turno' : 'Sin turno abierto',
                      icon: Icons.receipt_long_rounded,
                      onTap: () => context.push('/cash-close'),
                    ),
                    if (isAdmin)
                      _MenuTile(
                        title: 'Reportes',
                        subtitle: 'Ventas y ganancias',
                        icon: Icons.bar_chart_rounded,
                        onTap: () => context.push('/reports'),
                      ),
                  ];

                  if (isTablet) {
                    return Row(
                      children: cards
                          .map((card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: card,
                                ),
                              ))
                          .toList(),
                    );
                  }

                  // En celular: 2 columnas y si es impar, el último ocupa todo el ancho
                  final rows = <Widget>[];
                  for (int i = 0; i < cards.length; i += 2) {
                    if (i + 1 < cards.length) {
                      rows.add(Row(
                        children: [
                          Expanded(child: cards[i]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[i + 1]),
                        ],
                      ));
                    } else {
                      rows.add(cards[i]);
                    }
                    rows.add(const SizedBox(height: 12));
                  }
                  return Column(children: rows);
                },
              ),

              const SizedBox(height: 12),

              // Indicador de respaldo
              InkWell(
                onTap: PermissionService.can(role, AppPermission.manageSettings)
                    ? () => context.push('/settings')
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_done_rounded, size: 20, color: c.info),
                      const SizedBox(width: 8),
                      Text(
                        'Respaldo: $_lastBackup',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 32),

              // Barra inferior: Configuración (solo admin) y Cerrar sesión
              Row(
                children: [
                  PermissionGate(
                    currentRole: role,
                    requiredPermission: AppPermission.manageSettings,
                    child: Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                          side: BorderSide(color: c.line),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => context.push('/settings'),
                        icon: const Icon(Icons.settings_rounded),
                        label: const Text('Configuración', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  if (PermissionService.can(role, AppPermission.manageSettings)) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        foregroundColor: c.danger,
                        side: BorderSide(color: c.line),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _confirmLogout(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Cerrar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 136,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPrimary ? c.brand : c.card,
          borderRadius: BorderRadius.circular(24),
          border: isPrimary ? null : c.cardBorder,
          boxShadow: isPrimary
              ? [BoxShadow(color: c.brand.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]
              : c.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary ? c.onBrand.withValues(alpha: 0.16) : c.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: isPrimary ? c.onBrand : c.brand),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isPrimary ? c.onBrand : c.ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPrimary ? c.onBrand.withValues(alpha: 0.85) : c.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}