import 'dart:async';

import 'package:flutter/widgets.dart';

typedef AdsInitialization = Future<void> Function();

/// Starts optional ad initialization only after Flutter has rendered a frame.
/// SDK failures are deliberately isolated from app startup and UI lifecycle.
void scheduleAdsInitializationAfterFirstFrame(AdsInitialization initialize) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeSafely(initialize));
  });
}

Future<void> _initializeSafely(AdsInitialization initialize) async {
  try {
    await initialize();
  } catch (_) {
    // Ads are optional and must never interrupt the app's initial UI.
  }
}
