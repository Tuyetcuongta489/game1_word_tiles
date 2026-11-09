import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/iap_product_model.dart';
import '../services/ads_manager.dart';
import '../services/audio_manager.dart';
import '../services/app_localization.dart';
import '../services/game_storage.dart';
import '../services/iap_manager.dart';
import '../theme/app_typography.dart';
import 'widgets/bouncy_button.dart';

class ShopScreen extends StatefulWidget {
  final int currentLevel;
  final VoidCallback? onClosed;

  const ShopScreen({
    super.key,
    this.currentLevel = 1,
    this.onClosed,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    IapManager.init();
    IapManager.refreshPrices();
    IapManager.pricesVersion.addListener(_onPricesUpdated);
    IapManager.logShopImpression(level: widget.currentLevel);
    if (!GameStorage.isNoAdsPurchased()) {
      AdsManager.showBanner('shop_bottom', level: widget.currentLevel);
    }
  }

  void _onPricesUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    IapManager.pricesVersion.removeListener(_onPricesUpdated);
    _scrollController.dispose();
    super.dispose();
  }

  bool _isProcessingPurchase = false;

  Future<void> _handlePurchase(IapProduct product) async {
    if (_isProcessingPurchase) return;
    _isProcessingPurchase = true;
    AudioManager.playTileSelect(pitchIndex: 4);
    try {
      await IapManager.buyProduct(
        context,
        product,
        level: widget.currentLevel,
        onPurchased: () {
          if (mounted) setState(() {});
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingPurchase = false);
      } else {
        _isProcessingPurchase = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isNoAds = GameStorage.isNoAdsPurchased();

    return Scaffold(
      backgroundColor: const Color(0xFF0A2B78),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F3B9E),
              Color(0xFF0C3388),
              Color(0xFF082260),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: topInset + 8.h),
            // ── 1. Top Bar Header ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildHeader(),
            ),
            SizedBox(height: 10.h),

            // ── 2. Scrollable Offers Catalog ──────────────────────────────
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: IapManager.isPricesLoaded,
                builder: (context, _, _) {
                  return ListView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16.w,
                      4.h,
                      16.w,
                      bottomInset + (isNoAds ? 24.h : 70.h),
                    ),
                    children: [
                      // ══════════════════════════════════════════════════════
                      // SECTION 1: SPECIAL OFFERS & BUNDLES
                      // ══════════════════════════════════════════════════════
                      _buildSectionHeader(
                        title: AppLocalization.tr('special_offers'),
                        icon: '🎁',
                        subtitle: 'Limited packages with bonus coins & boosters',
                      ),
                      SizedBox(height: 12.h),

                      // 1. Starter Pack ($2.99 - Purple)
                      _buildBundleCard(
                        product: IapProduct.starterPack,
                        cardGradient: const [Color(0xFFB060FF), Color(0xFF8A2BE2)],
                        borderColor: const Color(0xFFD4A5FF),
                        sackAsset: 'assets/icons/icon_gift_box.webp',
                        badgeText: 'POPULAR',
                        badgeColor: const Color(0xFFFF9800),
                      ),
                      SizedBox(height: 12.h),

                      // 2. Limited Pack ($5.99 - Amber Gold)
                      _buildBundleCard(
                        product: IapProduct.limitedPack,
                        cardGradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
                        borderColor: const Color(0xFFFDE68A),
                        sackAsset: 'assets/icons/icon_gift_explore.webp',
                        badgeText: 'LIMITED',
                        badgeColor: const Color(0xFFEF4444),
                      ),
                      SizedBox(height: 12.h),

                      // 3. No Ads Bundle ($6.99 - Sky Blue)
                      _buildBundleCard(
                        product: IapProduct.noAdsBundle,
                        cardGradient: const [Color(0xFF29B6F6), Color(0xFF0288D1)],
                        borderColor: const Color(0xFF81D4FA),
                        sackAsset: 'assets/icons/icon_gift_master.webp',
                        badgeText: 'BEST VALUE',
                        badgeColor: const Color(0xFF10B981),
                        showNoAdsBadge: true,
                      ),
                      SizedBox(height: 12.h),

                      // 4. No Ads Standalone ($5.99 - Rose)
                      _buildNoAdsCard(IapProduct.noAds),
                      SizedBox(height: 12.h),

                      // 5. Beginner Bundle ($14.99 - Emerald)
                      _buildBundleCard(
                        product: IapProduct.beginnerBundle,
                        cardGradient: const [Color(0xFF10B981), Color(0xFF047857)],
                        borderColor: const Color(0xFF6EE7B7),
                        sackAsset: 'assets/icons/icon_gift_box.webp',
                      ),
                      SizedBox(height: 12.h),

                      // 6. Master Bundle ($29.99 - Crimson Red)
                      _buildBundleCard(
                        product: IapProduct.masterBundle,
                        cardGradient: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
                        borderColor: const Color(0xFFFCA5A5),
                        sackAsset: 'assets/icons/icon_gift_master.webp',
                        badgeText: 'MEGA DEAL',
                        badgeColor: const Color(0xFF8B5CF6),
                      ),
                      SizedBox(height: 24.h),

                      // ══════════════════════════════════════════════════════
                      // SECTION 2: COIN SHOP (All 6 Tiers Unified)
                      // ══════════════════════════════════════════════════════
                      _buildSectionHeader(
                        title: AppLocalization.tr('coin_packs'),
                        icon: '🪙',
                        subtitle: 'Use coins to buy hints, rockets & continues',
                      ),
                      SizedBox(height: 12.h),

                      // Row 1: Free (Gold 0), Gold 1 ($0.99), Gold 2 ($7.99)
                      _buildGoldRow([
                        IapProduct.gold0,
                        IapProduct.gold1,
                        IapProduct.gold2,
                      ]),
                      SizedBox(height: 10.h),

                      // Row 2: Gold 3 ($15.99), Gold 4 ($29.99), Gold 5 ($55.99)
                      _buildGoldRow([
                        IapProduct.gold3,
                        IapProduct.gold4,
                        IapProduct.gold5,
                      ]),
                      SizedBox(height: 28.h),

                      // ══════════════════════════════════════════════════════
                      // FOOTER: RESTORE PURCHASES & STORE LEGAL
                      // ══════════════════════════════════════════════════════
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            AudioManager.playTileSelect(pitchIndex: 2);
                            IapManager.restorePurchases(context);
                          },
                          icon: Icon(
                            Icons.restore_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 19.r,
                          ),
                          label: Text(
                            AppLocalization.tr('restore_purchases'),
                            style: AppTypography.font(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Center(
                        child: Text(
                          'Purchases are processed securely via Apple App Store / Google Play.',
                          textAlign: TextAlign.center,
                          style: AppTypography.font(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Circular Back Button
        BouncyButton(
          onTap: () {
            AudioManager.playTileSelect(pitchIndex: 2);
            widget.onClosed?.call();
            Navigator.of(context).pop();
          },
          child: Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: const Color(0xFF072460),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2B5EB8), width: 2.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24.r,
            ),
          ),
        ),

        // Centered "Shop" Title
        CartoonText(
          text: AppLocalization.tr('shop'),
          fontSize: 32,
          textColor: Colors.white,
          outlineColor: const Color(0xFF061A47),
          strokeWidth: 4.5,
          shadowOffset: 2.2,
        ),

        // Coin Pill Badge
        Container(
          height: 38.h,
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          decoration: BoxDecoration(
            color: const Color(0xFF072460),
            borderRadius: BorderRadius.circular(19.r),
            border: Border.all(color: const Color(0xFFE5A93C), width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35000000),
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/icons/icon_coin.webp',
                width: 26.r,
                height: 26.r,
              ),
              SizedBox(width: 6.w),
              ValueListenableBuilder<int>(
                valueListenable: GameStorage.coinsNotifier,
                builder: (context, coins, _) {
                  return Text(
                    '$coins',
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section Header with Banner Pill ────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String icon,
    required String subtitle,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 2.h,
              width: 28.w,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xFF60A5FA)],
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 5.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF172554)],
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x30000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    title,
                    style: AppTypography.font(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 2.h,
              width: 28.w,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF60A5FA), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          subtitle,
          style: AppTypography.font(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Big Bundle Card ────────────────────────────────────────────────────────
  Widget _buildBundleCard({
    required IapProduct product,
    required List<Color> cardGradient,
    required Color borderColor,
    required String sackAsset,
    String? badgeText,
    Color? badgeColor,
    bool showNoAdsBadge = false,
  }) {
    final priceText = IapManager.getDisplayPrice(product);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardGradient,
            ),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: borderColor, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                offset: Offset(0, 5),
                blurRadius: 8,
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Upper Row: Item rewards + Big pouch art on right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Rewards List
                  Expanded(
                    child: Wrap(
                      spacing: 8.w,
                      runSpacing: 6.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Coin Pill
                        if (product.coins > 0)
                          _buildRewardCapsule(
                            iconAsset: 'assets/icons/icon_coin.webp',
                            count: '${product.coins}',
                            badgeColor: const Color(0xFFEF4444),
                            iconSize: 34.r,
                          ),

                        // Hint Pill
                        if (product.hints > 0)
                          _buildRewardCapsule(
                            iconAsset: 'assets/icons/icon_hint.webp',
                            count: '${product.hints}',
                            badgeColor: const Color(0xFFEF4444),
                            containerBg: Colors.white.withValues(alpha: 0.22),
                            iconSize: 26.r,
                          ),

                        // Rocket Pill
                        if (product.rockets > 0)
                          _buildRewardCapsule(
                            iconAsset: 'assets/icons/icon_rocket.webp',
                            count: '${product.rockets}',
                            badgeColor: const Color(0xFFEF4444),
                            containerBg: Colors.white.withValues(alpha: 0.22),
                            iconSize: 26.r,
                          ),

                        // Special No Ads Pill in Bundle
                        if (showNoAdsBadge)
                          Container(
                            height: 42.r,
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ClapperboardNoAdsIcon(size: 28),
                                SizedBox(width: 4.w),
                                Text(
                                  '+ NO ADS',
                                  style: AppTypography.font(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Big Gift Pouch / Sack Art
                  Image.asset(
                    sackAsset,
                    width: 66.r,
                    height: 66.r,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Lower Row: Title + Green 3D Buy Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: CartoonText(
                      text: product.title,
                      fontSize: 19,
                      textColor: Colors.white,
                      outlineColor: const Color(0xFF2C1052),
                      strokeWidth: 3.2,
                      shadowOffset: 1.4,
                    ),
                  ),
                  _buildGreenBuyButton(
                    text: priceText,
                    onTap: () => _handlePurchase(product),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Corner Ribbon Badge (POPULAR, LIMITED, BEST VALUE)
        if (badgeText != null)
          Positioned(
            top: -7.h,
            left: 14.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x35000000),
                    offset: Offset(0, 2),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Text(
                badgeText,
                style: AppTypography.font(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── No Ads Standalone Card with Custom Clapperboard Art ────────────────────
  Widget _buildNoAdsCard(IapProduct product) {
    final isAlreadyOwned = GameStorage.isNoAdsPurchased();
    final priceText = isAlreadyOwned ? 'Owned' : IapManager.getDisplayPrice(product);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF43F5E), Color(0xFFBE123C)],
        ),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFFDA4AF), width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            offset: Offset(0, 5),
            blurRadius: 8,
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: High-detail Clapperboard No Ads Graphic + Title & Subtitle
          Expanded(
            child: Row(
              children: [
                const ClapperboardNoAdsIcon(size: 46),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CartoonText(
                        text: 'No Ads',
                        fontSize: 20,
                        textColor: Colors.white,
                        outlineColor: Color(0xFF700620),
                        strokeWidth: 3.2,
                        shadowOffset: 1.4,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Remove popups & banner ads',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.font(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Right: Buy Button
          _buildGreenBuyButton(
            text: priceText,
            isOwned: isAlreadyOwned,
            onTap: isAlreadyOwned ? null : () => _handlePurchase(product),
          ),
        ],
      ),
    );
  }

  // ── Gold Cards Row (3 Cards side-by-side) ──────────────────────────────────
  Widget _buildGoldRow(List<IapProduct> products) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: products.map((prod) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: _buildGoldCard(prod),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoldCard(IapProduct product) {
    final priceText = IapManager.getDisplayPrice(product);
    final isFree = product.isAdsReward;
    final isBestDeal = product.productId.endsWith('gold_5');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 172.h,
          decoration: BoxDecoration(
            color: const Color(0xFFF6FAFD),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isBestDeal ? const Color(0xFFF59E0B) : const Color(0xFF90CAF9),
              width: isBestDeal ? 2.4 : 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(6.w, 8.h, 6.w, 8.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Coin pile on Red Cushion / Pedestal
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // Red Pedestal base
                  Container(
                    width: 72.w,
                    height: 28.h,
                    margin: EdgeInsets.only(top: 26.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x25000000),
                          offset: Offset(0, 2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),

                  // Coin stack on top
                  Positioned(
                    top: 0,
                    child: Image.asset(
                      'assets/icons/icon_coin.webp',
                      width: 48.r,
                      height: 48.r,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Red Pill Badge with Coin Count
                  Positioned(
                    bottom: -6.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x30000000),
                            offset: Offset(0, 1.5),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        '${product.coins}',
                        style: AppTypography.font(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),

              // Button at bottom: "Free" with ad icon or Price tag
              _buildCompactBuyButton(
                text: priceText,
                isFree: isFree,
                onTap: () => _handlePurchase(product),
              ),
            ],
          ),
        ),

        // Best Deal tag on highest coin tier
        if (isBestDeal)
          Positioned(
            top: -6.h,
            right: 6.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                'BEST DEAL',
                style: AppTypography.font(
                  color: Colors.white,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Reusable Component Helpers ─────────────────────────────────────────────

  /// Reward Capsule: Icon inside translucent box with red count tag
  Widget _buildRewardCapsule({
    required String iconAsset,
    required String count,
    required Color badgeColor,
    Color? containerBg,
    double iconSize = 28,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42.r,
          height: 42.r,
          decoration: BoxDecoration(
            color: containerBg ?? Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Image.asset(
            iconAsset,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        // Red badge tag at bottom right
        Positioned(
          bottom: -4.h,
          right: -4.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Text(
              count,
              style: AppTypography.font(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Green 3D Pill Buy Button for wide cards
  Widget _buildGreenBuyButton({
    required String text,
    VoidCallback? onTap,
    bool isOwned = false,
  }) {
    return BouncyButton(
      onTap: onTap,
      child: Container(
        width: 108.w,
        height: 42.h,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/btn_green_victory.png'),
            colorFilter: isOwned
                ? const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0.2126, 0.7152, 0.0722, 0, 0,
                    0,      0,      0,      1, 0,
                  ])
                : null,
            fit: BoxFit.fill,
          ),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 3.h, left: 6.w, right: 6.w),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: AppTypography.font(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: isOwned ? const Color(0xFF424242) : const Color(0xFF1B5E20),
                  offset: const Offset(0, 1.5),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Compact Green 3D Buy Button for the 3-column gold packs
  Widget _buildCompactBuyButton({
    required String text,
    required bool isFree,
    VoidCallback? onTap,
  }) {
    return BouncyButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 38.h,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/btn_green_victory.png'),
            fit: BoxFit.fill,
          ),
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 2.5.h, left: 4.w, right: 4.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isFree) ...[
              Image.asset(
                'assets/icons/icon_ads.webp',
                width: 16.r,
                height: 16.r,
              ),
              SizedBox(width: 3.w),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  maxLines: 1,
                  style: AppTypography.font(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Color(0xFF1B5E20),
                        offset: Offset(0, 1.5),
                        blurRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HIGH-POLISH NO ADS MOVIE CLAPPERBOARD ICON WIDGET & PAINTER
// ═════════════════════════════════════════════════════════════════════════════
class ClapperboardNoAdsIcon extends StatelessWidget {
  final double size;

  const ClapperboardNoAdsIcon({super.key, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.95,
      child: CustomPaint(
        painter: _ClapperboardPainter(),
      ),
    );
  }
}

class _ClapperboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Drop Shadow under clapperboard
    final shadowPaint = Paint()
      ..color = const Color(0x38000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.28, w * 0.84, h * 0.68),
        Radius.circular(w * 0.12),
      ),
      shadowPaint,
    );

    // 2. Slate Body (Lower Dark Board)
    final boardRect = Rect.fromLTWH(w * 0.08, h * 0.26, w * 0.84, h * 0.68);
    final boardPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF334155), Color(0xFF1E293B)],
      ).createShader(boardRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.12)),
      boardPaint,
    );

    // Thin slate border
    final borderPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boardRect, Radius.circular(w * 0.12)),
      borderPaint,
    );

    // Subtle white chalk lines on slate ("SCENE / TAKE")
    final chalkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.20, h * 0.55), Offset(w * 0.70, h * 0.55), chalkPaint);
    canvas.drawLine(Offset(w * 0.20, h * 0.72), Offset(w * 0.55, h * 0.72), chalkPaint);

    // 3. Lower Fixed Clapper Bar with Zebra Stripes
    final lowerBarRect = Rect.fromLTWH(w * 0.08, h * 0.26, w * 0.84, h * 0.18);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(
      lowerBarRect,
      topLeft: Radius.circular(w * 0.12),
      topRight: Radius.circular(w * 0.12),
    ));
    final barBgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(lowerBarRect, barBgPaint);

    // Diagonal white zebra stripes
    final stripePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    for (double x = -w * 0.2; x < w * 1.2; x += w * 0.22) {
      final path = Path()
        ..moveTo(x, lowerBarRect.bottom)
        ..lineTo(x + w * 0.12, lowerBarRect.top)
        ..lineTo(x + w * 0.20, lowerBarRect.top)
        ..lineTo(x + w * 0.08, lowerBarRect.bottom)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    canvas.restore();

    // 4. Upper Open Clapper Arm (Tilted ~16 degrees up)
    canvas.save();
    canvas.translate(w * 0.12, h * 0.26);
    canvas.rotate(-16 * math.pi / 180);

    final upperBarRect = Rect.fromLTWH(0, -h * 0.18, w * 0.84, h * 0.18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(upperBarRect, Radius.circular(w * 0.06)),
      Paint()..color = const Color(0xFF0F172A),
    );

    canvas.clipRRect(RRect.fromRectAndRadius(upperBarRect, Radius.circular(w * 0.06)));
    for (double x = -w * 0.2; x < w * 1.2; x += w * 0.22) {
      final path = Path()
        ..moveTo(x, upperBarRect.bottom)
        ..lineTo(x + w * 0.12, upperBarRect.top)
        ..lineTo(x + w * 0.20, upperBarRect.top)
        ..lineTo(x + w * 0.08, upperBarRect.bottom)
        ..close();
      canvas.drawPath(path, stripePaint);
    }
    canvas.restore();

    // 5. Metallic Hinge Rivet (Bottom-left pivot point)
    final rivetCenter = Offset(w * 0.14, h * 0.26);
    final rivetPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFE2E8F0), Color(0xFF64748B), Color(0xFF334155)],
      ).createShader(Rect.fromCircle(center: rivetCenter, radius: w * 0.08));
    canvas.drawCircle(rivetCenter, w * 0.065, rivetPaint);
    canvas.drawCircle(
      rivetCenter,
      w * 0.065,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 6. Vibrant Glossy Red "NO ADS" Prohibition Ring & Slash
    final banCenter = Offset(w * 0.58, h * 0.60);
    final banRadius = w * 0.32;

    // Outer glow / shadow
    canvas.drawCircle(
      banCenter,
      banRadius + 1.5,
      Paint()
        ..color = const Color(0x35000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Dark red base circle
    final redBasePaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFF3366), Color(0xFFDC2626), Color(0xFF991B1B)],
      ).createShader(Rect.fromCircle(center: banCenter, radius: banRadius));

    final ringPaint = Paint()
      ..shader = redBasePaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095;
    canvas.drawCircle(banCenter, banRadius, ringPaint);

    // White backing circle inside
    final innerBgPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawCircle(banCenter, banRadius - (w * 0.05), innerBgPaint);

    // Text "ADS" inside circle
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'ADS',
        style: TextStyle(
          color: Colors.white,
          fontSize: banRadius * 0.92,
          fontWeight: FontWeight.w900,
          fontFamily: 'sans-serif',
          letterSpacing: -0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      banCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    // Red Diagonal Slash across "ADS" (top-left to bottom-right)
    final slashPaint = Paint()
      ..shader = redBasePaint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round;

    final slashOffset = banRadius * 0.72;
    canvas.drawLine(
      banCenter - Offset(slashOffset, slashOffset),
      banCenter + Offset(slashOffset, slashOffset),
      slashPaint,
    );

    // Top Gloss Highlight Arc on Red Ring
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: banCenter, radius: banRadius + (w * 0.02)),
      -math.pi * 0.85,
      math.pi * 0.65,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
