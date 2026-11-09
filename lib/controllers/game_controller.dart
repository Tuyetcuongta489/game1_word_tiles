import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/chapter_model.dart';
import '../models/level_model.dart';
import '../services/analytics_service.dart';
import '../services/app_localization.dart';
import '../services/audio_manager.dart';
import '../services/game_storage.dart';
import '../services/level_loader.dart';
import '../services/no_ads_trigger_service.dart';

class ExtraWordFlyEvent {
  final String word;
  final List<Point<int>> path;
  final int bankCount;

  const ExtraWordFlyEvent({
    required this.word,
    required this.path,
    required this.bankCount,
  });
}

class ComboFeedbackData {
  final String praise;
  final String multiplier;
  final Color color;

  const ComboFeedbackData({
    required this.praise,
    required this.multiplier,
    required this.color,
  });
}

class GameController extends ChangeNotifier {
  final String language;
  final int levelId;
  final int levelNumber;
  final LevelModel level;

  late List<List<LetterTile>> grid;
  final Set<String> solvedTargetWords = {};
  final Set<String> foundExtraWords = {};

  final ValueNotifier<ExtraWordFlyEvent?> extraWordFlyNotifier = ValueNotifier<ExtraWordFlyEvent?>(null);

  final List<Point<int>> currentPath = [];
  String currentWord = '';

  bool isWon = false;
  bool isWinning = false;
  int starsEarned = 0;
  int coinsReward = 10;
  String victoryCelebrationText = 'LEVEL COMPLETE!';

  int comboStreak = 0;
  int? feedbackCombo;
  String? feedbackPraise;
  String? feedbackComboMultiplier;

  int invalidAttemptsCount = 0;
  int consecutiveFailedSwipes = 0;
  List<Point<int>>? failSafeHintPath;

  /// Fail-safe dynamic hint threshold based on level:
  /// - Lv 1-4: 2 failed swipes
  /// - Lv 5-10: 3 failed swipes
  /// - Lv 11+: 5 failed swipes
  int get failSafeThreshold {
    if (levelNumber <= 4) return 2;
    if (levelNumber <= 10) return 3;
    return 5;
  }
  int boostersUsedCount = 0;
  final DateTime levelStartTime = DateTime.now();
  double adDurationSeconds = 0.0;

  void addAdDuration(double seconds) {
    adDurationSeconds += seconds;
  }

  // Chapter & Level progression (Chapter 1: 5 levels, Chapter 2+: 10 levels)
  ChapterInfo get chapterInfo => ChapterInfo.forLevel(levelNumber);
  int get chapterNumber => chapterInfo.chapterNumber;
  int get levelInChapter => chapterInfo.levelInChapter;
  int get totalLevelsInChapter => chapterInfo.totalLevelsInChapter;
  bool get isLastLevelOfChapter => chapterInfo.isChapterCompleted;
  ChapterTheme get chapterTheme => ChapterTheme.forChapter(chapterNumber);

  // Progressive Feature & Booster Unlocks
  bool get isBoosterBarVisible => levelNumber >= 5;
  bool get isHintUnlocked => levelNumber >= 5;
  bool get isRocketUnlocked => levelNumber >= 7;
  bool get isExtraWordsUnlocked => levelNumber >= 6;
  bool get isShopUnlocked => levelNumber >= 7;

  List<Point<int>>? highlightedHintPath;
  Timer? _hintTimer;
  Timer? _victoryTimer;

  String? feedbackMessage;
  Color? feedbackColor;
  Timer? _feedbackTimer;

  static const List<String> celebrationPhrases = [
    'WORD MASTER! 👑',
    'SMOOTH SOLVE! ✨',
    'CRUSHED IT! 💥',
    'WORDPLAY MAGIC! 🪄',
    'FLAWLESS! 💎',
    'ZERO MISTAKES! 🎯',
    'MASTERFUL! 🌟',
    'ON FIRE! 🔥',
    'UNSTOPPABLE! 🚀',
    'WORDSTORM! 🌪️',
  ];

  // Tiered Praise Word Pools for Combos across all 9 supported languages

  // 1. English 🇺🇸
  static const List<String> _praiseTier1En = [
    'GOOD! 👍', 'NICE! ✨', 'COOL! 😎', 'SWEET! 🍬', 'WELL DONE! 👏', 'BINGO! 🎯', 'SMART! 💡', 'PERFECT! 👌', 'LOVELY! 🌸', 'CLEVER! 🧐'
  ];
  static const List<String> _praiseTier2En = [
    'GREAT! 🎯', 'AWESOME! 🚀', 'SUPER! ⚡', 'WONDERFUL! 💫', 'SPLENDID! ✨', 'SHARP! 🗡️', 'BRILLIANT! 💎', 'BRAVO! 👏', 'TERRIFIC! 🌟', 'DYNAMITE! 🧨'
  ];
  static const List<String> _praiseTier3En = [
    'AMAZING! 🤩', 'EXCELLENT! 🏆', 'FANTASTIC! 🎉', 'MAGNIFICENT! 🌈', 'SUPERB! 💫', 'SPECTACULAR! ✨', 'MARVELOUS! 🌟', 'FABULOUS! 💖', 'SENSATIONAL! 🎊'
  ];
  static const List<String> _praiseTier4En = [
    'INCREDIBLE! 💥', 'OUTSTANDING! 🌟', 'ON FIRE! 🔥', 'STUNNING! ⚡', 'ASTONISHING! 💫', 'UNBELIEVABLE! 🤯', 'BLAZING! 🔥', 'POWERFUL! 💪'
  ];
  static const List<String> _praiseTier5En = [
    'UNSTOPPABLE! 💥', 'LEGENDARY! 🌟', 'MASTERPIECE! 🎨', 'GODLIKE! ⚡', 'GENIUS! 🧠', 'PHENOMENAL! 🚀', 'WORD MASTER! 👑', 'ULTRA COMBO! 🌪️', 'SUPREME! 👑'
  ];

  // 2. Vietnamese / Tiếng Việt 🇻🇳
  static const List<String> _praiseTier1Vi = [
    'TỐT LẮM! 👍', 'CHUẨN! 🎯', 'ĐÚNG RỒI! ✨', 'HAY! 👏', 'TUYỆT! 🌟', 'CHUẨN XÁC! 👌', 'ĐẸP! 🌸'
  ];
  static const List<String> _praiseTier2Vi = [
    'RẤT TỐT! 👏', 'XUẤT SẮC! 🏆', 'QUÁ ĐỈNH! 🚀', 'QUÁ HAY! ⚡', 'ĐẸP MẮT! 💫', 'TUYỆT VỜI! 🎉', 'CHÍNH XÁC! 🎯'
  ];
  static const List<String> _praiseTier3Vi = [
    'SIÊU ĐỈNH! 🚀', 'THẦN THÁNH! ⚡', 'QUÁ PRO! 😎', 'SIÊU ĐẲNG! 💎', 'CỰC KỲ PRO! 🌟', 'THÔNG MINH! 💡', 'ĐẲNG CẤP! 🏆'
  ];
  static const List<String> _praiseTier4Vi = [
    'KHÔNG THỂ CẢN! 💥', 'BÁ ĐẠO! 🥊', 'XUẤT THẦN! ⚡', 'ĐỈNH CAO! 🏔️', 'QUÁ CHÁY! 🔥', 'CHÁY QUÁ! 🔥', 'SIÊU VIỆT! 🚀'
  ];
  static const List<String> _praiseTier5Vi = [
    'BẬC THẦY! 👑', 'THIÊN TÀI! 🧠', 'HUYỀN THOẠI! 🌟', 'VÔ ĐỐI! 💎', 'SIÊU SAO! ⭐', 'TRÙM TỪ VỰNG! 👑', 'QUÁ KHỦNG! 💥'
  ];

