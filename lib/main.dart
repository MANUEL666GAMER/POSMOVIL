import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Aquí inicializaremos la BD Drift y otras dependencias locales antes de correr la app

  runApp(
    const ProviderScope(
      child: PosApp(),
    ),
  );
}