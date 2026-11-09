import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/game_controller.dart';
import '../../models/chapter_model.dart';
import '../../services/ads_manager.dart';
import '../../services/analytics_service.dart';
import '../../services/app_localization.dart';
import '../../services/audio_manager.dart';
import '../../services/game_storage.dart';
import '../../theme/app_typography.dart';
import '../../utils/game_transitions.dart';
import '../widgets/bouncy_button.dart';
import '../shop_screen.dart';
import 'remove_ads_dialog.dart';
import 'dictionary_dialog.dart';
import '../../services/no_ads_trigger_service.dart';
import '../../services/remote_config_service.dart';

enum VictoryStep {
  congrats,
  chapterPreview,
}

/// Helper model & generator for rich celebratory messages on victory.
/// Combines global percentile stats with skill-based compliments.
class VictoryMessage {
  final String prefix;
  final String? highlight;
  final String suffix;

  const VictoryMessage({
    required this.prefix,
    this.highlight,
    this.suffix = '',
  });

  static VictoryMessage generate({
    required int levelNumber,
    required bool isChapterMilestone,
    Random? random,
  }) {
    final rng = random ?? Random();

    if (isChapterMilestone) {
      return const VictoryMessage(
        prefix: 'Chapter Conquered!\n',
        highlight: 'Top 1%',
        suffix: ' Elite Master!',
      );
    }

    // Dynamic percentile scaling with level:
    // Level 1-3: ~55-65%
    // Level 4-10: ~68-79%
    // Level 11-25: ~80-89%
    // Level 26-50: ~90-95%
    // Level 51+: ~96-99%
    int basePercentile;
    if (levelNumber <= 3) {
      basePercentile = 55 + (levelNumber * 3) + rng.nextInt(3);
    } else if (levelNumber <= 10) {
      basePercentile = 68 + ((levelNumber - 3) * 1.5).round() + rng.nextInt(3);
    } else if (levelNumber <= 25) {
      basePercentile = 80 + ((levelNumber - 10) * 0.6).round() + rng.nextInt(3);
    } else if (levelNumber <= 50) {
      basePercentile = 90 + ((levelNumber - 25) * 0.2).round() + rng.nextInt(2);
    } else {
      basePercentile = min(99, 96 + rng.nextInt(4));
    }
    final percentile = basePercentile.clamp(50, 99);
    final topPercent = max(1, 100 - percentile);

    final templates = <VictoryMessage>[
      // Global Brain / Percentile Templates
      VictoryMessage(
        prefix: 'Smarter than ',
        highlight: '$percentile%',
        suffix: '\nof players worldwide!',
      ),
      VictoryMessage(
        prefix: 'You outsmarted\n',
        highlight: '$percentile%',
        suffix: ' of the world!',
      ),
      VictoryMessage(
        prefix: 'Top ',
        highlight: '$topPercent%',
        suffix: ' brain power!\nPure genius!',
      ),
      VictoryMessage(
        prefix: 'Ahead of ',
        highlight: '$percentile%',
        suffix: ' of\npeople on Earth!',
      ),
      VictoryMessage(
        prefix: 'Only ',
        highlight: '$topPercent%',
        suffix: ' could solve\nthis so fast!',
      ),
      VictoryMessage(
        prefix: 'Sharp mind!\nTop ',
        highlight: '$topPercent%',
        suffix: ' worldwide!',
      ),

      // Arcade / Compliment Templates
      const VictoryMessage(
        prefix: 'This level was\n',
        highlight: 'no match',
        suffix: ' for you!',
      ),
      const VictoryMessage(
        prefix: 'Pure genius!\n',
        highlight: 'You nailed it!',
      ),
      const VictoryMessage(
        prefix: 'Wordsmith master\n',
        highlight: 'at work!',
      ),
      const VictoryMessage(
        prefix: 'Too easy for a\n',
        highlight: 'pro like you!',
      ),
      const VictoryMessage(
        prefix: 'Unstoppable streak!\n',
        highlight: 'Flawless play!',
      ),
      const VictoryMessage(
        prefix: 'Spot on!\n',
        highlight: 'That was impressive!',
      ),
    ];

    return templates[rng.nextInt(templates.length)];
  }
}

class VictoryOverlay extends StatefulWidget {
  final GameController controller;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;