  // 3. German / Deutsch 🇩🇪
  static const List<String> _praiseTier1De = [
    'GUT! 👍', 'NICE! ✨', 'SCHÖN! 🌸', 'TOLL! 👏', 'KLASSE! 🎯', 'PRIMA! 👌', 'SUPER! ⚡', 'SAUBER! 💫'
  ];
  static const List<String> _praiseTier2De = [
    'SEHR GUT! 👏', 'GROSSARTIG! 🚀', 'WUNDERBAR! 💫', 'HERVORRAGEND! 🏆', 'BRAVO! 🎉', 'STARK! 💪'
  ];
  static const List<String> _praiseTier3De = [
    'FANTASTISCH! 🎉', 'AUSGEZEICHNET! 🏆', 'GENIAL! 💡', 'SPITZE! 🌟', 'GLÄNZEND! ✨', 'BRILLANT! 💎'
  ];
  static const List<String> _praiseTier4De = [
    'UNGLAUBLICH! 💥', 'SPEKTAKULÄR! 🚀', 'ON FIRE! 🔥', 'ÜBERRAGEND! ⚡', 'WAHNSINN! 🤯', 'MEISTERHAFT! 🎨'
  ];
  static const List<String> _praiseTier5De = [
    'UNAUFHALTSAM! 💥', 'LEGENDÄR! 🌟', 'WORTMEISTER! 👑', 'GENIE! 🧠', 'UNSCHLAGBAR! 🛡️', 'GÖTTLICH! ⚡'
  ];

  // 4. French / Français 🇫🇷
  static const List<String> _praiseTier1Fr = [
    'BIEN ! 👍', 'BRAVO ! 👏', 'JOLI ! 🌸', 'CHOUETTE ! ✨', 'SUPER ! ⚡', 'BON DÉBUT ! 🎯', 'IMPECCABLE ! 👌'
  ];
  static const List<String> _praiseTier2Fr = [
    'TRÈS BIEN ! 👏', 'GÉNIAL ! 🚀', 'EXCELLENT ! 🏆', 'FORMIDABLE ! 💫', 'MAGNIFIQUE ! 💖', 'BIEN JOUÉ ! 🎯'
  ];
  static const List<String> _praiseTier3Fr = [
    'FANTASTIQUE ! 🎉', 'INCROYABLE ! 🤩', 'BRILLANT ! 💎', 'SENSATIONNEL ! 🎊', 'ÉPATANT ! 🌟', 'SUPERBE ! ✨'
  ];
  static const List<String> _praiseTier4Fr = [
    'EXTRAORDINAIRE ! 💥', 'SPECTACULAIRE ! 🚀', 'EN FEU ! 🔥', 'ÉPOUSTOUFLANT ! 🤯', 'SUBJUGUANT ! ⚡'
  ];
  static const List<String> _praiseTier5Fr = [
    'IMBATTABLE ! 🛡️', 'LÉGENDAIRE ! 🌟', 'GÉNIE ! 🧠', 'MAÎTRE DES MOTS ! 👑', 'DIVIN ! ⚡', 'SUPRÊME ! 👑'
  ];

  // 5. Spanish / Español 🇪🇸
  static const List<String> _praiseTier1Es = [
    '¡BIEN! 👍', '¡BUENA! ✨', '¡GENIAL! 😎', '¡LINDO! 🌸', '¡CORRECTO! 🎯', '¡BUEN COMIENZO! 👏', '¡BONITO! 👌'
  ];
  static const List<String> _praiseTier2Es = [
    '¡MUY BIEN! 👏', '¡ESTUPENDO! 🚀', '¡FANTÁSTICO! 💫', '¡BRAVO! 🎉', '¡EXCELENTE! 🏆', '¡BIEN HECHO! 🎯'
  ];
  static const List<String> _praiseTier3Es = [
    '¡ASOMBROSO! 🤩', '¡MAGNÍFICO! 🌈', '¡BRILLANTE! 💎', '¡ESPECTACULAR! ✨', '¡FORMIDABLE! 🌟', '¡PORTENTO! 💡'
  ];
  static const List<String> _praiseTier4Es = [
    '¡INCREÍBLE! 💥', '¡EN RACHA! 🔥', '¡IMPRESIONANTE! ⚡', '¡ESTÁS EN LLAMAS! 🔥', '¡BRUTAL! 🥊'
  ];
  static const List<String> _praiseTier5Es = [
    '¡IMPARABLE! 💥', '¡LEGENDARIO! 🌟', '¡MAESTRO DE PALABRAS! 👑', '¡GENIO! 🧠', '¡SUBLIME! 💎', '¡SUPREMO! 👑'
  ];

  // 6. Italian / Italiano 🇮🇹
  static const List<String> _praiseTier1It = [
    'BENE! 👍', 'BRAVO! 👏', 'BELLO! 🌸', 'GIUSTO! 🎯', 'OTTIMO INIZIO! ✨', 'CARINO! 👌', 'ESATTO! 💡'
  ];
  static const List<String> _praiseTier2It = [
    'MOLTO BENE! 👏', 'GRANDE! 🚀', 'SPLENDIDO! 💫', 'SUPER! ⚡', 'ECCELLENTE! 🏆', 'BEN FATTO! 🎯'
  ];
  static const List<String> _praiseTier3It = [
    'FANTASTICO! 🎉', 'MERAVIGLIOSO! 🌈', 'BRILLANTE! 💎', 'MAGNIFICO! ✨', 'STRATOSFERICO! 🚀', 'SUPERBO! 🌟'
  ];
  static const List<String> _praiseTier4It = [
    'INCREDIBILE! 💥', 'INARRESTABILE! 🛡️', 'IN FUOCO! 🔥', 'SPETTACOLARE! ⚡', 'FORMIDABILE! 🥊'
  ];
  static const List<String> _praiseTier5It = [
    'LEGGENDARIO! 🌟', 'MAESTRO DELLE PAROLE! 👑', 'GENIO! 🧠', 'INSUPERABILE! 💎', 'DIVINO! ⚡', 'SUPREMO! 👑'
  ];

  // 7. Portuguese / Português 🇵🇹
  static const List<String> _praiseTier1Pt = [
    'BOM! 👍', 'LEGAL! 😎', 'BOA! ✨', 'BELEZA! 👌', 'CERTO! 🎯', 'BOM COMEÇO! 👏', 'MUITO BEM! 🌸'
  ];
  static const List<String> _praiseTier2Pt = [
    'MUITO BOM! 👏', 'ÓTIMO! 🚀', 'MARAVILHA! 💫', 'SHOW! 🎉', 'EXCELENTE! 🏆', 'PARABÉNS! 🌟'
  ];
  static const List<String> _praiseTier3Pt = [
    'FANTÁSTICO! 🎉', 'BRILHANTE! 💎', 'MAGNÍFICO! 🌈', 'SENSACIONAL! 🎊', 'ESPETACULAR! ✨', 'GENIAL! 💡'
  ];
  static const List<String> _praiseTier4Pt = [
    'INCRÍVEL! 💥', 'ON FIRE! 🔥', 'ARRASOU! ⚡', 'SURPREENDENTE! 🤯', 'DE MAIS! 🚀', 'FENOMENAL! 🌟'
  ];
  static const List<String> _praiseTier5Pt = [
    'IMPARÁVEL! 💥', 'LENDÁRIO! 🌟', 'MESTRE DAS PALAVRAS! 👑', 'GÊNIO! 🧠', 'SUPREMO! 👑', 'INVENCÍVEL! 🛡️'
  ];

