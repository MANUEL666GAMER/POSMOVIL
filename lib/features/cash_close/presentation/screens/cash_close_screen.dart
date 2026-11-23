import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/capture_boundary.dart';
import '../../../../shared/widgets/cash_close_receipt.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/cash_close_repository.dart';
import '../providers/cash_close_provider.dart';
import '../widgets/change_float_sheet.dart';

class CashCloseScreen extends ConsumerStatefulWidget {
  const CashCloseScreen({super.key});

  @override
  ConsumerState<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends ConsumerState<CashCloseScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _useBillCounter = false;
  String? _selectedShiftUserId; // Para administrador con varios turnos abiertos

  final List<int> _denominations = [
    100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100, 50
  ];
  final Map<int, int> _billCounts = {};

  CashClose? _closedShiftReceipt;
  String _closedOwnerName = '';
  int _closedSalesCount = 0;
  List<FloatChangeWithUser> _closedFloatChanges = [];
  String _businessName = 'Mi Negocio';
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _amountController.text = '500'; // Valor inicial sugerido según spec
    _loadBusinessName();
    _amountController.addListener(() => setState(() {}));
  }

  Future<void> _loadBusinessName() async {
    final name = await ref.read(settingsRepositoryProvider).getSetting('business_name');
    if (mounted && name != null && name.isNotEmpty) {
      setState(() => _businessName = name);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int get _countedBillsCents {
    int sum = 0;
    _billCounts.forEach((denom, qty) => sum += denom * qty);
    return sum;
  }

  int get _effectiveCountedCents =>
      _useBillCounter ? _countedBillsCents : MoneyUtils.parseToCents(_amountController.text);

  Future<void> _openShift() async {
    final user = ref.read(authStateProvider);
    if (user == null) return;
    final floatCents = MoneyUtils.parseToCents(_amountController.text);

    setState(() => _isLoading = true);
    try {
      await ref.read(cashCloseRepositoryProvider).openShift(
            userId: user.id,
            openingFloatCents: floatCents,
          );
      _amountController.clear();
      _billCounts.clear();
      ref.invalidate(activeShiftProvider);
      if (mounted) {
        setState(() => _selectedShiftUserId = user.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Turno abierto. ¡A vender!'), backgroundColor: context.pos.brand),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openChangeFloatSheet({
    required CashClose shift,
    required String ownerName,
    required bool isOwnShift,
    required int cashSalesCents,
  }) async {
    final currentUser = ref.read(authStateProvider);
    if (currentUser == null) return;

    final result = await ChangeFloatSheet.show(
      context,
      shift: shift,
      ownerName: ownerName,
      isOwnShift: isOwnShift,
      cashSalesCents: cashSalesCents,
    );

    if (result == null) return;

    await ref.read(cashCloseRepositoryProvider).changeOpeningFloat(
          shift: shift,
          newFloatCents: result.newFloatCents,
          reason: result.reason,
          modifiedByUserId: currentUser.id,
        );

    ref.invalidate(activeShiftProvider);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Fondo inicial actualizado'), backgroundColor: context.pos.brand),
      );
    }
  }

  Future<void> _confirmAndCloseShift({
    required CashClose activeShift,
    required String ownerName,
    required bool isOwnShift,
    required int salesCount,
    required List<FloatChangeWithUser> floatChanges,
  }) async {
    final currentUser = ref.read(authStateProvider);
    if (currentUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isOwnShift ? '¿Cerrar tu turno?' : '¿Cerrar el turno de $ownerName?'),
        content: const Text('Después de cerrar ya no se pueden agregar ventas a este corte.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, regresar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.pos.accent, foregroundColor: context.pos.onAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cerrar turno'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final counted = _effectiveCountedCents;
      final closedRecord = await ref.read(cashCloseRepositoryProvider).closeShift(
            activeShift: activeShift,
            countedCashCents: counted,
            closedByUserId: currentUser.id,
            denominations: _useBillCounter ? Map.of(_billCounts) : null,
          );

      if (mounted) {
        setState(() {
          _closedShiftReceipt = closedRecord;
          _closedOwnerName = ownerName;
          _closedSalesCount = salesCount;
          _closedFloatChanges = floatChanges;
        });
      }
      ref.invalidate(activeShiftProvider);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareReceipt() async {
    final pngBytes = await CaptureBoundary.capturePng(_receiptKey);
    if (pngBytes == null) return;
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/corte_caja.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Corte de caja · $_closedOwnerName');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final currentUser = ref.watch(authStateProvider);
    if (currentUser == null) return const SizedBox.shrink();

    final isAdmin = AppRole.fromString(currentUser.role) == AppRole.admin;
    final repo = ref.watch(cashCloseRepositoryProvider);

    // VISTA DE COMPROBANTE TRAS CERRAR TURNO
    if (_closedShiftReceipt != null) {
      return Scaffold(
        backgroundColor: c.brandSoft,
        appBar: AppBar(title: const Text('Corte guardado')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, color: c.onBrand, size: 44),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¡Corte guardado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: c.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'El administrador lo puede revisar en Reportes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: c.muted),
                ),
                const SizedBox(height: 20),
                Center(
                  child: CaptureBoundary(
                    boundaryKey: _receiptKey,
                    child: CashCloseReceipt(
                      businessName: _businessName,
                      userName: _closedOwnerName,
                      cashClose: _closedShiftReceipt!,
                      salesCount: _closedSalesCount,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25A244),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _shareReceipt,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir por WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: c.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver al inicio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<OpenShiftWithUser>>(
      future: isAdmin
          ? repo.getAllOpenShifts()
          : repo.getActiveShift(currentUser.id).then((s) => s == null ? [] : [OpenShiftWithUser(s, currentUser)]),
      builder: (context, openShiftsSnap) {
        if (openShiftsSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title: const Text('Corte de caja')), body: const LoadingView());
        }

        final openShifts = openShiftsSnap.data ?? [];

        // 1. SIN TURNO ABIERTO: Pantalla para abrir turno
        if (openShifts.isEmpty) {
          final floatCents = MoneyUtils.parseToCents(_amountController.text);
          final shortcuts = [0, 20000, 30000, 50000];

          return Scaffold(
            appBar: AppBar(title: const Text('Corte de caja')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 64, color: c.brand),
                    const SizedBox(height: 16),
                    Text(
                      'No tienes un turno abierto',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.ink),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Con cuánto dinero empiezas en la caja? (fondo para dar cambio)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: c.muted),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: shortcuts.map((cents) {
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(96, 56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _amountController.text = (cents ~/ 100).toString(),
                          child: Text('\$${cents ~/ 100}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0',
                        filled: true,
                        fillColor: c.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 72,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.brand,
                          foregroundColor: c.onBrand,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isLoading ? null : _openShift,
                        child: Text(
                          'Abrir turno con ${MoneyUtils.formatCents(floatCents)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Determinar el turno seleccionado (por defecto el del usuario actual, o el primero abierto)
        final selectedEntry = openShifts.firstWhere(
          (e) => e.user.id == (_selectedShiftUserId ?? currentUser.id),
          orElse: () => openShifts.first,
        );
        final activeShift = selectedEntry.shift;
        final owner = selectedEntry.user;
        final isOwnShift = owner.id == currentUser.id;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Corte de caja'),
                Text(
                  isOwnShift ? 'Mi turno' : 'Turno de ${owner.name}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted),
                ),
              ],
            ),
          ),
          body: FutureBuilder(
            future: Future.wait([
              repo.getUnassignedSales(activeShift.userId),
              repo.getFloatChanges(activeShift.id),
            ]),
            builder: (context, AsyncSnapshot<List<dynamic>> detailsSnap) {
              final shiftSales = (detailsSnap.data?[0] as List<Sale>?) ?? [];
              final floatChanges = (detailsSnap.data?[1] as List<FloatChangeWithUser>?) ?? [];

              int sumByMethod(String m) => shiftSales
                  .where((s) => (s.paymentMethod ?? 'cash') == m)
                  .fold<int>(0, (sum, s) => sum + s.totalCents);

              final cashSalesCents = sumByMethod('cash');
              final cardSalesCents = sumByMethod('card');
              final transferSalesCents = sumByMethod('transfer');
              final expectedCents = activeShift.openingFloatCents + cashSalesCents;
              final countedCents = _effectiveCountedCents;
              final diffCents = countedCents - expectedCents;

              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selector de turno si hay más de un turno abierto (solo admin)
                  if (isAdmin && openShifts.length > 1) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: openShifts.map((entry) {
                          final selected = entry.user.id == owner.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedShiftUserId = entry.user.id;
                                  _amountController.clear();
                                  _billCounts.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected ? c.brandSoft : c.card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2 : 1),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: c.brand,
                                      child: Text(entry.user.name[0].toUpperCase(), style: TextStyle(color: c.onBrand, fontWeight: FontWeight.w900)),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          entry.user.id == currentUser.id ? 'Mi turno' : entry.user.name,
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.ink),
                                        ),
                                        Text(
                                          'desde ${DateFormat('h:mm a').format(entry.shift.openedAt)}',
                                          style: TextStyle(fontSize: 13, color: c.muted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tarjeta del turno + Resumen
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(20),
                      border: c.cardBorder ?? Border.all(color: c.line),
                      boxShadow: c.shadowCard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: c.brandSoft,
                              child: Text(
                                owner.name[0].toUpperCase(),
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.brandDark),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(owner.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.ink)),
                                  Text(
                                    'Turno desde las ${DateFormat('h:mm a').format(activeShift.openedAt)}',
                                    style: TextStyle(fontSize: 15, color: c.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(height: 28, color: c.line),

                        // Fondo inicial + botón Cambiar
                        Row(
                          children: [
                            Expanded(
                              child: Text('Fondo inicial de caja', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink)),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: c.brandDark,
                                backgroundColor: c.brandSoft,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _openChangeFloatSheet(
                                shift: activeShift,
                                ownerName: owner.name,
                                isOwnShift: isOwnShift,
                                cashSalesCents: cashSalesCents,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              MoneyUtils.formatCents(activeShift.openingFloatCents),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.ink, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ],
                        ),

                        // Etiquetas naranjas con historial de cambios del fondo
                        if (floatChanges.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...floatChanges.map((fc) => Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.accentSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Cambió de ${MoneyUtils.formatCents(fc.change.fromCents)} a ${MoneyUtils.formatCents(fc.change.toCents)} · ${fc.change.reason} · ${fc.userName}, ${DateFormat('h:mm a').format(fc.change.changedAt)}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accentDark),
                                ),
                              )),
                        ],

                        const SizedBox(height: 12),
                        _SummaryRow(label: 'Ventas en efectivo', amountCents: cashSalesCents, bold: true),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Ventas con tarjeta', amountCents: cardSalesCents, muted: true),
                        const SizedBox(height: 8),
                        _SummaryRow(label: 'Transferencias', amountCents: transferSalesCents, muted: true),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Número de ventas', style: TextStyle(fontSize: 16, color: c.muted)),
                            Text('${shiftSales.length}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bloque alto contraste: Efectivo esperado
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.inverse,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Efectivo esperado (fondo + efectivo)',
                          style: TextStyle(fontSize: 15, color: c.onInverse.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MoneyUtils.formatCents(expectedCents),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: c.onInverse,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '¿Cuánto efectivo tienes en la caja?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.ink),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Escribir total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          selected: !_useBillCounter,
                          onSelected: (_) => setState(() => _useBillCounter = false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('Contar billetes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          selected: _useBillCounter,
                          onSelected: (_) => setState(() => _useBillCounter = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_useBillCounter)
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: '0.00',
                        filled: true,
                        fillColor: c.card,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: c.line),
                      ),
                      child: Column(
                        children: _denominations.map((denom) {
                          final qty = _billCounts[denom] ?? 0;
                          final label = denom >= 100 ? '\$${denom ~/ 100}' : '${denom}¢';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.ink)),
                                ),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: c.canvas, minimumSize: const Size(48, 48)),
                                  icon: const Icon(Icons.remove_rounded),
                                  onPressed: qty > 0 ? () => setState(() => _billCounts[denom] = qty - 1) : null,
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                ),
                                IconButton(
                                  style: IconButton.styleFrom(backgroundColor: c.brandSoft, foregroundColor: c.brandDark, minimumSize: const Size(48, 48)),
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: () => setState(() => _billCounts[denom] = qty + 1),
                                ),
                                const Spacer(),
                                Text(
                                  MoneyUtils.formatCents(denom * qty),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Caja de resultado: Cuadra / Sobrante / Faltante
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: diffCents == 0
                          ? c.brandSoft
                          : diffCents > 0
                              ? c.infoSoft
                              : c.dangerSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: diffCents == 0
                            ? c.brandLine
                            : diffCents > 0
                                ? c.info
                                : c.danger,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          diffCents == 0
                              ? Icons.check_circle_rounded
                              : diffCents > 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                          size: 36,
                          color: diffCents == 0
                              ? c.brand
                              : diffCents > 0
                                  ? c.info
                                  : c.danger,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                diffCents == 0
                                    ? 'Cuadra perfecto'
                                    : diffCents > 0
                                        ? 'Sobrante ${MoneyUtils.formatCents(diffCents)}'
                                        : 'Faltante ${MoneyUtils.formatCents(diffCents.abs())}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: diffCents == 0
                                      ? c.brandDark
                                      : diffCents > 0
                                          ? c.info
                                          : c.danger,
                                ),
                              ),
                              Text(
                                diffCents == 0
                                    ? 'El dinero coincide con las ventas.'
                                    : 'Contado: ${MoneyUtils.formatCents(countedCents)}',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 72,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.brand,
                        foregroundColor: c.onBrand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _confirmAndCloseShift(
                                activeShift: activeShift,
                                ownerName: owner.name,
                                isOwnShift: isOwnShift,
                                salesCount: shiftSales.length,
                                floatChanges: floatChanges,
                              ),
                      child: const Text(
                        'Cerrar turno y guardar corte',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 1024) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: leftColumn),
                          const SizedBox(width: 24),
                          Expanded(child: rightColumn),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      leftColumn,
                      const SizedBox(height: 24),
                      rightColumn,
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int amountCents;
  final bool bold;
  final bool muted;

  const _SummaryRow({
    required this.label,
    required this.amountCents,
    this.bold = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: muted ? c.muted : c.ink,
          ),
        ),
        Text(
          MoneyUtils.formatCents(amountCents),
          style: TextStyle(
            fontSize: 17,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: muted ? c.muted : c.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}