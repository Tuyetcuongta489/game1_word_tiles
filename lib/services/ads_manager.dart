import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:funtap_global_sdk/funtap_global_sdk.dart';
import 'analytics_service.dart';
import 'game_storage.dart';
import 'remote_config_service.dart';

/// Central Ad Manager for Word Tiles.
/// Handles Interstitial, Rewarded, AppOpen (AOA), and Banner ads
/// with strict gating, cooldown countdown (25s), and state synchronization.
class AdsManager {
  AdsManager._();

  /// Master switch to enable or disable ads across the entire app.
  /// - Set to `false` to completely disable all ads (Banner, Interstitial, Resume/AOA, Rewarded).
  /// - When `false`, rewarded buttons automatically grant rewards directly (ideal for testing/development).
  /// - Set to `true` when ready to serve production ads.
  static bool enableAds = true;

  static DateTime? _lastInterOrResumeTime;
  static bool _isShowingAd = false;
  static DateTime? _showingAdStartTime;
  static bool _adWasClicked = false;
  static bool _isRewardedLoaded = false;
  static bool _isAppOpenLoaded = false;
  static bool _isInterLoaded = false;
  static bool _isIapInProgress = false;
  static bool _isSplashInProgress = false;
  static bool _suppressNextResumeAd = false;
  static DateTime? _lastIapTime;
  static Timer? _retryLoadTimer;
  static int _rewardedRetryAttempt = 0;
  static final List<StreamSubscription> _subscriptions = [];

  /// Check if the ad manager is currently displaying an ad
  static bool get isShowingAd => _isShowingAd;

  /// Check if user has just clicked an ad (and might be in external store)
  static bool get adWasClicked => _adWasClicked;

  /// Whether a rewarded ad is confirmed loaded and ready
  static bool get isRewardedLoaded => _isRewardedLoaded;

  /// Whether an App Open ad is confirmed loaded and ready
  static bool get isAppOpenLoaded => _isAppOpenLoaded;

  /// Whether an Interstitial ad is confirmed loaded and ready
  static bool get isInterLoaded => _isInterLoaded;

  /// Time since last Inter or Resume ad was closed
  static DateTime? get lastInterOrResumeTime => _lastInterOrResumeTime;

  /// Check if an IAP checkout flow is currently active
  static bool get isIapInProgress => _isIapInProgress;

  /// Check if the Splash / LoadingScreen is currently active
  static bool get isSplashInProgress => _isSplashInProgress;

  /// Notify AdsManager whether the initial Splash / LoadingScreen is in progress
  /// to prevent premature App Resume ads from firing during startup dialogs (e.g., ATT / Notification permission).
  static void setSplashInProgress(bool inProgress) {
    _isSplashInProgress = inProgress;
  }

  /// Check if the next App Resume ad is suppressed due to an IAP checkout flow
  static bool get suppressNextResumeAd => _suppressNextResumeAd;

  /// Time when the last IAP flow completed
  static DateTime? get lastIapTime => _lastIapTime;

  /// Notify AdsManager that an in-app purchase flow has started or ended
  static void setIapInProgress(bool inProgress) {
    _isIapInProgress = inProgress;
    if (inProgress) {
      _suppressNextResumeAd = true;
    }
  }

  /// Notifies that an IAP transaction / checkout flow has completed (success, cancel, or fail).
  /// Strictly enforces ad suppression so NO App Open or Interstitial ad will show when returning from Google Play/App Store.
  static void onIapFlowFinished({bool success = false}) {
    _isIapInProgress = false;
    _suppressNextResumeAd = true;
    _lastIapTime = DateTime.now();
    _recordAdCompleted(); // Resets the 25s cooldown timer
    debugPrint('[AdsManager] IAP flow finished (success: $success). Suppressing resume/open ads.');
  }

