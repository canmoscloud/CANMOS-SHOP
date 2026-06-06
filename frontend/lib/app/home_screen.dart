import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_theme.dart';
import '../features/pdv/pdv_screen.dart';
import '../features/products/products_screen.dart';
import '../features/cashier/cashier_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    PdvScreen(),
    ProductsScreen(),
    CashierScreen(),
    ReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'PDV'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Produtos'),
          NavigationDestination(icon: Icon(Icons.monetization_on), label: 'Caixa'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Relatórios'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
