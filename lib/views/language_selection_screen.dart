import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/audio_manager.dart';
import '../services/app_localization.dart';
import '../services/game_storage.dart';
import '../services/level_loader.dart';
import '../theme/app_typography.dart';
import '../utils/game_transitions.dart';

/// Language Selection Screen & Popup Dialog styled consistently with Settings & Exit popups.
/// Features:
/// - Purple 3D banner header (`bg_btn_setting.png`)
/// - Tactile close button overflowing the corner (`icon_close.png`) - hidden on first launch FTUE
/// - Sunken pastel panel (`#D5E7F3`) with scrollable 3D language cards
/// - Real-time selection highlighting with checkmark badge
/// - Tactile 3D Green "Confirm" button
class LanguageSelectionScreen extends StatefulWidget {
  final String? currentLanguage;
  final ValueChanged<String>? onLanguageSelected;

  const LanguageSelectionScreen({
    super.key,
    this.currentLanguage,
    this.onLanguageSelected,
  });

  /// Helper to open LanguageSelectionScreen as a popup dialog
  static Future<void> show(
    BuildContext context, {
    required String currentLanguage,
    required ValueChanged<String> onLanguageSelected,
  }) {
    AudioManager.playTileSelect(pitchIndex: 4);
    return showGameDialog(
      context: context,
      builder: (_) => LanguageSelectionScreen(
        currentLanguage: currentLanguage,
        onLanguageSelected: onLanguageSelected,
      ),
    );
  }

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _tempSelectedLanguage;

  @override
  void initState() {
    super.initState();
    _tempSelectedLanguage = widget.currentLanguage ?? GameStorage.getSelectedLanguage();
  }