  // 8. Russian / Русский 🇷🇺
  static const List<String> _praiseTier1Ru = [
    'ХОРОШО! 👍', 'ВЕРНО! 🎯', 'КРАСИВО! 🌸', 'ТОЧНО! 👌', 'ОТЛИЧНЫЙ СТАРТ! ✨', 'ЗДОРОВО! 👏', 'ПРАВИЛЬНО! 💡'
  ];
  static const List<String> _praiseTier2Ru = [
    'ОТЛИЧНО! 👏', 'ПРЕКРАСНО! 💫', 'СУПЕР! ⚡', 'КЛАСС! 🚀', 'МОЛОДЕЦ! 🎉', 'ЗАМЕЧАТЕЛЬНО! 🏆'
  ];
  static const List<String> _praiseTier3Ru = [
    'ПОТРЯСAЮЩЕ! 🤩', 'ВЕЛИКОЛЕПНО! 🌈', 'БЛЕСТЯЩЕ! 💎', 'ФАНТАСТИКА! 🎉', 'БЕСПОДОБНО! ✨', 'ШЕДЕВР! 🎨'
  ];
  static const List<String> _praiseTier4Ru = [
    'НЕВЕРОЯТНО! 💥', 'ТЫ В ОГНЕ! 🔥', 'НЕОБЫКНОВЕННО! ⚡', 'СНОГСШИБАТЕЛЬНО! 🤯', 'ВОСТОРГ! 🚀'
  ];
  static const List<String> _praiseTier5Ru = [
    'НЕУДЕРЖИМЫЙ! 💥', 'ЛЕГЕНДАРНО! 🌟', 'МАСТЕР СЛОВ! 👑', 'ГЕНИЙ! 🧠', 'БОЖЕСТВЕННО! ⚡', 'ВЕРШИНА! 🏆'
  ];

  // 9. Turkish / Türkçe 🇹🇷
  static const List<String> _praiseTier1Tr = [
    'İYİ! 👍', 'GÜZEL! 🌸', 'DOĞRU! 🎯', 'HARİKA BAŞLANGIÇ! ✨', 'SÜPER! ⚡', 'TATLI! 🍬', 'TEMİZ! 👌'
  ];
  static const List<String> _praiseTier2Tr = [
    'ÇOK İYİ! 👏', 'TEBRİKLER! 🎉', 'MÜKEMMEL! 🏆', 'HARİKASIN! 🚀', 'BRAVO! 👏', 'NEFİS! 💫'
  ];
  static const List<String> _praiseTier3Tr = [
    'MUHTEŞEM! 🤩', 'KUSURSUZ! 💎', 'BÜYÜLEYİCİ! ✨', 'ŞAHANE! 🌈', 'OLAĞANÜSTÜ! 🌟', 'PARLAK! 💡'
  ];
  static const List<String> _praiseTier4Tr = [
    'İNANILMAZ! 💥', 'ALEV ALDIN! 🔥', 'DURDURULAMAZ! 🥊', 'BOMBA GİBİ! 🧨', 'BÜYÜK BAŞARI! 🚀'
  ];
  static const List<String> _praiseTier5Tr = [
    'EFSANEVİ! 🌟', 'KELİME USTASI! 👑', 'DAHİ! 🧠', 'YENİLMEZ! 💎', 'KRAL! ⭐', 'SÜPER GÜÇ! ⚡'
  ];

  final Random _feedbackRandom = Random();

  ComboFeedbackData getComboFeedbackData(int combo, String lang) {
    final l = lang.toLowerCase();
    final List<String> list;
    final String multiplier;
    final Color color;

    if (combo <= 1) {
      multiplier = '1x';
      color = const Color(0xFF10B981); // Emerald Mint
      switch (l) {
        case 'vietnamese':
          list = _praiseTier1Vi;
          break;
        case 'german':
          list = _praiseTier1De;
          break;
        case 'french':
          list = _praiseTier1Fr;
          break;
        case 'spanish':
          list = _praiseTier1Es;
          break;
        case 'italian':
          list = _praiseTier1It;
          break;
        case 'portuguese':
          list = _praiseTier1Pt;
          break;
        case 'russian':
          list = _praiseTier1Ru;
          break;
        case 'turkish':
          list = _praiseTier1Tr;
          break;
        case 'english':
        default:
          list = _praiseTier1En;
          break;
      }
    } else if (combo == 2) {
      multiplier = '2x 🔥';
      color = const Color(0xFF2563EB); // Ocean Blue
      switch (l) {
        case 'vietnamese':
          list = _praiseTier2Vi;
          break;
        case 'german':
          list = _praiseTier2De;
          break;
        case 'french':
          list = _praiseTier2Fr;
          break;
        case 'spanish':
          list = _praiseTier2Es;
          break;
        case 'italian':
          list = _praiseTier2It;
          break;
        case 'portuguese':
          list = _praiseTier2Pt;
          break;
        case 'russian':
          list = _praiseTier2Ru;
          break;
        case 'turkish':
          list = _praiseTier2Tr;
          break;
        case 'english':
        default:
          list = _praiseTier2En;
          break;
      }
    } else if (combo == 3) {
      multiplier = '3x 🔥🔥';
      color = const Color(0xFF7C3AED); // Royal Violet
      switch (l) {
        case 'vietnamese':
          list = _praiseTier3Vi;
          break;
        case 'german':
          list = _praiseTier3De;
          break;
        case 'french':
          list = _praiseTier3Fr;
          break;
        case 'spanish':
          list = _praiseTier3Es;
          break;
        case 'italian':
          list = _praiseTier3It;
          break;
        case 'portuguese':
          list = _praiseTier3Pt;
          break;
        case 'russian':
          list = _praiseTier3Ru;
          break;
        case 'turkish':
          list = _praiseTier3Tr;
          break;
        case 'english':
        default:
          list = _praiseTier3En;
          break;
      }
    } else if (combo == 4) {
      multiplier = '4x ⚡';
      color = const Color(0xFFEA580C); // Vivid Orange
      switch (l) {
        case 'vietnamese':
          list = _praiseTier4Vi;
          break;
        case 'german':
          list = _praiseTier4De;
          break;
        case 'french':
          list = _praiseTier4Fr;
          break;
        case 'spanish':
          list = _praiseTier4Es;
          break;
        case 'italian':
          list = _praiseTier4It;
          break;
        case 'portuguese':
          list = _praiseTier4Pt;
          break;
        case 'russian':
          list = _praiseTier4Ru;
          break;
        case 'turkish':
          list = _praiseTier4Tr;
          break;
        case 'english':
        default:
          list = _praiseTier4En;
          break;
      }
    } else {
      multiplier = '${combo}x 👑';
      color = const Color(0xFFE11D48); // Crimson Ruby
      switch (l) {
        case 'vietnamese':
          list = _praiseTier5Vi;
          break;
        case 'german':
          list = _praiseTier5De;
          break;
        case 'french':
          list = _praiseTier5Fr;
          break;
        case 'spanish':
          list = _praiseTier5Es;
          break;
        case 'italian':
          list = _praiseTier5It;
          break;
        case 'portuguese':
          list = _praiseTier5Pt;
          break;
        case 'russian':
          list = _praiseTier5Ru;
          break;
        case 'turkish':
          list = _praiseTier5Tr;
          break;
        case 'english':
        default:
          list = _praiseTier5En;
          break;
      }
    }

    final praise = list[_feedbackRandom.nextInt(list.length)];
    return ComboFeedbackData(praise: praise, multiplier: multiplier, color: color);
  }

