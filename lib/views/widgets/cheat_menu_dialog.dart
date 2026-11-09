import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/game_controller.dart';
import '../../services/analytics_service.dart';
import '../../services/analytics_toast.dart';
import '../../services/audio_manager.dart';
import '../../services/game_storage.dart';
import '../../services/level_loader.dart';
import '../../services/remote_config_service.dart';
import '../../services/daily_login_service.dart';
import 'daily_login_dialog.dart';
import 'dictionary_dialog.dart';
import '../../services/notification_service.dart';
import 'package:funtap_global_sdk/funtap_global_sdk.dart';

class CheatMenuDialog extends StatefulWidget {
  final String? language;
  final GameController? controller;
  final ValueChanged<int>? onJumpToLevel;
  final VoidCallback? onNextLevel;
  final VoidCallback? onInstantWin;
  final VoidCallback? onSolveWord;
  final VoidCallback? onUpdated;

  const CheatMenuDialog({
    super.key,
    this.language,
    this.controller,
    this.onJumpToLevel,
    this.onNextLevel,
    this.onInstantWin,
    this.onSolveWord,
    this.onUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    String? language,
    GameController? controller,
    ValueChanged<int>? onJumpToLevel,
    VoidCallback? onNextLevel,
    VoidCallback? onInstantWin,
    VoidCallback? onSolveWord,
    VoidCallback? onUpdated,
  }) {
    if (!RemoteConfigService.cheatEnabled) {
      return Future.value();
    }
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CheatMenuDialog(
        language: language,
        controller: controller,
        onJumpToLevel: onJumpToLevel,
        onNextLevel: onNextLevel,
        onInstantWin: onInstantWin,
        onSolveWord: onSolveWord,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<CheatMenuDialog> createState() => _CheatMenuDialogState();
}

class _CheatMenuDialogState extends State<CheatMenuDialog> {
  late final TextEditingController _levelTextController;
  late String _lang;
  bool _isInfiniteBoosters = false;
  bool _isHideGameplayUI = false;
  bool _isTutorialTapOutside = false;
  bool _isFirebaseAnalyticsTest = false;

  @override
  void initState() {
    super.initState();
    _lang = widget.language ?? GameStorage.getLanguage();
    _isInfiniteBoosters = GameStorage.isInfiniteBoostersEnabled();
    _isHideGameplayUI = GameStorage.isGameplayUIHidden();
    _isTutorialTapOutside = RemoteConfigService.tutorialTapOutsideClose;
    _isFirebaseAnalyticsTest = GameStorage.isFirebaseAnalyticsTestEnabled();

    final initialLvl = widget.controller?.levelNumber ?? (GameStorage.getCurrentLevelIndex(_lang) + 1);
    _levelTextController = TextEditingController(text: '$initialLvl');
  }

  @override
  void dispose() {
    _levelTextController.dispose();
    super.dispose();
  }

  void _notifyUpdate() {
    setState(() {});
    widget.onUpdated?.call();
  }

  void _showFeedbackToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: AppTypography.font(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
        ),
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCoins = GameStorage.getCoins();
    final hintCount = GameStorage.getHintCount();
    final rocketCount = GameStorage.getRocketCount();
    final extraCount = GameStorage.getExtraWordsChestCount();
    final totalLevels = LevelLoader.totalLevelsPerLanguage[_lang] ?? 1500;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 350.w,
          constraints: BoxConstraints(maxHeight: 0.85.sh),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                blurRadius: 16,
                spreadRadius: 2,
              ),
              const BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Section 1: Level Navigation ---
                      _buildSectionTitle('🎮 LEVEL NAVIGATION & CHEATS'),
                      SizedBox(height: 8.h),
                      _buildLevelJumpRow(totalLevels),
                      SizedBox(height: 8.h),
                      _buildQuickLevelChips(),
                      if (widget.controller != null) ...[
                        SizedBox(height: 10.h),
                        _buildIngameActions(),
                      ],
                      SizedBox(height: 16.h),

                      // --- Section 2: Coins ---
                      _buildSectionTitle('💰 COINS & ECONOMY (Current: $currentCoins 🪙)'),
                      SizedBox(height: 8.h),
                      _buildCoinsRow(),
                      SizedBox(height: 16.h),

                      // --- Section 3: Boosters ---
                      _buildSectionTitle('💡 BOOSTERS (Hint: $hintCount | Rocket: $rocketCount)'),
                      SizedBox(height: 8.h),
                      _buildBoostersRow(),
                      SizedBox(height: 6.h),
                      _buildInfiniteBoosterSwitch(),
                      SizedBox(height: 16.h),

                      // --- Section 4: Extra Words & Daily Gift ---
                      _buildSectionTitle('🎁 REWARDS & RETENTION (Extra: $extraCount/10)'),
                      SizedBox(height: 8.h),
                      _buildRewardsRow(),
                      SizedBox(height: 8.h),
                      _buildDailyLoginAndDictionaryRow(),
                      SizedBox(height: 8.h),
                      _buildNotificationTestingRow(),
                      SizedBox(height: 16.h),

                      // --- Section 5: Progression & Reset ---
                      _buildSectionTitle('🔓 PROGRESSION & DEV SETTINGS'),
                      SizedBox(height: 8.h),
                      _buildProgressionRow(),
                      SizedBox(height: 16.h),

                      // --- Section 6: UI & Display Cheats ---
                      _buildSectionTitle('👁️ UI & DISPLAY CHEATS'),
                      SizedBox(height: 8.h),
                      _buildHideGameplayUISwitch(),
                      SizedBox(height: 8.h),
                      _buildTutorialTapOutsideSwitch(),
                      SizedBox(height: 16.h),

                      // --- Section 7: Ads & MAX Mediation Debugger ---
                      _buildSectionTitle('📢 ADS & MEDIATION DEBUGGER'),
                      SizedBox(height: 8.h),
                      _buildMaxDebuggerButton(),
                      SizedBox(height: 16.h),

                      // --- Section 8: Firebase Analytics Testing ---
                      _buildSectionTitle('🔥 FIREBASE ANALYTICS TRACKING & TEST'),
                      SizedBox(height: 8.h),
                      _buildFirebaseAnalyticsTestSwitch(),
                      SizedBox(height: 8.h),
                      _buildFirebaseTestButtonsRow(),
                      SizedBox(height: 12.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(21.r),
          topRight: Radius.circular(21.r),
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8.w),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'DEV & CHEAT MENU',
                      style: AppTypography.font(
                        color: const Color(0xFF38BDF8),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: EdgeInsets.all(4.r),
              decoration: const BoxDecoration(
                color: Color(0xFF334155),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTypography.font(
        color: const Color(0xFF94A3B8),
        fontSize: 11.sp,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildLevelJumpRow(int totalLevels) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: const Color(0xFF475569)),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _levelTextController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTypography.font(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '1 - $totalLevels',
                hintStyle: AppTypography.font(color: Colors.white38, fontSize: 13.sp),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        _buildActionButton(
          label: 'JUMP 🚀',
          color: const Color(0xFF0284C7),
          onTap: () {
            final targetLvl = int.tryParse(_levelTextController.text.trim()) ?? 1;
            final clamped = targetLvl.clamp(1, totalLevels);
            GameStorage.forceSetLevelProgression(_lang, clamped);
            Navigator.of(context).pop();
            widget.onJumpToLevel?.call(clamped);
            _showFeedbackToast('Jumped to Level $clamped!');
          },
        ),
      ],
    );
  }

  Widget _buildQuickLevelChips() {
    final chips = [1, 5, 6, 10, 50, 100];
    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: chips.map((lvl) {
        return GestureDetector(
          onTap: () {
            _levelTextController.text = '$lvl';
            GameStorage.forceSetLevelProgression(_lang, lvl);
            Navigator.of(context).pop();
            widget.onJumpToLevel?.call(lvl);
            _showFeedbackToast('Jumped to Level $lvl!');
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              'Lvl $lvl',
              style: AppTypography.font(
                color: const Color(0xFFE2E8F0),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIngameActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Solve 1 Word 🎯',
            color: const Color(0xFF8B5CF6),
            onTap: () {
              Navigator.of(context).pop();
              widget.controller?.cheatSolveNextWord();
              widget.onSolveWord?.call();
              _showFeedbackToast('Target word solved!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Instant Win 🏆',
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.of(context).pop();
              widget.controller?.cheatInstantWin();
              widget.onInstantWin?.call();
              _showFeedbackToast('Level cleared!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Skip Level ⚡',
            color: const Color(0xFFF59E0B),
            onTap: () {
              Navigator.of(context).pop();
              widget.onNextLevel?.call();
              _showFeedbackToast('Advancing to next level...');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCoinsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: '+1,000 🪙',
            color: const Color(0xFF059669),
            onTap: () async {
              await GameStorage.addCoins(1000);
              _notifyUpdate();
              _showFeedbackToast('+1,000 Coins added!');
            },
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: _buildActionButton(
            label: '+10,000 🪙',
            color: const Color(0xFF047857),
            onTap: () async {
              await GameStorage.addCoins(10000);
              _notifyUpdate();
              _showFeedbackToast('+10,000 Coins added!');
            },
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: _buildActionButton(
            label: '+99,999 🪙',
            color: const Color(0xFF065F46),
            onTap: () async {
              await GameStorage.addCoins(99999);
              _notifyUpdate();
              _showFeedbackToast('+99,999 Coins added!');
            },
          ),
        ),
        SizedBox(width: 6.w),
        _buildActionButton(
          label: '0 🪙',
          color: const Color(0xFFDC2626),
          onTap: () async {
            await GameStorage.setCoins(0);
            _notifyUpdate();
            _showFeedbackToast('Coins reset to 0!');
          },
        ),
      ],
    );
  }

  Widget _buildBoostersRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: '+10 💡 Hint',
            color: const Color(0xFFD97706),
            onTap: () async {
              await GameStorage.addHintCount(10);
              _notifyUpdate();
              _showFeedbackToast('+10 Hints added!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: '+10 🚀 Rocket',
            color: const Color(0xFFEA580C),
            onTap: () async {
              await GameStorage.addRocketCount(10);
              _notifyUpdate();
              _showFeedbackToast('+10 Rockets added!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'All 999 🔥',
            color: const Color(0xFFB45309),
            onTap: () async {
              await GameStorage.setHintCount(999);
              await GameStorage.setRocketCount(999);
              _notifyUpdate();
              _showFeedbackToast('Hints & Rockets set to 999!');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfiniteBoosterSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('♾️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    'Infinite Boosters (Free & Unlimited)',
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isInfiniteBoosters,
            activeThumbColor: const Color(0xFF38BDF8),
            onChanged: (val) async {
              setState(() => _isInfiniteBoosters = val);
              await GameStorage.setInfiniteBoostersEnabled(val);
              _notifyUpdate();
              _showFeedbackToast(val ? 'Infinite boosters enabled (∞)!' : 'Infinite boosters disabled');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Fill Extra (10/10) ⭐',
            color: const Color(0xFF6366F1),
            onTap: () async {
              await GameStorage.setExtraWordsChestCount(10);
              _notifyUpdate();
              _showFeedbackToast('Extra Words Chest filled to 10/10!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Reset Daily Streak 📅',
            color: const Color(0xFFEC4899),
            onTap: () async {
              await DailyLoginService.resetStreakForTest();
              _notifyUpdate();
              _showFeedbackToast('Daily Login Streak reset! Ready to claim Day 1.');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLoginAndDictionaryRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Daily Login Popup 🎁',
            color: const Color(0xFFEAB308),
            onTap: () {
              Navigator.of(context).pop();
              DailyLoginDialog.show(
                 context,
                level: widget.controller?.levelNumber ?? 1,
                onRewardClaimed: _notifyUpdate,
              );
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Open Dictionary 📖',
            color: const Color(0xFF0284C7),
            onTap: () {
              Navigator.of(context).pop();
              DictionaryDialog.show(
                context,
                words: widget.controller != null
                    ? widget.controller!.level.targetWords.map((tw) => tw.word).toList()
                    : const ['CAT', 'DOG', 'PEN', 'HELLO'],
                language: widget.controller?.language ?? 'en',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTestingRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Test Push Noti 🔔',
            color: const Color(0xFF8B5CF6),
            onTap: () async {
              await NotificationService.showTestNotification();
              _showFeedbackToast('Đã bắn thông báo thử nghiệm tức thì!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Schedule Noti 5s ⏳',
            color: const Color(0xFF6366F1),
            onTap: () async {
              await NotificationService.scheduleTestNotification(seconds: 5);
              _showFeedbackToast('Đã hẹn giờ sau 5s! Hãy thoát app/minimize để xem.');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'Unlock All Levels 🔓',
            color: const Color(0xFF2563EB),
            onTap: () async {
              await GameStorage.unlockAllLevels(_lang);
              _notifyUpdate();
              _showFeedbackToast('All levels unlocked for $_lang!');
            },
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildActionButton(
            label: 'Reset All Data 🗑️',
            color: const Color(0xFFB91C1C),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: Text('Reset All Data?', style: AppTypography.font(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                    'This will reset coins, levels, boosters, and preferences to fresh install state.',
                    style: AppTypography.font(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Cancel', style: AppTypography.font(color: Colors.white54)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text('Reset', style: AppTypography.font(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await GameStorage.resetAllData();
                _notifyUpdate();
                if (mounted) {
                  Navigator.of(context).pop();
                }
                _showFeedbackToast('Game data completely reset!');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHideGameplayUISwitch() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('👁️', style: TextStyle(fontSize: 16)),
                SizedBox(width: 8.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hide In-Game UI (All HUD & Boosters)',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Hides Coins, Gift, Settings, Star & Boosters',
                        style: AppTypography.font(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isHideGameplayUI,
            activeThumbColor: const Color(0xFF38BDF8),
            onChanged: (val) async {
              setState(() => _isHideGameplayUI = val);
              await GameStorage.setGameplayUIHidden(val);
              _notifyUpdate();
              _showFeedbackToast(
                val
                    ? 'In-Game UI & Boosters hidden! (Long-press LEVEL to open settings)'
                    : 'In-Game UI restored!',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialTapOutsideSwitch() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('👆', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap Outside Closes Tutorial',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Remote Config: tutorial_tap_outside_close',
                        style: AppTypography.font(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isTutorialTapOutside,
            activeThumbColor: const Color(0xFF38BDF8),
            onChanged: (val) async {
              setState(() => _isTutorialTapOutside = val);
              await GameStorage.setTutorialTapOutsideOverride(val);
              _notifyUpdate();
              _showFeedbackToast(
                val
                    ? 'Tutorial tap-outside close ENABLED!'
                    : 'Tutorial tap-outside close DISABLED!',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AudioManager.playTileSelect(pitchIndex: 4);
          onTap();
        },
        borderRadius: BorderRadius.circular(10.r),
        child: Ink(
          height: 38.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                offset: const Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.font(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaxDebuggerButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAX Mediation Debugger',
                      style: AppTypography.font(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'AppLovin MAX ad network mediation diagnostics',
                      style: AppTypography.font(
                        color: const Color(0xFF94A3B8),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                AudioManager.playTileSelect(pitchIndex: 5);
                FGSDK.showMediationDebugger();
                _showFeedbackToast('Opening MAX Mediation Debugger...');
              },
              borderRadius: BorderRadius.circular(8.r),
              child: Ink(
                height: 38.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.bug_report_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6.w),
                          Text(
                            'OPEN MEDIATION DEBUGGER',
                            style: AppTypography.font(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseAnalyticsTestSwitch() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: _isFirebaseAnalyticsTest ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          width: _isFirebaseAnalyticsTest ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Direct Firebase Tracking',
                              style: AppTypography.font(
                                color: Colors.white,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: _isFirebaseAnalyticsTest ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.white10,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              _isFirebaseAnalyticsTest ? 'LIVE TEST' : 'DISABLED',
                              style: AppTypography.font(
                                color: _isFirebaseAnalyticsTest ? const Color(0xFFF59E0B) : Colors.white38,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Bắn trực tiếp Firebase & hiện Toast HUD real-time',
                        style: AppTypography.font(
                          color: const Color(0xFF94A3B8),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isFirebaseAnalyticsTest,
            activeThumbColor: const Color(0xFFF59E0B),
            onChanged: (val) async {
              setState(() => _isFirebaseAnalyticsTest = val);
              await GameStorage.setFirebaseAnalyticsTestEnabled(val);
              if (!val) {
                AnalyticsToast.dismiss();
              }
              _notifyUpdate();
              _showFeedbackToast(
                val
                    ? '🔥 Firebase Direct Tracking BẬT! Events bắn lên sẽ hiện Toast HUD.'
                    : 'Firebase Direct Tracking TẮT (Chế độ mặc định FGSDK).',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFirebaseTestButtonsRow() {
    final currentLvl = widget.controller?.levelNumber ?? (GameStorage.getCurrentLevelIndex(_lang) + 1);

    return Column(
      children: [
        // One-tap fire ALL 15 events
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              AudioManager.playTileSelect(pitchIndex: 7);
              final count = await AnalyticsService.fireAllTestEvents(level: currentLvl);
              _showFeedbackToast('🚀 Đã bắn thành công $count/15 Events & User Properties lên Firebase!');
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Ink(
              height: 38.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(8.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 18),
                        SizedBox(width: 6.w),
                        Text(
                          '⚡ TEST TOÀN BỘ 15 EVENTS (ONE-TAP)',
                          style: AppTypography.font(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Test Event 🚀',
                color: const Color(0xFFEA580C),
                onTap: () async {
                  AudioManager.playTileSelect(pitchIndex: 4);
                  final success = await AnalyticsService.sendTestFirebaseEvent(
                    eventName: 'test_firebase_event',
                    params: {
                      'test_timestamp': DateTime.now().toIso8601String(),
                      'test_level': currentLvl,
                      'platform': defaultTargetPlatform.name,
                      'status': 'success',
                    },
                  );
                  _showFeedbackToast(
                    success
                        ? '🔥 Đã bắn event [test_firebase_event] lên Firebase!'
                        : '⚠️ Bắn event thất bại. Kiểm tra kết nối mạng!',
                  );
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActionButton(
                label: 'Test level_start 🎮',
                color: const Color(0xFFD97706),
                onTap: () {
                  AudioManager.playTileSelect(pitchIndex: 5);
                  AnalyticsService.logLevelStart(
                    level: currentLvl,
                    playCount: 1,
                    loseCount: 0,
                    playMode: 'default',
                  );
                  _showFeedbackToast('🔥 Đã bắn event [level_start] Lvl $currentLvl!');
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Test Resource 💎',
                color: const Color(0xFF0284C7),
                onTap: () {
                  AudioManager.playTileSelect(pitchIndex: 4);
                  AnalyticsService.logEarnResource(
                    level: currentLvl,
                    type: 'currency',
                    name: 'gold',
                    amount: 50.0,
                    reason: 'win_level',
                    balance: 300.0,
                  );
                  AnalyticsService.logSpendResource(
                    level: currentLvl,
                    type: 'booster',
                    name: 'hint',
                    amount: 1.0,
                    reason: 'ingame',
                    balance: 2.0,
                  );
                  _showFeedbackToast('🔥 Đã bắn [resource_source] & [resource_sink]!');
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActionButton(
                label: 'Test IAP 🛒',
                color: const Color(0xFF0D9488),
                onTap: () {
                  AudioManager.playTileSelect(pitchIndex: 4);
                  AnalyticsService.logIAPShow(
                    level: currentLvl,
                    location: 'home_shop',
                    type: 'shop',
                    productId: 'coin_small',
                  );
                  AnalyticsService.logIAPClick(
                    level: currentLvl,
                    location: 'home_shop',
                    type: 'shop',
                    productId: 'coin_small',
                  );
                  _showFeedbackToast('🔥 Đã bắn [iap_show] & [iap_click]!');
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Test User Props 👤',
                color: const Color(0xFF475569),
                onTap: () {
                  AudioManager.playTileSelect(pitchIndex: 3);
                  AnalyticsService.updateUserProperties(level: currentLvl);
                  _showFeedbackToast('🔥 Đã cập nhật User Properties lên Firebase!');
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildActionButton(
                label: 'Test level_end 🏆',
                color: const Color(0xFF059669),
                onTap: () {
                  AudioManager.playTileSelect(pitchIndex: 6);
                  AnalyticsService.logLevelEnd(
                    level: currentLvl,
                    playDuration: 25.0,
                    totalItems: 3,
                    clearedItems: 3,
                    success: true,
                    reason: 'win',
                  );
                  _showFeedbackToast('🔥 Đã bắn event [level_end] Lvl $currentLvl (win)!');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
