import 'package:flutter_test/flutter_test.dart';
import 'package:tager2/core/ads/ad_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all production ad IDs from the bundled central config', () async {
    await AdConfig.load();

    expect(AdConfig.hasConfiguredIds, isTrue);
    expect(AdConfig.isConfigured, isFalse);
    expect(AdConfig.appId, isNotEmpty);
    expect(AdConfig.bannerAdUnitId, isNotEmpty);
    expect(AdConfig.nativeAdUnitId, isNotEmpty);
    expect(AdConfig.appOpenAdUnitId, isNotEmpty);
  });
}
