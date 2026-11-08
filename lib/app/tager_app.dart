import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/ads/banner_ad_slot.dart';
import '../core/formatters.dart';
import '../features/inventory/presentation/inventory_page.dart';
import '../features/products/presentation/deleted_products_page.dart';
import '../features/products/data/products_repository.dart';
import '../features/products/domain/product.dart';
import '../features/products/presentation/products_page.dart';
import '../features/sales/data/sales_repository.dart';
import '../features/purchases/data/purchases_repository.dart';
import '../features/purchases/presentation/purchase_invoice_sheet.dart';
import '../features/debts/presentation/debts_page.dart';

import '../features/expenses/data/expenses_repository.dart';
import '../features/expenses/presentation/expenses_page.dart';

import '../features/backup/data/database_backup_repository.dart';
import '../features/backup/presentation/backup_page.dart';
import '../features/scanner/presentation/barcode_scanner_page.dart';
import '../features/scanner/presentation/product_code_binding_sheet.dart';
import '../features/analytics/data/report_repository.dart';
import '../features/analytics/presentation/analytics_page.dart';
import '../features/analytics/presentation/analysis_overview_page.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/notes/presentation/notes_page.dart';
import '../features/calculator/presentation/calculator_page.dart';
import '../features/contact/presentation/contact_page.dart';
import '../features/settings/data/app_settings_repository.dart';

class TagerApp extends StatefulWidget {
  const TagerApp({
    super.key,
    required this.productsRepository,
    required this.salesRepository,
    required this.purchasesRepository,
    required this.expensesRepository,
    required this.backupRepository,
    required this.reportRepository,
    required this.notesRepository,
    required this.settingsRepository,
  });

  final ProductsRepository productsRepository;
  final SalesRepository salesRepository;
  final PurchasesRepository purchasesRepository;
  final ExpensesRepository expensesRepository;
  final DatabaseBackupRepository backupRepository;
  final ReportRepository reportRepository;
  final NotesRepository notesRepository;
  final AppSettingsRepository settingsRepository;

  @override
  State<TagerApp> createState() => _TagerAppState();
}

