import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../controllers/game_controller.dart';
import '../../models/chapter_model.dart';
import '../../models/level_model.dart';
import '../../services/game_storage.dart';

class TargetWordsBar extends StatefulWidget {
  final GameController controller;

  const TargetWordsBar({super.key, required this.controller});

  @override
  State<TargetWordsBar> createState() => TargetWordsBarState();
}

class TargetWordsBarState extends State<TargetWordsBar> {
  final GlobalKey _wordsColumnKey = GlobalKey();
  int _lastSolvedCount = 0;
  bool _lastIsWon = false;

  /// Returns the bottom global Y coordinate of the target words block.
  double? getWordsBottomGlobal() {
    final RenderBox? renderBox = _wordsColumnKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    return renderBox.localToGlobal(Offset(0, renderBox.size.height)).dy;
  }

  @override
  void initState() {
    super.initState();
    _lastSolvedCount = widget.controller.solvedTargetWords.length;
    _lastIsWon = widget.controller.isWon;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TargetWordsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _lastSolvedCount = widget.controller.solvedTargetWords.length;
      _lastIsWon = widget.controller.isWon;
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final solvedCount = widget.controller.solvedTargetWords.length;
    final isWon = widget.controller.isWon;
    if (solvedCount != _lastSolvedCount || isWon != _lastIsWon) {
      _lastSolvedCount = solvedCount;
      _lastIsWon = isWon;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final words = controller.level.targetWords;
    final maxLen = words.fold<int>(0, (maxVal, tw) => tw.word.length > maxVal ? tw.word.length : maxVal);
    final tutorialTargetWord = (!GameStorage.isTutorialCompleted() &&
            controller.levelNumber == 1 &&
            !controller.isWon &&
            controller.solvedTargetWords.length < controller.level.targetWords.length)
        ? controller.getNextUnsolvedTargetWord()
        : null;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableH = constraints.maxHeight;
          final double availableW = constraints.maxWidth;
          final int wordsCount = words.length;

          // Dynamic vertical gap based on words count
          final double vGap;
          if (wordsCount <= 4) {
            vGap = 4.0.h;
          } else if (wordsCount <= 6) {
            vGap = 3.0.h;
          } else if (wordsCount <= 8) {
            vGap = 2.0.h;
          } else {
            vGap = 1.5.h;
          }

          final double totalVGap = (wordsCount - 1) * vGap;
          final double vPadding = wordsCount > 6 ? 2.0.h : 6.0.h;
          final double hAvailableForBoxes = max(0.0, availableH - (vPadding * 2) - totalVGap - 6.0);
          final double sizeByHeight = wordsCount > 0 ? hAvailableForBoxes / wordsCount : 52.0.r;

          // Horizontal constraint: ensure longest word fits within available width
          final double hPadding = 16.0.w;
          final double hAvailableForWord = max(0.0, availableW - (hPadding * 2));
          final double sizeByWidth = maxLen > 0 ? (hAvailableForWord - (maxLen * 3.0.w)) / maxLen : 52.0.r;

          // Fit size dynamically ensuring no overflow vertically or horizontally
          final double boxSize = min(sizeByHeight, sizeByWidth).clamp(14.0, 52.0.r);

          return Container(
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Column(
                key: _wordsColumnKey,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: words.map((tw) {
                  final isSolved = controller.solvedTargetWords.contains(tw.word);
                  final isTutorialTarget = !isSolved && tutorialTargetWord == tw.word;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: vGap / 2),
                    child: _TargetWordRow(
                      targetWord: tw,
                      isSolved: isSolved,
                      isTutorialTarget: isTutorialTarget,
                      boxSize: boxSize,
                      chapterTheme: controller.chapterTheme,
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TargetWordRow extends StatelessWidget {
  final TargetWord targetWord;
  final bool isSolved;
  final bool isTutorialTarget;
  final double boxSize;
  final ChapterTheme chapterTheme;

  const _TargetWordRow({
    required this.targetWord,
    required this.isSolved,
    required this.isTutorialTarget,
    required this.boxSize,
    required this.chapterTheme,
  });

  @override
  Widget build(BuildContext context) {
    final word = targetWord.word;
    final double radius = (boxSize * 0.27).clamp(6.0, 14.0).r;
    final double bevelHeight = (boxSize * 0.06).clamp(1.5, 3.0);
    final double dropShadowOffset = (boxSize * 0.075).clamp(2.0, 4.0);
    final double dropShadowBlur = (boxSize * 0.065).clamp(1.5, 3.5);
    final double borderWidth = (boxSize * 0.035).clamp(1.0, 1.8);
    final double hMargin = (boxSize * 0.035).clamp(1.0, 1.5).w;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(word.length, (index) {
        final char = word[index];

        final theme = chapterTheme;

        if (isSolved) {
          final light = theme.lightColor;
          final face = theme.primaryColor;
          final border = theme.borderColor;
          final bevel = theme.bevelColor;
          final textCol = theme.textColor;

          return Container(
            width: boxSize,
            height: boxSize,
            margin: EdgeInsets.symmetric(horizontal: hMargin),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [light, face],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: borderWidth),
              boxShadow: [
                // 1. Solid 3D Bevel Lip (Độ dày gạch)
                BoxShadow(
                  color: bevel,
                  offset: Offset(0, bevelHeight),
                  blurRadius: 0,
                ),
                // 2. Soft Ambient Drop Shadow (Bóng đổ mềm nổi lên)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  offset: Offset(0, dropShadowOffset),
                  blurRadius: dropShadowBlur,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  char,
                  style: AppTypography.font(
                    fontSize: boxSize * 0.62,
                    fontWeight: FontWeight.w900,
                    color: textCol,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: bevel.withValues(alpha: 0.8),
                        offset: Offset(0, (bevelHeight * 0.4).clamp(0.8, 1.2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate(delay: (50 * index).ms)
              .scale(begin: const Offset(0.3, 0.3), end: const Offset(1.0, 1.0), duration: 250.ms, curve: Curves.elasticOut)
              .shimmer(duration: 800.ms, color: Colors.white.withValues(alpha: 0.4));
        }

        return Container(
          width: boxSize,
          height: boxSize,
          margin: EdgeInsets.symmetric(horizontal: hMargin),
          decoration: BoxDecoration(
            color: isTutorialTarget ? const Color(0xFFFFF9F0) : const Color(0xFFFBF1E6),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isTutorialTarget ? theme.primaryColor : Colors.white.withValues(alpha: 0.65),
              width: isTutorialTarget ? 2.0 : borderWidth,
            ),
            boxShadow: [
              if (isTutorialTarget)
                const BoxShadow(
                  color: Color(0x55BA805D),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              // 1. Solid 3D Bevel Lip (Độ dày gạch màu cam đào)
              BoxShadow(
                color: const Color(0xFFEEB596),
                offset: Offset(0, bevelHeight),
                blurRadius: 0,
              ),
              // 2. Soft Ambient Drop Shadow (Bóng đổ mềm hắt xuống nền)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                offset: Offset(0, dropShadowOffset),
                blurRadius: dropShadowBlur,
                spreadRadius: 0.5,
              ),
            ],
          ),
        );
      }),
    );
  }
}
