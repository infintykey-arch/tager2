# فهرس ميزة المنتجات

**المجلد:** `lib/features/products/`

**الدور:** إدارة بيانات المنتجات والبحث والأرشفة وأكوادها، وعرض القائمة والتفاصيل وإجراءات المخزون والبيع السريع.

## الملفات

- [`data/products_repository.dart`](data/products_repository.dart) — عمليات المنتجات ومخزونها والبحث والتصفية والترقيم وأكواد المنتجات عبر Drift.
- [`domain/product.dart`](domain/product.dart) — نماذج المنتج والفلترة ومطابقة الأكواد وحركة المخزون.
- [`domain/product_search.dart`](domain/product_search.dart) — وظائف/أنواع مساعدة للبحث في أسماء المنتجات.
- [`presentation/products_page.dart`](presentation/products_page.dart) — قائمة المنتجات، الإجراءات، التفاصيل، وربط المنتج بإنشاء فاتورة بيع.
- [`presentation/product_form_sheet.dart`](presentation/product_form_sheet.dart) — نموذج إضافة المنتج أو تعديل بياناته.
- [`presentation/deleted_products_page.dart`](presentation/deleted_products_page.dart) — عرض المنتجات المحذوفة/المؤرشفة والتفاصيل المرتبطة بها.
- [`presentation/stock_adjustment_dialog.dart`](presentation/stock_adjustment_dialog.dart) — إدخال تسوية مخزون والتحقق من بياناتها.

## من أين أبدأ التعديل؟

- تغيير الشاشة أو التفاعل: ابدأ من مجلد `presentation/` في هذه الوحدة.
- تغيير نموذج أو قاعدة عمل: ابدأ من مجلد `domain/` في هذه الوحدة.
- تغيير القراءة أو الكتابة أو تكامل المنصة: ابدأ من مجلد `data/` في هذه الوحدة.

قبل التعديل، راجع الاختبارات المرتبطة بالميزة في [`test/features/`](../../../test/features/) ثم أضف/حدّث اختبارًا للسلوك الذي تغيّر.
