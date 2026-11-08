(function () {
  window._extractText = async function (imagePath, mapData) {
    const request = mapData || {};
    const language = request.language || "ara+eng";
    const base = new URL("tesseract/", document.baseURI);
    const worker = await Tesseract.createWorker({
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
})();
