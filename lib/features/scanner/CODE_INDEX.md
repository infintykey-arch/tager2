# فهرس ميزة الماسح وربط الأكواد

**المجلد:** `lib/features/scanner/`

**الدور:** مسح باركود المنتج ثم ربط الرمز بمنتج موجود واستخدامه من مسارات التطبيق.

## الملفات

- [`presentation/barcode_scanner_page.dart`](presentation/barcode_scanner_page.dart) — فتح الكاميرا ومسح الباركود وإرجاع الرمز المقروء.
- [`presentation/product_code_binding_sheet.dart`](presentation/product_code_binding_sheet.dart) — البحث عن منتج وربط رمز ممسوح به عبر مستودع المنتجات.

## من أين أبدأ التعديل؟

- تغيير الشاشة أو التفاعل: ابدأ من مجلد `presentation/` في هذه الوحدة.

قبل التعديل، راجع الاختبارات المرتبطة بالميزة في [`test/features/`](../../../test/features/) ثم أضف/حدّث اختبارًا للسلوك الذي تغيّر.
