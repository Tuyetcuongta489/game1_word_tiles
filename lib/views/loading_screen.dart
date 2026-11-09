import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:funtap_global_sdk/funtap_global_sdk.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ads_manager.dart';
import '../services/analytics_service.dart';
import '../services/app_localization.dart';
import '../services/audio_manager.dart';
import '../services/chapter_loader.dart';
import '../services/game_storage.dart';
import '../services/iap_manager.dart';
import '../services/notification_service.dart';
import '../services/remote_config_service.dart';
import 'home_screen.dart';
import 'first_language_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _startLoadingPipeline();
  }

  @override
  void dispose() {
    AdsManager.setSplashInProgress(false);
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _startLoadingPipeline() async {
    final startTime = DateTime.now();
    bool initFinished = false;
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    // Prevent AppLifecycleState.resumed (triggered by iOS Notification / ATT permission dialogs)
    // from firing a premature Resume AOA ad while LoadingScreen is still running.
    AdsManager.setSplashInProgress(true);

    // Register FGSDK ad & remote config stream listeners BEFORE any FGSDK method call
    // opens the native EventChannel so buffered early ad-loaded events are never dropped.
    if (!isTest) {
      try {
        AdsManager.init();
      } catch (_) {}
    }

    // 1. Start smooth visual progress
    _progressTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (!initFinished) {
          if (_progress < 0.88) {
            _progress += 0.012;
          }
        } else {
          if (_progress < 1.0) {
            _progress += 0.025;
            if (_progress >= 1.0) {
              _progress = 1.0;
            }
          }
        }
      });
    });

    // 2. Perform async initializations (GameStorage first so AnalyticsService can read prefs)
    try {
      await GameStorage.init();
      AnalyticsService.logLoadingStart(placement: 'splash');
      await ChapterLoader.init();
      await NotificationService.init();
      AnalyticsService.updateUserProperties();
      if (GameStorage.isFirstSession()) {
        AnalyticsService.logTutorial(name: 'ftue_loading_start', value: 1);
      }
    } catch (_) {}

    try {
      await AudioManager.init();
      AudioManager.startBgm();
    } catch (_) {}

    // Wait for SDK initialization and Consent completion (UMP / ATT) before loading gameplay.
    // This ensures:
    // 1. The Consent popup is presented and completed over the LoadingScreen.
    // 2. The user has finished tapping consent before entering GameScreen.
    // 3. Early game tracking events (level_start, FTUE tutorials) are not lost or blocked.
    if (!isTest && !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      final consentWaitStart = DateTime.now();
      while (!await FGSDK.isInit()) {
        if (!mounted) return;
        // Safety timeout (45s) in case of unexpected native stall or offline edge cases
        if (DateTime.now().difference(consentWaitStart).inSeconds > 45) {
          debugPrint('[LoadingScreen] Consent / isInit wait reached 45s timeout, continuing.');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Refresh RemoteConfig & preload Rewarded once SDK & Consent are ready
    if (!isTest) {
      try {
        AdsManager.preloadRewarded();
        // Wait for Remote Config to be ready from cloud if possible (max 1500ms)
        final rcStartTime = DateTime.now();
        while (!await FGSDK.isRemoteConfigReady() &&
            DateTime.now().difference(rcStartTime).inMilliseconds < 1500) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        await RemoteConfigService.fetchConfigs();
      } catch (_) {}
    }

    // Initialize IAP manager in background
    try {
      unawaited(IapManager.init());
    } catch (_) {}

    final isFirstSession = GameStorage.isFirstSession();

    // Show Splash ad for returning sessions WHILE loading (at ~88%)
    // Wait up to 4000ms for cold-start network download (typically ~2.2s on iOS/Android).
    if (!isFirstSession && !GameStorage.isNoAdsPurchased() && !isTest) {
      await AdsManager.showSplashAd(timeoutMs: 4000);
    }

    // Mark init as finished so timer drives progress smoothly to 100%
    initFinished = true;

    // Wait until progress actually completes to 100%
    while (_progress < 1.0) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 25));
    }

    if (!mounted) return;
    _progressTimer?.cancel();

    // Ensure state reflects 100%
    setState(() {
      _progress = 1.0;
    });

    final loadDuration = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    AnalyticsService.logLoadingFinish(placement: 'splash', success: true, value: loadDuration);
    if (isFirstSession) {
      AnalyticsService.logTutorial(name: 'ftue_loading_end', value: 2);
    }

    // Brief 120ms visual confirmation of 100% then immediately navigate
    await Future.delayed(const Duration(milliseconds: 120));

    AdsManager.setSplashInProgress(false);
    if (!mounted) return;
    final nav = Navigator.of(context);

    if (isFirstSession) {
      nav.pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => const FirstLanguageScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      );
    } else {
      nav.pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6B42A6),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-bleed background with floating tiles and bottom scrabble tiles
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_loading_splash.webp',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Fore-layer interactive UI: Glowing Logo + Loading... + Progress Capsule
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 32),

                // Center Word Connect Logo with ambient radial glow
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Soft warm radial light halo
                    Container(
                      width: 290.w,
                      height: 180.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),

                    // Logo Artwork
                    Image.asset(
                      'assets/icons/logo_loading_splash.webp',
                      width: 310.w,
                      fit: BoxFit.contain,
                    ),
                  ],
                )
                    .animate()
                    .scale(
                      duration: 650.ms,
                      curve: Curves.elasticOut,
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1.0, 1.0),
                    )
                    .then()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      duration: 2200.ms,
                      begin: const Offset(1.0, 1.0),
                      end: const Offset(1.025, 1.025),
                      curve: Curves.easeInOut,
                    ),

                const Spacer(flex: 18),

                // Animated Loading... status label with dynamic cycling dots & shimmer wave
                const AnimatedLoadingText(),

                SizedBox(height: 10.h),

                // Sleek Capsule Progress Bar with Percentage
                Container(
                  width: 250.w,
                  height: 28.h,
                  padding: EdgeInsets.all(2.5.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2D38),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: const Color(0xFFF3ECE4),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 2.5),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final maxW = constraints.maxWidth;
                          final barW = (maxW * _progress.clamp(0.0, 1.0));
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: barW,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF5FE86D), // bright top lime highlight
                                    Color(0xFF32D34E), // rich emerald green
                                    Color(0xFF1EAE3A), // deep green base
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x664ADE80),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Centered percentage inside the progress capsule
                      Text(
                        '${(_progress.clamp(0.0, 1.0) * 100).toInt()}%',
                        textScaler: TextScaler.noScaling,
                        strutStyle: StrutStyle(
                          fontSize: 12.5.sp,
                          height: 1.0,
                          forceStrutHeight: true,
                        ),
                        style: AppTypography.font(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          shadows: const [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 1.2),
                              blurRadius: 2.5,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 500.ms),

                const Spacer(flex: 38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated loading text with dynamic cycling dots & continuous shimmer wave.
/// Optical center alignment balances trailing dots with hidden phantom dots to prevent layout jitter.
class AnimatedLoadingText extends StatefulWidget {
  final TextStyle? style;

  const AnimatedLoadingText({super.key, this.style});

  @override
  State<AnimatedLoadingText> createState() => _AnimatedLoadingTextState();
}

class _AnimatedLoadingTextState extends State<AnimatedLoadingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ??
        AppTypography.font(
          fontSize: 17.sp,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(
              color: Color(0x99000000),
              offset: Offset(0, 1.5),
              blurRadius: 4,
            ),
          ],
        );

    final rawText = AppLocalization.tr('loading');
    final baseText = rawText.replaceAll('.', '').trim();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final dotCount = (_controller.value * 4).floor().clamp(0, 3);
        final dots = '.' * dotCount;

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left invisible placeholder matches width of 3 dots for exact optical center
            Opacity(
              opacity: 0.0,
              child: Text('...', style: baseStyle),
            ),
            Text(baseText, style: baseStyle),
            // Right slot with fixed width of 3 dots displaying active dots
            Stack(
              alignment: Alignment.centerLeft,
              children: [
                Opacity(
                  opacity: 0.0,
                  child: Text('...', style: baseStyle),
                ),
                Text(dots, style: baseStyle),
              ],
            ),
          ],
        );
      },
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1800.ms,
          color: Colors.white.withValues(alpha: 0.75),
        );
  }
}

