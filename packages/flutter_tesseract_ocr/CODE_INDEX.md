# فهرس إضافة OCR المحلية

**المجلد:** `packages/flutter_tesseract_ocr/` — إضافة Flutter محلية يستخدمها المشروع لربط OCR الأصلي والويب.

- [`pubspec.yaml`](pubspec.yaml) — تعريف الحزمة المحلية واعتمادياتها.
- [`lib/flutter_tesseract_ocr.dart`](lib/flutter_tesseract_ocr.dart) — واجهة الحزمة المشتركة.
- [`lib/android_ios.dart`](lib/android_ios.dart) — واجهة/تكامل المنصات الأصلية.
- [`lib/web.dart`](lib/web.dart) — واجهة تكامل الويب.
- `android/` — تنفيذ إضافة Android وملفات البناء/المكتبة المحلية المرفقة.
- [`LICENSE`](LICENSE) — ترخيص الحزمة.

إذا عدلت الجسر، راجع استخدامه في [`lib/features/ocr/`](../../lib/features/ocr/CODE_INDEX.md) وموارد [`web/`](../../web/CODE_INDEX.md) والاختبارات ذات الصلة. هذا مجلد حزمة؛ تحقّق من مصدر وترخيص أي مكتبة أو ملف ثنائي قبل استبداله.