  /// Initializes AdsManager, listens to reward completions and remote config updates
  static void init() {
    if (!enableAds) {
      debugPrint('[AdsManager] Ads are disabled (enableAds = false). Skipping ads initialization.');
      return;
    }

    RemoteConfigService.listenToUpdates();
    RemoteConfigService.fetchConfigs();

    for (final s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();

    // Track ad clicks to prevent App Resume ad collision when returning from external store
    _subscriptions.add(FGSDK.onInterstitialClicked.listen((info) {
      debugPrint('[AdsManager] onInterstitialClicked: placement=${info.placement} -> marking _adWasClicked = true');
      _adWasClicked = true;
    }));
    _subscriptions.add(FGSDK.onAppOpenClicked.listen((info) {
      debugPrint('[AdsManager] onAppOpenClicked: placement=${info.placement} -> marking _adWasClicked = true');
      _adWasClicked = true;
    }));
    _subscriptions.add(FGSDK.onRewardedClicked.listen((info) {
      debugPrint('[AdsManager] onRewardedClicked: placement=${info.placement} -> marking _adWasClicked = true');
      _adWasClicked = true;
    }));

    // Track rewarded ad loading lifecycle
    _subscriptions.add(FGSDK.onRewardedLoaded.listen((info) {
      debugPrint('[AdsManager] onRewardedLoaded: placement=${info.placement}');
      _isRewardedLoaded = true;
      _cancelRetryTimer();
    }));
    _subscriptions.add(FGSDK.onRewardedFailedToLoad.listen((info) {
      debugPrint('[AdsManager] onRewardedFailedToLoad: placement=${info.placement}');
      _isRewardedLoaded = false;
      _scheduleRewardedRetry();
    }));
    _subscriptions.add(FGSDK.onRewardedClosed.listen((info) {
      _isRewardedLoaded = false;
      preloadRewarded();
    }));

    // Track AppOpen loading lifecycle
    _subscriptions.add(FGSDK.onAppOpenLoaded.listen((info) {
      debugPrint('[AdsManager] onAppOpenLoaded: placement=${info.placement}');
      _isAppOpenLoaded = true;
    }));
    _subscriptions.add(FGSDK.onAppOpenFailedToLoad.listen((info) {
      debugPrint('[AdsManager] onAppOpenFailedToLoad: placement=${info.placement}');
      _isAppOpenLoaded = false;
    }));
    _subscriptions.add(FGSDK.onAppOpenClosed.listen((info) {
      debugPrint('[AdsManager] onAppOpenClosed: placement=${info.placement}');
      _isAppOpenLoaded = false;
    }));

    // Track Interstitial loading lifecycle
    _subscriptions.add(FGSDK.onInterstitialLoaded.listen((info) {
      debugPrint('[AdsManager] onInterstitialLoaded: placement=${info.placement}');
      _isInterLoaded = true;
    }));
    _subscriptions.add(FGSDK.onInterstitialFailedToLoad.listen((info) {
      debugPrint('[AdsManager] onInterstitialFailedToLoad: placement=${info.placement}');
      _isInterLoaded = false;
    }));
    _subscriptions.add(FGSDK.onInterstitialClosed.listen((info) {
      debugPrint('[AdsManager] onInterstitialClosed: placement=${info.placement}');
      _isInterLoaded = false;
    }));

    // Track banner lifecycle events
    _subscriptions.add(FGSDK.onBannerLoaded.listen((info) {
      debugPrint('[AdsManager] onBannerLoaded: placement=${info.placement}, network=${info.networkName}, adId=${info.adId}');
    }));
    _subscriptions.add(FGSDK.onBannerFailedToLoad.listen((info) {
      debugPrint('[AdsManager] onBannerFailedToLoad: placement=${info.placement}, network=${info.networkName}, adId=${info.adId}');
    }));
    _subscriptions.add(FGSDK.onBannerShown.listen((info) {
      debugPrint('[AdsManager] onBannerShown: placement=${info.placement}, network=${info.networkName}');
    }));
    _subscriptions.add(FGSDK.onBannerClicked.listen((info) {
      debugPrint('[AdsManager] onBannerClicked: placement=${info.placement}');
      _adWasClicked = true;
    }));

    // Track IAP events to suppress App Open and Resume ads during and after checkout
    _subscriptions.add(FGSDK.onPurchaseProcessing.listen((_) {
      debugPrint('[AdsManager] onPurchaseProcessing -> setting _isIapInProgress = true');
      setIapInProgress(true);
    }));
    _subscriptions.add(FGSDK.onPurchaseCompleted.listen((_) {
      debugPrint('[AdsManager] onPurchaseCompleted -> onIapFlowFinished(success: true)');
      onIapFlowFinished(success: true);
    }));
    _subscriptions.add(FGSDK.onPurchaseFailed.listen((_) {
      debugPrint('[AdsManager] onPurchaseFailed -> onIapFlowFinished(success: false)');
      onIapFlowFinished(success: false);
    }));
    _subscriptions.add(FGSDK.onRestorePurchasesCompleted.listen((_) {
      debugPrint('[AdsManager] onRestorePurchasesCompleted -> onIapFlowFinished');
      onIapFlowFinished();
    }));

    // Preload rewarded ad
    preloadRewarded();
  }

  /// Safely triggers a background preload for Rewarded Ad
  static void preloadRewarded() {
    if (!enableAds) return;
    try {
      debugPrint('[AdsManager] Preloading Rewarded ad...');
      FGSDK.loadRewarded();
    } catch (e) {
      debugPrint('[AdsManager] Error preloading rewarded ad: $e');
    }
  }

  static void _scheduleRewardedRetry() {
    if (!enableAds) return;
    _retryLoadTimer?.cancel();
    final delaySeconds = (5 * (1 << _rewardedRetryAttempt.clamp(0, 3))).clamp(5, 30);
    _retryLoadTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!enableAds) return;
      debugPrint('[AdsManager] Retrying rewarded ad preload (attempt: $_rewardedRetryAttempt, delay: ${delaySeconds}s)...');
      _rewardedRetryAttempt++;
      preloadRewarded();
    });
  }

  static void _cancelRetryTimer() {
    _retryLoadTimer?.cancel();
    _retryLoadTimer = null;
    _rewardedRetryAttempt = 0;
  }

  /// Whether the minimum interval (cooldown) has elapsed since last Inter / Resume ad
  static bool isCooldownPassed() {
    if (_lastInterOrResumeTime == null) return true;
    final elapsedSeconds = DateTime.now().difference(_lastInterOrResumeTime!).inSeconds;
    final cooldown = RemoteConfigService.adsInterval;
    return elapsedSeconds >= cooldown;
  }

  // ── Interstitial: Endgame ──────────────────────────────────────────────────

  /// Shows Interstitial ad at Endgame (VictoryDialog) on "Claim" or "Next Level" click.
  /// Rule:
  /// - Only shows when level >= Inter_level_x (default: 10).
  /// - Only shows when cooldown >= Ads_interval (default: 25s).
  /// - Marks hasShownFirstInter = true upon completion.
  static Future<void> showInterEndgame({
    required int levelNumber,
    required Function onCompleted,
  }) async {
    void invokeCallback([bool adWasShown = false]) {
      if (onCompleted is void Function(bool)) {
        onCompleted(adWasShown);
      } else if (onCompleted is void Function()) {
        onCompleted();
      } else {
        try {
          (onCompleted as dynamic)(adWasShown);
        } catch (_) {
          (onCompleted as dynamic)();
        }
      }
    }

    if (!enableAds) {
      debugPrint('[AdsManager] Ads disabled (enableAds = false) -> skipping Endgame Interstitial.');
      invokeCallback(false);
      return;
    }

    if (GameStorage.isNoAdsPurchased()) {
      debugPrint('[AdsManager] User has purchased No Ads -> skipping Endgame Interstitial.');
      invokeCallback(false);
      return;
    }

    final threshold = RemoteConfigService.interLevelX;
    final isLevelEligible = levelNumber >= threshold;
    final isIntervalPassed = isCooldownPassed();

    debugPrint(
      '[AdsManager] showInterEndgame -> Level: $levelNumber (req >= $threshold: $isLevelEligible), '
      'Cooldown passed: $isIntervalPassed',
    );

    if (!isLevelEligible || !isIntervalPassed || _isShowingAd) {
      invokeCallback(false);
      return;
    }

    _isShowingAd = true;
    _adWasClicked = false;
    bool adWasShown = false;

    final completer = Completer<void>();
    StreamSubscription? closeSub;
    StreamSubscription? failSub;

    void finishAd() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    closeSub = FGSDK.onInterstitialClosed.listen((_) => finishAd());
    failSub = FGSDK.onInterstitialFailedToShow.listen((_) => finishAd());

    try {
      AnalyticsService.logAfIntersLogicGame();
      debugPrint('[AdsManager] Showing Interstitial (placement: endgame, level: $levelNumber)...');
      await Future.any([
        FGSDK.showInterstitial('endgame', 'classic', levelNumber),
        completer.future,
      ]);
      _recordAdCompleted();
      adWasShown = true;
      unawaited(GameStorage.setHasWatchedInterEndgame(true));
    } catch (e) {
      debugPrint('[AdsManager] Error showing endgame inter: $e');
    } finally {
      await closeSub.cancel();
      await failSub.cancel();
      _isShowingAd = false;
      invokeCallback(adWasShown);
    }
  }

  // ── Interstitial: Replay ───────────────────────────────────────────────────

  /// Shows ad when user taps "Replay" (Restart level).
  /// Rule:
  /// - Check cooldown >= Ads_interval (25s).
  /// - Ads_replay == false -> Interstitial.
  /// - Ads_replay == true -> Native Full Screen (falls back to Inter if native not available).
  static Future<void> showInterReplay({
    required int levelNumber,
    required VoidCallback onCompleted,
  }) async {
    if (!enableAds) {
      debugPrint('[AdsManager] Ads disabled (enableAds = false) -> skipping Replay ad.');
      onCompleted();
      return;
    }

    if (GameStorage.isNoAdsPurchased()) {
      debugPrint('[AdsManager] User has purchased No Ads -> skipping Replay ad.');
      onCompleted();
      return;
    }

    final isIntervalPassed = isCooldownPassed();
    debugPrint('[AdsManager] showInterReplay -> Cooldown passed: $isIntervalPassed');

    if (!isIntervalPassed || _isShowingAd) {
      onCompleted();
      return;
    }

    _isShowingAd = true;
    _adWasClicked = false;
    final isNative = RemoteConfigService.adsReplay;

    final completer = Completer<void>();
    StreamSubscription? closeSub;
    StreamSubscription? failSub;

    void finishAd() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    closeSub = FGSDK.onInterstitialClosed.listen((_) => finishAd());
    failSub = FGSDK.onInterstitialFailedToShow.listen((_) => finishAd());

    try {
      AnalyticsService.logAfIntersLogicGame();
      debugPrint('[AdsManager] Showing ad for replay (isNative: $isNative, level: $levelNumber)...');
      await Future.any([
        FGSDK.showInterstitial('replay', 'classic', levelNumber),
        completer.future,
      ]);
      _recordAdCompleted();
    } catch (e) {
      debugPrint('[AdsManager] Error showing replay ad: $e');
    } finally {
      await closeSub.cancel();
      await failSub.cancel();
      _isShowingAd = false;
      onCompleted();
    }
  }

  // ── Rewarded Ads ───────────────────────────────────────────────────────────

  /// Shows Rewarded ad for Double Coin reward at Endgame.
  /// User earns reward ONLY if video is watched completely.
  static Future<void> showDoubleCoinReward({
    required int levelNumber,
    required Function(bool success) onRewardResult,
  }) async {
    await _showRewardAdInternal(
      placement: 'double_coin',
      levelNumber: levelNumber,
      onRewardResult: onRewardResult,
    );
  }

  /// Shows Rewarded ad for Booster (Hint, Rocket) or Free Shop coins.
  static Future<void> showBoosterReward({
    required String boosterType,
    required int levelNumber,
    required Function(bool success) onRewardResult,
  }) async {
    await _showRewardAdInternal(
      placement: 'booster_$boosterType',
      levelNumber: levelNumber,
      onRewardResult: onRewardResult,
    );
  }

  /// Shows Rewarded ad for Daily Gift / Free Pack in Daily & Gift dialog.
  static Future<void> showDailyFreePackReward({
    required int levelNumber,
    required Function(bool success) onRewardResult,
  }) async {
    await _showRewardAdInternal(
      placement: 'daily_free_pack',
      levelNumber: levelNumber,
      onRewardResult: onRewardResult,
    );
  }

  /// Shows Rewarded ad for Daily Login Streak x2 multiplier.
  static Future<void> showDailyLoginX2Reward({
    required int levelNumber,
    required Function(bool success) onRewardResult,
  }) async {
    await _showRewardAdInternal(
      placement: 'daily_login_x2',
      levelNumber: levelNumber,
      onRewardResult: onRewardResult,
    );
  }

  @visibleForTesting
  static bool? mockRewardResult;

  static Future<void> _showRewardAdInternal({
    required String placement,
    required int levelNumber,
    required Function(bool success) onRewardResult,
  }) async {
    if (!enableAds) {
      debugPrint('[AdsManager] Ads disabled (enableAds = false) -> granting reward directly for $placement.');
      _recordAdCompleted();
      onRewardResult(true);
      return;
    }

    if (mockRewardResult != null) {
      if (mockRewardResult == true) {
        _recordAdCompleted();
      }
      onRewardResult(mockRewardResult!);
      return;
    }

    // 1. Anti-deadlock guard: prevent permanent lock if a previous ad call was somehow orphaned
    if (_isShowingAd) {
      if (_showingAdStartTime != null &&
          DateTime.now().difference(_showingAdStartTime!).inSeconds > 45) {
        debugPrint('[AdsManager] Clearing hung _isShowingAd state after 45s.');
        _isShowingAd = false;
      } else {
        debugPrint('[AdsManager] Ad is already displaying or loading. Ignoring call.');
        onRewardResult(false);
        return;
      }
    }

    _isShowingAd = true;
    _showingAdStartTime = DateTime.now();
    _adWasClicked = false;

    // Triggered when user taps any button to view rewarded ad according to game logic (spec Sheet 2)
    AnalyticsService.logAfRewardedLogicGame();

    // 2. Check if Rewarded Ad is already loaded and ready
    bool isReady = false;
    try {
      isReady = await FGSDK.isRewardedReady().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => false,
      );
    } catch (_) {
      isReady = false;
    }

    // 3. If not ready, request on-demand load and wait up to 8 seconds
    if (!isReady) {
      debugPrint('[AdsManager] Rewarded ad not ready. Requesting on-demand load & waiting up to 8s...');
      preloadRewarded();
      try {
        await FGSDK.onRewardedLoaded.first.timeout(const Duration(seconds: 8));
        isReady = true;
        debugPrint('[AdsManager] Rewarded ad loaded successfully on-demand!');
      } catch (e) {
        debugPrint('[AdsManager] On-demand ad load timed out or failed: $e');
      }
    }

    // 4. If still not ready after waiting (e.g. offline / network unavailable)
    if (!isReady) {
      debugPrint('[AdsManager] Rewarded ad unavailable (offline or load failed). Releasing state.');
      _isShowingAd = false;
      _showingAdStartTime = null;
      onRewardResult(false);
      return;
    }

    bool rewardEarned = false;
    final completer = Completer<void>();
    StreamSubscription? closeSub;
    StreamSubscription? failSub;
    StreamSubscription? rewardSub;
    StreamSubscription? showSub;
    Timer? watchdogTimer;

    void finishAd() {
      watchdogTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    closeSub = FGSDK.onRewardedClosed.listen((_) => finishAd());
    failSub = FGSDK.onRewardedFailedToShow.listen((_) => finishAd());
    rewardSub = FGSDK.onRewardedCompleted.listen((_) {
      rewardEarned = true;
    });

    // 6-second watchdog: if ad doesn't actually display on screen within 6 seconds, abort gracefully
    watchdogTimer = Timer(const Duration(seconds: 6), () {
      debugPrint('[AdsManager] Watchdog: Rewarded ad did not display within 6s. Aborting.');
      finishAd();
    });

    // Once displayed, cancel 6s watchdog and give up to 120s for user to watch video
    showSub = FGSDK.onRewardedShown.listen((_) {
      debugPrint('[AdsManager] onRewardedShown: Ad started playing.');
      watchdogTimer?.cancel();
      watchdogTimer = Timer(const Duration(seconds: 120), () {
        debugPrint('[AdsManager] Watchdog: Rewarded ad playback exceeded 120s.');
        finishAd();
      });
    });

    try {
      debugPrint('[AdsManager] Showing Rewarded ad (placement: $placement, level: $levelNumber)...');
      await Future.any([
        FGSDK.showRewarded(placement, 'classic', levelNumber),
        completer.future,
      ]);
    } catch (e) {
      debugPrint('[AdsManager] Error showing rewarded ad: $e');
    } finally {
      watchdogTimer?.cancel();
      await closeSub.cancel();
      await failSub.cancel();
      await rewardSub.cancel();
      await showSub.cancel();
      _isShowingAd = false;
      _showingAdStartTime = null;

      if (rewardEarned) {
        _recordAdCompleted();
      }
      onRewardResult(rewardEarned);

      // Preload next rewarded ad in background
      preloadRewarded();
    }
  }

  // ── Splash Ads (AOA or Inter on cold start / loading complete) ──────────────

  /// Shows Splash App Open or Interstitial ad after LoadingScreen completes.
  /// - Gated by No Ads purchase.
  /// - Format determined by RemoteConfigService.adsResume (false = AOA, true = Inter).
  /// - Times out safely after 6 seconds so user is never blocked from entering the game.
  static Future<void> showSplashAd({int timeoutMs = 1800}) async {
    if (!enableAds || GameStorage.isNoAdsPurchased()) return;

    final showInter = RemoteConfigService.adsResume;
    debugPrint('[AdsManager] showSplashAd: Requesting Splash ad (format: ${showInter ? "Inter" : "AOA"})...');

    // Wait up to timeoutMs for the ad to finish downloading from the network if not ready yet
    final waitStart = DateTime.now();
    while ((showInter ? !_isInterLoaded : !_isAppOpenLoaded) &&
        DateTime.now().difference(waitStart).inMilliseconds < timeoutMs) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final isReady = showInter ? _isInterLoaded : _isAppOpenLoaded;
    if (!isReady) {
      final timeoutSec = (timeoutMs / 1000).toStringAsFixed(1);
      debugPrint('[AdsManager] Splash ad is not ready within ${timeoutSec}s timeout (format: ${showInter ? "Inter" : "AOA"}) -> proceeding to game.');
      return;
    }

    final completer = Completer<void>();
    StreamSubscription? closeSub;
    StreamSubscription? failSub;

    void finishAd() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    if (showInter) {
      closeSub = FGSDK.onInterstitialClosed.listen((_) {
        debugPrint('[AdsManager] Splash Inter closed.');
        finishAd();
      });
      failSub = FGSDK.onInterstitialFailedToShow.listen((_) {
        debugPrint('[AdsManager] Splash Inter failed to show.');
        finishAd();
      });
    } else {
      closeSub = FGSDK.onAppOpenClosed.listen((_) {
        debugPrint('[AdsManager] Splash AOA closed.');
        finishAd();
      });
      failSub = FGSDK.onAppOpenFailedToShow.listen((_) {
        debugPrint('[AdsManager] Splash AOA failed to show.');
        finishAd();
      });
    }

    try {
      _isShowingAd = true;
      if (showInter) {
        AnalyticsService.logAfIntersLogicGame();
        FGSDK.showInterstitial('splash', 'classic', 1);
      } else {
        FGSDK.showAppOpen('splash', 'classic', 1);
      }
      // Wait for user to dismiss ad or fail, with 6s safety watchdog
      await completer.future.timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('[AdsManager] Splash ad timeout (6s) -> continuing to game.');
      });
      _recordAdCompleted();
    } catch (e) {
      debugPrint('[AdsManager] Error showing splash ad: $e');
    } finally {
      await closeSub.cancel();
      await failSub.cancel();
      _isShowingAd = false;
    }
  }

  // ── Resume Ads (AOA or Inter on App Resume) ───────────────────────────────

  /// Handles App Lifecycle Resume from background.
  /// Rule:
  /// - Preloads Rewarded Ad so it is ready if user toggled network in settings.
  /// - Blocked while initial Splash / LoadingScreen is still running.
  /// - Blocked if returning from an ad click / external store.
  /// - Blocked until user has seen first Inter (GameStorage.hasShownFirstInter() == true).
  /// - Shares Ads_interval (25s) cooldown with Inter ads.
  /// - Format determined by Ads_resume: false = AOA, true = Inter.
  static Future<void> handleAppResume({int currentLevel = 1}) async {
    if (_isSplashInProgress) {
      debugPrint('[AdsManager] Resume ad skipped: Splash / LoadingScreen is still in progress.');
      return;
    }

    // 1. Always attempt to preload Rewarded Ad on App Resume
    // (Crucial: when user switches out to enable WiFi/Cellular data in settings/control center and comes back)
    preloadRewarded();

    if (!enableAds || GameStorage.isNoAdsPurchased()) return;

    if (_isIapInProgress) {
      debugPrint('[AdsManager] Resume ad skipped: IAP purchase flow is currently in progress.');
      return;
    }

    if (_suppressNextResumeAd) {
      debugPrint('[AdsManager] Resume ad skipped: returning from IAP checkout flow.');
      _suppressNextResumeAd = false;
      return;
    }

    if (_lastIapTime != null &&
        DateTime.now().difference(_lastIapTime!).inSeconds < 60) {
      debugPrint('[AdsManager] Resume ad skipped: recently completed IAP flow within 60s.');
      return;
    }

    if (_isShowingAd) {
      debugPrint('[AdsManager] Resume ad skipped: ad is already showing.');
      return;
    }

    if (_adWasClicked) {
      debugPrint('[AdsManager] Resume ad skipped: user just returned from ad click/store.');
      _adWasClicked = false;
      return;
    }

    final hasShownFirstInter = GameStorage.hasShownFirstInter();
    if (!hasShownFirstInter) {
      debugPrint('[AdsManager] Resume ad gated: user has not seen first Inter yet.');
      return;
    }

    final isIntervalPassed = isCooldownPassed();
    if (!isIntervalPassed) {
      debugPrint('[AdsManager] Resume ad gated: 25s cooldown not reached yet.');
      return;
    }

    _isShowingAd = true;
    final showInterInsteadOfAoa = RemoteConfigService.adsResume;

    final completer = Completer<void>();
    StreamSubscription? closeSub;
    StreamSubscription? failSub;

    void finishAd() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    if (showInterInsteadOfAoa) {
      closeSub = FGSDK.onInterstitialClosed.listen((_) => finishAd());
      failSub = FGSDK.onInterstitialFailedToShow.listen((_) => finishAd());
    } else {
      closeSub = FGSDK.onAppOpenClosed.listen((_) => finishAd());
      failSub = FGSDK.onAppOpenFailedToShow.listen((_) => finishAd());
    }

    try {
      if (showInterInsteadOfAoa) {
        AnalyticsService.logAfIntersLogicGame();
        debugPrint('[AdsManager] Showing Resume Inter ad (level: $currentLevel)...');
        await Future.any([
          FGSDK.showInterstitial('resume', 'classic', currentLevel),
          completer.future,
        ]);
      } else {
        debugPrint('[AdsManager] Showing Resume AOA ad (level: $currentLevel)...');
        try {
          FGSDK.showAppOpen('resume', 'classic', currentLevel);
          await completer.future.timeout(const Duration(seconds: 15), onTimeout: () {});
        } catch (e) {
          debugPrint('[AdsManager] Error showing resume AOA: $e');
        }
      }
      _recordAdCompleted();
    } catch (e) {
      debugPrint('[AdsManager] Error showing resume ad: $e');
    } finally {
      await closeSub.cancel();
      await failSub.cancel();
      _isShowingAd = false;
    }
  }

  // ── Banner Ads ─────────────────────────────────────────────────────────────

  /// Shows Banner ad on non-gameplay screens (HomeScreen, LevelSelectScreen)
  static void showBanner(String placement, {int level = 1}) {
    if (!enableAds || GameStorage.isNoAdsPurchased()) return;
    try {
      debugPrint('[AdsManager] showBanner: placement=$placement, level=$level');
      FGSDK.showBanner(placement, 'classic', level);
    } catch (e) {
      debugPrint('[AdsManager] Error showing banner: $e');
    }
  }

  /// Hides Banner ad when entering gameplay (GameScreen)
  static void hideBanner() {
    if (!enableAds) return;
    try {
      debugPrint('[AdsManager] hideBanner');
      FGSDK.hideBanner();
    } catch (e) {
      debugPrint('[AdsManager] Error hiding banner: $e');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _recordAdCompleted() {
    _lastInterOrResumeTime = DateTime.now();
    GameStorage.setHasShownFirstInter(true);
    debugPrint('[AdsManager] Ad completed. Cooldown reset to now ($_lastInterOrResumeTime).');
  }

  @visibleForTesting
  static void setMockState({
    DateTime? lastAdTime,
    bool clearLastAdTime = false,
    bool? isShowingAd,
    bool? adWasClicked,
    bool? isRewardedLoaded,
    bool? isAppOpenLoaded,
    bool? isInterLoaded,
    bool? isIapInProgress,
    bool? suppressNextResumeAd,
    DateTime? lastIapTime,
  }) {
    if (clearLastAdTime) {
      _lastInterOrResumeTime = null;
    } else if (lastAdTime != null) {
      _lastInterOrResumeTime = lastAdTime;
    }
    if (isShowingAd != null) {
      _isShowingAd = isShowingAd;
      _showingAdStartTime = isShowingAd ? DateTime.now() : null;
    }
    if (adWasClicked != null) _adWasClicked = adWasClicked;
    if (isRewardedLoaded != null) _isRewardedLoaded = isRewardedLoaded;
    if (isAppOpenLoaded != null) _isAppOpenLoaded = isAppOpenLoaded;
    if (isInterLoaded != null) _isInterLoaded = isInterLoaded;
    if (isIapInProgress != null) _isIapInProgress = isIapInProgress;
    if (suppressNextResumeAd != null) _suppressNextResumeAd = suppressNextResumeAd;
    if (lastIapTime != null) _lastIapTime = lastIapTime;
  }
}
