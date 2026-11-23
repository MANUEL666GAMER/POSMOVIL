import 'package:flutter/material.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'numeric_keypad.dart';

class WidgetGalleryScreen extends StatelessWidget {
  const WidgetGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Galería de Widgets (Debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Botones', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AppButton(label: 'Primario', onPressed: () {}),
          const SizedBox(height: 8),
          AppButton(label: 'Secundario', variant: AppButtonVariant.secondary, onPressed: () {}),
          const SizedBox(height: 8),
          AppButton(label: 'Peligro', variant: AppButtonVariant.danger, onPressed: () {}),
          const SizedBox(height: 8),
          AppButton(label: 'Con ícono y Outline', icon: Icons.save, variant: AppButtonVariant.outline, onPressed: () {}),
          
          const Divider(height: 48),
          
          const Text('Campos de texto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const AppTextField(label: 'Nombre del producto', prefixIcon: Icons.shopping_bag),
          const AppTextField(label: 'Precio', prefixIcon: Icons.attach_money, keyboardType: TextInputType.number),
          
          const Divider(height: 48),
          
          const Text('Teclado Numérico', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          NumericKeypad(
            onNumberTapped: (val) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Presionado: $val'), duration: const Duration(milliseconds: 500)));
            },
            onBackspaceTapped: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Borrar'), duration: Duration(milliseconds: 500)));
            },
          ),
        ],
      ),
    );
  }
}