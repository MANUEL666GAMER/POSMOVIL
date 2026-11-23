import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
//import '../../../../shared/widgets/confirm_dialog.dart'; // Si no lo tienes, puedes sustituir por un AlertDialog normal
import '../../../../shared/widgets/permission_gate.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/products_repository.dart';
import '../providers/products_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product; // Si es nulo, estamos creando uno nuevo
  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _barcodeController;
  late TextEditingController _priceController;
  
  String _saleType = 'unit'; // 'unit' o 'weight'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    
    // Convertimos de centavos a texto normal para editar (ej. 1550 -> "15.5")
    final initialPrice = widget.product != null 
        ? (widget.product!.priceCents / 100).toString()
        : '';
    _priceController = TextEditingController(text: initialPrice);
    
    if (widget.product != null) {
      _saleType = widget.product!.saleType;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final priceCents = MoneyUtils.parseToCents(_priceController.text);
      
      await ref.read(productsRepositoryProvider).saveProduct(
        id: widget.product?.id,
        name: _nameController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        saleType: _saleType,
        priceCents: priceCents,
      );
      
      if (!mounted) return;
      ref.invalidate(productsListProvider); // Refresca la lista
      Navigator.of(context).pop(); // Cierra el formulario
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text('¿Estás seguro de que deseas eliminar este producto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(productsRepositoryProvider).deleteProduct(widget.product!.id);
      ref.invalidate(productsListProvider);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    final currentUser = ref.watch(authStateProvider);
    final userRole = currentUser != null ? AppRole.fromString(currentUser.role) : AppRole.cashier;
    
    // Regla de negocio: El cajero solo puede ver, no editar (esto debería bloquearse desde la lista, pero por seguridad lo bloqueamos aquí).
    final canEdit = PermissionService.can(userRole, AppPermission.manageProducts);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
        actions: [
          if (isEditing && canEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AppTextField(
              label: 'Nombre del producto',
              controller: _nameController,
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            AppTextField(
              label: 'Código de barras (opcional)',
              controller: _barcodeController,
              keyboardType: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Precio',
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.attach_money,
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _saleType,
                    decoration: InputDecoration(
                      labelText: 'Se vende por',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'unit', child: Text('Pieza')),
                      DropdownMenuItem(value: 'weight', child: Text('Peso (kg/gramos)')),
                    ],
                    onChanged: canEdit ? (val) {
                      if (val != null) setState(() => _saleType = val);
                    } : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            PermissionGate(
              currentRole: userRole,
              requiredPermission: AppPermission.manageProducts,
              fallback: const Center(child: Text('Solo los administradores pueden modificar productos.')),
              child: AppButton(
                label: 'Guardar Producto',
                isLoading: _isLoading,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}