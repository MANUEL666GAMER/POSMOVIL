import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';

class WeightInputSheet extends StatefulWidget {
  final Product product;
  final double? initialWeightKg;

  const WeightInputSheet({
    super.key,
    required this.product,
    this.initialWeightKg,
  });

  static Future<double?> show(
    BuildContext context,
    Product product, {
    double? initialWeightKg,
  }) {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    if (isTablet) {
      return showDialog<double>(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: WeightInputSheet(product: product, initialWeightKg: initialWeightKg),
          ),
        ),
      );
    }

    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => WeightInputSheet(product: product, initialWeightKg: initialWeightKg),
    );
  }

  @override
  State<WeightInputSheet> createState() => _WeightInputSheetState();
}

class _WeightInputSheetState extends State<WeightInputSheet> {
  bool _byMoney = false;
  String _rawInput = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialWeightKg != null && widget.initialWeightKg! > 0) {
      _rawInput = widget.initialWeightKg!.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
    }
  }

  double get _numericValue => double.tryParse(_rawInput) ?? 0.0;

  double get _weightKg {
    if (_numericValue <= 0) return 0.0;
    if (!_byMoney) return double.parse(_numericValue.toStringAsFixed(3));
    final pricePesos = widget.product.priceCents / 100.0;
    if (pricePesos <= 0) return 0.0;
    return double.parse((_numericValue / pricePesos).toStringAsFixed(3));
  }

  int get _totalCents {
    if (_numericValue <= 0) return 0;
    if (_byMoney) return (_numericValue * 100).round();
    return (_weightKg * widget.product.priceCents).round();
  }

  void _switchMode(bool toMoney) {
    if (_byMoney == toMoney) return;
    setState(() {
      if (_numericValue > 0) {
        if (toMoney) {
          final pesos = _totalCents / 100.0;
          _rawInput = pesos.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
        } else {
          final kg = _weightKg;
          _rawInput = kg.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
        }
      }
      _byMoney = toMoney;
    });
  }

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'DEL') {
        if (_rawInput.isNotEmpty) {
          _rawInput = _rawInput.substring(0, _rawInput.length - 1);
        }
        return;
      }
      if (key == '.') {
        if (_rawInput.contains('.')) return;
        _rawInput = _rawInput.isEmpty ? '0.' : '$_rawInput.';
        return;
      }

      final maxDecimals = _byMoney ? 2 : 3;
      if (_rawInput.contains('.')) {
        final decimals = _rawInput.split('.')[1];
        if (decimals.length >= maxDecimals) return;
      }
      if (_rawInput == '0' && key != '.') {
        _rawInput = key;
      } else if (_rawInput.length < 8) {
        _rawInput += key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final shortcuts = _byMoney
        ? [('10', '\$10'), ('20', '\$20'), ('50', '\$50'), ('100', '\$100')]
        : [('0.25', '¼ kg'), ('0.5', '½ kg'), ('1', '1 kg'), ('2', '2 kg')];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.ink),
                    ),
                    Text(
                      '${MoneyUtils.formatCents(widget.product.priceCents)} por kg',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.accentDark),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 26),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Por peso (kg)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  selected: !_byMoney,
                  onSelected: (_) => _switchMode(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Por dinero (\$)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  selected: _byMoney,
                  onSelected: (_) => _switchMode(true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: c.canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.line),
            ),
            child: Column(
              children: [
                Text(
                  _byMoney ? '¿Cuánto dinero quiere el cliente?' : '¿Cuántos kilos?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted),
                ),
                Text(
                  _byMoney
                      ? '\$${_rawInput.isEmpty ? '0' : _rawInput}'
                      : '${_rawInput.isEmpty ? '0' : _rawInput} kg',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: c.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _byMoney
                      ? 'Equivale a ${_weightKg.toStringAsFixed(3)} kg'
                      : 'Total: ${MoneyUtils.formatCents(_totalCents)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.brand),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Row(
            children: shortcuts.map((s) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => setState(() => _rawInput = s.$1),
                    child: Text(s.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'DEL'].map((k) {
              final isDel = k == 'DEL';
              return InkWell(
                onTap: () => _onKeyTap(k),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDel ? c.dangerSoft : c.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.line),
                  ),
                  child: Center(
                    child: isDel
                        ? Icon(Icons.backspace_outlined, color: c.danger, size: 22)
                        : Text(
                            k,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: c.ink,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 58,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.brand,
                foregroundColor: c.onBrand,
                disabledBackgroundColor: c.brandDisabled,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _weightKg > 0 ? () => Navigator.pop(context, _weightKg) : null,
              child: Text(
                widget.initialWeightKg != null ? 'Guardar cambio' : 'Agregar a la venta',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.scale_rounded, size: 15, color: c.faint),
              const SizedBox(width: 6),
              Text(
                'Próximamente: conectar báscula',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.faint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}