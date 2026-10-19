import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/iap_product_model.dart';
import '../../services/app_localization.dart';
import '../../services/audio_manager.dart';
import '../../services/game_storage.dart';
import '../../services/iap_manager.dart';
import '../../theme/app_typography.dart';
import '../../utils/game_transitions.dart';
import 'pressable_3d_button.dart';

/// Modal dialog offering Remove Ads package to player.
/// Triggered right after an endgame interstitial ad is closed, before advancing to the new level.
class RemoveAdsDialog extends StatefulWidget {
  final int level;
  final String location;

  const RemoveAdsDialog({
    super.key,
    required this.level,
    this.location = 'endgame_win',
  });

  /// Presents the Remove Ads popup using standard game dialog transition.
  /// Executes [onClosed] when the dialog is dismissed or completed.
  static Future<void> show(
    BuildContext context, {
    required int level,
    required VoidCallback onClosed,
    String location = 'endgame_win',
  }) async {
    // If player already bought No Ads, bypass immediately
    if (GameStorage.isNoAdsPurchased()) {
      onClosed();
      return;
    }

    // Mark that user has seen No Ads popup anywhere (Case 1 gatekeeper)
    await GameStorage.setHasEverSeenNoAdsPopup(true);

    AudioManager.playTileSelect(pitchIndex: 4);
    IapManager.logShopImpression(level: level, location: location);

    if (!context.mounted) return;

    await showGameDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RemoveAdsDialog(
        level: level,
        location: location,
      ),
    );

    onClosed();
  }

  @override
  State<RemoveAdsDialog> createState() => _RemoveAdsDialogState();
}

class _RemoveAdsDialogState extends State<RemoveAdsDialog> {
  bool _isBuying = false;

  Future<void> _buyNoAds() async {
    if (_isBuying) return;
    setState(() => _isBuying = true);

    try {
      final success = await IapManager.buyProduct(
        context,
        IapProduct.noAds,
        level: widget.level,
        location: widget.location,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      // Handled inside buyProduct
    } finally {
      if (mounted) {
        setState(() => _isBuying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 326.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. Main Warm Cream Card Container
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF5),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: const Color(0xFFF3E8D8),
                    width: 2.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3D000000),
                      offset: Offset(0, 10),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0xFFE2CBB2),
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 38.h),

                    // Center 3D Clapperboard Graphic
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Image.asset(
                        'assets/images/img_remove_ads.png',
                        width: 190.w,
                        height: 190.w,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) => SizedBox(
                          height: 160.h,
                          child: const Center(
                            child: Icon(
                              Icons.block_rounded,
                              size: 72,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // Feature descriptions (2 lines)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Column(
                        children: [
                          Text(
                            AppLocalization.tr('remove_ads_desc_1'),
                            textAlign: TextAlign.center,
                            style: AppTypography.font(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF38354A),
                              height: 1.25,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            AppLocalization.tr('remove_ads_desc_2'),
                            textAlign: TextAlign.center,
                            style: AppTypography.font(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF38354A),
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Custom 3D Green Price Button
                    Pressable3DButton(
                      width: 236.w,
                      height: 52.h,
                      borderRadius: 26,
                      faceColor: const Color(0xFF00D13B),
                      bevelColor: const Color(0xFF009024),
                      borderColor: const Color(0xFF006818),
                      borderWidth: 1.5,
                      bevelOffset: 4.0,
                      onTap: _isBuying ? null : _buyNoAds,
                      child: _isBuying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : ValueListenableBuilder<bool>(
                              valueListenable: IapManager.isPricesLoaded,
                              builder: (context, isLoaded, child) {
                                final price = IapManager.getDisplayPrice(IapProduct.noAds);
                                return Text(
                                  price,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.font(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: const [
                                      Shadow(
                                        color: Color(0xFF005814),
                                        offset: Offset(0, 1.8),
                                        blurRadius: 1,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 8.h),

                    // "One Time Purchase" Subtitle
                    Text(
                      AppLocalization.tr('one_time_purchase'),
                      style: AppTypography.font(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5E596D),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),

              // 2. Red Pill Header Badge ("Remove Ads")
              Positioned(
                top: -18.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 26.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFF5757),
                        Color(0xFFE53935),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFB71C1C),
                        offset: Offset(0, 3.5),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 4.0),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    AppLocalization.tr('remove_ads_title'),
                    textAlign: TextAlign.center,
                    style: AppTypography.font(
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0xFF8B1212),
                          offset: Offset(0, 1.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Top-Right Soft Tan 'X' Close Button
              Positioned(
                top: 8.h,
                right: 8.w,
                child: GestureDetector(
                  onTap: () {
                    AudioManager.playTileSelect(pitchIndex: 0);
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(8.r),
                    child: Icon(
                      Icons.close_rounded,
                      size: 28.r,
                      color: const Color(0xFFC78A6E),
                    ),
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