class _TagerAppState extends State<TagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _themeLoaded = false;

  @override
  void initState() {
    super.initState();
    _restoreThemeMode();
  }

  Future<void> _restoreThemeMode() async {
    try {
      final isDark = await widget.settingsRepository.loadDarkTheme();
      if (!mounted) return;
      setState(() {
        _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        _themeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _themeLoaded = true);
    }
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    await widget.settingsRepository.saveDarkTheme(mode == ThemeMode.dark);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تاجر ٢',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: MainShell(
        productsRepository: widget.productsRepository,
        salesRepository: widget.salesRepository,
        purchasesRepository: widget.purchasesRepository,
        expensesRepository: widget.expensesRepository,
        backupRepository: widget.backupRepository,
        reportRepository: widget.reportRepository,
        notesRepository: widget.notesRepository,
        themeLoaded: _themeLoaded,
        themeMode: _themeMode,
        onThemeModeChanged: _saveThemeMode,
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const blue = Color(0xFF1859A9);
    const darkBlue = Color(0xFF5A9CEE);
    const silver = Color(0xFF98A6B5);
    const lightBackground = Color(0xFFF3F6F9);
    const darkBackground = Color(0xFF05070A);
    const darkSurface = Color(0xFF11161D);
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: isDark ? darkBlue : blue,
      brightness: brightness,
      surface: isDark ? darkSurface : Colors.white,
    );
    final scheme = baseScheme.copyWith(
      primary: isDark ? darkBlue : blue,
      secondary: silver,
      surface: isDark ? darkSurface : Colors.white,
      outline: isDark ? const Color(0xFF34404D) : const Color(0xFFDCE3EA),
    );

    return ThemeData(
      fontFamily: 'TagerArabic',
      fontFamilyFallback: const ['TagerLatin'],
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkBackground : lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBackground : lightBackground,
        foregroundColor: isDark
            ? const Color(0xFFE8EDF3)
            : const Color(0xFF17212D),
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: isDark ? darkSurface : Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline, width: 0.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurface : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.productsRepository,
    required this.salesRepository,
    required this.purchasesRepository,
    required this.expensesRepository,
    required this.backupRepository,
    required this.reportRepository,
    required this.notesRepository,
    required this.themeMode,
    this.themeLoaded = true,
    required this.onThemeModeChanged,
    this.initialInvoiceImportText,
  });

  final ProductsRepository productsRepository;
  final SalesRepository salesRepository;
  final PurchasesRepository purchasesRepository;
  final ExpensesRepository expensesRepository;
  final DatabaseBackupRepository backupRepository;
  final ReportRepository reportRepository;
  final NotesRepository notesRepository;
  final ThemeMode themeMode;
  final bool themeLoaded;
  final FutureOr<void> Function(ThemeMode) onThemeModeChanged;
  final String? initialInvoiceImportText;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _refreshToken = 0;
  static const _bannerPageIndexes = <int>{0, 7, 9, 10, 11};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ProductsPageState> _productsPageKey =
      GlobalKey<ProductsPageState>();

  static const _titles = [
    'الرئيسية',
    'المصروفات',
    'ديون الموردين',
    'ديون العملاء',
    'التقارير',
    'الأصناف المحذوفة',
    'دفتر الملاحظات',
    'الآلة الحاسبة',
    'التحليل',
    'اتصل بنا',
    'الأصناف الناقصة',
    'على وشك النفاد',
    'النسخ الاحتياطي',
  ];

  void _refreshData() => setState(() => _refreshToken++);

  Future<void> _scanProductCode() async {
    final scannedCode = await Navigator.of(context).push<ScannedProductCode>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (scannedCode == null || !mounted) return;

    final ProductCodeMatch? match;
    try {
      match = await widget.productsRepository.findProductByCode(
        scannedCode.value,
      );
    } catch (_) {
      if (mounted) _showMessage('تعذر البحث عن هذا الكود في قاعدة البيانات.');
      return;
    }
    if (!mounted) return;

    if (match == null) {
      final linkedProduct = await showModalBottomSheet<Product>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.84,
          child: ProductCodeBindingSheet(
            repository: widget.productsRepository,
            code: scannedCode.value,
            codeType: scannedCode.type,
          ),
        ),
      );
      if (linkedProduct == null || !mounted) return;
      _refreshData();
      final quantity = await _confirmScannedProduct(linkedProduct);
      if (quantity != null && mounted) {
        await _addScannedProductToSale(linkedProduct, quantity: quantity);
      }
      return;
    }

    if (match.isDeleted) {
      final deletedProduct = match.product;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(deletedProduct.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سعر البيع: ${formatMoneyMinor(deletedProduct.salePriceMinor)}',
              ),
              const SizedBox(height: 8),
              const Text('هذا المنتج محذوف ولا يمكن إضافته إلى فاتورة البيع.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
      return;
    }

    final product = match.product;
    final quantity = await _confirmScannedProduct(product);
    if (quantity != null && mounted) {
      await _addScannedProductToSale(product, quantity: quantity);
    }
  }

  Future<double?> _confirmScannedProduct(Product product) async {
    final controller = TextEditingController(
      text: formatQuantity(product.stockOnHand < 1 ? product.stockOnHand : 1),
    );
    String? error;
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سعر البيع: ${formatMoneyMinor(product.salePriceMinor)}'),
              const SizedBox(height: 6),
              Text('المخزون المتاح: ${formatQuantity(product.stockOnHand)}'),
              if (product.stockOnHand > 0) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'كمية البيع',
                    helperText: 'حتى ثلاث خانات عشرية.',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                const Text('الرصيد صفر؛ لا يمكن إضافته إلى فاتورة بيع.'),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(product.stockOnHand > 0 ? 'إلغاء' : 'تمام'),
            ),
            if (product.stockOnHand > 0)
              FilledButton.icon(
                onPressed: () {
                  final value = parseQuantity(controller.text);
                  if (value == null || value <= 0) {
                    setDialogState(() => error = 'أدخل كمية أكبر من صفر.');
                    return;
                  }
                  if (value > product.stockOnHand + 0.0000001) {
                    setDialogState(
                      () => error =
                          'المتاح هو ${formatQuantity(product.stockOnHand)} فقط.',
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: const Text('إضافة إلى الفاتورة'),
              ),
          ],
        ),
      ),
    );
    controller.dispose();
    return quantity;
  }

  Future<void> _addScannedProductToSale(
    Product product, {
    required double quantity,
  }) async {
    setState(() => _selectedIndex = 0);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final productsPage = _productsPageKey.currentState;
    if (productsPage == null) {
      _showMessage('تعذر فتح سلة البيع؛ أعد المسح وحاول مرة أخرى.');
      return;
    }
    productsPage.addScannedProduct(product, quantity: quantity);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPurchaseInvoice() async {
    final receipt = await showModalBottomSheet<PurchaseReceipt>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.95,
        child: PurchaseInvoiceSheet(
          productsRepository: widget.productsRepository,
          purchasesRepository: widget.purchasesRepository,
          initialImportText: widget.initialInvoiceImportText,
        ),
      ),
    );
    if (receipt == null || !mounted) return;
    _refreshData();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ ${receipt.invoiceNumber} بإجمالي '
            '${receipt.totalMinor ~/ 100}.${(receipt.totalMinor % 100).toString().padLeft(2, '0')} ج.م.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_selectedIndex) {
      0 => ProductsPage(
        key: _productsPageKey,
        refreshToken: _refreshToken,
        repository: widget.productsRepository,
        salesRepository: widget.salesRepository,
        onDataChanged: _refreshData,
        onAddProduct: _openPurchaseInvoice,
        onOpenMissing: () => setState(() => _selectedIndex = 10),
        onOpenLowStock: () => setState(() => _selectedIndex = 11),
      ),
      1 => ExpensesPage(
        key: ValueKey('expenses-$_refreshToken'),
        repository: widget.expensesRepository,
      ),
      2 => DebtsPage(
        key: ValueKey('supplier-debts-$_refreshToken'),
        kind: DebtKind.suppliers,
        salesRepository: widget.salesRepository,
        purchasesRepository: widget.purchasesRepository,
      ),
      3 => DebtsPage(
        key: ValueKey('customer-debts-$_refreshToken'),
        kind: DebtKind.customers,
        salesRepository: widget.salesRepository,
        purchasesRepository: widget.purchasesRepository,
      ),
      4 => AnalyticsPage(
        key: ValueKey('reports-$_refreshToken'),
        repository: widget.reportRepository,
      ),
      5 => DeletedProductsPage(
        key: ValueKey('deleted-$_refreshToken'),
        repository: widget.productsRepository,
      ),
      6 => NotesPage(
        key: ValueKey('notes-$_refreshToken'),
        repository: widget.notesRepository,
      ),
      7 => const CalculatorPage(),
      8 => AnalysisOverviewPage(
        key: ValueKey('analysis-$_refreshToken'),
        reportRepository: widget.reportRepository,
        productsRepository: widget.productsRepository,
        salesRepository: widget.salesRepository,
        purchasesRepository: widget.purchasesRepository,
      ),
      9 => const ContactPage(),
      10 => InventoryPage(
        key: ValueKey('missing-$_refreshToken'),
        repository: widget.productsRepository,
        filter: ProductListFilter.missing,
      ),
      11 => InventoryPage(
        key: ValueKey('low-stock-$_refreshToken'),
        repository: widget.productsRepository,
        filter: ProductListFilter.lowStock,
      ),
      _ => BackupPage(
        key: ValueKey('backup-$_refreshToken'),
        repository: widget.backupRepository,
        onDataRestored: _refreshData,
      ),
    };

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/tager_logo.png',
              key: const ValueKey('tager-app-brand-logo'),
              width: 34,
              height: 34,
              fit: BoxFit.contain,
              semanticLabel: 'شعار Tager',
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _titles[_selectedIndex],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: IconButton(
              tooltip: 'مسح QR أو باركود',
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFE9DFC9),
                foregroundColor: const Color(0xFF554A34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _scanProductCode,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 18),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/tager_logo.png',
                        key: const ValueKey('tager-drawer-brand-logo'),
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        semanticLabel: 'شعار تاجر',
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'تاجر',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerDestination(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'الرئيسية',
                      selected: _selectedIndex == 0,
                      onTap: () => _selectPage(0),
                    ),
                    _DrawerDestination(
                      icon: Icons.payments_outlined,
                      selectedIcon: Icons.payments_rounded,
                      label: 'المصروفات',
                      selected: _selectedIndex == 1,
                      onTap: () => _selectPage(1),
                    ),
                    _DrawerDestination(
                      icon: Icons.storefront_outlined,
                      selectedIcon: Icons.storefront_rounded,
                      label: 'ديون الموردين',
                      selected: _selectedIndex == 2,
                      onTap: () => _selectPage(2),
                    ),
                    _DrawerDestination(
                      icon: Icons.people_alt_outlined,
                      selectedIcon: Icons.people_alt_rounded,
                      label: 'ديون العملاء',
                      selected: _selectedIndex == 3,
                      onTap: () => _selectPage(3),
                    ),
                    _DrawerDestination(
                      icon: Icons.description_outlined,
                      selectedIcon: Icons.description_rounded,
                      label: 'التقارير',
                      selected: _selectedIndex == 4,
                      onTap: () => _selectPage(4),
                    ),
                    _DrawerDestination(
                      icon: Icons.analytics_outlined,
                      selectedIcon: Icons.analytics_rounded,
                      label: 'التحليل',
                      selected: _selectedIndex == 8,
                      onTap: () => _selectPage(8),
                    ),
                    _DrawerDestination(
                      icon: Icons.delete_outline_rounded,
                      selectedIcon: Icons.delete_rounded,
                      label: 'الأصناف المحذوفة',
                      selected: _selectedIndex == 5,
                      onTap: () => _selectPage(5),
                    ),
                    _DrawerDestination(
                      icon: Icons.sticky_note_2_outlined,
                      selectedIcon: Icons.sticky_note_2_rounded,
                      label: 'دفتر الملاحظات',
                      selected: _selectedIndex == 6,
                      onTap: () => _selectPage(6),
                    ),
                    _DrawerDestination(
                      icon: Icons.calculate_outlined,
                      selectedIcon: Icons.calculate_rounded,
                      label: 'الآلة الحاسبة',
                      selected: _selectedIndex == 7,
                      onTap: () => _selectPage(7),
                    ),
                    _DrawerDestination(
                      icon: Icons.support_agent_outlined,
                      selectedIcon: Icons.support_agent_rounded,
                      label: 'اتصل بنا',
                      selected: _selectedIndex == 9,
                      onTap: () => _selectPage(9),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('النسخ الاحتياطي'),
                      selected: _selectedIndex == 12,
                      onTap: () => _selectPage(12),
                    ),
                    const Divider(height: 1),
                    SwitchListTile.adaptive(
                      secondary: Icon(
                        widget.themeMode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                      title: Text(
                        widget.themeMode == ThemeMode.dark
                            ? 'الوضع الداكن'
                            : 'الوضع الفاتح',
                      ),
                      value: widget.themeMode == ThemeMode.dark,
                      onChanged: widget.themeLoaded
                          ? (isDark) async {
                              try {
                                await widget.onThemeModeChanged(
                                  isDark ? ThemeMode.dark : ThemeMode.light,
                                );
                              } catch (_) {
                                if (mounted) {
                                  _showMessage('تعذر حفظ إعداد الوضع اللوني.');
                                }
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: page),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'open-main-menu',
                tooltip: 'فتح القائمة',
                backgroundColor: const Color(0xFFE5B94D),
                foregroundColor: const Color(0xFF231D0D),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                child: const Icon(Icons.menu_rounded),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bannerPageIndexes.contains(_selectedIndex)
          ? const BannerAdSlot()
          : null,
    );
  }

  void _selectPage(int index) {
    Navigator.of(context).pop();
    setState(() => _selectedIndex = index);
  }
}

class _DrawerDestination extends StatelessWidget {
  const _DrawerDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 2, 8, 2),
      child: ListTile(
        selected: selected,
        leading: Icon(selected ? selectedIcon : icon),
        title: Text(label),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
