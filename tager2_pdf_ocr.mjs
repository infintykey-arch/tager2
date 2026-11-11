import { GlobalWorkerOptions, getDocument } from './pdfjs/pdf.mjs';

const pdfjsBase = new URL('./pdfjs/', import.meta.url);
const tesseractBase = new URL('tesseract/', document.baseURI);
GlobalWorkerOptions.workerSrc = new URL('pdf.worker.mjs', pdfjsBase).href;

window._extractPdfText = async function (pdfBase64, request = {}) {
  let pdfDocument;
  let tesseractWorker;

  try {
    const binary = atob(pdfBase64);
    const pdfBytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
    pdfDocument = await getDocument({
      data: pdfBytes,
      cMapUrl: new URL('cmaps/', pdfjsBase).href,
      cMapPacked: true,
      standardFontDataUrl: new URL('standard_fonts/', pdfjsBase).href,
      useWasm: false,
      isEvalSupported: false,
    }).promise;

    if (pdfDocument.numPages < 1) {
      throw new Error('ملف PDF لا يحتوي على صفحات.');
    }

    const requestedPages = Number(request.maxPages || 5);
    const pageLimit = Math.min(10, Math.max(1, requestedPages));
    const pagesToRead = Math.min(pdfDocument.numPages, pageLimit);
    const language = request.language || 'ara+eng';
    const ocrArgs = request.args || {};

    tesseractWorker = await Tesseract.createWorker({
      workerPath: new URL('worker.min.js', tesseractBase).href,
      corePath: new URL('tesseract-core.wasm.js', tesseractBase).href,
      langPath: new URL('tessdata/', tesseractBase).href,
      gzip: true,
      workerBlobURL: false,
    });
    await tesseractWorker.loadLanguage(language);
    await tesseractWorker.initialize(language);
    await tesseractWorker.setParameters(ocrArgs);

    const sections = [];
    for (let pageNumber = 1; pageNumber <= pagesToRead; pageNumber += 1) {
      const page = await pdfDocument.getPage(pageNumber);
      const unscaledViewport = page.getViewport({ scale: 1 });
      const scale = Math.min(
        2,
        2400 / Math.max(unscaledViewport.width, unscaledViewport.height),
      );
      const viewport = page.getViewport({ scale });
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.floor(viewport.width));
      canvas.height = Math.max(1, Math.floor(viewport.height));

      try {
        const context = canvas.getContext('2d', { alpha: false });
        if (!context) throw new Error('تعذر تجهيز مساحة رسم صفحة PDF.');
        await page.render({ canvasContext: context, viewport }).promise;
        const result = await tesseractWorker.recognize(canvas);
        sections.push(`صفحة ${pageNumber}:\n${(result.data.text || '').trim()}`);
      } finally {
        page.cleanup();
        canvas.width = 0;
        canvas.height = 0;
      }
    }

    if (pdfDocument.numPages > pagesToRead) {
      sections.push(
        `تمت قراءة أول ${pagesToRead} صفحات فقط من أصل ${pdfDocument.numPages}.`,
      );
    }
    return sections.join('\n\n');
  } finally {
    if (tesseractWorker) await tesseractWorker.terminate();
    if (pdfDocument) await pdfDocument.destroy();
  }
};
