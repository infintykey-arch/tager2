import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// AdMob's four production IDs are kept in `assets/admob_ids.json`.
/// Android's manifest and Flutter both read that single buildable config.
abstract final class AdConfig {
  static Future<void>? _loadFuture;
  static String _appId = '';
  static String _bannerAdUnitId = '';
  static String _nativeAdUnitId = '';
  static String _appOpenAdUnitId = '';

  static String get appId => _appId;
  static String get bannerAdUnitId => _bannerAdUnitId;
  static String get nativeAdUnitId => _nativeAdUnitId;
  static String get appOpenAdUnitId => _appOpenAdUnitId;

  static bool get hasConfiguredIds =>
      appId.isNotEmpty &&
      bannerAdUnitId.isNotEmpty &&
      nativeAdUnitId.isNotEmpty &&
      appOpenAdUnitId.isNotEmpty;

  /// Avoid real ad requests during debug/profile runs; no test IDs are used.
  static bool get isConfigured => kReleaseMode && hasConfiguredIds;

  static Future<void> load() => _loadFuture ??= _loadFromAsset();

  static Future<void> _loadFromAsset() async {
    try {
      final config = jsonDecode(
        await rootBundle.loadString('assets/admob_ids.json'),
      ) as Map<String, dynamic>;
      _appId = config['app_id'] as String? ?? '';
      _bannerAdUnitId = config['banner_unit_id'] as String? ?? '';
      _nativeAdUnitId = config['native_unit_id'] as String? ?? '';
      _appOpenAdUnitId = config['app_open_unit_id'] as String? ?? '';
    } catch (_) {
      _appId = '';
      _bannerAdUnitId = '';
      _nativeAdUnitId = '';
      _appOpenAdUnitId = '';
    }
  }
}
