import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/more/presentation/more_page.dart';
import '../features/products/data/products_repository.dart';
import '../features/products/presentation/products_page.dart';

class TagerApp extends StatelessWidget {
  const TagerApp({super.key, required this.productsRepository});

  final ProductsRepository productsRepository;

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF176B5B);

    return MaterialApp(
      title: 'تاجر ٢',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          surface: const Color(0xFFF8FAF9),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAF9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAF9),
          foregroundColor: Color(0xFF173A33),
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE8EEEB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE6E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDE6E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: brand, width: 1.5),
          ),
        ),
      ),
      home: MainShell(productsRepository: productsRepository),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.productsRepository});

  final ProductsRepository productsRepository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _refreshToken = 0;

  static const _titles = ['الرئيسية', 'المنتجات', 'المخزون', 'المزيد'];

  void _refreshData() => setState(() => _refreshToken++);

  @override
  Widget build(BuildContext context) {
    final page = switch (_selectedIndex) {
      0 => DashboardPage(
        key: ValueKey('dashboard-$_refreshToken'),
        repository: widget.productsRepository,
        onOpenProducts: () => setState(() => _selectedIndex = 1),
      ),
      1 => ProductsPage(
        key: const ValueKey('products'),
        repository: widget.productsRepository,
        onDataChanged: _refreshData,
      ),
      2 => InventoryPage(
        key: ValueKey('inventory-$_refreshToken'),
        repository: widget.productsRepository,
      ),
      _ => const MorePage(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE4F1EC),
              child: Icon(Icons.storefront_rounded, color: Color(0xFF176B5B)),
            ),
          ),
        ],
      ),
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'المنتجات',
          ),
          NavigationDestination(
            icon: Icon(Icons.warehouse_outlined),
            selectedIcon: Icon(Icons.warehouse_rounded),
            label: 'المخزون',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'المزيد',
          ),
        ],
      ),
    );
  }
}