  const VictoryOverlay({
    super.key,
    required this.controller,
    required this.onNextLevel,
    required this.onReplay,
  });

  @override
  State<VictoryOverlay> createState() => _VictoryOverlayState();
}

class _VictoryOverlayState extends State<VictoryOverlay>
    with SingleTickerProviderStateMixin {
  VictoryStep _currentStep = VictoryStep.congrats;
  late ConfettiController _confettiController;
  late AnimationController _previewSlideController;
  late Animation<Offset> _oldCardSlideAnimation;
  late Animation<double> _oldCardFadeAnimation;
  late Animation<Offset> _newCardSlideAnimation;
  late Animation<double> _newCardFadeAnimation;
  late final VictoryMessage _victoryMessage;

  Timer? _previewSlideTimer;
  Timer? _previewSoundTimer;
  Timer? _autoAdvanceTimer;
  bool _hasNavigated = false;
  bool _claimedDouble = false;
  bool _isLoadingReward = false;

  @override
  void initState() {
    super.initState();
    _victoryMessage = VictoryMessage.generate(
      levelNumber: widget.controller.levelNumber,
      isChapterMilestone: widget.controller.isLastLevelOfChapter,
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _confettiController.play();

    _previewSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _oldCardSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.2, 0.0),
    ).animate(CurvedAnimation(
      parent: _previewSlideController,
      curve: Curves.easeInOutCubic,
    ));

    _oldCardFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _previewSlideController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
    ));

    _newCardSlideAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _previewSlideController,
      curve: Curves.easeInOutCubic,
    ));

    _newCardFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _previewSlideController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _previewSlideTimer?.cancel();
    _previewSoundTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _previewSlideController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleContinue({bool skipAd = false}) {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _previewSlideTimer?.cancel();
    _previewSoundTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    final shouldShowNoAds = NoAdsTriggerService.shouldShowCase2();

    void proceedToNextStep() {
      if (!mounted) return;
      if (shouldShowNoAds) {
        NoAdsTriggerService.onCase2Triggered();
        RemoveAdsDialog.show(
          context,
          level: widget.controller.levelNumber,
          location: 'endgame_periodic_win',
          onClosed: () {
            if (mounted) {
              widget.onNextLevel();
            }
          },
        );
      } else {
        widget.onNextLevel();
      }
    }

    // If user already watched rewarded ad on this victory dialog, NEVER show an interstitial ad
    if (skipAd || _claimedDouble) {
      debugPrint('[VictoryDialog] Rewarded ad was watched -> skipping Endgame Interstitial.');
      proceedToNextStep();
      return;
    }

    AdsManager.showInterEndgame(
      levelNumber: widget.controller.levelNumber,
      onCompleted: (bool adWasShown) {
        proceedToNextStep();
      },
    );
  }

  void _goToChapterPreview() {
    AudioManager.playTileSelect(pitchIndex: 4);
    final theme = ChapterTheme.forChapter(widget.controller.chapterNumber);
    GameStorage.addCoins(theme.rewardCoins);
    AnalyticsService.logEarnResource(
      level: widget.controller.levelNumber,
      type: 'currency',
      name: 'gold',
      amount: theme.rewardCoins.toDouble(),
      reason: 'win_level',
      balance: GameStorage.getCoins().toDouble(),
    );

    setState(() {
      _currentStep = VictoryStep.chapterPreview;
    });

    _previewSlideTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _previewSlideController.forward();
      }
    });

    _previewSoundTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        AudioManager.playTileSelect(pitchIndex: 5);
      }
    });

    _autoAdvanceTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _handleContinue();
      }
    });
  }

  void _claimDoubleCoins() {
    if (_isLoadingReward || _claimedDouble) return;
    setState(() => _isLoadingReward = true);

    AdsManager.showDoubleCoinReward(
      levelNumber: widget.controller.levelNumber,
      onRewardResult: (success) {
        if (!mounted) return;
        setState(() => _isLoadingReward = false);
        if (success) {
          final bonusCoins = widget.controller.coinsReward;
          GameStorage.addCoins(bonusCoins);
          AnalyticsService.logEarnResource(
            level: widget.controller.levelNumber,
            type: 'currency',
            name: 'gold',
            amount: bonusCoins.toDouble(),
            reason: 'ads',
            balance: GameStorage.getCoins().toDouble(),
          );
          if (mounted) {
            setState(() => _claimedDouble = true);
          }
          AudioManager.playWordMatch();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 +$bonusCoins coins added!',
                style: AppTypography.font(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 1),
            ),
          );

          // Auto-advance after watching rewarded ad:
          // If chapter milestone: transition to Chapter Preview (which awards chapter bonus & auto-advances to next level)
          // If normal level: advance directly to next level without any interstitial ad
          final isChapterMilestone = widget.controller.isLastLevelOfChapter;
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            if (isChapterMilestone) {
              _goToChapterPreview();
            } else {
              _handleContinue(skipAd: true);
            }
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ad not available. Please check your connection and try again.',
                style: AppTypography.font(fontWeight: FontWeight.w600),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _openShop() {
    AudioManager.playTileSelect(pitchIndex: 4);
    Navigator.push(
      context,
      GamePageRoute(
        child: ShopScreen(
          currentLevel: widget.controller.levelNumber,
          onClosed: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: BouncyButton(
        onTap: _openShop,
        child: SizedBox(
          height: 44.h,
          child: IntrinsicWidth(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  margin: EdgeInsets.only(left: 18.w),
                  height: 34.h,
                  constraints: BoxConstraints(minWidth: 78.w),
                  padding: EdgeInsets.only(left: 20.w, right: 14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF041026).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: ValueListenableBuilder<int>(
                    valueListenable: GameStorage.coinsNotifier,
                    builder: (context, coins, _) {
                      return Text(
                        '$coins',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      );
                    },
                  ),
                ),
                Image.asset(
                  'assets/icons/icon_coin.webp',
                  width: 44.r,
                  height: 44.r,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterCard({
    required ChapterTheme theme,
    required bool isCompleted,
    int? bonusCoins,
  }) {
    return Container(
      width: 290.w,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: const Color(0xFF041026).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isCompleted ? const Color(0xFF3EEC62) : const Color(0xFFFFD700),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCompleted ? const Color(0xFF3EEC62) : const Color(0xFFFFD700)).withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status Pill Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFF59E0B), const Color(0xFFFFB300)],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  offset: const Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.lock_open_rounded,
                  color: Colors.white,
                  size: 14.sp,
                ),
                SizedBox(width: 5.w),
                Flexible(
                  child: Text(
                    isCompleted ? 'CHAPTER ${theme.chapterNumber} COMPLETED' : 'NEW CHAPTER UNLOCKED!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),

          // Custom Landscape Artwork
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: SizedBox(
              width: double.infinity,
              height: 160.h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ChapterLandscapePainter(
                        theme: theme,
                        progress: 1.0,
                        showSunGlow: true,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Chapter Title & Subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                theme.emoji,
                style: TextStyle(fontSize: 22.sp),
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  theme.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.font(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            theme.subtitle,
            style: AppTypography.font(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),

          if (bonusCoins != null) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF132A1F),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: const Color(0xFF3EEC62).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icons/icon_coin.webp',
                    width: 18.r,
                    height: 18.r,
                  ),
                  SizedBox(width: 5.w),
                  Flexible(
                    child: Text(
                      '+$bonusCoins Chapter Bonus!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.font(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterVictoryView() {
    final oldChapter = widget.controller.chapterNumber;
    final nextChapter = oldChapter + 1;
    final oldTheme = ChapterTheme.forChapter(oldChapter);
    final nextTheme = ChapterTheme.forChapter(nextChapter);

    return Column(
      children: [
        SizedBox(height: 8.h),
        // Top Bar: Coins Capsule on Left
        _buildTopBar(),

        SizedBox(height: 0.015.sh),

        // Title Header with Pulse
        Text(
          'CHAPTER COMPLETE!',
          textAlign: TextAlign.center,
          style: AppTypography.font(
            fontSize: 26.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFD700),
            letterSpacing: 1.0,
            shadows: const [
              Shadow(
                color: Color(0xFF8B4513),
                offset: Offset(0, 3),
                blurRadius: 6,
              ),
              Shadow(
                color: Colors.black45,
                offset: Offset(0, 5),
                blurRadius: 10,
              ),
            ],
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

        SizedBox(height: 4.h),
        Text(
          'Next chapter unlocked!',
          style: AppTypography.font(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        SizedBox(height: 0.015.sh),

        // Sliding Chapter Cards Container with ClipRect
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ClipRect(
                child: SizedBox(
                  width: 320.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Old Chapter Card (slides out to left)
                      SlideTransition(
                        position: _oldCardSlideAnimation,
                        child: FadeTransition(
                          opacity: _oldCardFadeAnimation,
                          child: _buildChapterCard(
                            theme: oldTheme,
                            isCompleted: true,
                          ),
                        ),
                      ),

                      // New Chapter Card (slides in from right)
                      SlideTransition(
                        position: _newCardSlideAnimation,
                        child: FadeTransition(
                          opacity: _newCardFadeAnimation,
                          child: _buildChapterCard(
                            theme: nextTheme,
                            isCompleted: false,
                            bonusCoins: oldTheme.rewardCoins,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: 0.015.sh),

        // Bottom CTA Button: Next Chapter / Level X
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: SizedBox(
                  width: 170.w,
                  child: BouncyButton(
                    onTap: _handleContinue,
                    child: SizedBox(
                      height: 68.h,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/btn_green_victory.png',
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.fill,
                          ),
                          CartoonText(
                            text: AppLocalization.tr('level_n', args: [widget.controller.levelNumber + 1]),
                            fontSize: 22.sp,
                            textColor: Colors.white,
                            outlineColor: const Color(0xFF0E5606),
                            strokeWidth: 3.5,
                            shadowOffset: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Auto-advancing to next level...',
                style: AppTypography.font(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalVictoryView() {
    final isChapterMilestone = widget.controller.isLastLevelOfChapter;
    final chapterInfo = widget.controller.chapterInfo;
    final currentLvlInChapter = min(chapterInfo.levelInChapter, chapterInfo.totalLevelsInChapter);
    final totalLevelsInChapter = chapterInfo.totalLevelsInChapter;
    final progressFraction = (currentLvlInChapter / totalLevelsInChapter).clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(height: 8.h),
        // Top Bar: Coins Capsule on Left
        _buildTopBar(),

        const Spacer(flex: 1),
        // Center: Golden Crown & Congrats graphic with glowing light aura
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 280.r,
              height: 180.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFE082).withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Image.asset(
              'assets/icons/icon_congrats.webp',
              width: 290.r,
              fit: BoxFit.contain,
            ),
          ],
        )
            .animate()
            .scale(
              duration: 600.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.3, 0.3),
              end: const Offset(1.0, 1.0),
            ),

        const Spacer(flex: 1),

        // Message Capsule: Dynamic celebratory message with % percentile or skill compliments
        Container(
          constraints: BoxConstraints(maxWidth: 320.w),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF041026).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28.r),
            border: Border.all(color: Colors.white, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text.rich(
            TextSpan(
              style: AppTypography.font(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
              ),
              children: [
                TextSpan(text: _victoryMessage.prefix),
                if (_victoryMessage.highlight != null)
                  TextSpan(
                    text: _victoryMessage.highlight,
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: const Color(0xFFFF9100).withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                if (_victoryMessage.suffix.isNotEmpty)
                  TextSpan(text: _victoryMessage.suffix),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms, delay: 200.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),

        const Spacer(flex: 2),

        // Chapter Progress Bar with Coin Reward Stack
        SizedBox(
          width: 250.r,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Progress Bar Track Capsule
              Container(
                width: 226.r,
                height: 30.h,
                padding: EdgeInsets.all(2.5.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF041026).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(11.r),
                  border: Border.all(color: Colors.white, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    return Stack(
                      children: [
                        // Green Progress Fill
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: maxW * progressFraction,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.r),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF3EEC62),
                                  Color(0xFF23D046),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Centered "2/5" Text
                        Center(
                          child: Text(
                            '$currentLvlInChapter/$totalLevelsInChapter',
                            style: AppTypography.font(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Gold Coin Stack Anchor at Right Edge
              Positioned(
                right: 0,
                top: -4.h,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'assets/icons/icon_coin_victory.webp',
                      width: 55.r,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      right: 5,
                      bottom: -8,
                      child: Text(
                        '${widget.controller.coinsReward}',
                        style: AppTypography.font(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Color(0xFF0D2540),
                              offset: Offset(0, 1.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 350.ms),

        const Spacer(flex: 1),

        if (RemoteConfigService.isDictionaryAvailableForLevel(widget.controller.levelNumber))
          Padding(
            padding: EdgeInsets.only(bottom: 4.h),
            child: BouncyButton(
              onTap: () {
                AudioManager.playTileSelect(pitchIndex: 4);
                final solvedTargets = widget.controller.level.targetWords
                    .map((tw) => tw.word.toUpperCase())
                    .where((w) => widget.controller.solvedTargetWords.contains(w))
                    .toList();
                final extraWords = widget.controller.foundExtraWords
                    .map((w) => w.toUpperCase())
                    .toList();
                final foundWords = {...solvedTargets, ...extraWords}.toList();

                DictionaryDialog.show(
                  context,
                  words: foundWords,
                  language: widget.controller.language,
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6.w),
                    Text(
                      'Word Meanings 📖',
                      style: AppTypography.font(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 400.ms),

        const Spacer(flex: 1),

        Builder(
          builder: (context) {
            final showRewardButton = widget.controller.levelNumber >= 8;

            Widget buildNextLevelBtn() {
              return BouncyButton(
                onTap: _isLoadingReward
                    ? null
                    : (isChapterMilestone ? _goToChapterPreview : _handleContinue),
                child: SizedBox(
                  height: 68.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/btn_green_victory.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.fill,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: CartoonText(
                            text: isChapterMilestone
                                ? AppLocalization.tr('next_chapter')
                                : AppLocalization.tr('level_n', args: [widget.controller.levelNumber + 1]),
                            fontSize: isChapterMilestone ? 19.sp : 22.sp,
                            textColor: Colors.white,
                            outlineColor: const Color(0xFF0E5606),
                            strokeWidth: 3.5,
                            shadowOffset: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget buildRewardBtn() {
              return BouncyButton(
                onTap: _isLoadingReward || _claimedDouble ? null : _claimDoubleCoins,
                child: SizedBox(
                  height: 68.h,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/btn_blue_victory.png',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.fill,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10.w),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _isLoadingReward
                              ? SizedBox(
                                  width: 22.r,
                                  height: 22.r,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : _claimedDouble
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Claimed!',
                                          style: AppTypography.font(
                                            fontSize: 18.sp,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset(
                                          'assets/icons/icon_ads.webp',
                                          width: 32.r,
                                          height: 32.r,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(width: 6.w),
                                        Image.asset(
                                          'assets/icons/icon_coin.webp',
                                          width: 22.r,
                                          height: 22.r,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(width: 4.w),
                                        CartoonText(
                                          text: '${widget.controller.coinsReward}',
                                          fontSize: 22.sp,
                                          textColor: Colors.white,
                                          outlineColor: const Color(0xFF0F4778),
                                          strokeWidth: 3.5,
                                          shadowOffset: 1.5,
                                        ),
                                      ],
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!showRewardButton) {
              return Center(
                child: SizedBox(
                  width: isChapterMilestone ? 185.w : 170.w,
                  child: buildNextLevelBtn(),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Expanded(child: buildNextLevelBtn()),
                  SizedBox(width: 14.w),
                  Expanded(child: buildRewardBtn()),
                ],
              ),
            );
          },
        ).animate().fadeIn(duration: 400.ms, delay: 450.ms),
        const Spacer(flex: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChapterMilestone = widget.controller.isLastLevelOfChapter;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 1. Deep Ocean Navy / Dark Blue Fullscreen Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF020E24),
                      Color(0xFF02173B),
                      Color(0xFF01091A),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Celebratory Confetti Cascade (Vibrant arcade colors)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFF00E5FF), // Cyan
                  Color(0xFFFF4081), // Pink
                  Color(0xFFFFD700), // Gold
                  Color(0xFF00E676), // Green
                  Color(0xFFFF9100), // Orange
                  Colors.white,
                ],
                numberOfParticles: 35,
                gravity: 0.12,
              ),
            ),

            // 3. Foreground Layout
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: isChapterMilestone
                    ? (_currentStep == VictoryStep.congrats
                        ? _buildNormalVictoryView()
                        : _buildChapterVictoryView())
                    : _buildNormalVictoryView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
