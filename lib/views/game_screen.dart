import 'dart:async';
import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../controllers/game_controller.dart';
import '../models/chapter_model.dart';
import '../services/ads_manager.dart';
import '../services/analytics_service.dart';
import '../services/app_localization.dart';
import '../services/audio_manager.dart';
import '../services/game_storage.dart';
import '../services/level_loader.dart';
import '../services/remote_config_service.dart';
import '../theme/app_theme.dart';
import '../utils/game_transitions.dart';
import '../widgets/common/game_button.dart';
import '../widgets/common/game_scaffold.dart';
import 'home_screen.dart';
import 'level_select_screen.dart';
import 'widgets/board_widget.dart';
import 'widgets/booster_bar.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/extra_word_fly_effect.dart';
import 'widgets/extra_words_dialog.dart';
import 'widgets/settings_dialog.dart';
import 'shop_screen.dart';
import 'widgets/target_words_bar.dart';
import 'widgets/tutorial_overlay.dart';
import 'widgets/victory_dialog.dart';
import 'widgets/remove_ads_dialog.dart';
import 'widgets/dictionary_dialog.dart';

class GameScreen extends StatefulWidget {
  final String language;
  final int levelIndex;

  const GameScreen({
    super.key,
    required this.language,
    required this.levelIndex,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GlobalKey<TargetWordsBarState> _targetWordsKey = GlobalKey<TargetWordsBarState>();
  GlobalKey<BoardWidgetState> _boardKey = GlobalKey<BoardWidgetState>();
  GlobalKey<ExtraWordsButtonState> _extraWordsBtnKey = GlobalKey<ExtraWordsButtonState>();
  GlobalKey _hintBtnKey = GlobalKey();
  GlobalKey _rocketBtnKey = GlobalKey();
  final ValueNotifier<double?> _popupMidYNotifier = ValueNotifier<double?>(null);

  GameController? _controller;
  late ConfettiController _confettiController;
  bool _isLoading = true;
  String? _errorMessage;
  late int _currentLevelIndex;

  int _lastSolvedWordsCount = 0;
  bool _lastIsWon = false;
  List<Point<int>>? _lastFailSafeHintPath;
  int _lastExtraFoundCount = 0;
  int _dismissedLevel1Step = -1;

  bool _hasEndedThisLevel = false;

  void _logLevelEnd({required String reason}) {
    if (_controller == null || _controller!.isWon || _hasEndedThisLevel) return;
    _hasEndedThisLevel = true;
    final lvl = _currentLevelIndex + 1;
    final playCount = GameStorage.getLevelPlayCount(widget.language, lvl);
    var loseCount = GameStorage.getLevelLoseCount(widget.language, lvl);
    final durationSec = (DateTime.now().difference(_controller!.levelStartTime).inMilliseconds / 1000.0) - _controller!.adDurationSeconds;
    final playDuration = durationSec > 0 ? durationSec : 0.0;

    if (reason == 'quit' || reason == 'restart') {
      unawaited(GameStorage.incrementLevelLoseCount(widget.language, lvl));
      unawaited(GameStorage.incrementLoseStreak());
      loseCount++;
      AnalyticsService.updateUserProperties(level: lvl);
    }

    AnalyticsService.logLevelEnd(
      level: lvl,
      playCount: playCount > 0 ? playCount : 1,
      loseCount: loseCount,
      playDuration: playDuration,
      totalItems: _controller!.level.targetWords.length,
      clearedItems: _controller!.solvedTargetWords.length,
      success: false,
      reason: reason,
      adDuration: _controller!.adDurationSeconds,
    );
  }

  void _logLevelBackground() {
    if (_controller == null || _controller!.isWon || _hasEndedThisLevel) return;
    final lvl = _currentLevelIndex + 1;
    final playCount = GameStorage.getLevelPlayCount(widget.language, lvl);
    final loseCount = GameStorage.getLevelLoseCount(widget.language, lvl);
    final durationSec = (DateTime.now().difference(_controller!.levelStartTime).inMilliseconds / 1000.0) - _controller!.adDurationSeconds;
    final playDuration = durationSec > 0 ? durationSec : 0.0;

    AnalyticsService.logLevelExit(
      level: lvl,
      playCount: playCount > 0 ? playCount : 1,
      loseCount: loseCount,
      playDuration: playDuration,
      totalItems: _controller!.level.targetWords.length,
      clearedItems: _controller!.solvedTargetWords.length,
      reason: 'background',
    );
  }

  void _logLevelReopen() {
    if (_controller == null || _controller!.isWon || _hasEndedThisLevel) return;
    final lvl = _currentLevelIndex + 1;
    final playCount = GameStorage.getLevelPlayCount(widget.language, lvl);
    final loseCount = GameStorage.getLevelLoseCount(widget.language, lvl);

    AnalyticsService.logLevelReopen(
      level: lvl,
      playCount: playCount > 0 ? playCount : 1,
      loseCount: loseCount,
      totalItems: _controller!.level.targetWords.length,
      clearedItems: _controller!.solvedTargetWords.length,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdsManager.hideBanner();
    _currentLevelIndex = widget.levelIndex;
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _loadGame();
  }

  @override
  void dispose() {
    _logLevelEnd(reason: 'quit');
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _popupMidYNotifier.dispose();
    _controller?.removeListener(_onGameControllerStateChanged);
    _controller?.dispose();
    AdsManager.showBanner('bottom', level: _currentLevelIndex + 1);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      _controller?.saveProgress();
      _logLevelBackground();
    } else if (state == AppLifecycleState.resumed) {
      _logLevelReopen();
    }
  }

  void _onGameControllerStateChanged() {
    if (!mounted || _controller == null) return;
    final isWon = _controller!.isWon;
    final solvedCount = _controller!.solvedTargetWords.length;
    final failSafePath = _controller!.failSafeHintPath;
    final extraFoundCount = _controller!.foundExtraWords.length;

    if (isWon != _lastIsWon ||
        solvedCount != _lastSolvedWordsCount ||
        failSafePath != _lastFailSafeHintPath ||
        extraFoundCount != _lastExtraFoundCount) {
      _lastIsWon = isWon;
      _lastSolvedWordsCount = solvedCount;
      _lastFailSafeHintPath = failSafePath;
      _lastExtraFoundCount = extraFoundCount;
      setState(() {});
    }
  }

  Future<void> _loadGame({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final levelIds = await LevelLoader.loadLevelList(widget.language);
      if (levelIds.isEmpty) {
        throw Exception('No levels found for ${widget.language}');
      }

      if (_currentLevelIndex >= levelIds.length) {
        _currentLevelIndex = levelIds.length - 1;
      }

      final levelId = levelIds[_currentLevelIndex];
      final level = await LevelLoader.loadLevel(widget.language, levelId);
      if (level == null) {
        throw Exception('Failed to load level $levelId');
      }

      await GameStorage.setCurrentLevelIndex(widget.language, _currentLevelIndex);

      _controller?.removeListener(_onGameControllerStateChanged);
      _controller?.dispose();

      _controller = GameController(
        language: widget.language,
        levelId: levelId,
        levelNumber: _currentLevelIndex + 1,
        level: level,
      );
      _lastSolvedWordsCount = 0;
      _lastIsWon = false;
      _lastFailSafeHintPath = null;
      _lastExtraFoundCount = 0;
      _hasEndedThisLevel = false;
      _dismissedLevel1Step = -1;
      _controller!.addListener(_onGameControllerStateChanged);

      final currentLvlNumber = _currentLevelIndex + 1;
      final playCount = await GameStorage.incrementLevelPlayCount(widget.language, currentLvlNumber);
      final loseCount = GameStorage.getLevelLoseCount(widget.language, currentLvlNumber);

      AnalyticsService.logLevelStart(
        level: currentLvlNumber,
        playCount: playCount,
        loseCount: loseCount,
      );
      AnalyticsService.updateUserProperties(level: currentLvlNumber);
      AdsManager.hideBanner();

      if (_currentLevelIndex == 0 && !GameStorage.isTutorialCompleted()) {
        AnalyticsService.logTutorial(name: 'tut_start', value: 3);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load level: $e';
      });
    }
  }

  void _nextLevel() {
    setState(() {
      _currentLevelIndex++;
      _targetWordsKey = GlobalKey<TargetWordsBarState>();
      _boardKey = GlobalKey<BoardWidgetState>();
      _extraWordsBtnKey = GlobalKey<ExtraWordsButtonState>();
      _hintBtnKey = GlobalKey();
      _rocketBtnKey = GlobalKey();
      _popupMidYNotifier.value = null;
      _dismissedLevel1Step = -1;
    });
    _loadGame(showLoading: false);
  }

  void _replayLevel() {
    _logLevelEnd(reason: 'restart');
    GameStorage.clearLevelProgress(widget.language, _currentLevelIndex + 1);
    setState(() {
      _targetWordsKey = GlobalKey<TargetWordsBarState>();
      _boardKey = GlobalKey<BoardWidgetState>();
      _extraWordsBtnKey = GlobalKey<ExtraWordsButtonState>();
      _hintBtnKey = GlobalKey();
      _rocketBtnKey = GlobalKey();
      _popupMidYNotifier.value = null;
    });
    _loadGame();
  }

  void _cheatJumpToLevel(int targetLevelNumber) {
    _logLevelEnd(reason: 'quit');
    final maxCount = LevelLoader.totalLevelsPerLanguage[widget.language] ?? 1500;
    final index = (targetLevelNumber - 1).clamp(0, maxCount - 1);
    GameStorage.setCurrentLevelIndex(widget.language, index);
    GameStorage.setMaxUnlockedLevelIndex(widget.language, index);
    setState(() {
      _currentLevelIndex = index;
      _targetWordsKey = GlobalKey<TargetWordsBarState>();
      _boardKey = GlobalKey<BoardWidgetState>();
      _extraWordsBtnKey = GlobalKey<ExtraWordsButtonState>();
      _hintBtnKey = GlobalKey();
      _rocketBtnKey = GlobalKey();
      _popupMidYNotifier.value = null;
    });
    _loadGame();
  }

  void _cheatNextLevel() {
    _logLevelEnd(reason: 'quit');
    final maxCount = LevelLoader.totalLevelsPerLanguage[widget.language] ?? 1500;
    final nextIndex = (_currentLevelIndex + 1).clamp(0, maxCount - 1);
    GameStorage.setCurrentLevelIndex(widget.language, nextIndex);
    GameStorage.setMaxUnlockedLevelIndex(widget.language, nextIndex);
    setState(() {
      _currentLevelIndex = nextIndex;
      _targetWordsKey = GlobalKey<TargetWordsBarState>();
      _boardKey = GlobalKey<BoardWidgetState>();
      _extraWordsBtnKey = GlobalKey<ExtraWordsButtonState>();
      _hintBtnKey = GlobalKey();
      _rocketBtnKey = GlobalKey();
      _popupMidYNotifier.value = null;
    });
    _loadGame(showLoading: false);
  }

  void _openSettings() {
    AudioManager.playTileSelect(pitchIndex: 4);
    showGameDialog(
      context: context,
      builder: (context) => SettingsDialog(
        isHomeScreen: false,
        controller: _controller,
        onJumpToLevel: _cheatJumpToLevel,
        onNextLevel: _cheatNextLevel,
        onRestartLevel: () {
          _replayLevel();
        },
        onGoHome: () {
          _logLevelEnd(reason: 'quit');
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _openExtraWords() {
    if (_controller == null) return;
    ExtraWordsDialog.show(
      context,
      controller: _controller!,
      onUpdated: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _openShop() {
    AudioManager.playTileSelect(pitchIndex: 4);
    Navigator.push(
      context,
      GamePageRoute(
        child: ShopScreen(
          currentLevel: widget.levelIndex + 1,
          onClosed: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
        AdsManager.hideBanner();
      }
    });
  }

  void _openDailyGift() {
    _openShop();
  }

  void _openDictionary([String? initialWord]) {
    if (_controller == null) return;

    // Only display words that the user has already found!
    final solvedTargets = _controller!.level.targetWords
        .map((tw) => tw.word.toUpperCase())
        .where((w) => _controller!.solvedTargetWords.contains(w))
        .toList();
    final extraWords = _controller!.foundExtraWords
        .map((w) => w.toUpperCase())
        .toList();

    final foundWords = {...solvedTargets, ...extraWords}.toList();

    if (foundWords.isEmpty) {
      AudioManager.playTileSelect(pitchIndex: 2);
      _controller?.showFeedback(
        AppLocalization.tr('find_words_first'),
        const Color(0xFFFFD54F),
      );
      return;
    }

    DictionaryDialog.show(
      context,
      words: foundWords,
      initialWord: initialWord,
      language: widget.language,
    );
  }

  void _openLevelSelect() async {
    AudioManager.playTileSelect(pitchIndex: 3);
    final selectedIndex = await Navigator.push<int>(
      context,
      GamePageRoute(
        child: LevelSelectScreen(
          language: widget.language,
          isFromGame: true,
        ),
      ),
    );

    AdsManager.hideBanner();

    if (selectedIndex != null && selectedIndex != _currentLevelIndex && mounted) {
      _logLevelEnd(reason: 'quit');
      setState(() {
        _currentLevelIndex = selectedIndex;
      });
      _loadGame();
    }
  }

  bool _isHandlingTutorialBooster = false;

  void _onTutorialHintTap() {
    if (_isHandlingTutorialBooster) return;
    _isHandlingTutorialBooster = true;
    GameStorage.setHintTutorialShown(true);
    GameStorage.setLevel5FreeHintUsed(true);
    _controller?.useHint(isTutorialFree: true);
    if (mounted) setState(() {});
    Future.microtask(() => _isHandlingTutorialBooster = false);
  }

  void _onTutorialRocketTap() {
    if (_isHandlingTutorialBooster) return;
    _isHandlingTutorialBooster = true;
    GameStorage.setRocketTutorialShown(true);
    GameStorage.setLevel7FreeRocketUsed(true);
    _controller?.useRocket(isTutorialFree: true);
    if (mounted) setState(() {});
    Future.microtask(() => _isHandlingTutorialBooster = false);
  }

  Widget _buildBackground() {
    final chapterNumber = _controller?.chapterNumber ?? 1;
    final bgPath = ChapterTheme.getImagePath(chapterNumber);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: Image.asset(
        bgPath,
        key: ValueKey<String>(bgPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/bg_home.webp',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  void _updateDetectedMidY() {
    if (!mounted) return;
    final RenderBox? screenBox = context.findRenderObject() as RenderBox?;
    if (screenBox == null || !screenBox.hasSize) return;

    final targetBottomGlobal = _targetWordsKey.currentState?.getWordsBottomGlobal();
    final boardTopGlobal = _boardKey.currentState?.getBoardCardTopGlobal();

    if (targetBottomGlobal != null && boardTopGlobal != null && boardTopGlobal > targetBottomGlobal) {
      final localTargetBottom = screenBox.globalToLocal(Offset(0, targetBottomGlobal)).dy;
      final localBoardTop = screenBox.globalToLocal(Offset(0, boardTopGlobal)).dy;

      final midY = (localTargetBottom + localBoardTop) / 2;
      if (_popupMidYNotifier.value == null || (midY - _popupMidYNotifier.value!).abs() > 0.5) {
        _popupMidYNotifier.value = midY;
      }
    }
  }

  bool _isTouchInsideBoard(Offset globalPos) {
    final state = _boardKey.currentState;
    if (state == null) return false;
    return state.isPointInsideGrid(globalPos);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _controller == null) {
      return GameScaffold(
        useSafeArea: false,
        background: _buildBackground(),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.btnFaceBrown),
        ),
      );
    }

    if (_errorMessage != null || _controller == null) {
      return GameScaffold(
        background: _buildBackground(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Unknown error',
                  style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              GameButton.primary(
                text: 'Retry',
                size: GameButtonSize.small,
                onTap: _loadGame,
              ),
            ],
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateDetectedMidY());

    final isLevel1Tut = !_controller!.isWon &&
        !GameStorage.isTutorialCompleted() &&
        _controller!.levelNumber == 1 &&
        _controller!.solvedTargetWords.length < _controller!.level.targetWords.length &&
        _controller!.solvedTargetWords.length < 2 &&
        _dismissedLevel1Step < _controller!.solvedTargetWords.length;

    final isCountTut = !_controller!.isWon &&
        _controller!.levelNumber == 2 &&
        !GameStorage.isCountTutorialShown() &&
        _controller!.getFirstTileWithCountGreaterThanOne() != null;

    final isReverseTut = !_controller!.isWon &&
        _controller!.levelNumber == 4 &&
        !GameStorage.isReverseTutorialShown() &&
        _controller!.solvedTargetWords.isEmpty;

    if (_controller!.levelNumber == 4 &&
        _controller!.solvedTargetWords.isNotEmpty &&
        !GameStorage.isReverseTutorialShown()) {
      GameStorage.setReverseTutorialShown(true);
    }

    final isHintTut = !_controller!.isWon &&
        _controller!.levelNumber == 5 &&
        !GameStorage.isHintTutorialShown();

    final isExtraWordsTut = !_controller!.isWon &&
        _controller!.levelNumber == 6 &&
        !GameStorage.isExtraWordsTutorialShown();

    final isRocketTut = !_controller!.isWon &&
        _controller!.levelNumber == 7 &&
        !GameStorage.isRocketTutorialShown();

    final isDarkScrimTut = isLevel1Tut || isCountTut || isReverseTut || isHintTut || isExtraWordsTut || isRocketTut;

    return GameScaffold(
      useSafeArea: false,
      background: _buildBackground(),
      onWillPop: () async {
        _controller?.saveProgress();
        _logLevelEnd(reason: 'quit');
        if (Navigator.of(context).canPop()) {
          return true;
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
          return false;
        }
      },
      body: Stack(
        children: [
              // Dark background scrim behind gameplay when any tutorial is active
              if (isDarkScrimTut)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),

              // Main Playing Interface with Smooth Level Transition
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('level-$_currentLevelIndex'),
                  child: Column(
                    children: [
                      // Header (dimmed when tutorial is active)
                      AnimatedOpacity(
                        opacity: isDarkScrimTut ? 0.20 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: _buildHeader(),
                      ),
                      // TargetWordsBar with Side Buttons (Gift & Star Progress)
                      Expanded(
                        flex: 5,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: GameStorage.hideGameplayUINotifier,
                          builder: (context, hideUI, _) {
                            return Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.center,
                                  child: AnimatedOpacity(
                                    opacity: isDarkScrimTut ? 0.20 : 1.0,
                                    duration: const Duration(milliseconds: 250),
                                    child: TargetWordsBar(
                                      key: _targetWordsKey,
                                      controller: _controller!,
                                      onWordTap: (word) {
                                        if (RemoteConfigService.isDictionaryAvailableForLevel(_controller!.levelNumber)) {
                                          _openDictionary(word);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                // Left Side Utility Column: Gift Box Button on top, Remove Ads directly underneath
                                if (!hideUI)
                                  Positioned(
                                    top: 8.h,
                                    left: 16.w,
                                    child: AnimatedOpacity(
                                      opacity: isDarkScrimTut ? 0.20 : 1.0,
                                      duration: const Duration(milliseconds: 250),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          if (_controller!.levelNumber > 1)
                                            _buildGiftButton(),
                                          ValueListenableBuilder<bool>(
                                            valueListenable: GameStorage.noAdsNotifier,
                                            builder: (context, isPurchased, _) {
                                              if (isPurchased) return const SizedBox.shrink();
                                              return Padding(
                                                padding: EdgeInsets.only(top: _controller!.levelNumber > 1 ? 6.h : 0),
                                                child: _buildNoAdsIconButton(),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Right Star / Extra Words Button (Only shown when Extra Words is unlocked and not hidden by cheat)
                                if (_controller!.isExtraWordsUnlocked && !hideUI)
                                  Positioned(
                                    top: 8.h,
                                    right: 16.w,
                                    child: AnimatedOpacity(
                                      opacity: (isDarkScrimTut && !isExtraWordsTut) ? 0.20 : 1.0,
                                      duration: const Duration(milliseconds: 250),
                                      child: ExtraWordsButton(
                                        key: _extraWordsBtnKey,
                                        extraCount: GameStorage.getExtraWordsChestCount(),
                                        onTap: () {
                                          if (isExtraWordsTut) {
                                            GameStorage.setExtraWordsTutorialShown(true);
                                            setState(() {});
                                          }
                                          _openExtraWords();
                                        },
                                        isSpotlighted: isExtraWordsTut,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      // BoardWidget (Dimmed on Level 5 & Level 7 tutorials, full 100% on Level 1, 2, 4)
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: (isHintTut || isExtraWordsTut || isRocketTut) ? 0.20 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            child: BoardWidget(
                              key: _boardKey,
                              controller: _controller!,
                            ),
                          ),
                        ),
                      ),
                      // BoosterBar (Spotlighted on Level 5 Hint & Level 7 Rocket, dimmed on other tutorials, hidden by cheat)
                      ValueListenableBuilder<bool>(
                        valueListenable: GameStorage.hideGameplayUINotifier,
                        builder: (context, hideUI, _) {
                          if (hideUI) return const SizedBox.shrink();
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(height: 10.h),
                              AnimatedOpacity(
                                opacity: (isDarkScrimTut && !isHintTut && !isRocketTut) ? 0.20 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                child: IgnorePointer(
                                  ignoring: isDarkScrimTut && !isHintTut && !isRocketTut,
                                  child: BoosterBar(
                                    controller: _controller!,
                                    onOpenShop: _openShop,
                                    onOpenExtraWords: _openExtraWords,
                                    onHintTap: () {
                                      if (isHintTut) {
                                        _onTutorialHintTap();
                                      }
                                    },
                                    onRocketTap: () {
                                      if (isRocketTut) {
                                        _onTutorialRocketTap();
                                      }
                                    },
                                    isHintSpotlighted: isHintTut,
                                    isRocketSpotlighted: isRocketTut,
                                    extraWordsBtnKey: _extraWordsBtnKey,
                                    hintBtnKey: _hintBtnKey,
                                    rocketBtnKey: _rocketBtnKey,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Floating Preview & Feedback Popup dynamically centered between Target Words and Board Card
              ValueListenableBuilder<double?>(
                valueListenable: _popupMidYNotifier,
                builder: (context, midY, _) {
                  final effectiveMidY = midY ?? (MediaQuery.sizeOf(context).height * 0.44);
                  return Positioned(
                    top: effectiveMidY - 24.h,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: isDarkScrimTut ? 0.20 : 1.0,
                        duration: const Duration(milliseconds: 250),
                        child: _buildPreviewAndFeedback(),
                      ),
                    ),
                  );
                },
              ),

              // Level 1: Centered Floating Swipe Tutorial Modal (Step 1 & Step 2) with "Got it" Button
              if (isLevel1Tut)
                Positioned.fill(
                  child: Builder(
                    builder: (_) {
                      final solvedCount = _controller!.solvedTargetWords.length;
                      final nextWord = _controller!.getNextUnsolvedTargetWord() ?? 'SUN';
                      return Level1SwipeTutorialModal(
                        spans: solvedCount == 1
                            ? [
                                const TextSpan(text: 'You can go left, right, up, or down.\nSwipe the Word '),
                                TextSpan(
                                  text: '"$nextWord"',
                                  style: const TextStyle(
                                    color: Color(0xFFDD4C8E),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ]
                            : [
                                const TextSpan(text: 'Swipe the Word '),
                                TextSpan(
                                  text: '"$nextWord"',
                                  style: const TextStyle(
                                    color: Color(0xFFDD4C8E),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                        onDismiss: () {
                          _dismissedLevel1Step = solvedCount;
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
                ),

              // Level 2: Centered Tile Usage Count Explanation Modal
              if (isCountTut)
                Positioned.fill(
                  child: TileCountTutorialModal(
                    onDismiss: () => setState(() {}),
                  ),
                ),

              // Level 4: Centered Reverse Swipe Tutorial Card with Tap-Outside-to-Dismiss
              if (isReverseTut)
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (PointerDownEvent event) async {
                      if (!RemoteConfigService.tutorialTapOutsideClose) {
                        debugPrint('[Level4Tut] Tap outside ignored: tutorialTapOutsideClose is false');
                        return;
                      }
                      if (_isTouchInsideBoard(event.position)) return;
                      debugPrint('[Level4Tut] Tap outside board detected -> dismissing reverse tutorial');
                      await GameStorage.setReverseTutorialShown(true);
                      if (mounted) setState(() {});
                    },
                    child: SwipeTutorialCard(
                      spans: const [
                        TextSpan(text: 'You can also swipe\nwords '),
                        TextSpan(
                          text: 'backwards',
                          style: TextStyle(
                            color: Color(0xFFDD4C8E),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                      onDismiss: () async {
                        await GameStorage.setReverseTutorialShown(true);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),

              // Level 5 Hint Booster Tutorial Overlay
              if (isHintTut)
                Positioned.fill(
                  child: HintBoosterTutorialOverlay(
                    onDismiss: () => setState(() {}),
                    onBoosterTap: _onTutorialHintTap,
                    boosterBtnKey: _hintBtnKey,
                  ),
                ),

              // Level 6 Extra Words Tutorial Overlay
              if (isExtraWordsTut)
                Positioned.fill(
                  child: ExtraWordsTutorialOverlay(
                    onDismiss: () => setState(() {}),
                  ),
                ),

              // Level 7 Rocket Booster Tutorial Overlay
              if (isRocketTut)
                Positioned.fill(
                  child: RocketBoosterTutorialOverlay(
                    onDismiss: () => setState(() {}),
                    onBoosterTap: _onTutorialRocketTap,
                    boosterBtnKey: _rocketBtnKey,
                  ),
                ),

              // Single Unified 120fps Victory Orchestration (Dark Scrim + Gold WELL DONE + Victory Card + Confetti)
              if (_controller!.isWon)
                VictoryOverlay(
                  controller: _controller!,
                  onNextLevel: _nextLevel,
                  onReplay: _replayLevel,
                ),

              // Flying Extra Word Jump Animation & Visual FX Layer
              if (_controller!.isExtraWordsUnlocked)
                Positioned.fill(
                  child: ExtraWordFlyOverlay(
                    controller: _controller!,
                    boardKey: _boardKey,
                    extraWordsBtnKey: _extraWordsBtnKey,
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildHeader() {
    final showIcons = _controller != null && _controller!.levelNumber > 1;

    return ValueListenableBuilder<bool>(
      valueListenable: GameStorage.hideGameplayUINotifier,
      builder: (context, hideUI, _) {
        final shouldShowIcons = showIcons && !hideUI;

        return SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: SizedBox(
              height: 44.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Left slot: Coin Capsule (Intrinsic width, left-aligned)
                  shouldShowIcons
                      ? _buildCoinCapsule()
                      : const SizedBox(width: 80),

                  // 2. Center slot: Auto-flexing Level Text with FittedBox guard
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onLongPress: _openSettings,
                        child: BouncyButton(
                          onTap: _openLevelSelect,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${AppLocalization.tr('level').toUpperCase()} ${_controller?.levelNumber ?? widget.levelIndex + 1}',
                                maxLines: 1,
                                style: AppTypography.font(
                                  fontSize: 19.sp,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black38,
                                      offset: Offset(0, 1.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Right slot: Dictionary + Settings Buttons (Intrinsic width, right-aligned)
                  shouldShowIcons
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_controller != null &&
                                RemoteConfigService.isDictionaryAvailableForLevel(_controller!.levelNumber))
                              Padding(
                                padding: EdgeInsets.only(right: 6.w),
                                child: _buildDictionaryButton(),
                              ),
                            _buildSettingsButton(),
                          ],
                        )
                      : const SizedBox(width: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDictionaryButton() {
    return BouncyButton(
      onTap: () {
        AudioManager.playTileSelect(pitchIndex: 4);
        _openDictionary();
      },
      child: Container(
        width: 38.r,
        height: 38.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E2846).withValues(alpha: 0.5),
          border: Border.all(color: Colors.white, width: 1.8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.menu_book_rounded,
          color: Colors.white,
          size: 19,
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return BouncyButton(
      onTap: _openSettings,
      child: Image.asset(
        'assets/icons/icon_setting.webp',
        width: 38.r,
        height: 38.r,
      ),
    );
  }

  Widget _buildNoAdsIconButton() {
    return BouncyButton(
      onTap: () {
        AudioManager.playTileSelect(pitchIndex: 4);
        RemoveAdsDialog.show(
          context,
          level: _controller?.levelNumber ?? (widget.levelIndex + 1),
          location: 'ingame_icon',
          onClosed: () {
            if (mounted) setState(() {});
          },
        );
      },
      child: Container(
        width: 44.r,
        height: 44.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1E2846).withValues(alpha: 0.5),
          border: Border.all(color: Colors.white, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        padding: EdgeInsets.all(5.r),
        child: Image.asset(
          'assets/images/img_remove_ads.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  String _formatCoins(int count) {
    if (count >= 1000000) {
      final m = count / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    } else if (count >= 100000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(0)}K';
    }
    return '$count';
  }

  Widget _buildCoinCapsule() {
    return BouncyButton(
      onTap: _openShop,
      child: SizedBox(
        height: 38.h,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                margin: EdgeInsets.only(left: 14.w),
                height: 32.h,
                constraints: BoxConstraints(minWidth: 64.w),
                padding: EdgeInsets.only(left: 22.w, right: 6.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white, width: 2.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<int>(
                      valueListenable: GameStorage.coinsNotifier,
                      builder: (context, coins, _) {
                        return Text(
                          _formatCoins(coins),
                          maxLines: 1,
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 5.w),
                    _buildPlusBadge(),
                  ],
                ),
              ),
              Image.asset(
                'assets/icons/icon_coin.webp',
                width: 38.r,
                height: 38.r,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlusBadge() {
    return Container(
      width: 20.r,
      height: 20.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5CEB38),
            Color(0xFF28A811),
          ],
        ),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38000000),
            offset: Offset(0, 1.5),
            blurRadius: 2,
          ),
          BoxShadow(
            color: Color(0xFF1E820D),
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.add_rounded,
        color: Colors.white,
        size: 14.r,
        shadows: const [
          Shadow(
            color: Color(0xFF0E5606),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildGiftButton() {
    final canClaim = GameStorage.canClaimDailyGift();
    return BouncyButton(
      onTap: _openDailyGift,
      child: SizedBox(
        width: 54.r,
        height: 64.r,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              child: Image.asset(
                'assets/icons/icon_gift_box.webp',
                width: 48.r,
                height: 48.r,
                fit: BoxFit.contain,
              ),
            ),
            if (canClaim)
              Positioned(
                top: -2.h,
                right: 0,
                child: Image.asset(
                  'assets/icons/icon_notice.webp',
                  width: 20.r,
                  height: 20.r,
                  fit: BoxFit.contain,
                ),
              ),
            Positioned(
              bottom: 5.h,
              child: GreenPillBadge.text(text: 'GIFT'),
            ),
          ],
        ),
      ),
    );
  }

  ({List<Color> gradient, Color bevel}) _getFeedbackPillColors(Color baseColor, ChapterTheme theme) {
    if (baseColor == const Color(0xFF10B981)) {
      // Tier 1 Emerald Mint
      return (
        gradient: const [Color(0xFF34D399), Color(0xFF059669)],
        bevel: const Color(0xFF065F46),
      );
    } else if (baseColor == const Color(0xFF2563EB)) {
      // Tier 2 Ocean Blue
      return (
        gradient: const [Color(0xFF60A5FA), Color(0xFF1D4ED8)],
        bevel: const Color(0xFF1E3A8A),
      );
    } else if (baseColor == const Color(0xFF7C3AED)) {
      // Tier 3 Royal Violet
      return (
        gradient: const [Color(0xFFA78BFA), Color(0xFF6D28D9)],
        bevel: const Color(0xFF4C1D95),
      );
    } else if (baseColor == const Color(0xFFEA580C)) {
      // Tier 4 Vivid Orange
      return (
        gradient: const [Color(0xFFFB923C), Color(0xFFC2410C)],
        bevel: const Color(0xFF7C2D12),
      );
    } else if (baseColor == const Color(0xFFE11D48)) {
      // Tier 5 Rose Ruby
      return (
        gradient: const [Color(0xFFFB7185), Color(0xFFBE123C)],
        bevel: const Color(0xFF881337),
      );
    } else if (baseColor == Colors.amber || baseColor == const Color(0xFFFFD54F) || baseColor == Colors.amberAccent) {
      // Amber / Warning / Extra Words
      return (
        gradient: const [Color(0xFFFFEE58), Color(0xFFFFA000)],
        bevel: const Color(0xFFB45309),
      );
    } else if (baseColor == Colors.red ||
        baseColor == Colors.redAccent ||
        baseColor == Colors.redAccent.shade100 ||
        baseColor == const Color(0xFFEF4444)) {
      // Error / Not on board Red
      return (
        gradient: const [Color(0xFFF87171), Color(0xFFDC2626)],
        bevel: const Color(0xFF991B1B),
      );
    } else {
      // Default to chapter theme colors
      return (
        gradient: [baseColor.withValues(alpha: 0.95), baseColor],
        bevel: theme.bevelColor,
      );
    }
  }

  Widget _buildPreviewAndFeedback() {
    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        final word = _controller!.currentWord;
        final feedback = _controller!.feedbackMessage;
        final theme = _controller!.chapterTheme;
        final feedbackColor = _controller!.feedbackColor ?? theme.primaryColor;

        // 1. Live word preview while actively dragging/swiping (Highest priority, zero delay)
        if (word.isNotEmpty) {
          return Container(
            height: 48.h,
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.primaryColor.withValues(alpha: 0.95),
                    theme.primaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: theme.bevelColor,
                    offset: const Offset(0, 2.5),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    offset: const Offset(0, 3.0),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                word,
                style: AppTypography.font(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2.0,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 1.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ).animate().scale(duration: 100.ms, curve: Curves.easeOut),
          );
        }

        // 2. Feedback popup after swipe (Combo Praise / Not on Board / Already Found)
        if (feedback != null) {
          final isCombo = _controller!.feedbackCombo != null && _controller!.feedbackCombo! >= 1;
          final praise = _controller!.feedbackPraise;
          final multiplier = _controller!.feedbackComboMultiplier;
          final pillColors = _getFeedbackPillColors(feedbackColor, theme);

          Widget pillContent;
          if (isCombo && praise != null && multiplier != null) {
            pillContent = Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pillColors.gradient,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  // 1. 3D Solid Bevel Lip
                  BoxShadow(
                    color: pillColors.bevel,
                    offset: const Offset(0, 2.8),
                    blurRadius: 0,
                  ),
                  // 2. Soft Ambient Drop Shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    offset: const Offset(0, 3.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Golden Combo Text (Seamless single pill, no nested background!)
                  Text(
                    '${AppLocalization.tr('combo', language: _controller?.language)} $multiplier',
                    style: AppTypography.font(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFEE58),
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF78350F),
                          offset: Offset(0, 1.2),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7.w),
                    child: Container(
                      width: 1.5,
                      height: 13.h,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  // Praise Word
                  Text(
                    praise,
                    style: AppTypography.font(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 1.2),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            pillContent = Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: pillColors.gradient,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  // 1. 3D Solid Bevel Lip
                  BoxShadow(
                    color: pillColors.bevel,
                    offset: const Offset(0, 2.8),
                    blurRadius: 0,
                  ),
                  // 2. Soft Ambient Drop Shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    offset: const Offset(0, 3.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
              child: Text(
                feedback,
                style: AppTypography.font(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.8,
                  shadows: const [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 1.2),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            height: 48.h,
            alignment: Alignment.center,
            child: pillContent
                .animate(key: ValueKey('feedback-$feedback-${_controller!.comboStreak}'))
                .scale(
                  duration: 180.ms,
                  curve: Curves.easeOutBack,
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1.0, 1.0),
                )
                .fadeIn(duration: 100.ms),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
