import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/activity_screen.dart';
import 'screens/allocation_plans_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pockets_screen.dart';
import 'screens/profile_screen.dart';

class PusaApp extends StatelessWidget {
  const PusaApp({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF101B2D);
    const green = Color(0xFFB8F36B);
    return MaterialApp(
      title: 'Pusa — Financial Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
        colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light, surface: const Color(0xFFF6F8F4)),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF6F8F4), foregroundColor: ink, elevation: 0, centerTitle: false),
        fontFamily: 'Roboto',
      ),
      home: backendConfigured ? const _AuthGate() : const PusaShell(backendConfigured: false),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _passwordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;
      if (state.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _passwordRecovery = true);
      } else if (state.event == AuthChangeEvent.signedOut) {
        setState(() => _passwordRecovery = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (_passwordRecovery) {
      return const AuthScreen(passwordRecovery: true);
    }
    if (session == null) return const AuthScreen();
    return const PusaShell(backendConfigured: true);
  }
}

class PusaShell extends StatefulWidget {
  const PusaShell({super.key, required this.backendConfigured});
  final bool backendConfigured;
  @override
  State<PusaShell> createState() => _PusaShellState();
}

class _PusaShellState extends State<PusaShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(backendConfigured: widget.backendConfigured),
      PocketsScreen(backendConfigured: widget.backendConfigured),
      AllocationPlansScreen(backendConfigured: widget.backendConfigured),
      ActivityScreen(backendConfigured: widget.backendConfigured),
      ProfileScreen(backendConfigured: widget.backendConfigured),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Pockets'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline_rounded), label: 'Plans'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
