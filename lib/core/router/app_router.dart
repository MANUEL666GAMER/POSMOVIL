import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/sales/presentation/screens/home_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/cash_close/presentation/screens/cash_close_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/cash-close',
      builder: (context, state) => const CashCloseScreen(),
    ),
    GoRoute(
  path: '/inventory',
  builder: (context, state) => const InventoryScreen(),
),
    GoRoute(
  path: '/reports',
  builder: (context, state) => const ReportsScreen(),
),
    
  ],
);