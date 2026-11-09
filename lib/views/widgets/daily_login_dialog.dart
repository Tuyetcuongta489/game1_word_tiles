import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/daily_login_reward.dart';
import '../../services/ads_manager.dart';
import '../../services/audio_manager.dart';
import '../../services/daily_login_service.dart';
import '../../theme/app_typography.dart';
import '../../utils/game_transitions.dart';
import 'bouncy_button.dart';
import 'pressable_3d_button.dart';

/// 7-Day Daily Login Streak Popup with high-contrast, beautiful 3D casual UI
/// and rewarding progressive bonuses.
class DailyLoginDialog extends StatefulWidget {
  final int levelNumber;
  final VoidCallback? onRewardClaimed;

  const DailyLoginDialog({
    super.key,
    required this.levelNumber,
    this.onRewardClaimed,
  });

  static Future<void> show(
    BuildContext context, {
    int level = 1,
    VoidCallback? onRewardClaimed,
  }) {
    AudioManager.playTileSelect(pitchIndex: 4);
    return showGameDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DailyLoginDialog(
        levelNumber: level,
        onRewardClaimed: onRewardClaimed,
      ),
    );
  }

  @override
  State<DailyLoginDialog> createState() => _DailyLoginDialogState();
}

class _DailyLoginDialogState extends State<DailyLoginDialog> {
  bool _canClaim = true;
  int _currentStreakDay = 1;
  bool _isClaiming = false;
  String? _claimedMessage;

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  void _refreshState() {
    _canClaim = DailyLoginService.canClaimToday();
    _currentStreakDay = DailyLoginService.getCurrentStreakDay();
  }

  Future<void> _handleClaim({required bool isDouble}) async {
    if (_isClaiming || !_canClaim) return;
    _isClaiming = true;

    if (isDouble) {
      await AdsManager.showDailyLoginX2Reward(
        levelNumber: widget.levelNumber,
        onRewardResult: (success) async {
          if (!mounted) return;
          if (success) {
            await _executeClaim(isDouble: true);
          } else {
            _isClaiming = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ad not ready or incomplete. Please try again!'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      );
    } else {
      await _executeClaim(isDouble: false);
    }
  }

  Future<void> _executeClaim({required bool isDouble}) async {
    final reward = await DailyLoginService.claimToday(
      isDouble: isDouble,
      currentLevel: widget.levelNumber,
    );

    AudioManager.playVictory();

    final parts = <String>[];
    if (reward.coins > 0) parts.add('+${reward.coins} Coins');
    if (reward.hints > 0) parts.add('+${reward.hints} Hints');
    if (reward.rockets > 0) parts.add('+${reward.rockets} Rockets');

    final msg = isDouble
        ? 'Claimed 2X Reward!\n${parts.join('  •  ')}'
        : 'Reward Claimed!\n${parts.join('  •  ')}';

    if (!mounted) return;
    setState(() {
      _refreshState();
      _isClaiming = false;
      _claimedMessage = msg;
    });

    widget.onRewardClaimed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 356.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. Main 3D Card Shell (Matching SettingsDialog & ExtraWordsDialog)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(14.w, 36.h, 14.w, 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: const Color(0xFFE5EFF5), width: 3.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38000000),
                      offset: Offset(0, 12),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0xFFB0C9DA),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtitle / Streak Status Bar (Harmonized pastel blue pill)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F3FA),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(color: const Color(0xFFBED7E8), width: 1.5),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFEA580C), size: 18),
                            SizedBox(width: 4.w),
                            Text(
                              'Day $_currentStreakDay / 7 Streak',
                              style: AppTypography.font(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6.w),
                              child: Container(
                                width: 3.5.r,
                                height: 3.5.r,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Text(
                              'Free Rewards Daily!',
                              style: AppTypography.font(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),

                    // Success Claim Banner
                    if (_claimedMessage != null) ...[
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                        margin: EdgeInsets.only(bottom: 10.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: const Color(0xFF10B981), width: 1.8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A10B981),
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Text(
                          _claimedMessage!,
                          textAlign: TextAlign.center,
                          style: AppTypography.font(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF047857),
                            height: 1.3,
                          ),
                        ),
                      ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack),
                    ],

                    // Sunken Card Stage Container for Days 1 through 6 (Matching SettingsDialog 0xFFD5E7F3)
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5E7F3),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: const Color(0xFFBED7E8), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                          childAspectRatio: 0.88,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          final day = index + 1;
                          final reward = kDailyLoginRewards[index];
                          final isClaimed = DailyLoginService.isDayClaimed(day);
                          final isToday = day == _currentStreakDay && _canClaim;

