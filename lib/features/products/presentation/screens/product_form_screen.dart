import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/pos_colors.dart';
import '../../../../core/utils/money.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../inventory/presentation/screens/inventory_screen.dart';
import '../../../sales/presentation/screens/scanner_screen.dart';
import '../../data/products_repository.dart';
import '../providers/products_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const ProductFormScreen({
    super.key,
    this.product,
    this.initialBarcode,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _initialStockCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();

  String _saleType = 'unit'; // 'unit' o 'weight'
  String _selectedCategory = 'Abarrotes';
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _saleType = p.saleType;
      _priceCtrl.text = (p.priceCents / 100).toStringAsFixed(2);
      if (p.costCents != null) {
        _costCtrl.text = (p.costCents! / 100).toStringAsFixed(2);
      }
      if (p.barcode != null) {
        _barcodeCtrl.text = p.barcode!;
      }
      final minVal = p.saleType == 'weight' ? (p.minStock / 1000) : p.minStock;
      _minStockCtrl.text = minVal.toString();
    } else if (widget.initialBarcode != null) {
      _barcodeCtrl.text = widget.initialBarcode!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _barcodeCtrl.dispose();
    _initialStockCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  int _parseQuantity(String raw, bool isWeight) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0.0;
    if (parsed <= 0) return 0;
    return isWeight ? (parsed * 1000).round() : parsed.round();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen(captureOnly: true)),
    );
    if (code is String && code.isNotEmpty) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _save() async {
    final c = context.pos;
    final name = _nameCtrl.text.trim();
    final priceCents = MoneyUtils.parseToCents(_priceCtrl.text);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Escribe el nombre del producto'), backgroundColor: c.danger),
      );
      return;
    }
   if (priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(r'El precio debe ser mayor a $0.00'),
          backgroundColor: c.danger,
        ),
      );
      return;
    }

    final costCents = _costCtrl.text.trim().isEmpty
        ? null
        : MoneyUtils.parseToCents(_costCtrl.text);
    final barcode = _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim();
    final isWeight = _saleType == 'weight';
    final minStock = _parseQuantity(_minStockCtrl.text, isWeight);
    final initialStock = _parseQuantity(_initialStockCtrl.text, isWeight);

    final user = ref.read(authStateProvider);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      if (_isEditing) {
        await repo.updateProduct(
          id: widget.product!.id,
          name: name,
          saleType: _saleType,
          priceCents: priceCents,
          costCents: costCents,
          barcode: barcode,
          minStock: minStock,
        );
      } else {
        await repo.createProduct(
          name: name,
          saleType: _saleType,
          priceCents: priceCents,
          costCents: costCents,
          barcode: barcode,
          minStock: minStock,
          initialStock: initialStock,
          userId: user.id,
        );
      }

      ref.invalidate(productsListProvider);
      ref.invalidate(inventoryListProvider);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar "${widget.product!.name}"?'),
        content: const Text('Ya no aparecerá para vender. Las ventas pasadas se conservan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No, regresar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.pos.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await ref.read(productsRepositoryProvider).deleteProduct(widget.product!.id);
    ref.invalidate(productsListProvider);
    ref.invalidate(inventoryListProvider);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    final isWeight = _saleType == 'weight';
    final unitLabel = isWeight ? 'kg' : 'piezas';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(_isEditing ? 'Editar producto' : 'Agregar producto'),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: c.card,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 60),
                    backgroundColor: c.brand,
                    foregroundColor: c.onBrand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: Text(
                    _isSaving ? 'Guardando...' : 'Guardar',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Nombre del producto
              _FormCard(
                title: 'Nombre del producto',
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Ej. Papaya',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. ¿Cómo se vende?
              _FormCard(
                title: '¿Cómo se vende?',
                child: Row(
                  children: [
                    Expanded(
                      child: _SelectOptionButton(
                        label: 'Por pieza',
                        selected: !isWeight,
                        onTap: () => setState(() => _saleType = 'unit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SelectOptionButton(
                        label: 'Por kilo',
                        selected: isWeight,
                        onTap: () => setState(() => _saleType = 'weight'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 3. Precio de venta y Costo (opcional)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FormCard(
                      title: isWeight ? 'Precio por kilo' : 'Precio de venta por pieza',
                      child: TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: '0.00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormCard(
                      title: 'Costo (opcional)',
                      subtitle: 'Lo que te cuesta a ti. Solo lo ve el administrador.',
                      child: TextField(
                        controller: _costCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          hintText: '0.00',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 4. Categoría
              _FormCard(
                title: 'Categoría',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Frutas', 'Verduras', 'Abarrotes', 'Bebidas'].map((cat) {
                    final selected = _selectedCategory == cat;
                    return InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? c.brandSoft : c.canvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? c.brand : c.line,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: selected ? c.brandDark : c.ink,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // 5. Código de barras + Escanear
              _FormCard(
                title: 'Código de barras',
                subtitle: 'Opcional. Para cobrar más rápido con la cámara.',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Sin código',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        backgroundColor: c.brandSoft,
                        foregroundColor: c.brandDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _scanBarcode,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Escanear', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 6. Existencia inicial (solo al crear) y Stock mínimo
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditing) ...[
                    Expanded(
                      child: _FormCard(
                        title: 'Existencia inicial ($unitLabel)',
                        child: TextField(
                          controller: _initialStockCtrl,
                          keyboardType: TextInputType.numberWithOptions(decimal: isWeight),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                          decoration: InputDecoration(
                            hintText: '0',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _FormCard(
                      title: 'Avisarme cuando queden menos de',
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minStockCtrl,
                              keyboardType: TextInputType.numberWithOptions(decimal: isWeight),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                              decoration: InputDecoration(
                                hintText: '0',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(unitLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // 7. Eliminar producto (solo al editar)
              if (_isEditing) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _deleteProduct,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Eliminar producto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _FormCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: c.cardBorder ?? Border.all(color: c.line),
        boxShadow: c.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.ink)),
          const SizedBox(height: 10),
          child,
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

class _SelectOptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectOptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.brandSoft : c.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.brand : c.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: selected ? c.brandDark : c.ink,
          ),
        ),
      ),
    );
  }
}