import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/capture_boundary.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/sales_repository.dart';
import '../../domain/cart_models.dart';
import '../providers/sales_provider.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  final int totalCents;

  const CheckoutDialog({super.key, required this.totalCents});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  String _paymentMethod = 'cash'; // 'cash', 'card', 'transfer'
  final _cashController = TextEditingController();
  int _receivedCents = 0;
  bool _isSaving = false;

  // Estado tras confirmar la venta
  bool _saleCompleted = false;
  String? _savedSaleId;
  late Cart _completedCart;
  String _businessName = 'Mi Negocio';
  String _businessAddress = '';
  String _ticketMessage = '¡Gracias por su compra! Vuelva pronto.';
  final GlobalKey _ticketKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadBusinessInfo();
    _cashController.addListener(() {
      setState(() {
        _receivedCents = MoneyUtils.parseToCents(_cashController.text);
      });
    });
  }

  Future<void> _loadBusinessInfo() async {
    final repo = ref.read(settingsRepositoryProvider);
    final name = await repo.getSetting('business_name');
    final addr = await repo.getSetting('business_address');
    final msg = await repo.getSetting('ticket_message');
    if (mounted) {
      setState(() {
        if (name != null && name.isNotEmpty) _businessName = name;
        if (addr != null) _businessAddress = addr;
        if (msg != null && msg.isNotEmpty) _ticketMessage = msg;
      });
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  int get _effectiveReceivedCents =>
      _paymentMethod == 'cash' ? _receivedCents : widget.totalCents;

  int get _changeCents =>
      _paymentMethod == 'cash' ? (_receivedCents - widget.totalCents) : 0;

  bool get _canConfirm =>
      !_isSaving &&
      (_paymentMethod != 'cash' || _receivedCents >= widget.totalCents);

  void _setQuickBill(int billCents) {
    final formatted = (billCents / 100).toStringAsFixed(billCents % 100 == 0 ? 0 : 2);
    _cashController.text = formatted;
  }

  Future<void> _confirmSale() async {
    final currentUser = ref.read(authStateProvider);
    if (currentUser == null) return;

    final activeCart = ref.read(salesProvider).activeCart;
    if (activeCart.items.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final saleId = await ref.read(salesRepositoryProvider).saveSale(
            activeCart,
            currentUser,
            paymentMethod: _paymentMethod,
            cashReceivedCents: _effectiveReceivedCents,
            changeCents: _changeCents > 0 ? _changeCents : 0,
          );

      // Guardamos copia del carrito para mostrar el ticket y limpiamos la venta abierta
      _completedCart = Cart(name: activeCart.name, items: List.of(activeCart.items));
      ref.read(salesProvider.notifier).clearActiveCart();

      if (mounted) {
        setState(() {
          _savedSaleId = saleId;
          _saleCompleted = true;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar venta: $e'), backgroundColor: context.pos.danger),
        );
      }
    }
  }

  Future<void> _shareTicketImage() async {
    final pngBytes = await CaptureBoundary.capturePng(_ticketKey);
    if (pngBytes == null) return;
    final tempDir = await getTemporaryDirectory();
    final folio = (_savedSaleId ?? 'ticket').substring(0, 6).toUpperCase();
    final file = File('${tempDir.path}/ticket_$folio.png');
    await file.writeAsBytes(pngBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Comprobante de compra - $_businessName');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final user = ref.watch(authStateProvider);

    if (_saleCompleted) {
      return _buildSuccessTicketView(c, user);
    }

    final activeCart = ref.watch(salesProvider).activeCart;
    final bills = [2000, 5000, 10000, 20000, 50000]; // $20, $50, $100, $200, $500

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 68,
          leadingWidth: 100,
          leading: TextButton.icon(
            onPressed: () => Navigator.pop(context, false),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Atrás', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          title: Text('Cobrar • ${activeCart.name}'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // BLOQUE DE ALTO CONTRASTE: Total a cobrar
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: c.inverse,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total a cobrar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: c.onInverse.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        MoneyUtils.formatCents(widget.totalCents),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: c.onInverse,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text('¿Cómo paga el cliente?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.ink)),
                const SizedBox(height: 12),

                // MÉTODOS DE PAGO (botones grandes de 88 px)
                Row(
                  children: [
                    Expanded(
                      child: _PaymentMethodCard(
                        label: 'Efectivo',
                        icon: Icons.payments_rounded,
                        selected: _paymentMethod == 'cash',
                        onTap: () => setState(() => _paymentMethod = 'cash'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PaymentMethodCard(
                        label: 'Tarjeta',
                        icon: Icons.credit_card_rounded,
                        selected: _paymentMethod == 'card',
                        onTap: () => setState(() => _paymentMethod = 'card'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PaymentMethodCard(
                        label: 'Transferencia',
                        icon: Icons.account_balance_rounded,
                        selected: _paymentMethod == 'transfer',
                        onTap: () => setState(() => _paymentMethod = 'transfer'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // CONTENIDO SEGÚN MÉTODO DE PAGO
                if (_paymentMethod == 'cash') ...[
                  Text('¿Con cuánto paga?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.ink)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _cashController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.muted),
                      hintText: '0.00',
                      filled: true,
                      fillColor: c.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: c.line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // BILLETES RÁPIDOS + EXACTO
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ...bills.map((b) {
                        final isEnough = b >= widget.totalCents;
                        return OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(88, 56),
                            backgroundColor: isEnough ? c.card : c.canvas,
                            foregroundColor: isEnough ? c.ink : c.faint,
                            side: BorderSide(color: isEnough ? c.line : c.line.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => _setQuickBill(b),
                          child: Text(
                            '\$${b ~/ 100}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        );
                      }),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(110, 56),
                          backgroundColor: c.brandSoft,
                          foregroundColor: c.brandDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _setQuickBill(widget.totalCents),
                        child: const Text('Exacto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // RESULTADO DE CAMBIO O FALTANTE
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _receivedCents >= widget.totalCents ? c.brandSoft : c.accentSoft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _receivedCents >= widget.totalCents ? c.brandLine : c.accentLine,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _receivedCents >= widget.totalCents ? 'Su cambio' : 'Faltan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _receivedCents >= widget.totalCents ? c.brandDark : c.accentDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          MoneyUtils.formatCents(_changeCents.abs()),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: _receivedCents >= widget.totalCents ? c.brand : c.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_paymentMethod == 'card') ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.infoSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.credit_score_rounded, color: c.info, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Cobra ${MoneyUtils.formatCents(widget.totalCents)} en tu terminal. Cuando salga "Aprobada", toca Confirmar venta.',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.infoSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet_rounded, color: c.info, size: 36),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Confirma cuando veas los ${MoneyUtils.formatCents(widget.totalCents)} reflejados en tu cuenta bancaria.',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // BOTÓN CONFIRMAR VENTA (72 px)
                SizedBox(
                  height: 72,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.brand,
                      foregroundColor: c.onBrand,
                      disabledBackgroundColor: c.brandDisabled,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _canConfirm ? _confirmSale : null,
                    icon: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.check_circle_rounded, size: 28),
                    label: Text(
                      _isSaving ? 'Guardando...' : 'Confirmar venta',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
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

  Widget _buildSuccessTicketView(PosColors c, User? user) {
    final folio = (_savedSaleId ?? '000000').substring(0, 6).toUpperCase();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final methodLabel = _paymentMethod == 'cash'
        ? 'Efectivo'
        : _paymentMethod == 'card'
            ? 'Tarjeta'
            : 'Transferencia';

    return Dialog.fullscreen(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '¡Venta registrada!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c.ink),
                  ),
                  if (_paymentMethod == 'cash' && _changeCents > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Entrega de cambio: ${MoneyUtils.formatCents(_changeCents)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.brand),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // VISTA PREVIA DEL TICKET (siempre blanco para WhatsApp)
                  Center(
                    child: CaptureBoundary(
                      boundaryKey: _ticketKey,
                      child: Container(
                        width: 360,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: DefaultTextStyle(
                          style: const TextStyle(color: Colors.black87, fontSize: 14, fontFamily: 'sans-serif'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _businessName.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              if (_businessAddress.isNotEmpty)
                                Text(
                                  _businessAddress,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              const SizedBox(height: 6),
                              Text('Folio: #$folio  •  $dateStr', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                              Text('Atendió: ${user?.name ?? 'Caja'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                              const Divider(color: Colors.black26, height: 20),
                              ..._completedCart.items.map((item) {
                                final isWeight = item.product.saleType == 'weight';
                                final qtyStr = isWeight ? '${item.quantity.toStringAsFixed(3)} kg' : '${item.quantity.round()}';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('$qtyStr × ${item.product.name}')),
                                      Text(MoneyUtils.formatCents(item.subtotalCents), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                );
                              }),
                              const Divider(color: Colors.black26, height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                  Text(MoneyUtils.formatCents(widget.totalCents), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Pago ($methodLabel):'),
                                  Text(MoneyUtils.formatCents(_effectiveReceivedCents)),
                                ],
                              ),
                              if (_paymentMethod == 'cash')
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Cambio:'),
                                    Text(MoneyUtils.formatCents(_changeCents > 0 ? _changeCents : 0)),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              Text(
                                _ticketMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BOTÓN WHATSAPP
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25A244),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _shareTicketImage,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Enviar ticket por WhatsApp', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // BOTÓN PRINCIPAL: NUEVA VENTA (72 px)
                  SizedBox(
                    height: 72,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.brand,
                        foregroundColor: c.onBrand,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 26),
                      label: const Text('Nueva venta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? c.brand : c.line, width: selected ? 2.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: selected ? c.brand : c.ink),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? c.brandDark : c.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}