                          return _DailyDayCard(
                            day: day,
                            reward: reward,
                            isClaimed: isClaimed,
                            isToday: isToday,
                          );
                        },
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // 3. Day 7 Featured Grand Prize Banner
                    _Day7GrandCard(
                      reward: kDailyLoginRewards[6],
                      isClaimed: DailyLoginService.isDayClaimed(7),
                      isToday: _currentStreakDay == 7 && _canClaim,
                    ),

                    SizedBox(height: 16.h),

                    // 4. Action Buttons
                    if (_canClaim) ...[
                      Row(
                        children: [
                          // Claim Normal
                          Expanded(
                            flex: 4,
                            child: Pressable3DButton(
                              height: 50.h,
                              faceColor: const Color(0xFF22C55E),
                              bevelColor: const Color(0xFF15803D),
                              borderColor: const Color(0xFF14532D),
                              borderRadius: 18.r,
                              onTap: _isClaiming ? null : () => _handleClaim(isDouble: false),
                              child: Center(
                                child: CartoonText(
                                  text: 'CLAIM',
                                  fontSize: 16.sp,
                                  textColor: Colors.white,
                                  outlineColor: const Color(0xFF14532D),
                                  strokeWidth: 3.2,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 10.w),

                          // Claim x2 with Ads
                          Expanded(
                            flex: 5,
                            child: Pressable3DButton(
                              height: 50.h,
                              faceColor: const Color(0xFFFF9800),
                              bevelColor: const Color(0xFFD97706),
                              borderColor: const Color(0xFF92400E),
                              borderRadius: 18.r,
                              onTap: _isClaiming ? null : () => _handleClaim(isDouble: true),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/icons/icon_ads.webp',
                                    width: 22.r,
                                    height: 22.r,
                                  ),
                                  SizedBox(width: 5.w),
                                  CartoonText(
                                    text: 'CLAIM x2',
                                    fontSize: 16.sp,
                                    textColor: Colors.white,
                                    outlineColor: const Color(0xFF92400E),
                                    strokeWidth: 3.2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Already claimed today
                      Pressable3DButton(
                        width: 220.w,
                        height: 48.h,
                        faceColor: const Color(0xFF3B82F6),
                        bevelColor: const Color(0xFF1D4ED8),
                        borderColor: const Color(0xFF1E3A8A),
                        borderRadius: 18.r,
                        onTap: () {
                          AudioManager.playTileSelect(pitchIndex: 2);
                          Navigator.of(context).pop();
                        },
                        child: Center(
                          child: CartoonText(
                            text: 'AWESOME!',
                            fontSize: 16.sp,
                            textColor: Colors.white,
                            outlineColor: const Color(0xFF1E3A8A),
                            strokeWidth: 3.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 5. Header Banner: "DAILY REWARDS 🎁"
              Positioned(
                top: -22.h,
                child: Container(
                  height: 46.h,
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF9F1A),
                        Color(0xFFE87A00),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(23.r),
                    border: Border.all(color: Colors.white, width: 2.8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF9E4E00),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x40000000),
                        offset: Offset(0, 6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 8.w),
                        CartoonText(
                          text: 'DAILY REWARDS',
                          fontSize: 19.sp,
                          textColor: Colors.white,
                          outlineColor: const Color(0xFF7A3600),
                          strokeWidth: 3.8,
                          shadowOffset: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 6. Close Button
              Positioned(
                top: -14.h,
                right: -6.w,
                child: BouncyButton(
                  onTap: () {
                    AudioManager.playTileSelect(pitchIndex: 2);
                    Navigator.of(context).pop();
                  },
                  child: Image.asset(
                    'assets/icons/icon_close.webp',
                    width: 44.r,
                    height: 44.r,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Day Card for Days 1 through 6 with high contrast, big icons, and bold labels
class _DailyDayCard extends StatelessWidget {
  final int day;
  final DailyLoginReward reward;
  final bool isClaimed;
  final bool isToday;

  const _DailyDayCard({
    required this.day,
    required this.reward,
    required this.isClaimed,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    // Background, border, and ribbon styling based on state (Harmonized casual game palette)
    Color cardBg = Colors.white;
    Color borderColor = const Color(0xFFB8D5E5);
    Color bevelColor = const Color(0xFFC7DEEB);
    List<Color> ribbonGradient = const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
    String ribbonText = 'DAY $day';

    if (isClaimed) {
      cardBg = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF86EFAC);
      bevelColor = const Color(0xFFBBF7D0);
      ribbonGradient = const [Color(0xFF22C55E), Color(0xFF16A34A)];
      ribbonText = 'DAY $day';
    } else if (isToday) {
      cardBg = const Color(0xFFFFFDF5);
      borderColor = const Color(0xFFF59E0B);
      bevelColor = const Color(0xFFD97706);
      ribbonGradient = const [Color(0xFFFF9800), Color(0xFFEA580C)];
      ribbonText = 'TODAY ⚡';
    }

    final double cardRadius = 16.r;
    final double borderWidth = isToday ? 2.5 : 1.5;
    final double innerRadius = (cardRadius - borderWidth).clamp(0.0, cardRadius);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          // 3D Bottom Bevel
          BoxShadow(
            color: bevelColor,
            offset: Offset(0, isToday ? 3.0 : 2.0),
            blurRadius: 0,
          ),
          if (isToday)
            const BoxShadow(
              color: Color(0x4DF59E0B),
              offset: Offset(0, 3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(innerRadius),
        child: Column(
          children: [
            // Top Day Header Ribbon
            Container(
              width: double.infinity,
              height: 22.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: ribbonGradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(innerRadius),
                  topRight: Radius.circular(innerRadius),
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isClaimed) ...[
                    Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13.sp,
                    ),
                    SizedBox(width: 3.w),
                  ],
                  Text(
                    ribbonText,
                    style: AppTypography.font(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Middle: Reward Icons with big, clear visuals (100% visible and un-dimmed)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: _buildRewardVisual(),
                ),
              ),
            ),

            // Bottom Reward Value Capsule
            Padding(
              padding: EdgeInsets.only(bottom: 6.h, left: 4.w, right: 4.w),
              child: _buildBottomBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardVisual() {
    final hasBooster = reward.hints > 0 || reward.rockets > 0;

    if (!hasBooster) {
      // Day 1: Big coin
      return Image.asset(
        'assets/icons/icon_coin.webp',
        width: 34.r,
        height: 34.r,
        fit: BoxFit.contain,
      );
    }

    final hasBothBoosters = reward.hints > 0 && reward.rockets > 0;
    final double coinSize = hasBothBoosters ? 22.r : 25.r;
    final double boosterSize = hasBothBoosters ? 20.r : 24.r;

    // Days 2 to 6: Coin + Booster(s) side by side
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/icons/icon_coin.webp',
          width: coinSize,
          height: coinSize,
          fit: BoxFit.contain,
        ),
        SizedBox(width: hasBothBoosters ? 3.w : 4.w),
        if (reward.hints > 0)
          Image.asset(
            'assets/icons/icon_hint.webp',
            width: boosterSize,
            height: boosterSize,
            fit: BoxFit.contain,
          ),
        if (reward.rockets > 0) ...[
          if (reward.hints > 0) SizedBox(width: 3.w),
          Image.asset(
            'assets/icons/icon_rocket.webp',
            width: boosterSize,
            height: boosterSize,
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBadge() {
    Color badgeBg;
    Color badgeBorder;
    Color coinTextColor;

    if (isClaimed) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeBorder = const Color(0xFFB9F6CA);
      coinTextColor = const Color(0xFF15803D);
    } else if (isToday) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFFDE68A);
      coinTextColor = const Color(0xFFB45309);
    } else {
      badgeBg = const Color(0xFFEFF6FC);
      badgeBorder = const Color(0xFFD3E6F2);
      coinTextColor = const Color(0xFF1E3A8A);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: badgeBorder,
          width: 1.0,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isClaimed) ...[
              Icon(
                Icons.check_rounded,
                color: coinTextColor,
                size: 11.sp,
              ),
              SizedBox(width: 2.w),
            ],
            Text(
              '+${reward.coins}',
              style: AppTypography.font(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w900,
                color: coinTextColor,
              ),
            ),
            if (reward.hints > 0) ...[
              Text(
                ' • ',
                style: AppTypography.font(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: isClaimed
                      ? const Color(0xFF86EFAC)
                      : (isToday ? const Color(0xFFFCD34D) : const Color(0xFF93C5FD)),
                ),
              ),
              Text(
                '+${reward.hints}💡',
                style: AppTypography.font(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w900,
                  color: isClaimed
                      ? const Color(0xFF15803D)
                      : const Color(0xFF0284C7),
                ),
              ),
            ],
            if (reward.rockets > 0) ...[
              Text(
                ' • ',
                style: AppTypography.font(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: isClaimed
                      ? const Color(0xFF86EFAC)
                      : (isToday ? const Color(0xFFFCD34D) : const Color(0xFF93C5FD)),
                ),
              ),
              Text(
                '+${reward.rockets}🚀',
                style: AppTypography.font(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w900,
                  color: isClaimed
                      ? const Color(0xFF15803D)
                      : const Color(0xFF7E22CE),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Day 7 Featured Grand Prize: Royal Gold Card with 3 distinct high-value reward chips
class _Day7GrandCard extends StatelessWidget {
  final DailyLoginReward reward;
  final bool isClaimed;
  final bool isToday;

  const _Day7GrandCard({
    required this.reward,
    required this.isClaimed,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> cardGradient;
    Color borderColor;
    Color bevelColor;

    if (isClaimed) {
      cardGradient = const [
        Color(0xFFF0FDF4),
        Color(0xFFDCFCE7),
        Color(0xFFBBF7D0),
      ];
      borderColor = const Color(0xFF16A34A);
      bevelColor = const Color(0xFF15803D);
    } else if (isToday) {
      cardGradient = const [
        Color(0xFFFFFBEB),
        Color(0xFFFEF08A),
        Color(0xFFFDE047),
      ];
      borderColor = const Color(0xFFD97706);
      bevelColor = const Color(0xFFB45309);
    } else {
      cardGradient = const [
        Color(0xFFFFFDF5),
        Color(0xFFFEF3C7),
        Color(0xFFFDE68A),
      ];
      borderColor = const Color(0xFFF59E0B);
      bevelColor = const Color(0xFFD97706);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardGradient,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: borderColor,
          width: isToday ? 2.8 : 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: bevelColor,
            offset: Offset(0, isToday ? 3.5 : 2.5),
            blurRadius: 0,
          ),
          if (isToday)
            const BoxShadow(
              color: Color(0x55F59E0B),
              offset: Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        children: [
          // Royal Master Chest Icon
          Image.asset(
            'assets/icons/icon_gift_master.webp',
            width: 52.r,
            height: 52.r,
            fit: BoxFit.contain,
          ),

          SizedBox(width: 8.w),

          // Details & 3 distinct reward chips (100% visible and un-dimmed)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grand Prize Header Row
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'DAY 7: GRAND JACKPOT',
                              style: AppTypography.font(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w900,
                                color: isClaimed ? const Color(0xFF166534) : const Color(0xFF78350F),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            const Text('👑', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(6.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x35000000),
                              offset: Offset(0, 1.5),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'READY! ⚡',
                          style: AppTypography.font(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ] else if (isClaimed) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6.r),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x25000000),
                              offset: Offset(0, 1.5),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 11.sp),
                            SizedBox(width: 3.w),
                            Text(
                              'CLAIMED',
                              style: AppTypography.font(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                SizedBox(height: 5.h),

                // 3 Distinct Reward Chips for Coins, Hints, and Rockets
                Row(
                  children: [
                    // Chip 1: Coins
                    Expanded(
                      child: _buildJackpotChip(
                        iconPath: 'assets/icons/icon_coin.webp',
                        text: '+${reward.coins}',
                        textColor: isClaimed ? const Color(0xFF166534) : const Color(0xFF92400E),
                        iconSize: 18.r,
                        isClaimed: isClaimed,
                      ),
                    ),
                    SizedBox(width: 5.w),

                    // Chip 2: Hints
                    Expanded(
                      child: _buildJackpotChip(
                        iconPath: 'assets/icons/icon_hint.webp',
                        text: '+${reward.hints}',
                        textColor: const Color(0xFF0369A1),
                        iconSize: 17.r,
                        isClaimed: isClaimed,
                      ),
                    ),
                    SizedBox(width: 5.w),

                    // Chip 3: Rockets
                    Expanded(
                      child: _buildJackpotChip(
                        iconPath: 'assets/icons/icon_rocket.webp',
                        text: '+${reward.rockets}',
                        textColor: const Color(0xFF7E22CE),
                        iconSize: 17.r,
                        isClaimed: isClaimed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJackpotChip({
    required String iconPath,
    required String text,
    required Color textColor,
    required double iconSize,
    bool isClaimed = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: isClaimed ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: isClaimed ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            offset: Offset(0, 1.5),
            blurRadius: 2,
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(iconPath, width: iconSize, height: iconSize, fit: BoxFit.contain),
            SizedBox(width: 3.w),
            Text(
              text,
              style: AppTypography.font(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
