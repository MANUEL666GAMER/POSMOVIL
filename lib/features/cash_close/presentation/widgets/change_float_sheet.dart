import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';

class ChangeFloatSheet extends StatefulWidget {
  final CashClose shift;
  final String ownerName;
  final bool isOwnShift;
  final int cashSalesCents;

  const ChangeFloatSheet({
    super.key,
    required this.shift,
    required this.ownerName,
    required this.isOwnShift,
    required this.cashSalesCents,
  });

  static Future<({int newFloatCents, String reason})?> show(
    BuildContext context, {
    required CashClose shift,
    required String ownerName,
    required bool isOwnShift,
    required int cashSalesCents,
  }) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final content = ChangeFloatSheet(
      shift: shift,
      ownerName: ownerName,
      isOwnShift: isOwnShift,
      cashSalesCents: cashSalesCents,
    );

    if (isTablet) {
      return showDialog<({int newFloatCents, String reason})>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: content,
          ),
        ),
      );
    }

    return showModalBottomSheet<({int newFloatCents, String reason})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => content,
    );
  }

  @override
  State<ChangeFloatSheet> createState() => _ChangeFloatSheetState();
}

class _ChangeFloatSheetState extends State<ChangeFloatSheet> {
  late final TextEditingController _amountCtrl;
  final _customReasonCtrl = TextEditingController();
  String? _selectedPresetReason;

  final List<String> _presetReasons = [
    'Me equivoqué al capturarlo',
    'Agregué más cambio',
    'Saqué dinero de la caja',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    final initialPesos = widget.shift.openingFloatCents / 100;
    _amountCtrl = TextEditingController(
      text: initialPesos.toStringAsFixed(widget.shift.openingFloatCents % 100 == 0 ? 0 : 2),
    );
    _amountCtrl.addListener(() => setState(() {}));
    _customReasonCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _customReasonCtrl.dispose();
    super.dispose();
  }

  int get _newFloatCents => MoneyUtils.parseToCents(_amountCtrl.text);

  String get _finalReason {
    if (_selectedPresetReason == null) return '';
    if (_selectedPresetReason == 'Otro') return _customReasonCtrl.text.trim();
    return _selectedPresetReason!;
  }

  bool get _canSave =>
      _newFloatCents != widget.shift.openingFloatCents && _finalReason.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final oldExpected = widget.shift.openingFloatCents + widget.cashSalesCents;
    final newExpected = _newFloatCents + widget.cashSalesCents;
    final shortcuts = [20000, 30000, 50000, 100000]; // $200, $300, $500, $1000

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isOwnShift
                        ? 'Cambiar fondo inicial'
                        : 'Fondo inicial de ${widget.ownerName}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.ink),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Úsalo si lo capturaste mal o si metiste o sacaste dinero para cambio. Quedará registrado.',
              style: TextStyle(fontSize: 15, color: c.muted),
            ),

            const SizedBox(height: 16),

            // Dos tarjetas: Fondo actual vs Nuevo fondo
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.canvas,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fondo actual', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                        const SizedBox(height: 4),
                        Text(
                          MoneyUtils.formatCents(widget.shift.openingFloatCents),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: c.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.brandSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.brandLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nuevo fondo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.brandDark)),
                        const SizedBox(height: 4),
                        Text(
                          MoneyUtils.formatCents(_newFloatCents),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: c.brand,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Campo numérico
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: c.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                filled: true,
                fillColor: c.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

            const SizedBox(height: 10),

            // Atajos: $200, $300, $500, $1000
            Row(
              children: shortcuts.map((cents) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _amountCtrl.text = (cents ~/ 100).toString(),
                      child: Text('\$${cents ~/ 100}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            Text('¿Por qué lo cambias?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.ink)),
            const SizedBox(height: 8),

            // Chips de motivo obligatorio
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetReasons.map((reason) {
                final selected = _selectedPresetReason == reason;
                return ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(reason, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedPresetReason = reason),
                );
              }).toList(),
            ),

            if (_selectedPresetReason == 'Otro') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customReasonCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Escribe el motivo',
                  filled: true,
                  fillColor: c.card,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Vista previa naranja del nuevo efectivo esperado
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.accentLine),
              ),
              child: Text(
                'El efectivo esperado pasará de ${MoneyUtils.formatCents(oldExpected)} a ${MoneyUtils.formatCents(newExpected)}.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accentDark),
              ),
            ),

            const SizedBox(height: 16),

            // Botón Guardar nuevo fondo
            SizedBox(
              height: 64,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  foregroundColor: c.onBrand,
                  disabledBackgroundColor: c.brandDisabled,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _canSave
                    ? () => Navigator.pop(context, (
                          newFloatCents: _newFloatCents,
                          reason: _finalReason,
                        ))
                    : null,
                child: const Text(
                  'Guardar nuevo fondo',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}