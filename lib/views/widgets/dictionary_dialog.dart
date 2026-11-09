import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/word_definition_model.dart';
import '../../services/audio_manager.dart';
import '../../services/dictionary_service.dart';
import '../../theme/app_typography.dart';
import '../../utils/game_transitions.dart';
import 'bouncy_button.dart';

/// Modal dialog showing word definitions, phonetics, and examples from Free Dictionary API.
class DictionaryDialog extends StatefulWidget {
  final List<String> words;
  final String initialWord;
  final String language;

  const DictionaryDialog({
    super.key,
    required this.words,
    required this.initialWord,
    this.language = 'en',
  });

  static Future<void> show(
    BuildContext context, {
    required List<String> words,
    String? initialWord,
    String language = 'en',
  }) {
    if (words.isEmpty) return Future.value();
    AudioManager.playTileSelect(pitchIndex: 4);

    final validInitial = (initialWord != null && words.contains(initialWord.toUpperCase()))
        ? initialWord.toUpperCase()
        : words.first.toUpperCase();

    return showGameDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DictionaryDialog(
        words: words.map((w) => w.toUpperCase()).toList(),
        initialWord: validInitial,
        language: language,
      ),
    );
  }

  @override
  State<DictionaryDialog> createState() => _DictionaryDialogState();
}

class _DictionaryDialogState extends State<DictionaryDialog> {
  late String _selectedWord;
  WordDefinitionModel? _definition;
  bool _isLoading = true;
  AudioPlayer? _audioPlayer;

  @override
  void initState() {
    super.initState();
    _selectedWord = widget.initialWord;
    _fetchWordDefinition(_selectedWord);
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _fetchWordDefinition(String word) async {
    setState(() {
      _isLoading = true;
      _definition = null;
    });

    final def = await DictionaryService.getDefinition(word, language: widget.language);
    if (!mounted) return;

    setState(() {
      _definition = def;
      _isLoading = false;
    });
  }

  void _onWordSelected(String word) {
    if (_selectedWord == word) return;
    AudioManager.playTileSelect(pitchIndex: 3);
    setState(() {
      _selectedWord = word;
    });
    _fetchWordDefinition(word);
  }

  Future<void> _playPronunciation(String audioUrl) async {
    if (audioUrl.isEmpty) return;
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.stop();
      await _audioPlayer!.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint('[DictionaryDialog] Error playing pronunciation audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 340.w,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. Main White Dialog Card Frame
              Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: 520.h),
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
                    SizedBox(height: 38.h),

                    // 2. Horizontal Word Selector Chips (if > 1 word)
                    if (widget.words.length > 1)
                      Container(
                        height: 38.h,
                        margin: EdgeInsets.only(bottom: 10.h),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: widget.words.length,
                          separatorBuilder: (_, _) => SizedBox(width: 8.w),
                          itemBuilder: (context, index) {
                            final w = widget.words[index];
                            final isSelected = w == _selectedWord;
                            return BouncyButton(
                              onTap: () => _onWordSelected(w),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFFEDF4FA),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2C6CB6) : const Color(0xFFCFE1F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  w,
                                  style: AppTypography.font(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected ? Colors.white : const Color(0xFF4A5F7D),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // 3. Word Definition Content Body
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18.w),
                        child: _buildDefinitionBody(),
                      ),
                    ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),

              // 4. Header Pill Banner: "DICTIONARY 📖"
              Positioned(
                top: -20.h,
                child: Container(
                  height: 44.h,
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B72C7),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF234B88),
                        offset: Offset(0, 3.5),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x33000000),
                        offset: Offset(0, 5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8.w),
                      CartoonText(
                        text: 'DICTIONARY',
                        fontSize: 18.sp,
                        textColor: Colors.white,
                        outlineColor: const Color(0xFF1B3D73),
                        strokeWidth: 3.5,
                        shadowOffset: 1.2,
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Close Button (Top Right)
              Positioned(
                top: -12.h,
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

  Widget _buildDefinitionBody() {
    if (_isLoading) {
      return Container(
        height: 180.h,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B72C7)),
            SizedBox(height: 12),
            Text(
              'Looking up definition...',
              style: TextStyle(color: Color(0xFF7A8A9E), fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_definition == null) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _selectedWord,
              style: AppTypography.font(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF2C3E50),
              ),
            ),
            SizedBox(height: 10.h),
            const Icon(Icons.info_outline_rounded, color: Color(0xFF9AAEC4), size: 36),
            SizedBox(height: 8.h),
            Text(
              'Definition not found for this word,\nor device is offline.',
              textAlign: TextAlign.center,
              style: AppTypography.font(
                fontSize: 13.sp,
                color: const Color(0xFF7A8A9E),
                height: 1.4,
              ),
            ),
            SizedBox(height: 14.h),
            BouncyButton(
              onTap: () => _fetchWordDefinition(_selectedWord),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 7.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B72C7),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x333B72C7),
                      offset: Offset(0, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 5.w),
                    Text(
                      'Retry',
                      style: AppTypography.font(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final def = _definition!;
    final phoneticText = def.phonetic ?? (def.word.isNotEmpty ? '/${def.word}/' : '');
    final hasAudio = def.audioUrl != null && def.audioUrl!.isNotEmpty;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word & Pronunciation Row
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FB),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFDFEAF5), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.word.toUpperCase(),
                        style: AppTypography.font(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1F3556),
                        ),
                      ),
                      if (phoneticText.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          phoneticText,
                          style: AppTypography.font(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6B829E),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasAudio)
                  BouncyButton(
                    onTap: () => _playPronunciation(def.audioUrl!),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B72C7),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x333B72C7),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 12.h),

          // Meanings by Part of Speech
          ...def.meanings.map((meaning) {
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Part of speech pill
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EDFA),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      meaning.partOfSpeech.toUpperCase(),
                      style: AppTypography.font(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2C6CB6),
                      ),
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Definitions
                  ...meaning.definitions.take(3).map((item) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: AppTypography.font(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF3B72C7),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.definition,
                                  style: AppTypography.font(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF2D3748),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.example != null && item.example!.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Padding(
                              padding: EdgeInsets.only(left: 12.w),
                              child: Text(
                                '"${item.example}"',
                                style: AppTypography.font(
                                  fontSize: 12.sp,
                                  color: const Color(0xFF6A7F98),
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
