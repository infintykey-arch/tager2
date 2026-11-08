import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Loads app-open ads in the background and shows them only on later returns
/// from the background. A cold start is never held up waiting for an ad.
class AppOpenAdService with WidgetsBindingObserver {
  AppOpenAdService._();

  static final AppOpenAdService instance = AppOpenAdService._();
  static const _maximumCacheAge = Duration(hours: 4);

  AppOpenAd? _appOpenAd;
  DateTime? _loadedAt;
  bool _initialized = false;
  Future<void>? _initializationFuture;
  bool _loading = false;
  bool _showing = false;
  bool _wentToBackground = false;
  bool _suppressNextResumeAfterAd = false;

  /// Starts SDK initialization and preloading without delaying `runApp`.
  bool get isInitialized => _initialized;

  Future<void> initialize() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        _initialized) {
      return Future<void>.value();
    }
    return _initializationFuture ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    try {
      await AdConfig.load();
      if (!AdConfig.isConfigured) return;
      WidgetsBinding.instance.addObserver(this);
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadAd();
    } catch (_) {
      _initialized = false;
      // Ads are optional: SDK failures must not affect app startup.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wentToBackground = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_wentToBackground) return;

    _wentToBackground = false;
    if (_suppressNextResumeAfterAd) {
      _suppressNextResumeAfterAd = false;
      return;
    }
    _showIfAvailable();
  }

  void _loadAd() {
    if (!_initialized || _loading || _appOpenAd != null) return;
    _loading = true;
    try {
      AppOpenAd.load(
        adUnitId: AdConfig.appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            _appOpenAd = ad;
            _loadedAt = DateTime.now();
          },
          onAdFailedToLoad: (_) {
            _loading = false;
            _appOpenAd = null;
            _loadedAt = null;
          },
        ),
      ).catchError((Object _) {
        _loading = false;
        _appOpenAd = null;
        _loadedAt = null;
      });
    } catch (_) {
      _loading = false;
      _appOpenAd = null;
      _loadedAt = null;
    }
  }

  void _showIfAvailable() {
    if (!_initialized || _showing) return;
    final ad = _appOpenAd;
    final loadedAt = _loadedAt;
    if (ad == null || loadedAt == null) {
      _loadAd();
      return;
    }
    if (DateTime.now().difference(loadedAt) >= _maximumCacheAge) {
      ad.dispose();
      _appOpenAd = null;
      _loadedAt = null;
      _loadAd();
      return;
    }

    _appOpenAd = null;
    _loadedAt = null;
    _showing = true;
    _suppressNextResumeAfterAd = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: (_) {},
      onAdFailedToShowFullScreenContent: (failedAd, _) {
        _showing = false;
        failedAd.dispose();
        _loadAd();
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        _showing = false;
        dismissedAd.dispose();
        _loadAd();
      },
    );
    void recoverFromShowFailure() {
      _showing = false;
      _suppressNextResumeAfterAd = false;
      ad.dispose();
      _loadAd();
    }

    try {
      ad.show().catchError((Object _) => recoverFromShowFailure());
    } catch (_) {
      recoverFromShowFailure();
    }
  }
}
