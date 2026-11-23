import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// En los próximos pasos crearemos esta pantalla
import '../../shared/widgets/widget_gallery_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PlaceholderScreen(title: 'Inicio - POS Fácil'),
    ),
    // Aquí agregaremos la galería de widgets para debuguear:
    // GoRoute(
    //   path: '/gallery',
    //   builder: (context, state) => const WidgetGalleryScreen(),
    // ),
  ],
);

// TODO: Eliminar cuando tengamos la WidgetGalleryScreen o el Home
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Text('Preparando Base de Proyecto...'),
      ),
    );
  }
}