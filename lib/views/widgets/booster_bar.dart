import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/game_controller.dart';
import '../../services/game_storage.dart';
import 'booster_unlock_dialog.dart';
import 'bouncy_button.dart';
import 'tutorial_overlay.dart';

class BoosterBar extends StatefulWidget {
  final GameController controller;
  final VoidCallback? onOpenShop;
  final VoidCallback? onOpenExtraWords;
  final VoidCallback? onHintTap;
  final VoidCallback? onRocketTap;
  final bool isHintSpotlighted;
  final bool isRocketSpotlighted;
  final GlobalKey<ExtraWordsButtonState>? extraWordsBtnKey;
  final GlobalKey? hintBtnKey;
  final GlobalKey? rocketBtnKey;

  const BoosterBar({
    super.key,
    required this.controller,
    this.onOpenShop,
    this.onOpenExtraWords,
    this.onHintTap,
    this.onRocketTap,
    this.isHintSpotlighted = false,
    this.isRocketSpotlighted = false,
    this.extraWordsBtnKey,
    this.hintBtnKey,
    this.rocketBtnKey,
  });

  @override
  State<BoosterBar> createState() => _BoosterBarState();
}

class _BoosterBarState extends State<BoosterBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    GameStorage.hintCountNotifier.addListener(_rebuild);
    GameStorage.rocketCountNotifier.addListener(_rebuild);
    GameStorage.coinsNotifier.addListener(_rebuild);
    GameStorage.infiniteBoostersNotifier.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant BoosterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    GameStorage.hintCountNotifier.removeListener(_rebuild);
    GameStorage.rocketCountNotifier.removeListener(_rebuild);
    GameStorage.coinsNotifier.removeListener(_rebuild);
    GameStorage.infiniteBoostersNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Dimensions matching mockup media_1789032593898.png:
    // Menu bar sits at bottom with height 54.h + bottomInset
    // Booster cards are 58.r tall. Exactly 50% (29.r) sits above menu_bar on the background,
    // and 50% (29.r) sits below the top edge of menu_bar.
    final cardHeight = 58.r;
    final halfOverlap = cardHeight / 2; // 29.r
    final menuBarHeight = 54.h + bottomInset;
    final totalHeight = halfOverlap + menuBarHeight;

    // Levels 1-4: No boosters unlocked yet. Do NOT show booster bar or menu_bar
    if (!controller.isBoosterBarVisible) {
      return const SizedBox.shrink();
    }

    final hintCount = GameStorage.getHintCount();
    final rocketCount = GameStorage.getRocketCount();

    // Levels 5 & 6: Only Hint is unlocked (Rocket unlocks at Level 7).
    // Display Hint button alone, centered at the bottom, without Rocket and without menu_bar.
    if (!controller.isRocketUnlocked) {
      return SizedBox(
        width: double.infinity,
        height: totalHeight,
        child: Align(
          alignment: Alignment.topCenter,
          child: _buildHintBooster(hintCount: hintCount),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 1. Menu bar asset at the bottom (NO custom code/container color)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: menuBarHeight,
            child: Image.asset(
              'assets/images/menu_bar.webp',
              width: double.infinity,
              height: menuBarHeight,
              fit: BoxFit.fill,
            ),
          ),

          // 2. Booster buttons row - aligned so cards are 50% on background, 50% on menu bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Hint Booster 💡
                _buildHintBooster(hintCount: hintCount),
                SizedBox(width: 18.w),
                // 2. Rocket Booster 🚀
                _buildRocketBooster(rocketCount: rocketCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintBooster({required int hintCount}) {
    final controller = widget.controller;
    final isSpotlighted = widget.isHintSpotlighted;
    final isLevel5Free = controller.levelNumber == 5 && !GameStorage.hasUsedLevel5FreeHint();
    final isFree = isSpotlighted || isLevel5Free;
    final isInfinite = GameStorage.isInfiniteBoostersEnabled();
    final hasBooster = isFree || isInfinite || hintCount > 0;

    return BouncyButton(
      key: widget.hintBtnKey,
      onTap: () async {
        if (isFree) {
          if (widget.onHintTap != null && isSpotlighted) {
            widget.onHintTap?.call();
          } else {
            GameStorage.setLevel5FreeHintUsed(true);
            controller.useHint(isTutorialFree: true);
            _rebuild();
          }
          return;
        }
        widget.onHintTap?.call();
        if (hasBooster) {
          controller.useHint();
        } else {
          await BoosterUnlockDialog.show(
            context,
            boosterType: BoosterType.hint,
            controller: controller,
          );
        }
      },
      child: SizedBox(
        width: 66.r,
        height: 70.r,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // White Rounded Square Card (58.r x 58.r)
            Container(
              width: 58.r,
              height: 58.r,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  if (isSpotlighted)
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.8),
                      blurRadius: 18,
                      spreadRadius: 4,
                    ),
                  const BoxShadow(
                    color: Color(0xFFCBD5E1),
                    offset: Offset(0, 2.5),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/icons/icon_hint.webp',
                  width: 38.r,
                  height: 38.r,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Attached badge: Green FREE badge centered at bottom when isFree, otherwise count badge in bottom-right corner
            if (isFree)
              Positioned(
                bottom: 2.h,
                left: 0,
                right: 0,
                child: const Center(
                  child: GreenFreeBadge(),
                ),
              )
            else
              Positioned(
                bottom: 2.h,
                right: 0,
                child: hasBooster
                    ? OrangeCountBadge(
                        count: hintCount,
                        label: isInfinite ? '∞' : null,
                      )
                    : const GreenPlusBadge(),
              ),

            // Downward arrow pointer positioned directly above the Hint icon
            if (isSpotlighted)
              Positioned(
                top: -60.h,
                child: const IgnorePointer(
                  child: TutorialArrowPointer(size: 38),
                ),
              ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildRocketBooster({required int rocketCount}) {
    final controller = widget.controller;
    final isSpotlighted = widget.isRocketSpotlighted;
    final isLevel7Free = controller.levelNumber == 7 && !GameStorage.hasUsedLevel7FreeRocket();
    final isFree = isSpotlighted || isLevel7Free;
    final isInfinite = GameStorage.isInfiniteBoostersEnabled();
    final hasBooster = isFree || isInfinite || rocketCount > 0;

    return BouncyButton(
      key: widget.rocketBtnKey,
      onTap: () async {
        if (isFree) {
          if (widget.onRocketTap != null && isSpotlighted) {
            widget.onRocketTap?.call();
          } else {
            GameStorage.setLevel7FreeRocketUsed(true);
            controller.useRocket(isTutorialFree: true);
            _rebuild();
          }
          return;
        }
        widget.onRocketTap?.call();
        if (hasBooster) {
          controller.useRocket();
        } else {
          await BoosterUnlockDialog.show(
            context,
            boosterType: BoosterType.rocket,
            controller: controller,
          );
        }
      },
      child: SizedBox(
        width: 66.r,
        height: 70.r,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // White Rounded Square Card (58.r x 58.r)
            Container(
              width: 58.r,
              height: 58.r,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  if (isSpotlighted) ...[
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.8),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                  const BoxShadow(
                    color: Color(0xFFCBD5E1),
                    offset: Offset(0, 2.5),
                    blurRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Image.asset(
                  'assets/icons/icon_rocket.webp',
                  width: 38.r,
                  height: 38.r,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Attached badge: Green FREE badge centered at bottom when isFree, otherwise count badge in bottom-right corner
            if (isFree)
              Positioned(
                bottom: 2.h,
                left: 0,
                right: 0,
                child: const Center(
                  child: GreenFreeBadge(),
                ),
              )
            else
              Positioned(
                bottom: 2.h,
                right: 0,
                child: hasBooster
                    ? OrangeCountBadge(
                        count: rocketCount,
                        label: isInfinite ? '∞' : null,
                      )
                    : const GreenPlusBadge(),
              ),

            // Downward arrow pointer positioned directly above the Rocket icon
            if (isSpotlighted)
              Positioned(
                top: -60.h,
                child: const IgnorePointer(
                  child: TutorialArrowPointer(size: 38),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Star Progress / Extra Words circular button matching mockup exactly
class ExtraWordsButton extends StatefulWidget {
  final int extraCount;
  final VoidCallback? onTap;
  final bool isSpotlighted;

  const ExtraWordsButton({
    super.key,
    required this.extraCount,
    required this.onTap,
    this.isSpotlighted = false,
  });

  @override
  State<ExtraWordsButton> createState() => ExtraWordsButtonState();
}

class ExtraWordsButtonState extends State<ExtraWordsButton> with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 0.90).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.90, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_bounceController);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void punchBounce() {
    _bounceController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ((widget.extraCount % 10) / 10.0).clamp(0.0, 1.0);
    final displayValue = widget.extraCount;

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          alignment: Alignment.center,
          child: child,
        );
      },
      child: BouncyButton(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48.r,
              height: 48.r,
              decoration: BoxDecoration(
                color: const Color(0xFF0F2A66),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSpotlighted ? const Color(0xFFFFD700) : Colors.white,
                  width: 2.5,
                ),
                boxShadow: [
                  if (widget.isSpotlighted) ...[
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.95),
                      blurRadius: 22,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inside green progress arc hugging inner rim of white border
                  if (progress > 0)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(0.8),
                        child: CustomPaint(
                          painter: _StarProgressArcPainter(
                            progress: progress,
                            color: const Color(0xFF4ADE80),
                            strokeWidth: 3.5,
                          ),
                        ),
                      ),
                    ),

                  // Centered Yellow Star
                  Image.asset(
                    'assets/icons/icon_star.webp',
                    width: 28.r,
                    height: 28.r,
                    fit: BoxFit.contain,
                  ),

                  // Number with dark navy cartoon outline matching reference exactly
                  Text(
                    '$displayValue',
                    style: AppTypography.font(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(offset: Offset(-1.2, -1.2), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(1.2, -1.2), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(-1.2, 1.2), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(1.2, 1.2), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(0, -1.5), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(0, 1.5), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(-1.5, 0), color: Color(0xFF0F2A66)),
                        Shadow(offset: Offset(1.5, 0), color: Color(0xFF0F2A66)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Upward arrow pointer positioned directly below the Extra Words star icon
            if (widget.isSpotlighted)
              Positioned(
                bottom: -52.h,
                child: const IgnorePointer(
                  child: TutorialArrowPointer(size: 38, pointingUp: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the green progress arc inside the star button rim
class _StarProgressArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  const _StarProgressArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Start at -pi / 2 (top / 12 o'clock), sweep clockwise
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StarProgressArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// 3D Vector-rendered Orange Circular/Pill Badge for remaining booster counts.
/// Dynamically expands horizontally for multi-digit counts (e.g. 10, 99, 999, ∞) without wrapping.
class OrangeCountBadge extends StatelessWidget {
  final int count;
  final String? label;
  final double size;

  const OrangeCountBadge({
    super.key,
    required this.count,
    this.label,
    this.size = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    final text = label ?? '$count';
    final isMultiDigit = text.length > 1;

    return Container(
      height: size.r,
      constraints: BoxConstraints(
        minWidth: size.r,
      ),
      padding: EdgeInsets.symmetric(horizontal: isMultiDigit ? 6.w : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.r / 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFCB63D), // top sunny amber
            Color(0xFFE58826), // bottom warm orange
          ],
        ),
        border: Border.all(
          color: const Color(0xFF8B3612), // cartoon warm russet outline
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF9E4216), // 3D bottom bevel
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 2.5,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: AppTypography.font(
          fontSize: (size * (text.length >= 3 ? 0.46 : 0.54)).sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          shadows: const [
            Shadow(offset: Offset(-0.8, -0.8), color: Color(0xFF1E3A6E)),
            Shadow(offset: Offset(0.8, -0.8), color: Color(0xFF1E3A6E)),
            Shadow(offset: Offset(-0.8, 0.8), color: Color(0xFF1E3A6E)),
            Shadow(offset: Offset(0.8, 0.8), color: Color(0xFF1E3A6E)),
            Shadow(offset: Offset(0, 1.2), color: Color(0xFF1E3A6E)),
          ],
        ),
      ),
    );
  }
}

/// 3D Vector-rendered Green Pill Badge for FREE tutorial booster prompt (centered at bottom).
class GreenFreeBadge extends StatelessWidget {
  final double size;

  const GreenFreeBadge({
    super.key,
    this.size = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.r,
      padding: EdgeInsets.symmetric(horizontal: 5.5.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size.r / 2),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5CEB38), // top sunny bright green
            Color(0xFF28A811), // bottom rich cartoon green
          ],
        ),
        border: Border.all(
          color: const Color(0xFF14530A), // dark green cartoon outline
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0E3D07), // 3D bottom bevel
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 2.5,
          ),
        ],
      ),
      child: Center(
        widthFactor: 1.0,
        heightFactor: 1.0,
        child: Text(
          'FREE',
          maxLines: 1,
          softWrap: false,
          style: AppTypography.font(
            fontSize: (size * 0.46).sp,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.2,
            height: 1.0,
            shadows: const [
              Shadow(offset: Offset(-0.8, -0.8), color: Color(0xFF0E3D07)),
              Shadow(offset: Offset(0.8, -0.8), color: Color(0xFF0E3D07)),
              Shadow(offset: Offset(-0.8, 0.8), color: Color(0xFF0E3D07)),
              Shadow(offset: Offset(0.8, 0.8), color: Color(0xFF0E3D07)),
              Shadow(offset: Offset(0, 1.2), color: Color(0xFF0E3D07)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3D Vector-rendered Green Plus Badge for when free boosters are depleted (count == 0).
class GreenPlusBadge extends StatelessWidget {
  final double size;

  const GreenPlusBadge({
    super.key,
    this.size = 25.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFCB63D), // top sunny amber
            Color(0xFFE58826), // bottom warm orange
          ],
        ),
        border: Border.all(
          color: const Color(0xFF8B3612), // cartoon warm russet outline
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF9E4216), // 3D bottom bevel
            offset: Offset(0, 1.5),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 2.5,
          ),
        ],
      ),
      padding: EdgeInsets.all(2.0.r),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF76E846), // bright fresh lime green
              Color(0xFF3EB818), // warm grass green
            ],
          ),
          border: Border.all(
            color: const Color(0xFF28870E),
            width: 0.8,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: (size * 0.64).r,
            shadows: const [
              Shadow(
                color: Color(0xFF1D6809),
                offset: Offset(0, 1.0),
                blurRadius: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3D Vector-rendered Green Pill Badge for booster prices and action buttons.
class GreenPillBadge extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GreenPillBadge({
    super.key,
    required this.child,
    this.padding,
  });

  /// Factory constructor for displaying a coin price (e.g. [coin] 80 or [coin] 240)
  factory GreenPillBadge.coinPrice({
    Key? key,
    required int coins,
    double? coinSize,
    double? fontSize,
  }) {
    return GreenPillBadge(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'assets/icons/icon_coin.webp',
            width: coinSize ?? 13.5.r,
            height: coinSize ?? 13.5.r,
          ),
          SizedBox(width: 2.5.w),
          Text(
            '$coins',
            style: AppTypography.font(
              fontSize: fontSize ?? 12.sp,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
              shadows: const [
                Shadow(
                  color: Color(0xFF238E13),
                  offset: Offset(0, 1.0),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Factory constructor for displaying text (e.g. 'GIFT')
  factory GreenPillBadge.text({
    Key? key,
    required String text,
    double? fontSize,
    EdgeInsetsGeometry? padding,
  }) {
    return GreenPillBadge(
      key: key,
      padding: padding ?? EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
      child: Text(
        text,
        style: AppTypography.font(
          fontSize: fontSize ?? 10.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
          height: 1.0,
          shadows: const [
            Shadow(
              color: Color(0xFF238E13),
              offset: Offset(0, 1.0),
              blurRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  /// Factory constructor for displaying a count number (e.g. 1, 2, 3...)
  factory GreenPillBadge.count({
    Key? key,
    required int count,
    double? fontSize,
  }) {
    return GreenPillBadge(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
      child: Text(
        '$count',
        style: AppTypography.font(
          fontSize: fontSize ?? 12.sp,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          shadows: const [
            Shadow(
              color: Color(0xFF238E13),
              offset: Offset(0, 1.0),
              blurRadius: 0,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF6DE853), // bright fresh lime-green
            Color(0xFF45D028), // warm vibrant grass-green
          ],
        ),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFF3AB81E), // natural soft green border, NOT dark forest green
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF238E13), // 3D bottom bevel
            offset: Offset(0, 1.6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x2A000000),
            offset: Offset(0, 1.5),
            blurRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