  void _confirmSelection() async {
    AudioManager.playTileSelect(pitchIndex: 6);
    await GameStorage.setSelectedLanguage(_tempSelectedLanguage);
    widget.onLanguageSelected?.call(_tempSelectedLanguage);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final languages = LevelLoader.supportedLanguages;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: _buildDialogCard(languages),
      ),
    );
  }

  /// Compact Modal Dialog card used when opened from Settings popup.
  Widget _buildDialogCard(List<String> languages) {
    return SizedBox(
      width: 336.w,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // 1. Outer White Card with Soft 3D Shadow
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30.r),
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
            padding: EdgeInsets.fromLTRB(16.w, 36.h, 16.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sunken Pastel Panel containing Language List
                Container(
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
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                  child: SizedBox(
                    height: 330.h,
                    child: RawScrollbar(
                      thumbColor: const Color(0xFF8FAFC6),
                      radius: Radius.circular(8.r),
                      thickness: 4.w,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 2.w),
                        itemCount: languages.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8.h),
                        itemBuilder: (context, index) {
                          final lang = languages[index];
                          final isSelected = lang == _tempSelectedLanguage;
                          final displayName = LevelLoader.languageDisplayNames[lang] ?? lang;
                          final lastSpaceIdx = displayName.lastIndexOf(' ');
                          final langName = lastSpaceIdx != -1 ? displayName.substring(0, lastSpaceIdx) : displayName;
                          final flag = lastSpaceIdx != -1 ? displayName.substring(lastSpaceIdx + 1) : '🌐';
                          final maxUnlocked = GameStorage.getMaxUnlockedLevelIndex(lang) + 1;

                          return _LanguageItemCard(
                            flag: flag,
                            name: langName,
                            progressLevel: maxUnlocked,
                            isSelected: isSelected,
                            onTap: () {
                              AudioManager.playTileSelect(pitchIndex: 4);
                              setState(() => _tempSelectedLanguage = lang);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Confirm 3D Button
                _Pressable3DButton(
                  label: AppLocalization.tr('confirm'),
                  icon: Icons.check_circle_rounded,
                  faceColor: const Color(0xFF23D046),
                  bevelColor: const Color(0xFF135025),
                  borderColor: const Color(0xFF0F3E1D),
                  outlineColor: const Color(0xFF0F3E1D),
                  onTap: _confirmSelection,
                ),
              ],
            ),
          ),

          // 2. Header Banner Ribbon (bg_btn_setting.png)
          Positioned(
            top: -24.h,
            child: SizedBox(
              width: 216.w,
              height: 58.h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/icons/bg_btn_setting.webp',
                    width: 216.w,
                    height: 58.h,
                    fit: BoxFit.fill,
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: CartoonText(
                      text: AppLocalization.tr('language'),
                      fontSize: 23,
                      textColor: Colors.white,
                      outlineColor: const Color(0xFF380662),
                      strokeWidth: 3.8,
                      shadowOffset: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Tactile Close Button (icon_close.png)
          Positioned(
            top: -12.h,
            right: -4.w,
            child: _CloseButton(
              onTap: () {
                AudioManager.playTileSelect(pitchIndex: 1);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive 3D Language Item Card with Flag, Name, Progress Level & Selection Badge
class _LanguageItemCard extends StatefulWidget {
  final String flag;
  final String name;
  final int progressLevel;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageItemCard({
    required this.flag,
    required this.name,
    required this.progressLevel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LanguageItemCard> createState() => _LanguageItemCardState();
}

class _LanguageItemCardState extends State<_LanguageItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (GameStorage.isHapticEnabled()) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 70),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : const Color(0xFFF3F8FB),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? const Color(0xFF23D046) : const Color(0xFFBED7E8),
              width: isSelected ? 2.2 : 1.2,
            ),
            boxShadow: [
              if (isSelected) ...[
                BoxShadow(
                  color: const Color(0xFF23D046).withValues(alpha: 0.25),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                ),
                BoxShadow(
                  color: const Color(0xFF135025).withValues(alpha: 0.12),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ] else ...[
                const BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ],
          ),
          child: Row(
            children: [
              // Flag Circle
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFE8F8ED) : Colors.white,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF23D046) : const Color(0xFFBED7E8),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.flag,
                  style: TextStyle(fontSize: 20.sp),
                ),
              ),

              SizedBox(width: 12.w),

              // Language Name & Progress Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      style: AppTypography.font(
                        fontSize: 16.sp,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      AppLocalization.tr('progress_level', args: [widget.progressLevel]),
                      style: AppTypography.font(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF5A7B9A),
                      ),
                    ),
                  ],
                ),
              ),

              // Radio Checkbox / Checkmark Circle
              Container(
                width: 24.r,
                height: 24.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFF23D046) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF23D046) : const Color(0xFFBED7E8),
                    width: 2.0,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tactile 3D Action Button matching Settings & Exit popups
class _Pressable3DButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color faceColor;
  final Color bevelColor;
  final Color borderColor;
  final Color outlineColor;
  final VoidCallback onTap;

  const _Pressable3DButton({
    required this.label,
    required this.icon,
    required this.faceColor,
    required this.bevelColor,
    required this.borderColor,
    required this.outlineColor,
    required this.onTap,
  });

  @override
  State<_Pressable3DButton> createState() => _Pressable3DButtonState();
}

class _Pressable3DButtonState extends State<_Pressable3DButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (GameStorage.isHapticEnabled()) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        height: 50.h,
        margin: EdgeInsets.only(
          top: _isPressed ? 3.h : 0,
          bottom: _isPressed ? 0 : 3.h,
        ),
        decoration: BoxDecoration(
          color: widget.faceColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: widget.borderColor, width: 0.5),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: widget.bevelColor,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            const BoxShadow(
              color: Color(0x22000000),
              offset: Offset(0, 4),
              blurRadius: 5,
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: _isPressed ? 0 : 2.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 22.r),
            SizedBox(width: 8.w),
            CartoonText(
              text: widget.label,
              fontSize: 18,
              textColor: Colors.white,
              outlineColor: widget.outlineColor,
              strokeWidth: 3.0,
              shadowOffset: 1.2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactile Close Button using icon_close.png
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (GameStorage.isHapticEnabled()) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        child: Image.asset(
          'assets/icons/icon_close.webp',
          width: 44.r,
          height: 44.r,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}


