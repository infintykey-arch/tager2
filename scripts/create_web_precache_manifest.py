#!/usr/bin/env python3
"""Generate the local-only PWA precache list after `flutter build web`."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web").resolve()
    if not (web_dir / "index.html").is_file():
        raise SystemExit(f"Web build not found: {web_dir}")

    required = [
        "index.html",
        "flutter_bootstrap.js",
        "main.dart.js",
        "pdfjs/pdf.mjs",
        "pdfjs/pdf.worker.mjs",
        "tager2_ocr.js",
        "tager2_pdf_ocr.mjs",
        "tesseract/tesseract.min.js",
        "tesseract/worker.min.js",
        "tesseract/tesseract-core.wasm",
        "zxing-wasm/index.js",
        "sqlite3.wasm",
    ]
    missing = [name for name in required if not (web_dir / name).is_file()]
    if missing:
        raise SystemExit("Required local Web assets are missing: " + ", ".join(missing))

    canvaskit_js = list(web_dir.rglob("canvaskit.js"))
    canvaskit_wasm = [
        path for path in web_dir.rglob("*.wasm") if "canvaskit" in path.parts
    ]
    if not canvaskit_js or not canvaskit_wasm:
        raise SystemExit("Local CanvasKit JavaScript/WebAssembly assets are missing.")

    # Cache every built file except source maps and service-worker metadata.
    # This includes nested OCR models, PDF.js CMaps, scanner libraries, SQLite,
    # Flutter assets/fonts, and the local CanvasKit runtime.
    excluded = {
        "tager2-service-worker.js",
        "flutter_service_worker.js",
        "precache-manifest.json",
    }
    files = sorted(
        path.relative_to(web_dir).as_posix()
        for path in web_dir.rglob("*")
        if path.is_file()
        and path.name not in excluded
        and path.suffix != ".map"
    )

    manifest = web_dir / "precache-manifest.json"
    manifest.write_text(json.dumps(files, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total_bytes = sum((web_dir / name).stat().st_size for name in files)
    print(f"Precache manifest: {manifest}")
    print(f"Files: {len(files)}; total: {total_bytes / (1024 * 1024):.1f} MiB")
    print("Includes local OCR, PDF.js, SQLite, scanner and CanvasKit assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