  /// Multilingual victory celebration text for level completion
  static String getVictoryCelebrationText(int stars, String lang) {
    final l = lang.toLowerCase();
    final List<String> list;

    if (stars >= 3) {
      switch (l) {
        case 'vietnamese':
          list = const ['HOÀN HẢO!', 'XUẤT SẮC!', 'TUYỆT ĐỈNH!', 'KHÔNG LỖI LẦM!', 'BẬC THẦY TỪ VỰNG!'];
          break;
        case 'german':
          list = const ['PERFEKT GELÖST!', 'EXZELLENT!', 'BRILLANT!', 'FEHLERFREI!', 'WORTMEISTER!'];
          break;
        case 'french':
          list = const ['RÉSOLUTION PARFAITE !', 'EXCELLENT !', 'BRILLANT !', 'SANS FAUTE !', 'MAÎTRE DES MOTS !'];
          break;
        case 'spanish':
          list = const ['¡RESOLUCIÓN PERFECTA!', '¡EXCELENTE!', '¡BRILLANTE!', '¡IMPECABLE!', '¡MAESTRO DE PALABRAS!'];
          break;
        case 'italian':
          list = const ['RISOLUZIONE PERFETTA!', 'ECCELLENTE!', 'BRILLANTE!', 'IMPECCABILE!', 'MAESTRO DELLE PAROLE!'];
          break;
        case 'portuguese':
          list = const ['RESOLUÇÃO PERFEITA!', 'EXCELENTE!', 'BRILHANTE!', 'IMPECÁVEL!', 'MESTRE DAS PALAVRAS!'];
          break;
        case 'russian':
          list = const ['ИДЕАЛЬНОЕ РЕШЕНИЕ!', 'ОТЛИЧНО!', 'БЛЕСТЯЩЕ!', 'БЕЗУПРЕЧНО!', 'МАСТЕР СЛОВ!'];
          break;
        case 'turkish':
          list = const ['KUSURSUZ ÇÖZÜM!', 'MÜKEMMEL!', 'HARİKA!', 'HATASIZ!', 'KELİME USTASI!'];
          break;
        case 'english':
        default:
          list = const ['PERFECT SOLVE!', 'EXCELLENT!', 'BRILLIANT!', 'FLAWLESS!', 'WORD MASTER!'];
          break;
      }
    } else if (stars == 2) {
      switch (l) {
        case 'vietnamese':
          list = const ['LÀM TỐT LẮM!', 'GIẢI MƯỢT MÀ!', 'CHƠI RẤT HAY!', 'KẾT THÚC ĐẸP!'];
          break;
        case 'german':
          list = const ['GUTE ARBEIT!', 'GUT GESPIELT!', 'SCHÖNER ABSCHLUSS!', 'TOLL GELÖST!'];
          break;
        case 'french':
          list = const ['BEAU TRAVAIL !', 'BIEN JOUÉ !', 'BELLE FIN !', 'SUPERBE RÉSOLUTION !'];
          break;
        case 'spanish':
          list = const ['¡BUEN TRABAJO!', '¡BIEN JUGADO!', '¡EXCELENTE FINAL!', '¡MUY BUENO!'];
          break;
        case 'italian':
          list = const ['OTTIMO LAVORO!', 'BEN GIOCATO!', 'BELLA CONCLUSIONE!', 'BRAVISSIMO!'];
          break;
        case 'portuguese':
          list = const ['BOM TRABALHO!', 'BEM JOGADO!', 'ÓTIMA FINALIZAÇÃO!', 'MANDOU BEM!'];
          break;
        case 'russian':
          list = const ['ОТЛИЧНАЯ РАБОТА!', 'ХОРОШАЯ ИГРА!', 'КРАСИВЫЙ ФИНИШ!', 'МОЛОДЕЦ!'];
          break;
        case 'turkish':
          list = const ['İYİ İŞ!', 'GÜZEL OYUN!', 'GÜZEL BİTİRİŞ!', 'HARİKA ÇÖZÜM!'];
          break;
        case 'english':
        default:
          list = const ['GREAT JOB!', 'SMOOTH SOLVE!', 'WELL PLAYED!', 'NICE FINISH!'];
          break;
      }
    } else {
      switch (l) {
        case 'vietnamese':
          list = const ['HOÀN THÀNH CẤP ĐỘ!', 'CỐ GẮNG LẮM!', 'VƯỢT MÀN THÀNH CÔNG!'];
          break;
        case 'german':
          list = const ['LEVEL GESCHAFFT!', 'GUTER VERSUCH!', 'STUFE GEMEISTERT!'];
          break;
        case 'french':
          list = const ['NIVEAU TERMINÉ !', 'BEL EFFORT !', 'ÉTAPE FRANCHIE !'];
          break;
        case 'spanish':
          list = const ['¡NIVEL COMPLETADO!', '¡BUEN INTENTO!', '¡ETAPA SUPERADA!'];
          break;
        case 'italian':
          list = const ['LIVELLO COMPLETATO!', 'BUON IMPEGNO!', 'LIVELLO SUPERATO!'];
          break;
        case 'portuguese':
          list = const ['NÍVEL CONCLUÍDO!', 'BOM ESFORÇO!', 'FASE SUPERADA!'];
          break;
        case 'russian':
          list = const ['УРОВЕНЬ ПРОЙДЕН!', 'ХОРОШАЯ ПОПЫТКА!', 'ЭТАП ЗАВЕРШЁН!'];
          break;
        case 'turkish':
          list = const ['SEVİYE TAMAMLANDI!', 'GÜZEL GAYRET!', 'AŞAMA GEÇİLDİ!'];
          break;
        case 'english':
        default:
          list = const ['LEVEL COMPLETED!', 'GOOD EFFORT!', 'STAGE CLEARED!'];
          break;
      }
    }

    return list[Random().nextInt(list.length)];
  }

  final bool enforceTutorialConstraints;
  final bool restoreProgress;

  GameController({
    required this.language,
    required this.levelId,
    required this.levelNumber,
    required this.level,
    this.enforceTutorialConstraints = true,
    this.restoreProgress = true,
  }) {
    _initGrid();
  }

