import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/audio_manager.dart';
import '../services/app_localization.dart';
import '../services/game_storage.dart';
import '../services/level_loader.dart';
import '../theme/app_typography.dart';
import '../widgets/common/game_scaffold.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'widgets/bouncy_button.dart';
import 'widgets/pressable_3d_button.dart';

/// Dedicated Full-Screen Onboarding Language Selection Screen (FTUE).
///
/// Designed as a genuine full-screen game view (not a dialog/popup):
/// - Authentic full-screen game background (`bg_home.webp`) without dimming scrim or dialog container
/// - Clean cartoon header title and responsive subtitle
/// - 1-column list of crisp 3D language cards with solid bevel depth and signature green selection outline
/// - Signature in-game 3D green action button (`assets/images/btn_green_victory.png`)
class FirstLanguageScreen extends StatefulWidget {
  const FirstLanguageScreen({super.key});

  @override
  State<FirstLanguageScreen> createState() => _FirstLanguageScreenState();
}

class _FirstLanguageScreenState extends State<FirstLanguageScreen> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = GameStorage.getSelectedLanguage();
  }

  void _onLanguageTapped(String lang) {
    if (_selectedLanguage == lang) return;
    AudioManager.playTileSelect(pitchIndex: 4);
    setState(() {
      _selectedLanguage = lang;
    });
  }

  Future<void> _onConfirmAndPlay() async {
    AudioManager.playTileSelect(pitchIndex: 6);
    try {
      if (GameStorage.isHapticEnabled()) {
        HapticFeedback.mediumImpact();
      }
    } catch (_) {}

    await GameStorage.setSelectedLanguage(_selectedLanguage);
    await GameStorage.markFirstSessionCompleted();

    if (!mounted) return;

    final count = LevelLoader.totalLevelsPerLanguage[_selectedLanguage] ?? 1000;
    final currentLvl = GameStorage.getMaxUnlockedLevelIndex(_selectedLanguage).clamp(0, count > 0 ? count - 1 : 0);

    final nav = Navigator.of(context);
    nav.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(isFirstSessionStart: true),
        transitionDuration: Duration.zero,
      ),
    );
    nav.push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(
          language: _selectedLanguage,
          levelIndex: currentLvl,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  String get _subtitle {
    switch (_selectedLanguage.toLowerCase()) {
      case 'vietnamese':
        return 'Chọn ngôn ngữ để bắt đầu chơi';
      case 'german':
        return 'Wähle deine Sprache zum Starten';
      case 'french':
        return 'Choisissez votre langue pour commencer';
      case 'spanish':
        return 'Elige tu idioma para comenzar';
      case 'italian':
        return 'Scegli la tua lingua per iniziare';
      case 'portuguese':
        return 'Escolha seu idioma para começar';
      case 'russian':
        return 'Выберите язык, чтобы начать игру';
      case 'turkish':
        return 'Oynamaya başlamak için dilini seç';
      case 'english':
      default:
        return 'Choose your language to start playing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = LevelLoader.supportedLanguages;

    return PopScope(
      canPop: false,
      child: GameScaffold(
        useSafeArea: false,
        background: Image.asset(
          'assets/images/bg_home.webp',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: Column(
              children: [
                SizedBox(height: 14.h),

                // ── 1. Screen Title & Subtitle ───────────────────────────────
                CartoonText(
                  text: AppLocalization.tr('language', language: _selectedLanguage).toUpperCase(),
                  fontSize: 28.sp,
                  textColor: Colors.white,
                  outlineColor: const Color(0xFF0F3E78),
                  strokeWidth: 4.5,
                  shadowOffset: 2.0,
                ),
                SizedBox(height: 4.h),
                Text(
                  _subtitle,
                  style: AppTypography.font(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                    shadows: const [
                      Shadow(
                        color: Colors.black45,
                        offset: Offset(0, 1.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // ── 2. Single-Column Scrollable Language List ───────────────
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 380.w),
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                        itemCount: languages.length,
                        separatorBuilder: (_, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final lang = languages[index];
                          final isSelected = lang == _selectedLanguage;
                          final displayName = LevelLoader.languageDisplayNames[lang] ?? lang;
                          final lastSpaceIdx = displayName.lastIndexOf(' ');
                          final langName = lastSpaceIdx != -1 ? displayName.substring(0, lastSpaceIdx) : displayName;
                          final flag = lastSpaceIdx != -1 ? displayName.substring(lastSpaceIdx + 1) : '🌐';

                          return _FirstLanguageItem(
                            flag: flag,
                            name: langName,
                            isSelected: isSelected,
                            onTap: () => _onLanguageTapped(lang),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 14.h),

                // ── 3. Authentic In-Game Custom 3D Green Action Button ─────────────
                Center(
                  child: Pressable3DButton(
                    key: const Key('first_language_confirm_btn'),
                    width: 260.w,
                    height: 56.h,
                    borderRadius: 20,
                    bevelOffset: 4.5,
                    borderWidth: 1.5,
                    faceColor: const Color(0xFF46DC28),
                    bevelColor: const Color(0xFF2DC419),
                    borderColor: const Color(0xFF19BA05),
                    onTap: _onConfirmAndPlay,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 24,
                            shadows: [
                              Shadow(color: Color(0x60000000), offset: Offset(0, 1.5), blurRadius: 2),
                            ],
                          ),
                          SizedBox(width: 8.w),
                          CartoonText(
                            text: AppLocalization.tr('confirm', language: _selectedLanguage).toUpperCase(),
                            fontSize: 21.sp,
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

                SizedBox(height: 18.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-column Language Item card styled consistently with in-game cards.
/// Crisp white face, tactile 3D bevel depth, circular flag badge, and signature emerald green selection border.
class _FirstLanguageItem extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _FirstLanguageItem({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      onTap: () {
        try {
          if (GameStorage.isHapticEnabled()) {
            HapticFeedback.lightImpact();
          }
        } catch (_) {}
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF23D046) : const Color(0xFFD8E5EE),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            if (isSelected) ...[
              BoxShadow(
                color: const Color(0xFF23D046).withValues(alpha: 0.35),
                offset: const Offset(0, 3),
                blurRadius: 8,
              ),
              const BoxShadow(
                color: Color(0xFF135025),
                offset: Offset(0, 3.5),
                blurRadius: 0,
              ),
            ] else ...[
              const BoxShadow(
                color: Color(0xFFB5CCE0),
                offset: Offset(0, 3.5),
                blurRadius: 0,
              ),
              const BoxShadow(
                color: Color(0x18000000),
                offset: Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ],
        ),
        child: Row(
          children: [
            // Flag Circular Avatar
            Container(
              width: 38.r,
              height: 38.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFFE8F8ED) : const Color(0xFFF3F8FB),
                border: Border.all(
                  color: isSelected ? const Color(0xFF23D046) : const Color(0xFFD8E5EE),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                flag,
                style: TextStyle(fontSize: 22.sp),
              ),
            ),

            SizedBox(width: 14.w),

            // Language Name
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.font(
                  fontSize: 17.sp,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: const Color(0xFF1E3A5F),
                  letterSpacing: 0.4,
                ),
              ),
            ),

            // Radio Circle / Checkmark Badge
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26.r,
              height: 26.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF23D046) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF23D046) : const Color(0xFFBED7E8),
                  width: 2.0,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18.r,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
