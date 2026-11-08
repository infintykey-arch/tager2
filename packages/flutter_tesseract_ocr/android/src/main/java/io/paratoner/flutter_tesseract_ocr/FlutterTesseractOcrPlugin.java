package io.paratoner.flutter_tesseract_ocr;

import android.graphics.Bitmap;
import android.graphics.Matrix;
import android.graphics.pdf.PdfRenderer;
import android.os.AsyncTask;
import android.os.ParcelFileDescriptor;
import androidx.annotation.NonNull;

import com.googlecode.tesseract.android.TessBaseAPI;

import java.io.File;
import java.io.IOException;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class FlutterTesseractOcrPlugin implements FlutterPlugin, MethodCallHandler {
  private static final int DEFAULT_PAGE_SEG_MODE = TessBaseAPI.PageSegMode.PSM_AUTO_OSD;
  private TessBaseAPI baseApi = null;
  private String lastLanguage = "";
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    BinaryMessenger messenger = flutterPluginBinding.getBinaryMessenger();
    channel = new MethodChannel(messenger, "flutter_tesseract_ocr");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    if (baseApi != null) {
      baseApi.recycle();
      baseApi = null;
    }
  }

  @Override
  public void onMethodCall(final MethodCall call, final Result result) {
    switch (call.method) {
      case "extractText":
      case "extractHocr": {
        final String tessDataPath = call.argument("tessData");
        final String imagePath = call.argument("imagePath");
        final Map<String, String> args = call.argument("args");
        final String language = call.argument("language") == null
            ? "eng"
            : call.argument("language");
        if (imagePath == null || imagePath.isEmpty()) {
          result.error("OCR_IMAGE_MISSING", "Image path is missing.", null);
          return;
        }
        if (!ensureBaseApi(tessDataPath, language, result)) return;
        configureApi(args);
        new OcrAsyncTask(
            baseApi,
            new File(imagePath),
            result,
            call.method.equals("extractHocr")).execute();
        break;
      }
      case "extractPdfText": {
        final String tessDataPath = call.argument("tessData");
        final String pdfPath = call.argument("pdfPath");
        final Map<String, String> args = call.argument("args");
        final String language = call.argument("language") == null
            ? "ara+eng"
            : call.argument("language");
        final Integer requestedPages = call.argument("maxPages");
        final int maxPages = requestedPages == null ? 5 : requestedPages;
        if (pdfPath == null || pdfPath.isEmpty()) {
          result.error("OCR_PDF_MISSING", "PDF path is missing.", null);
          return;
        }
        if (!ensureBaseApi(tessDataPath, language, result)) return;
        configureApi(args);
        new PdfOcrAsyncTask(baseApi, new File(pdfPath), maxPages, result).execute();
        break;
      }
      default:
        result.notImplemented();
    }
  }

  private boolean ensureBaseApi(String tessDataPath, String language, Result result) {
    if (tessDataPath == null || tessDataPath.isEmpty()) {
      result.error("OCR_DATA_MISSING", "Tesseract language data is missing.", null);
      return false;
    }
    if (baseApi == null || !lastLanguage.equals(language)) {
      if (baseApi != null) {
        baseApi.recycle();
        baseApi = null;
      }
      baseApi = new TessBaseAPI();
      if (!baseApi.init(tessDataPath, language)) {
        baseApi.recycle();
        baseApi = null;
        lastLanguage = "";
        result.error("OCR_INIT_FAILED", "Could not initialize local OCR language data.", null);
        return false;
      }
      lastLanguage = language;
    }
    return true;
  }

  private void configureApi(Map<String, String> args) {
    int psm = DEFAULT_PAGE_SEG_MODE;
    if (args != null) {
      for (Map.Entry<String, String> entry : args.entrySet()) {
        if ("psm".equals(entry.getKey())) {
          try {
            psm = Integer.parseInt(entry.getValue());
          } catch (NumberFormatException ignored) {
            psm = DEFAULT_PAGE_SEG_MODE;
          }
        } else {
          baseApi.setVariable(entry.getKey(), entry.getValue());
        }
      }
    }
    baseApi.setPageSegMode(psm);
  }

  private static class OcrAsyncTask extends AsyncTask<Void, Void, String> {
    private final TessBaseAPI baseApi;
    private final File imageFile;
    private final Result result;
    private final boolean extractHocr;

    OcrAsyncTask(TessBaseAPI baseApi, File imageFile, Result result, boolean extractHocr) {
      this.baseApi = baseApi;
      this.imageFile = imageFile;
      this.result = result;
      this.extractHocr = extractHocr;
    }

    @Override
    protected String doInBackground(Void... voids) {
      this.baseApi.setImage(imageFile);
      String recognizedText = this.extractHocr
          ? this.baseApi.getHOCRText(0)
          : this.baseApi.getUTF8Text();
      this.baseApi.stop();
      return recognizedText;
    }

    @Override
    protected void onPostExecute(String recognizedText) {
      result.success(recognizedText);
    }
  }

  private static class PdfOcrAsyncTask extends AsyncTask<Void, Void, String> {
    private final TessBaseAPI baseApi;
    private final File pdfFile;
    private final int maxPages;
    private final Result result;
    private String errorMessage;

    PdfOcrAsyncTask(TessBaseAPI baseApi, File pdfFile, int maxPages, Result result) {
      this.baseApi = baseApi;
      this.pdfFile = pdfFile;
      this.maxPages = Math.max(1, Math.min(maxPages, 10));
      this.result = result;
    }

    @Override
    protected String doInBackground(Void... voids) {
      if (!pdfFile.isFile()) {
        errorMessage = "PDF file could not be found.";
        return null;
      }

      ParcelFileDescriptor descriptor = null;
      PdfRenderer renderer = null;
      try {
        descriptor = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY);
        renderer = new PdfRenderer(descriptor);
        final int pageCount = renderer.getPageCount();
        if (pageCount < 1) {
          errorMessage = "PDF contains no pages.";
          return null;
        }

        final int pagesToRead = Math.min(pageCount, maxPages);
        final StringBuilder recognized = new StringBuilder();
        for (int pageIndex = 0; pageIndex < pagesToRead; pageIndex++) {
          final PdfRenderer.Page page = renderer.openPage(pageIndex);
          Bitmap bitmap = null;
          try {
            final float scale = Math.min(
                2.0f,
                2400.0f / Math.max(page.getWidth(), page.getHeight()));
            final int width = Math.max(1, Math.round(page.getWidth() * scale));
            final int height = Math.max(1, Math.round(page.getHeight() * scale));
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            final Matrix transform = new Matrix();
            transform.setScale(scale, scale);
            page.render(
                bitmap,
                null,
                transform,
                PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY);
            baseApi.setImage(bitmap);
            final String pageText = baseApi.getUTF8Text();
            if (recognized.length() > 0) recognized.append("\n\n");
            recognized.append("صفحة ").append(pageIndex + 1).append(":\n");
            if (pageText != null) recognized.append(pageText.trim());
            baseApi.clear();
          } finally {
            if (bitmap != null && !bitmap.isRecycled()) bitmap.recycle();
            page.close();
          }
        }

        if (pageCount > pagesToRead) {
          recognized.append("\n\nتمت قراءة أول ")
              .append(pagesToRead)
              .append(" صفحات فقط من أصل ")
              .append(pageCount)
              .append(".");
        }
        return recognized.toString();
      } catch (Exception exception) {
        errorMessage = exception.getMessage() == null
            ? "Could not render this PDF locally."
            : exception.getMessage();
        return null;
      } finally {
        if (renderer != null) {
          renderer.close();
        } else if (descriptor != null) {
          try {
            descriptor.close();
          } catch (IOException ignored) {
          }
        }
      }
    }

    @Override
    protected void onPostExecute(String recognizedText) {
      if (errorMessage != null) {
        result.error("PDF_OCR_FAILED", errorMessage, null);
      } else {
        result.success(recognizedText);
      }
    }
  }
}