  /// Active tutorial path when in guided tutorial steps
  List<Point<int>>? get activeTutorialPath {
    if (!enforceTutorialConstraints) return null;

    // 1. Level 1 Tutorial (All target words until level completed)
    if (!GameStorage.isTutorialCompleted() &&
        levelNumber == 1 &&
        solvedTargetWords.length < level.targetWords.length) {
      final nextWord = getNextUnsolvedTargetWord();
      if (nextWord != null) {
        return getTutorialPathForWord(nextWord);
      }
    }
    // 2. Level 4 Reverse Swipe Tutorial (Step 1)
    else if (!GameStorage.isReverseTutorialShown() &&
        levelNumber == 4 &&
        solvedTargetWords.isEmpty) {
      final firstWord = level.targetWords.isNotEmpty
          ? level.targetWords.first.word
          : 'CAR';
      return getTutorialPathForWord(firstWord);
    }
    return null;
  }

  /// Active tutorial target word when in guided tutorial steps
  String? get activeTutorialWord {
    if (!enforceTutorialConstraints) return null;

    if (!GameStorage.isTutorialCompleted() &&
        levelNumber == 1 &&
        solvedTargetWords.length < level.targetWords.length) {
      return getNextUnsolvedTargetWord();
    } else if (!GameStorage.isReverseTutorialShown() &&
        levelNumber == 4 &&
        solvedTargetWords.isEmpty) {
      return level.targetWords.isNotEmpty ? level.targetWords.first.word : 'CAR';
    }
    return null;
  }

  void _initGrid() {
    grid = LevelLoader.createInitialGridTiles(level);
    _checkObstacleUnlocks();
    if (restoreProgress) {
      _restoreSavedProgress();
    }
  }

  void _restoreSavedProgress() {
    final saved = GameStorage.getLevelProgress(language, levelNumber);
    if (saved == null) return;

    try {
      final savedSolved = (saved['solvedTargetWords'] as List<dynamic>?)?.map((e) => e.toString()).toList();
      if (savedSolved != null && savedSolved.isNotEmpty) {
        solvedTargetWords.addAll(savedSolved);
      }

      final savedExtra = (saved['foundExtraWords'] as List<dynamic>?)?.map((e) => e.toString()).toList();
      if (savedExtra != null && savedExtra.isNotEmpty) {
        foundExtraWords.addAll(savedExtra);
      }

      invalidAttemptsCount = (saved['invalidAttempts'] as num?)?.toInt() ?? 0;
      boostersUsedCount = (saved['boostersUsed'] as num?)?.toInt() ?? 0;
      comboStreak = (saved['comboStreak'] as num?)?.toInt() ?? 0;

      final gridData = saved['grid'] as List<dynamic>?;
      if (gridData != null && gridData.length == grid.length) {
        for (int r = 0; r < grid.length; r++) {
          final rowData = gridData[r] as List<dynamic>?;
          if (rowData != null && rowData.length == grid[r].length) {
            for (int c = 0; c < grid[r].length; c++) {
              final tileMap = rowData[c] as Map<String, dynamic>?;
              if (tileMap != null) {
                final tile = grid[r][c];
                tile.count = (tileMap['count'] as num?)?.toInt() ?? tile.count;
                tile.isCleared = (tileMap['isCleared'] as bool?) ?? tile.isCleared;
                tile.isObstacleLocked = (tileMap['isObstacleLocked'] as bool?) ?? tile.isObstacleLocked;
              }
            }
          }
        }
      }

      _checkObstacleUnlocks();
    } catch (e) {
      debugPrint('[GameController] Error restoring level progress: $e');
    }
  }

  /// Persists current in-level progress to storage
  void saveProgress() {
    if (isWon || isWinning) return;
    GameStorage.saveLevelProgress(
      language: language,
      levelNumber: levelNumber,
      solvedWords: solvedTargetWords,
      foundExtraWords: foundExtraWords,
      grid: grid,
      invalidAttempts: invalidAttemptsCount,
      boostersUsed: boostersUsedCount,
      comboStreak: comboStreak,
    );
  }

  int get wordsSolvedCount => solvedTargetWords.length;
  int get totalTargetWords => level.targetWords.length;
  double get progress => totalTargetWords > 0 ? wordsSolvedCount / totalTargetWords : 0.0;

  /// Start dragging from a tile at (row, col)
  void startSwipe(int row, int col) {
    if (isWon || isWinning) return;
    if (row < 0 || row >= grid.length || col < 0 || col >= grid[0].length) return;

    final tile = grid[row][col];
    if (tile.isCleared) return;

    if (tile.isObstacleLocked) {
      _showFeedback(
        'Locked! Solve ${tile.obstacleRequiredWords} words to unlock.',
        Colors.orangeAccent,
      );
      AudioManager.playInvalid();
      return;
    }

    // Enforce tutorial constraint: user MUST start from tutorial start tile!
    final tutPath = activeTutorialPath;
    if (tutPath != null && tutPath.isNotEmpty) {
      final startPt = Point(col, row);
      if (startPt != tutPath.first) {
        return;
      }
    }

    currentPath.clear();
    currentPath.add(Point(col, row));
    currentWord = tile.letter;
    highlightedHintPath = null;
    _clearFeedback();
    AudioManager.playTileSelect(pitchIndex: 1);
    notifyListeners();
  }

  /// Update swipe dragging to a tile at (row, col)
  void updateSwipe(int row, int col) {
    if (isWon || isWinning || currentPath.isEmpty) return;
    if (row < 0 || row >= grid.length || col < 0 || col >= grid[0].length) return;

    final pt = Point(col, row);
    final tile = grid[row][col];

    if (tile.isCleared) return;

    // Backtracking to previous tile
    if (currentPath.length > 1 && currentPath[currentPath.length - 2] == pt) {
      currentPath.removeLast();
      _recalculateCurrentWord();
      AudioManager.playTileSelect(pitchIndex: currentPath.length);
      notifyListeners();
      return;
    }

    if (currentPath.contains(pt)) return;

    if (tile.isObstacleLocked) {
      _showFeedback(
        'Locked! Needs ${tile.obstacleRequiredWords} solved words.',
        Colors.orangeAccent,
      );
      return;
    }

    // Enforce tutorial constraint:
    final tutPath = activeTutorialPath;
    if (tutPath != null && tutPath.isNotEmpty) {
      // 1. Cannot drag longer than tutorial path!
      if (currentPath.length >= tutPath.length) {
        return;
      }
      // 2. Can only drag to the exact next tile in the tutorial path!
      final expectedNextPt = tutPath[currentPath.length];
      if (pt != expectedNextPt) {
        return;
      }
    }

    // 4 directions (Horizontal & Vertical only)
    final last = currentPath.last;
    final dx = (last.x - pt.x).abs();
    final dy = (last.y - pt.y).abs();
    if (dx + dy == 1) {
      currentPath.add(pt);
      currentWord += tile.letter;
      AudioManager.playTileSelect(pitchIndex: currentPath.length);
      notifyListeners();
    }
  }

  /// End swipe and evaluate word
  void endSwipe() {
    if (isWon || isWinning || currentPath.isEmpty) {
      currentPath.clear();
      currentWord = '';
      notifyListeners();
      return;
    }

    final word = currentWord.trim();
    if (word.length >= 2) {
      _evaluateWord(word);
    }

    currentPath.clear();
    currentWord = '';
    notifyListeners();
  }

  void _recalculateCurrentWord() {
    final sb = StringBuffer();
    for (final pt in currentPath) {
      sb.write(grid[pt.y][pt.x].letter);
    }
    currentWord = sb.toString();
  }

