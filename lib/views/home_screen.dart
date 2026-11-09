import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../main.dart';
import '../services/ads_manager.dart';
import '../services/audio_manager.dart';
import '../services/app_localization.dart';
import '../services/game_storage.dart';
import '../services/level_loader.dart';
import '../theme/app_typography.dart';
import '../utils/game_transitions.dart';
import 'widgets/exit_game_dialog.dart';
import '../widgets/common/game_scaffold.dart';
import 'game_screen.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/pressable_3d_button.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/remove_ads_dialog.dart';
import 'widgets/daily_login_dialog.dart';
import 'widgets/booster_bar.dart';
import '../services/daily_login_service.dart';
import 'shop_screen.dart';
import '../services/no_ads_trigger_service.dart';

class HomeScreen extends StatefulWidget {
  final bool isFirstSessionStart;

  const HomeScreen({
    super.key,
    this.isFirstSessionStart = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  String _language = 'english';
  int _currentLevelIndex = 0;
  bool _isLoading = true;
  bool _hasCheckedStartupPopups = false;

  @override
  void initState() {
    super.initState();
    GameStorage.languageNotifier.addListener(_onLanguageChanged);
    _loadState(showBanner: !widget.isFirstSessionStart);
    AudioManager.startBgm();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStartupPopups();
    });
  }

  void _checkStartupPopups() {
    if (!mounted || _hasCheckedStartupPopups) return;
    _hasCheckedStartupPopups = true;

    final currentLevelNumber = _currentLevelIndex + 1;
    if (NoAdsTriggerService.shouldShowCase1(currentLevelNumber)) {
      RemoveAdsDialog.show(
        context,
        level: currentLevelNumber,
        location: 'home_startup',
        onClosed: () {
          if (mounted) {
            _loadState(showBanner: true);
            _checkStarterPackPopup();
          }
        },
      );
    } else {
      _checkStarterPackPopup();
    }
  }

