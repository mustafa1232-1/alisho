import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/admin_shell.dart';
import '../screens/auth_screen.dart';
import '../screens/customer_shell.dart';
import '../screens/delivery_shell.dart';
import 'auth_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) {
        return state.fullPath == '/splash' ? null : '/splash';
      }

      final isAuthRoute =
          state.fullPath == '/login' || state.fullPath == '/register';

      if (!authState.isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute || state.fullPath == '/splash') {
        return switch (authState.role) {
          'ADMIN' => '/admin',
          'DELIVERY' => '/delivery',
          _ => '/customer',
        };
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AuthScreen(isRegister: false),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const AuthScreen(isRegister: true),
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => const CustomerShell(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminShell(),
      ),
      GoRoute(
        path: '/delivery',
        builder: (context, state) => const DeliveryShell(),
      ),
    ],
  );
});
