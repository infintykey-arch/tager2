import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'app_open_ad_service.dart';

/// A bottom-anchored adaptive banner. Failed requests occupy no screen space.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _started = true;
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      await AppOpenAdService.instance.initialize();
      if (!mounted || !AppOpenAdService.instance.isInitialized) return;

      final width = MediaQuery.sizeOf(context).width.truncate();
      final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || size == null) return;

      final banner = BannerAd(
        adUnitId: AdConfig.bannerAdUnitId,
        request: const AdRequest(),
        size: size,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, _) {
            ad.dispose();
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _loaded = false;
              });
            }
          },
        ),
      );
      _bannerAd = banner;
      await banner.load();
    } catch (_) {
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() => _loaded = false);
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