  void _checkStarterPackPopup() {
    if (DailyLoginService.canClaimToday() && !widget.isFirstSessionStart) {
      DailyLoginDialog.show(
        context,
        level: _currentLevelIndex + 1,
        onRewardClaimed: () {
          if (mounted) setState(() {});
        },
      );
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      _loadState(showBanner: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    GameStorage.languageNotifier.removeListener(_onLanguageChanged);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadState(showBanner: true);
    AudioManager.resumeBgm();
  }

  Future<void> _loadState({bool showBanner = true}) async {
    final lang = GameStorage.getSelectedLanguage();
    final count = LevelLoader.totalLevelsPerLanguage[lang] ?? 1000;
    final currentLvl = GameStorage.getMaxUnlockedLevelIndex(lang).clamp(0, count > 0 ? count - 1 : 0);

    if (mounted) {
      setState(() {
        _language = lang;
        _currentLevelIndex = currentLvl;
        _isLoading = false;
      });
    }

    if (showBanner) {
      AdsManager.showBanner('bottom', level: currentLvl + 1);
    }
  }

  void _playCurrentLevel() {
    AudioManager.playTileSelect(pitchIndex: 3);
    Navigator.push(
      context,
      GamePageRoute(
        child: GameScreen(
          language: _language,
          levelIndex: _currentLevelIndex,
        ),
      ),
    ).then((_) => _loadState(showBanner: true));
  }

  void _jumpToLevel(int targetLevelNumber) {
    final maxCount = LevelLoader.totalLevelsPerLanguage[_language] ?? 1500;
    final index = (targetLevelNumber - 1).clamp(0, maxCount - 1);
    GameStorage.setCurrentLevelIndex(_language, index);
    GameStorage.setMaxUnlockedLevelIndex(_language, index);
    Navigator.push(
      context,
      GamePageRoute(
        child: GameScreen(
          language: _language,
          levelIndex: index,
        ),
      ),
    ).then((_) => _loadState(showBanner: true));
  }

  void _openSettings() {
    AudioManager.playTileSelect(pitchIndex: 4);
    showGameDialog(
      context: context,
      builder: (context) => SettingsDialog(
        isHomeScreen: true,
        onLanguageChanged: () {
          _loadState();
        },
        onJumpToLevel: _jumpToLevel,
      ),
    ).then((_) => _loadState());
  }

  void _openShop() {
    AudioManager.playTileSelect(pitchIndex: 4);
    Navigator.push(
      context,
      GamePageRoute(
        child: ShopScreen(
          currentLevel: _currentLevelIndex + 1,
          onClosed: _loadState,
        ),
      ),
    ).then((_) => _loadState());
  }

  Future<void> _handleExitAppConfirmation() async {
    AudioManager.playTileSelect(pitchIndex: 2);
    ExitGameDialog.show(
      context,
      onExit: () {
        SystemNavigator.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelNumber = _currentLevelIndex + 1;

    return GameScaffold(
      useSafeArea: false,
      background: Image.asset(
        'assets/images/bg_home.webp',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      ),
      onWillPop: () async {
        await _handleExitAppConfirmation();
        return false;
      },
      body: _isLoading
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  SizedBox(height: 0.05.sh), 
                  _buildLogo(),
                  const Spacer(),
                  _buildPlayButton(levelNumber),
                  SizedBox(height: 0.18.sh),
                ],
              ),
            ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Coin Capsule and Gift Button directly under it
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCoinCapsule(),
              SizedBox(height: 10.h),
              Padding(
                padding: EdgeInsets.only(left: 4.w),
                child: _buildGiftButton(),
              ),
            ],
          ),
          // Right: Remove Ads and Settings on top, Daily Button directly under Settings
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: GameStorage.noAdsNotifier,
                    builder: (context, isPurchased, _) {
                      if (isPurchased) return const SizedBox.shrink();
                      return Padding(
                        padding: EdgeInsets.only(right: 10.w),
                        child: _buildNoAdsIconButton(),
                      );
                    },
                  ),
                  _buildSettingsButton(),
                ],
              ),
              SizedBox(height: 10.h),
              _buildDailyButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoAdsIconButton() {
    return BouncyButton(
      onTap: () {
        AudioManager.playTileSelect(pitchIndex: 4);
        RemoveAdsDialog.show(
          context,
          level: _currentLevelIndex + 1,
          location: 'home_icon',
          onClosed: () {
            if (mounted) _loadState(showBanner: true);
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

  Widget _buildGiftButton() {
    return BouncyButton(
      key: const ValueKey('home_daily_gift_button'),
      onTap: _openShop,
      child: SizedBox(
        width: 50.r,
        height: 60.r,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              child: Image.asset(
                'assets/icons/icon_gift_box.webp',
                width: 44.r,
                height: 44.r,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              bottom: 4.h,
              child: GreenPillBadge.text(text: 'GIFT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: DailyLoginService.canClaimNotifier,
      builder: (context, canClaim, _) {
        return BouncyButton(
          key: const ValueKey('home_daily_login_button'),
          onTap: () {
            AudioManager.playTileSelect(pitchIndex: 4);
            DailyLoginDialog.show(
              context,
              level: _currentLevelIndex + 1,
              onRewardClaimed: () {
                if (mounted) setState(() {});
              },
            );
          },
          child: SizedBox(
            width: 50.r,
            height: 60.r,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  child: Image.asset(
                    'assets/icons/icon_gift_explore.webp',
                    width: 44.r,
                    height: 44.r,
                    fit: BoxFit.contain,
                  ),
                ),
                if (canClaim)
                  Positioned(
                    top: -2.h,
                    right: 0,
                    child: Image.asset(
                      'assets/icons/icon_notice.webp',
                      width: 18.r,
                      height: 18.r,
                      fit: BoxFit.contain,
                    ),
                  ),
                Positioned(
                  bottom: 4.h,
                  child: GreenPillBadge.text(text: 'DAILY'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoinCapsule() {
    return BouncyButton(
      key: const ValueKey('home_coin_capsule'),
      onTap: _openShop,
      child: SizedBox(
        height: 44.h,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Dark royal blue pill container
            Container(
              margin: EdgeInsets.only(left: 18.w),
              height: 34.h,
              constraints: BoxConstraints(minWidth: 96.w),
              padding: EdgeInsets.only(left: 25.w, right: 6.w),
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: Colors.white, width: 2.2),
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
                        '$coins',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 8.w),
                  _buildPlusBadge(),
                ],
              ),
            ),
            // Overlapping gold crown coin icon
            Image.asset(
              'assets/icons/icon_coin.webp',
              width: 44.r,
              height: 44.r,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlusBadge() {
    return Container(
      width: 24.r,
      height: 24.r,
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
        border: Border.all(color: Colors.white, width: 1.8),
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
      child: const Icon(
        Icons.add_rounded,
        color: Colors.white,
        size: 17,
        shadows: [
          Shadow(
            color: Color(0xFF0E5606),
            offset: Offset(0, 1),
            blurRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return BouncyButton(
      onTap: _openSettings,
      child: Image.asset(
        'assets/icons/icon_setting.webp',
        width: 44.r,
        height: 44.r,
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo_home.webp',
      width: 300.w,
      fit: BoxFit.contain,
    );
  }

  Widget _buildPlayButton(int levelNumber) {
    return Pressable3DButton(
      onTap: _playCurrentLevel,
      width: 240.w,
      height: 90.h,
      borderRadius: 22,
      bevelOffset: 5.0,
      borderWidth: 1.2,
      faceColor: const Color(0xFF46dc28),
      bevelColor: const Color(0xFF2DC419),
      borderColor: const Color(0xFF19BA05),
      child: CartoonText(
        text: AppLocalization.tr('level_n', args: [levelNumber]),
        fontSize: 32.sp,
        textColor: Colors.white,
        outlineColor: const Color(0xFF179A09),
        strokeWidth: 4.5,
        shadowOffset: 2.0,
      ),
    );
  }
}