  void _evaluateWord(String rawWord) {
    final word = rawWord.trim().toUpperCase();

    // If tutorial constraint is active, reject if it doesn't match the tutorial target word
    final tutWord = activeTutorialWord;
    if (tutWord != null && word != tutWord) {
      AudioManager.playInvalid();
      return;
    }

    // 1. Target word
    TargetWord? matchedTarget;
    for (final tw in level.targetWords) {
      if (tw.word.trim().toUpperCase() == word) {
        matchedTarget = tw;
        break;
      }
    }

    if (matchedTarget != null) {
      final targetKey = matchedTarget.word;
      if (solvedTargetWords.contains(targetKey)) {
        comboStreak = 0;
        _showFeedback(AppLocalization.tr('already_found', language: language), Colors.amber);
        AudioManager.playInvalid();
        return;
      }

      // Solved new target word!
      comboStreak++;
      solvedTargetWords.add(targetKey);
      consecutiveFailedSwipes = 0;
      failSafeHintPath = null;
      AudioManager.playWordMatch(combo: comboStreak);
      final comboData = getComboFeedbackData(comboStreak, language);
      _showComboFeedback(
        praise: comboData.praise,
        multiplier: comboData.multiplier,
        combo: comboStreak,
        color: comboData.color,
      );

      // If tutorial level 1 and this is the first solved word:
      if (levelNumber == 1 && solvedTargetWords.length == 1) {
        AnalyticsService.logTutorial(name: 'action_1', value: 4);
      }

      // Decrement optimal tile badge counts with 0-leftover guarantee
      _decrementWordTiles(targetKey, currentPath);

      // Unlock any obstacles requiring this word count
      _checkObstacleUnlocks();

      // Check win condition (500ms delay for last tile shatter animation to complete)
      if (solvedTargetWords.length >= level.targetWords.length) {
        isWinning = true;
        for (final row in grid) {
          for (final tile in row) {
            tile.count = 0;
            tile.isCleared = true;
          }
        }
        GameStorage.clearLevelProgress(language, levelNumber);
        _victoryTimer?.cancel();
        _victoryTimer = Timer(const Duration(milliseconds: 500), () {
          _handleVictory();
          notifyListeners();
        });
      } else {
        saveProgress();
      }
      return;
    }

    // 2. Extra / Bonus word (Only active from Level 7+ when Extra Words feature is unlocked)
    if (isExtraWordsUnlocked) {
      TargetWord? matchedExtra;
      for (final ew in level.extraWords) {
        if (ew.word.trim().toUpperCase() == word) {
          matchedExtra = ew;
          break;
        }
      }

      // 2b. Dynamic Safeguard for Plural/Singular:
      // If player swiped 'W' and 'W+S' is a target/extra word on this level,
      // or player swiped 'W' ending with 'S' and singular 'W' is a target/extra word on this level:
      if (matchedExtra == null) {
        final hasPluralOnBoard = level.targetWords.any((tw) => tw.word == '${word}S') ||
            level.extraWords.any((ew) => ew.word == '${word}S');
        final hasSingularOnBoard = word.endsWith('S') && word.length >= 4 &&
            (level.targetWords.any((tw) => tw.word == word.substring(0, word.length - 1)) ||
                level.extraWords.any((ew) => ew.word == word.substring(0, word.length - 1)));

        if (hasPluralOnBoard || hasSingularOnBoard) {
          matchedExtra = TargetWord(word: word, type: 0);
        }
      }

      if (matchedExtra != null) {
        final extraKey = matchedExtra.word;
        if (foundExtraWords.contains(extraKey)) {
          comboStreak = 0;
          _showFeedback(AppLocalization.tr('already_found', language: language), Colors.amber);
          AudioManager.playInvalid();
        } else {
          comboStreak++;
          foundExtraWords.add(extraKey);
          final bankCount = GameStorage.addExtraWordToBank();

          extraWordFlyNotifier.value = ExtraWordFlyEvent(
            word: extraKey,
            path: List<Point<int>>.from(currentPath),
            bankCount: bankCount,
          );

          if (bankCount >= 10) {
            AudioManager.playVictory();
            _showFeedback(AppLocalization.tr('extra_words_bank_full', language: language), const Color(0xFFFFD54F));
          } else {
            AudioManager.playExtraWord();
            final comboData = getComboFeedbackData(comboStreak, language);
            _showComboFeedback(
              praise: '🌟 ${comboData.praise}',
              multiplier: comboData.multiplier,
              combo: comboStreak,
              color: const Color(0xFFFFD54F),
            );
          }
          saveProgress();
        }
        return;
      }
    }

    // 3. Invalid word
    comboStreak = 0;
    invalidAttemptsCount++;
    consecutiveFailedSwipes++;
    if (consecutiveFailedSwipes >= failSafeThreshold) {
      final nextWord = getNextUnsolvedTargetWord();
      if (nextWord != null) {
        failSafeHintPath = getTutorialPathForWord(nextWord);
      }
    }
    AudioManager.playInvalid();
    _showFeedback(AppLocalization.tr('not_on_board', language: language), Colors.redAccent.shade100);
  }

  void _checkObstacleUnlocks() {
    final solved = wordsSolvedCount;
    bool unlockedAny = false;

    for (int r = 0; r < grid.length; r++) {
      for (int c = 0; c < grid[r].length; c++) {
        final tile = grid[r][c];
        if (tile.isObstacleLocked) {
          final req = tile.obstacleRequiredWords ?? 0;
          if (solved >= req) {
            tile.isObstacleLocked = false;
            unlockedAny = true;
          }
        }
      }
    }

    if (unlockedAny) {
      AudioManager.playObstacleUnlock();
      _showFeedback(AppLocalization.tr('obstacle_unlocked', language: language), Colors.lightBlueAccent);
    }
  }

