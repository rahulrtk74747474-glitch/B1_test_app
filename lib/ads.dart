import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob placements. Real ads are NEVER shipped in debug builds.
class AdsConfig {
  static const bool productionEnabled = bool.fromEnvironment('ADS_ENABLED', defaultValue: false);
  static const String bannerProductionId = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String interstitialProductionId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

  static const String testBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  static bool get enabled => !kReleaseMode || productionEnabled;
  static String get bannerId => kReleaseMode ? bannerProductionId : testBannerId;
  static String get interstitialId => kReleaseMode ? interstitialProductionId : testInterstitialId;
  static bool get configured => enabled &&
      bannerId.startsWith('ca-app-pub-') &&
      interstitialId.startsWith('ca-app-pub-');
}

/// Consent-first: never request ads until UMP says canRequestAds() == true.
/// App functions perfectly offline or when consent is unavailable.
class AdsManager {
  AdsManager._();
  static final instance = AdsManager._();
  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  bool _starting = false;
  bool _loadingFullScreen = false;
  bool _showingFullScreen = false;
  InterstitialAd? _interstitial;
  DateTime? _lastInterstitial;
  int _testsSinceAd = 0;

  /// Called once on every cold app launch.
  Future<void> initialize() async {
    if (_starting || !AdsConfig.configured) return;
    _starting = true;
    final finished = Completer<void>();
    final consent = ConsentInformation.instance;
    consent.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          await _enableIfAllowed();
          if (!finished.isCompleted) finished.complete();
        });
      },
      (error) async {
        // UMP may retain a valid decision from a previous session.
        await _enableIfAllowed();
        if (!finished.isCompleted) finished.complete();
      },
    );
    await finished.future;
  }

  Future<void> _enableIfAllowed() async {
    try {
      if (!await ConsentInformation.instance.canRequestAds()) return;
      if (ready.value) return;
      await MobileAds.instance.initialize();
      ready.value = true;
      _preloadInterstitial();
    } catch (error) {
      debugPrint('Advertising unavailable: $error');
    }
  }

  Future<bool> privacyOptionsRequired() async {
    if (!AdsConfig.configured) return false;
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> openPrivacyOptions() async {
    if (!AdsConfig.configured) return;
    final completion = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (!completion.isCompleted) completion.complete();
    });
    await completion.future;
  }

  void _preloadInterstitial() {
    if (!ready.value || _loadingFullScreen || _interstitial != null || !AdsConfig.configured) return;
    _loadingFullScreen = true;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingFullScreen = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _loadingFullScreen = false;
          debugPrint('Interstitial unavailable: $error');
        },
      ),
    );
  }

  /// Show only after a completed test's score has been seen and dismissed.
  /// Cooldown prevents users starting many tiny tests from being flooded.
  /// Never delay study/results if ad wasn't already loaded.
  Future<void> maybeShowAfterResult() async {
    _testsSinceAd++;
    if (!ready.value || _showingFullScreen) return;
    if (_testsSinceAd < 2) {
      _preloadInterstitial();
      return;
    }
    if (_lastInterstitial != null &&
        DateTime.now().difference(_lastInterstitial!) < const Duration(minutes: 4)) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return;
    }
    _interstitial = null;
    _showingFullScreen = true;
    _testsSinceAd = 0;
    _lastInterstitial = DateTime.now();
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _showingFullScreen = false;
        _preloadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _showingFullScreen = false;
        _preloadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    ad.show();
    await done.future;
  }
}

/// Reserved, non-clickable-in-app banner area safely separated from answers.
/// No artificial banner or fake advertisement is shown if SDK/consent is unavailable.
class QuestionBanner extends StatefulWidget {
  const QuestionBanner({super.key, this.large = false});
  /// On setup and result pages, use a 300 x 250 medium rectangle when it fits.
  final bool large;
  @override
  State<QuestionBanner> createState() => _QuestionBannerState();
}

class _QuestionBannerState extends State<QuestionBanner> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    AdsManager.instance.ready.addListener(_maybeLoad);
    if (AdsManager.instance.ready.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
    }
  }

  void _maybeLoad() {
    if (!mounted || !AdsManager.instance.ready.value || _loading || _banner != null) return;
    _load();
  }

  Future<void> _load() async {
    _loading = true;
    // A 300x250 medium rectangle is less intrusive than a full-screen ad and
    // works within the scrollable result/setup page. Compact phones fall back.
    final availableWidth = (MediaQuery.sizeOf(context).width - 52).floor().clamp(1, 10000);
    final size = widget.large && availableWidth >= 300
        ? AdSize.mediumRectangle
        : await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(availableWidth);
    if (!mounted) return;
    if (size == null) {
      _loading = false;
      return;
    }
    final ad = BannerAd(
      adUnitId: AdsConfig.bannerId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner unavailable: $error');
          ad.dispose();
          if (mounted) setState(() {
            _banner = null;
            _loaded = false;
            _loading = false;
          });
        },
      ),
    );
    _banner = ad;
    await ad.load();
  }

  @override
  void dispose() {
    AdsManager.instance.ready.removeListener(_maybeLoad);
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _banner;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Advertisement',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          const Text('Advertisement', style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          SizedBox(width: ad.size.width.toDouble(), height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad)),
        ]),
      ),
    );
  }
}
