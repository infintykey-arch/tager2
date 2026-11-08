import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'app_open_ad_service.dart';

/// A compact native ad shown only in the non-sensitive contact screen.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
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
    await AppOpenAdService.instance.initialize();
    if (!mounted || !AppOpenAdService.instance.isInitialized) return;

    final ad = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _nativeAd = null;
              _loaded = false;
            });
          }
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
    _nativeAd = ad;
    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
      _nativeAd = null;
      if (mounted) setState(() => _loaded = false);
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _nativeAd;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'إعلان',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(height: 104, child: AdWidget(ad: ad)),
          ],
        ),
      ),
    );
  }
}
