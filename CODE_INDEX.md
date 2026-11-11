# فهرس الويب

**المجلد:** `web/` — نقطة تشغيل Flutter Web والموارد التي تتيح التثبيت/العمل دون اتصال وبعض تكاملات المتصفح.

- [`index.html`](index.html) — قاعدة الصفحة، تحميل جسور OCR/PDF/الباركود، وتسجيل عامل الخدمة.
- [`manifest.json`](manifest.json) و`icons/` — بيانات التطبيق القابل للتثبيت وأيقوناته.
- [`tager2-service-worker.js`](tager2-service-worker.js) — عامل الخدمة المخصص للعمل دون اتصال.
- [`flutter_bootstrap.js`](flutter_bootstrap.js) — بدء تحميل تطبيق Flutter على الويب.
- [`tager2_ocr.js`](tager2_ocr.js) و[`tager2_pdf_ocr.mjs`](tager2_pdf_ocr.mjs) — جسر المتصفح لخدمات OCR للصور وPDF.
- `tesseract/`, `pdfjs/`, و`zxing-wasm/` — ملفات تشغيل/بيانات مورّدة محليًا لمكتبات OCR وPDF والباركود؛ تعامل معها كموارد طرف ثالث، لا كمنطق ميزة Flutter.
- `drift_worker.js` و`sqlite3.wasm` — مكونات قاعدة بيانات الويب/عامل Drift.

بناء الويب المحلي يتم عبر [`../scripts/build_local_web.sh`](../scripts/build_local_web.sh)، ويستدعي تجهيز الموارد المسبقة.