  void _handleVictory() {
    if (isWon) return;
    isWinning = false;
    isWon = true;

    // Track won level count for periodic No Ads popup (Case 2)
    NoAdsTriggerService.onLevelWon();

    // Dynamic Star Rating Calculation:
    // Flawless (<= 1 error/hint) -> 3 Stars ⭐⭐⭐
    // Great (2-3 errors/hints) -> 2 Stars ⭐⭐
    // Cleared (4+ errors/hints) -> 1 Star ⭐
    final penalty = invalidAttemptsCount + (boostersUsedCount * 1.5) - (foundExtraWords.length * 0.5);
    final isMilestone = (levelNumber % 5 == 0);

    if (penalty <= 1.0) {
      starsEarned = 3;
      coinsReward = isMilestone ? 35 : 15;
    } else if (penalty <= 3.0) {
      starsEarned = 2;
      coinsReward = isMilestone ? 25 : 10;
    } else {
      starsEarned = 1;
      coinsReward = isMilestone ? 15 : 6;
    }
    victoryCelebrationText = getVictoryCelebrationText(starsEarned, language);

    GameStorage.addCoins(coinsReward);
    AnalyticsService.logEarnResource(
      level: levelNumber,
      type: 'currency',
      name: 'gold',
      amount: coinsReward.toDouble(),
      reason: 'win_level',
      balance: GameStorage.getCoins().toDouble(),
    );

    // AppsFlyer af_level_achieved: fire only once per level when achieving a new level
    if (!GameStorage.isLevelAchievedLogged(levelNumber)) {
      AnalyticsService.logAfLevelAchieved(level: levelNumber);
      unawaited(GameStorage.setLevelAchievedLogged(levelNumber));
    }

    // Clear saved in-level progress since the level is completed
    unawaited(GameStorage.clearLevelProgress(language, levelNumber));

    // Booster retention reward: If level 5 or 7 free booster was never used, grant it permanently
    if (levelNumber == 5 && !GameStorage.hasUsedLevel5FreeHint()) {
      unawaited(GameStorage.addHintCount(1));
      unawaited(GameStorage.setLevel5FreeHintUsed(true));
    } else if (levelNumber == 7 && !GameStorage.hasUsedLevel7FreeRocket()) {
      unawaited(GameStorage.addRocketCount(1));
      unawaited(GameStorage.setLevel7FreeRocketUsed(true));
    }

    // Save progress
    GameStorage.saveLevelStars(language, levelId, starsEarned);
    GameStorage.setMaxUnlockedLevelIndex(language, levelNumber);
    unawaited(GameStorage.incrementWinStreak());
    AnalyticsService.updateUserProperties(level: levelNumber);

    if (levelNumber == 1 && !GameStorage.isTutorialCompleted()) {
      GameStorage.setTutorialCompleted(true);
      AnalyticsService.logTutorial(name: 'tut_finish', value: 5);
    }

    AudioManager.playVictory();
    _showFeedback('🎉 $victoryCelebrationText +$coinsReward 🪙', Colors.amberAccent);

    // Calculate accurate play duration (excluding ad time)
    final durationSec = (DateTime.now().difference(levelStartTime).inMilliseconds / 1000.0) - adDurationSeconds;
    final playDuration = durationSec > 0 ? durationSec : 0.0;
    final playCount = GameStorage.getLevelPlayCount(language, levelNumber);
    final loseCount = GameStorage.getLevelLoseCount(language, levelNumber);

    // Log level_end event according to Tracking Specification
    AnalyticsService.logLevelEnd(
      level: levelNumber,
      playCount: playCount > 0 ? playCount : 1,
      loseCount: loseCount,
      playDuration: playDuration,
      totalItems: level.targetWords.length,
      clearedItems: solvedTargetWords.length,
      success: true,
      reason: 'win',
      adDuration: adDurationSeconds,
    );
  }

  /// Get next unsolved target word for tutorial
  String? getNextUnsolvedTargetWord() {
    for (final target in level.targetWords) {
      if (!solvedTargetWords.contains(target.word)) {
        return target.word;
      }
    }
    return null;
  }

  /// Get valid path for tutorial word
  List<Point<int>>? getTutorialPathForWord(String word) {
    return _findValidActivePath(word);
  }

