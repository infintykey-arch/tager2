(function () {
  const scriptLoads = new Map();
  let pdfModulePromise;
  let paddleModulePromise;

  function loadScript(relativePath) {
    if (relativePath === "tesseract/tesseract.min.js" && window.Tesseract) {
      return Promise.resolve();
    }
    const url = new URL(relativePath, document.baseURI).href;
    if (scriptLoads.has(url)) return scriptLoads.get(url);

    const promise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = url;
      script.async = true;
      script.onload = resolve;
      script.onerror = () => reject(new Error("تعذر تحميل مورد OCR المحلي."));
      document.head.appendChild(script);
    }).catch((error) => {
      scriptLoads.delete(url);
      throw error;
    });
    scriptLoads.set(url, promise);
    return promise;
  }

  function loadPdfModule() {
    if (!pdfModulePromise) {
      const url = new URL("tager2_pdf_ocr.mjs", document.baseURI).href;
      pdfModulePromise = import(url).catch((error) => {
        pdfModulePromise = null;
        throw error;
      });
    }
    return pdfModulePromise;
  }

  function loadPaddleModule() {
    if (!paddleModulePromise) {
      const url = new URL("paddleocr/tager2_paddle_ocr.mjs", document.baseURI).href;
      paddleModulePromise = import(url).catch((error) => {
        paddleModulePromise = null;
        throw error;
      });
    }
    return paddleModulePromise;
  }

  window._extractText = async function (imagePath, mapData) {
    await loadScript("tesseract/tesseract.min.js");
    const request = mapData || {};
    const language = request.language || "ara+eng";
    const base = new URL("tesseract/", document.baseURI);
    const worker = await window.Tesseract.createWorker({
      workerPath: new URL("worker.min.js", base).href,
      corePath: new URL("tesseract-core.wasm.js", base).href,
      langPath: new URL("tessdata/", base).href,
      gzip: true,
      workerBlobURL: false,
    });

    try {
      await worker.loadLanguage(language);
      await worker.initialize(language);
      await worker.setParameters(request.args || {});
      const result = await worker.recognize(imagePath);
      return request.args && request.args.tessjs_create_hocr
        ? result.data.hocr
        : result.data.text;
    } finally {
      await worker.terminate();
    }
  };

  window._extractPdfText = async function (pdfBase64, request) {
    await loadScript("tesseract/tesseract.min.js");
    const module = await loadPdfModule();
    return module.extractPdfText(pdfBase64, request || {});
  };

  const lazyPaddleExtract = async function (imageDataUrl) {
    await loadPaddleModule();
    const extract = window._extractPaddleInvoiceText;
    if (extract === lazyPaddleExtract || typeof extract !== "function") {
      throw new Error("تعذر تهيئة محرك OCR المحلي.");
    }
    return extract(imageDataUrl);
  };
  window._extractPaddleInvoiceText = lazyPaddleExtract;
})();