  /// Check if board contains any active tile with count > 1
  Point<int>? getFirstTileWithCountGreaterThanOne() {
    final height = grid.length;
    final width = height > 0 ? grid[0].length : 0;
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        final tile = grid[r][c];
        if (!tile.isCleared && !tile.isObstacleLocked && tile.count > 1) {
          return Point(c, r);
        }
      }
    }
    return null;
  }

  /// Use 💡 Lightbulb Hint booster (Costs 80 Coins)
  Future<bool> useHint({bool isTutorialFree = false}) async {
    if (isWon || isWinning) return false;

    boostersUsedCount++;

    bool hasItem = false;
    if (isTutorialFree) {
      hasItem = true;
    } else {
      // Try using inventory item first
      hasItem = await GameStorage.useHintItem();
      if (hasItem) {
        AnalyticsService.logSpendResource(
          level: levelNumber,
          type: 'booster',
          name: 'hint',
          amount: 1,
          reason: 'ingame',
          balance: GameStorage.getHintCount().toDouble(),
        );
      } else {
        const hintCost = 80;
        final hasCoins = await GameStorage.spendCoins(hintCost);
        if (!hasCoins) {
          _showFeedback('Not enough coins! Need $hintCost 🪙 for Hint', Colors.redAccent);
          AudioManager.playInvalid();
          return false;
        }
        AnalyticsService.logSpendResource(
          level: levelNumber,
          type: 'currency',
          name: 'gold',
          amount: hintCost.toDouble(),
          reason: 'ingame',
          balance: GameStorage.getCoins().toDouble(),
        );
      }
    }

    for (final target in level.targetWords) {
      if (!solvedTargetWords.contains(target.word)) {
        final path = _findValidActivePath(target.word);
        if (path != null && path.isNotEmpty) {
          highlightedHintPath = path;
          _hintTimer?.cancel();
          _hintTimer = Timer(const Duration(seconds: 5), () {
            highlightedHintPath = null;
            notifyListeners();
          });
          final costStr = isTutorialFree ? ' (Free)' : (hasItem ? ' (Free Item)' : ' (-80 🪙)');
          _showFeedback('💡 Hint: "${target.word}"$costStr', const Color(0xFF69F0AE));
          AudioManager.playWordMatch();
          saveProgress();
          notifyListeners();
          return true;
        }
      }
    }

    _showFeedback('No available hint path found.', Colors.white70);
    return false;
  }

  /// Use 🚀 Rocket / Firework booster (Costs 240 Coins - Instantly Solves a Word!)
  Future<bool> useRocket({bool isTutorialFree = false}) async {
    if (isWon || isWinning) return false;

    boostersUsedCount++;

    bool hasItem = false;
    if (isTutorialFree) {
      hasItem = true;
    } else {
      // Try using inventory item first
      hasItem = await GameStorage.useRocketItem();
      if (hasItem) {
        AnalyticsService.logSpendResource(
          level: levelNumber,
          type: 'booster',
          name: 'rocket',
          amount: 1,
          reason: 'ingame',
          balance: GameStorage.getRocketCount().toDouble(),
        );
      } else {
        const rocketCost = 240;
        final hasCoins = await GameStorage.spendCoins(rocketCost);
        if (!hasCoins) {
          _showFeedback('Not enough coins! Need $rocketCost 🪙 for Rocket', Colors.redAccent);
          AudioManager.playInvalid();
          return false;
        }
        AnalyticsService.logSpendResource(
          level: levelNumber,
          type: 'currency',
          name: 'gold',
          amount: rocketCost.toDouble(),
          reason: 'ingame',
          balance: GameStorage.getCoins().toDouble(),
        );
      }
    }

    // Find the longest unsolved target word
    TargetWord? targetToSolve;
    int maxLen = 0;
    for (final target in level.targetWords) {
      if (!solvedTargetWords.contains(target.word)) {
        if (target.word.length > maxLen) {
          maxLen = target.word.length;
          targetToSolve = target;
        }
      }
    }

    if (targetToSolve != null) {
      final word = targetToSolve.word;
      solvedTargetWords.add(word);

      // Decrement tile counts on board with 0-leftover guarantee
      final path = _findValidActivePath(word) ?? [];
      _decrementWordTiles(word, path);

      AudioManager.playBooster();
      AnalyticsService.logBoosterUsed(boosterType: 'rocket', level: levelNumber);
      final costStr = isTutorialFree ? ' (Free)' : (hasItem ? ' (Free Item)' : ' (-240 🪙)');
      _showFeedback('🚀 Rocket Cleared: "$word"!$costStr', const Color(0xFF69F0AE));

      _checkObstacleUnlocks();

      if (solvedTargetWords.length >= level.targetWords.length) {
        _victoryTimer?.cancel();
        _victoryTimer = Timer(const Duration(milliseconds: 500), () {
          _handleVictory();
          notifyListeners();
        });
        return true;
      }

      saveProgress();
      notifyListeners();
      return true;
    }

    _showFeedback('All target words are already solved!', Colors.white70);
    return false;
  }

  /// Dev/Cheat: Instantly solve all remaining words and trigger victory
  void cheatInstantWin() {
    if (isWon) return;
    for (final tw in level.targetWords) {
      if (!solvedTargetWords.contains(tw.word)) {
        solvedTargetWords.add(tw.word);
      }
    }
    for (final row in grid) {
      for (final tile in row) {
        tile.count = 0;
        tile.isCleared = true;
      }
    }
    _victoryTimer?.cancel();
    _handleVictory();
    notifyListeners();
  }

  /// Dev/Cheat: Automatically solve the next unsolved target word
  void cheatSolveNextWord() {
    if (isWon || isWinning) return;
    TargetWord? targetToSolve;
    for (final target in level.targetWords) {
      if (!solvedTargetWords.contains(target.word)) {
        targetToSolve = target;
        break;
      }
    }

    if (targetToSolve != null) {
      final word = targetToSolve.word;
      solvedTargetWords.add(word);
      final path = _findValidActivePath(word) ?? [];
      _decrementWordTiles(word, path);
      AudioManager.playWordMatch();
      _showFeedback('⚡ Cheat Solved: "$word"!', const Color(0xFFFFD54F));
      _checkObstacleUnlocks();

      if (solvedTargetWords.length >= level.targetWords.length) {
        _victoryTimer?.cancel();
        _handleVictory();
      }
      notifyListeners();
    } else {
      cheatInstantWin();
    }
  }

  /// Checks if all remaining unsolved target words have at least one valid path on the board
  bool _areAllRemainingWordsSolvable(Set<String> solvedWords) {
    for (final tw in level.targetWords) {
      if (!solvedWords.contains(tw.word)) {
        if (_findValidActivePath(tw.word) == null) {
          return false;
        }
      }
    }
    return true;
  }

  /// Decrements tile counts with Solvability Protection, ensuring remaining words stay connected
  void _decrementWordTiles(String word, List<Point<int>> swipedPath) {
    final futureSolved = Set<String>.from(solvedTargetWords);

    for (int i = 0; i < word.length; i++) {
      final ch = word[i];
      final swipedPt = (i < swipedPath.length) ? swipedPath[i] : null;

      // Find all tiles on the board with this letter and count > 0
      final candidateTiles = <LetterTile>[];
      for (final row in grid) {
        for (final tile in row) {
          if (!tile.isCleared && tile.letter == ch && tile.count > 0) {
            candidateTiles.add(tile);
          }
        }
      }

      if (candidateTiles.isEmpty) continue;

      // Prefer the tile on the swiped path if available
      LetterTile chosenTile = candidateTiles.first;
      if (swipedPt != null) {
        final onPathTile = grid[swipedPt.y][swipedPt.x];
        if (candidateTiles.contains(onPathTile)) {
          chosenTile = onPathTile;
        }
      }

      // Decrement chosenTile
      chosenTile.count--;
      final wasCleared = chosenTile.count <= 0;
      if (wasCleared) chosenTile.isCleared = true;

      // If clearing chosenTile breaks any remaining word, search for a safer alternative tile
      if (!_areAllRemainingWordsSolvable(futureSolved) && candidateTiles.length > 1) {
        // Revert chosenTile
        if (wasCleared) chosenTile.isCleared = false;
        chosenTile.count++;

        LetterTile? safeTile;
        for (final altTile in candidateTiles) {
          if (altTile == chosenTile) continue;
          altTile.count--;
          final altCleared = altTile.count <= 0;
          if (altCleared) altTile.isCleared = true;

          if (_areAllRemainingWordsSolvable(futureSolved)) {
            safeTile = altTile;
            break;
          }

          // Revert altTile
          if (altCleared) altTile.isCleared = false;
          altTile.count++;
        }

        // If no safe tile was found, re-apply decrement on chosenTile
        if (safeTile == null) {
          chosenTile.count--;
          if (chosenTile.count <= 0) chosenTile.isCleared = true;
        }
      }
    }

    // Mark all tiles with count <= 0 as cleared immediately
    for (final row in grid) {
      for (final tile in row) {
        if (tile.count <= 0) {
          tile.count = 0;
          tile.isCleared = true;
        }
      }
    }
  }

  /// Search for a path for a word using 4 directions
  List<Point<int>>? _findValidActivePath(String word) {
    final height = grid.length;
    final width = height > 0 ? grid[0].length : 0;
    if (word.isEmpty || height == 0 || width == 0) return null;

    final firstChar = word[0];
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        final tile = grid[r][c];
        if (!tile.isCleared && !tile.isObstacleLocked && tile.letter == firstChar) {
          final visited = <Point<int>>{Point(c, r)};
          final path = <Point<int>>[Point(c, r)];
          if (_dfsActive(word, 1, Point(c, r), visited, path, width, height)) {
            return path;
          }
        }
      }
    }
    return null;
  }

  bool _dfsActive(
    String word,
    int index,
    Point<int> current,
    Set<Point<int>> visited,
    List<Point<int>> path,
    int width,
    int height,
  ) {
    if (index >= word.length) return true;

    final targetChar = word[index];
    const dr = [-1, 1, 0, 0];
    const dc = [0, 0, -1, 1];
    for (int i = 0; i < 4; i++) {
      final nx = current.x + dc[i];
      final ny = current.y + dr[i];

      if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
        final nextPt = Point(nx, ny);
        final tile = grid[ny][nx];
        if (!visited.contains(nextPt) &&
            !tile.isCleared &&
            !tile.isObstacleLocked &&
            tile.letter == targetChar) {
          visited.add(nextPt);
          path.add(nextPt);
          if (_dfsActive(word, index + 1, nextPt, visited, path, width, height)) {
            return true;
          }
          path.removeLast();
          visited.remove(nextPt);
        }
      }
    }
    return false;
  }

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    feedbackMessage = null;
    feedbackColor = null;
    feedbackCombo = null;
    feedbackPraise = null;
    feedbackComboMultiplier = null;
  }

  void showFeedback(String message, Color color) => _showFeedback(message, color);

  void _showFeedback(String message, Color color) {
    _clearFeedback();
    feedbackMessage = message;
    feedbackColor = color;
    _feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      _clearFeedback();
      notifyListeners();
    });
    notifyListeners();
  }

  void _showComboFeedback({
    required String praise,
    required String multiplier,
    required int combo,
    required Color color,
  }) {
    _clearFeedback();
    feedbackPraise = praise;
    feedbackComboMultiplier = multiplier;
    feedbackCombo = combo;
    feedbackMessage = '$praise • COMBO $multiplier';
    feedbackColor = color;
    _feedbackTimer = Timer(const Duration(milliseconds: 1100), () {
      _clearFeedback();
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    saveProgress();
    extraWordFlyNotifier.dispose();
    _hintTimer?.cancel();
    _feedbackTimer?.cancel();
    _victoryTimer?.cancel();
    super.dispose();
  }
}
