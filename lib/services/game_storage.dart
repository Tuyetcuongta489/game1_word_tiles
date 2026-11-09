import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/level_model.dart';
import 'level_loader.dart';
import 'app_localization.dart';

class GameStorage {
  static late SharedPreferences _prefs;
  static SharedPreferences get prefs => _prefs;
  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static int getHints() => getHintCount();
  static Future<void> addHints(int amount) => addHintCount(amount);
  static int getRockets() => getRocketCount();
  static Future<void> addRockets(int amount) => addRocketCount(amount);

  static String? _cachedLanguage;
  static final ValueNotifier<String> languageNotifier = ValueNotifier<String>('english');

  static int? _cachedCoins;
  static final ValueNotifier<int> coinsNotifier = ValueNotifier<int>(250);

  static int? _cachedExtraWordsChestCount;
  static final ValueNotifier<int> extraWordsNotifier = ValueNotifier<int>(0);

  static int? _cachedHintCount;
  static final ValueNotifier<int> hintCountNotifier = ValueNotifier<int>(2);

  static int? _cachedRocketCount;
  static final ValueNotifier<int> rocketCountNotifier = ValueNotifier<int>(1);

  static bool? _cachedTutorialCompleted;
  static bool? _cachedCountTutorialShown;
  static bool? _cachedReverseTutorialShown;
  static bool? _cachedHintTutorialShown;
  static bool? _cachedExtraWordsTutorialShown;
  static bool? _cachedRocketTutorialShown;
  static bool? _cachedLevel5FreeHintUsed;
  static bool? _cachedLevel7FreeRocketUsed;
  static bool? _cachedHasCompletedFirstSession;

  static bool? _cachedInfiniteBoosters;
  static final ValueNotifier<bool> infiniteBoostersNotifier = ValueNotifier<bool>(false);

  static bool? _cachedDevOverlay;
  static final ValueNotifier<bool> devOverlayNotifier = ValueNotifier<bool>(true);

  static bool? _cachedHideGameplayUI;
  static final ValueNotifier<bool> hideGameplayUINotifier = ValueNotifier<bool>(false);

  static bool? _cachedNoAdsPurchased;
  static final ValueNotifier<bool> noAdsNotifier = ValueNotifier<bool>(false);

  static bool? _cachedFirebaseAnalyticsTest;
  static final ValueNotifier<bool> firebaseAnalyticsTestNotifier = ValueNotifier<bool>(false);

  static bool? _cachedHasEverSeenNoAdsPopup;
  static bool? _cachedHasWatchedInterEndgame;
  static int _sessionCount = 1;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    _cachedCoins = _prefs.getInt('player_coins') ?? 250;
    coinsNotifier.value = _cachedCoins!;

    _cachedExtraWordsChestCount = _prefs.getInt('extra_words_chest_count') ?? 0;
    extraWordsNotifier.value = _cachedExtraWordsChestCount!;

    _cachedHintCount = _prefs.getInt('inventory_hint_count') ?? 2;
    hintCountNotifier.value = _cachedHintCount!;

    _cachedRocketCount = _prefs.getInt('inventory_rocket_count') ?? 1;
    rocketCountNotifier.value = _cachedRocketCount!;

    _cachedTutorialCompleted = _prefs.getBool('tutorial_completed') ?? false;
    _cachedCountTutorialShown = _prefs.getBool('count_tutorial_shown') ?? false;
    _cachedReverseTutorialShown = _prefs.getBool('reverse_tutorial_shown') ?? false;
    _cachedHintTutorialShown = _prefs.getBool('hint_tutorial_shown') ?? false;
    _cachedExtraWordsTutorialShown = _prefs.getBool('extra_words_tutorial_shown') ?? false;
    _cachedRocketTutorialShown = _prefs.getBool('rocket_tutorial_shown') ?? false;
    _cachedLevel5FreeHintUsed = _prefs.getBool('level_5_free_hint_used') ?? false;
    _cachedLevel7FreeRocketUsed = _prefs.getBool('level_7_free_rocket_used') ?? false;
    _cachedHasCompletedFirstSession = _prefs.getBool('has_completed_first_session') ?? false;

    _cachedInfiniteBoosters = _prefs.getBool('cheat_infinite_boosters') ?? false;
    infiniteBoostersNotifier.value = _cachedInfiniteBoosters!;

    _cachedDevOverlay = _prefs.getBool('cheat_dev_overlay_enabled') ?? true;
    devOverlayNotifier.value = _cachedDevOverlay!;

    _cachedHideGameplayUI = _prefs.getBool('cheat_hide_gameplay_ui') ?? false;
    hideGameplayUINotifier.value = _cachedHideGameplayUI!;

    _cachedNoAdsPurchased = _prefs.getBool('is_no_ads_purchased') ?? false;
    noAdsNotifier.value = _cachedNoAdsPurchased!;

    _cachedFirebaseAnalyticsTest = _prefs.getBool('cheat_firebase_analytics_test_enabled') ?? false;
    firebaseAnalyticsTestNotifier.value = _cachedFirebaseAnalyticsTest!;

    _cachedHasEverSeenNoAdsPopup = _prefs.getBool('has_ever_seen_no_ads_popup') ?? false;
    _cachedHasWatchedInterEndgame = _prefs.getBool('has_watched_inter_endgame') ?? false;
    _sessionCount = (_prefs.getInt('app_session_count') ?? 0) + 1;
    await _prefs.setInt('app_session_count', _sessionCount);

    final hasUserSelected = _prefs.getBool('has_user_selected_language') ?? false;
    if (!hasUserSelected && !_prefs.containsKey('selected_language')) {
      final detected = AppLocalization.detectDeviceLanguage();
      await _prefs.setString('selected_language', detected);
      _cachedLanguage = detected;
    } else {
      final saved = _prefs.getString('selected_language') ?? 'english';
      _cachedLanguage = LevelLoader.supportedLanguages.contains(saved) ? saved : 'english';
    }
    languageNotifier.value = _cachedLanguage!;
  }

  // Selected Language
  static String getSelectedLanguage() {
    if (_cachedLanguage != null && LevelLoader.supportedLanguages.contains(_cachedLanguage)) {
      return _cachedLanguage!;
    }
    if (_isInitialized) {
      final lang = _prefs.getString('selected_language');
      if (lang != null && LevelLoader.supportedLanguages.contains(lang)) {
        _cachedLanguage = lang;
        return lang;
      }
    }
    final detected = AppLocalization.detectDeviceLanguage();
    _cachedLanguage = detected;
    return detected;
  }

  static String getLanguage() => getSelectedLanguage();

  static Future<void> setSelectedLanguage(String lang, {bool isUserAction = true}) async {
    final validLang = LevelLoader.supportedLanguages.contains(lang) ? lang : 'english';
    if (_isInitialized) {
      await _prefs.setString('selected_language', validLang);
      if (isUserAction) {
        await _prefs.setBool('has_user_selected_language', true);
      }
    }
    _cachedLanguage = validLang;
    languageNotifier.value = validLang;
  }

  // Current Level Index in Progression List (0-indexed)
  static int getCurrentLevelIndex(String language) {
    return _prefs.getInt('current_level_index_$language') ?? 0;
  }

  static Future<void> setCurrentLevelIndex(String language, int index) async {
    await _prefs.setInt('current_level_index_$language', index);
  }

  // Max Unlocked Level Index
  static int getMaxUnlockedLevelIndex(String language) {
    return _prefs.getInt('max_unlocked_level_index_$language') ?? 0;
  }

  static Future<void> setMaxUnlockedLevelIndex(String language, int index) async {
    final current = getMaxUnlockedLevelIndex(language);
    if (index > current) {
      await _prefs.setInt('max_unlocked_level_index_$language', index);
    }
  }

  // Level Play Count (play_count tracking for analytics)
  static int getLevelPlayCount(String language, int level) {
    return _prefs.getInt('level_play_count_${language}_$level') ?? 0;
  }

  static Future<int> incrementLevelPlayCount(String language, int level) async {
    final count = getLevelPlayCount(language, level) + 1;
    await _prefs.setInt('level_play_count_${language}_$level', count);
    return count;
  }

  // Level Lose Count (lose_count tracking for analytics)
  static int getLevelLoseCount(String language, int level) {
    return _prefs.getInt('level_lose_count_${language}_$level') ?? 0;
  }

  static Future<int> incrementLevelLoseCount(String language, int level) async {
    final count = getLevelLoseCount(language, level) + 1;
    await _prefs.setInt('level_lose_count_${language}_$level', count);
    return count;
  }

  // IAP Tracking
  static int getIapCount() {
    return _prefs.getInt('iap_purchase_count') ?? 0;
  }

  static Future<int> incrementIapCount() async {
    final count = getIapCount() + 1;
    await _prefs.setInt('iap_purchase_count', count);
    return count;
  }

  static bool isIapUser() {
    return getIapCount() > 0 || isNoAdsPurchased();
  }

  // Win / Lose Streak Tracking
  static int getWinStreak() {
    return _prefs.getInt('analytics_win_streak') ?? 0;
  }

  static Future<int> incrementWinStreak() async {
    final streak = getWinStreak() + 1;
    await _prefs.setInt('analytics_win_streak', streak);
    await _prefs.setInt('analytics_lose_streak', 0);
    return streak;
  }

  static int getLoseStreak() {
    return _prefs.getInt('analytics_lose_streak') ?? 0;
  }

  static Future<int> incrementLoseStreak() async {
    final streak = getLoseStreak() + 1;
    await _prefs.setInt('analytics_lose_streak', streak);
    await _prefs.setInt('analytics_win_streak', 0);
    return streak;
  }

  static Future<void> resetStreaks() async {
    await _prefs.setInt('analytics_win_streak', 0);
    await _prefs.setInt('analytics_lose_streak', 0);
  }

  // AppsFlyer af_level_achieved Tracking (chỉ bắn 1 lần / level)
  static bool isLevelAchievedLogged(int level) {
    return _prefs.getBool('af_level_achieved_$level') ?? false;
  }

  static Future<void> setLevelAchievedLogged(int level, [bool value = true]) async {
    await _prefs.setBool('af_level_achieved_$level', value);
  }

  // Level Stars (Map of Level ID -> Stars 1-3)
  static Map<int, int> getLevelStars(String language) {
    final raw = _prefs.getString('level_stars_$language');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(int.parse(k), v as int));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveLevelStars(String language, int levelId, int stars) async {
    final currentMap = getLevelStars(language);
    if ((currentMap[levelId] ?? 0) < stars) {
      currentMap[levelId] = stars;
      final encoded = jsonEncode(currentMap.map((k, v) => MapEntry(k.toString(), v)));
      await _prefs.setString('level_stars_$language', encoded);
    }
  }

  // Coins (Start with 250 coins so player can test boosters)
  static int getCoins() {
    _cachedCoins ??= _prefs.getInt('player_coins') ?? 250;
    return _cachedCoins!;
  }

  static Future<void> addCoins(int amount) async {
    final current = getCoins();
    final updated = current + amount;
    _cachedCoins = updated;
    coinsNotifier.value = updated;
    await _prefs.setInt('player_coins', updated);
  }

  static Future<void> setCoins(int amount) async {
    final updated = amount.clamp(0, 9999999);
    _cachedCoins = updated;
    coinsNotifier.value = updated;
    await _prefs.setInt('player_coins', updated);
  }

  static Future<bool> spendCoins(int amount) async {
    final current = getCoins();
    if (current >= amount) {
      final updated = current - amount;
      _cachedCoins = updated;
      coinsNotifier.value = updated;
      await _prefs.setInt('player_coins', updated);
      return true;
    }
    return false;
  }

  // Extra Words Bank (Milestone: 10 words = 10 Coins Reward)
  static int getExtraWordsChestCount() {
    return _cachedExtraWordsChestCount ?? _prefs.getInt('extra_words_chest_count') ?? 0;
  }

  static Future<void> setExtraWordsChestCount(int count) async {
    _cachedExtraWordsChestCount = count;
    extraWordsNotifier.value = count;
    await _prefs.setInt('extra_words_chest_count', count);
  }

  static int addExtraWordToBank() {
    final current = getExtraWordsChestCount();
    final newCount = (current + 1).clamp(0, 10);
    setExtraWordsChestCount(newCount);
    return newCount;
  }

  static Future<bool> claimExtraWordsBankReward() async {
    final current = getExtraWordsChestCount();
    if (current >= 10) {
      await addCoins(50);
      await setExtraWordsChestCount(0);
      return true;
    }
    return false;
  }

  // Free Booster Inventory: 💡 Hint (80 Coins) & 🚀 Rocket (240 Coins)
  static int getHintCount() {
    return _cachedHintCount ?? _prefs.getInt('inventory_hint_count') ?? 2;
  }

  static Future<void> addHintCount(int amount) async {
    final current = getHintCount();
    final updated = (current + amount).clamp(0, 9999);
    _cachedHintCount = updated;
    hintCountNotifier.value = updated;
    await _prefs.setInt('inventory_hint_count', updated);
  }

  static Future<void> setHintCount(int amount) async {
    final updated = amount.clamp(0, 9999);
    _cachedHintCount = updated;
    hintCountNotifier.value = updated;
    await _prefs.setInt('inventory_hint_count', updated);
  }

  static Future<bool> useHintItem() async {
    if (isInfiniteBoostersEnabled()) return true;
    final current = getHintCount();
    if (current > 0) {
      final updated = current - 1;
      _cachedHintCount = updated;
      hintCountNotifier.value = updated;
      await _prefs.setInt('inventory_hint_count', updated);
      return true;
    }
    return false;
  }

  static int getRocketCount() {
    return _cachedRocketCount ?? _prefs.getInt('inventory_rocket_count') ?? 1;
  }

  static Future<void> addRocketCount(int amount) async {
    final current = getRocketCount();
    final updated = (current + amount).clamp(0, 9999);
    _cachedRocketCount = updated;
    rocketCountNotifier.value = updated;
    await _prefs.setInt('inventory_rocket_count', updated);
  }

  static Future<void> setRocketCount(int amount) async {
    final updated = amount.clamp(0, 9999);
    _cachedRocketCount = updated;
    rocketCountNotifier.value = updated;
    await _prefs.setInt('inventory_rocket_count', updated);
  }

  static Future<bool> useRocketItem() async {
    if (isInfiniteBoostersEnabled()) return true;
    final current = getRocketCount();
    if (current > 0) {
      final updated = current - 1;
      _cachedRocketCount = updated;
      rocketCountNotifier.value = updated;
      await _prefs.setInt('inventory_rocket_count', updated);
      return true;
    }
    return false;
  }

  // Daily Free Gift (24h Cooldown)
  static int getLastDailyGiftClaimTime() {
    return _prefs.getInt('last_daily_gift_claim_ms') ?? 0;
  }

  static Future<void> setLastDailyGiftClaimTime(int timestampMs) async {
    await _prefs.setInt('last_daily_gift_claim_ms', timestampMs);
  }

  static bool canClaimDailyGift() {
    final lastMs = getLastDailyGiftClaimTime();
    if (lastMs <= 0) return true;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(lastTime);
    return diff.inMilliseconds >= const Duration(hours: 24).inMilliseconds;
  }

  static Duration getRemainingDailyGiftCooldown() {
    final lastMs = getLastDailyGiftClaimTime();
    if (lastMs <= 0) return Duration.zero;
    final lastTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final elapsed = DateTime.now().difference(lastTime);
    const totalDuration = Duration(hours: 24);
    if (elapsed >= totalDuration) return Duration.zero;
    return totalDuration - elapsed;
  }

  // Sound, Music & Haptic Settings
  static bool getMusicEnabled() {
    return _prefs.getBool('music_enabled') ?? true;
  }

  static bool isMusicEnabled() => getMusicEnabled();

  static Future<void> setMusicEnabled(bool enabled) async {
    await _prefs.setBool('music_enabled', enabled);
  }

  static bool getSoundEnabled() {
    return _prefs.getBool('sound_enabled') ?? true;
  }

  static bool isSoundEnabled() => getSoundEnabled();

  static Future<void> setSoundEnabled(bool enabled) async {
    await _prefs.setBool('sound_enabled', enabled);
  }

  static bool getHapticEnabled() {
    if (!_isInitialized) return true;
    return _prefs.getBool('haptic_enabled') ?? true;
  }

  static bool isHapticEnabled() => getHapticEnabled();

  static Future<void> setHapticEnabled(bool enabled) async {
    await _prefs.setBool('haptic_enabled', enabled);
  }

  // In-Game Tutorial Progress
  static bool isTutorialCompleted() {
    return _cachedTutorialCompleted ?? _prefs.getBool('tutorial_completed') ?? false;
  }

  static Future<void> setTutorialCompleted(bool completed) async {
    _cachedTutorialCompleted = completed;
    await _prefs.setBool('tutorial_completed', completed);
  }

  static bool isCountTutorialShown() {
    return _cachedCountTutorialShown ?? _prefs.getBool('count_tutorial_shown') ?? false;
  }

  static Future<void> setCountTutorialShown(bool shown) async {
    _cachedCountTutorialShown = shown;
    await _prefs.setBool('count_tutorial_shown', shown);
  }

  static bool isReverseTutorialShown() {
    return _cachedReverseTutorialShown ?? _prefs.getBool('reverse_tutorial_shown') ?? false;
  }

  static Future<void> setReverseTutorialShown(bool shown) async {
    _cachedReverseTutorialShown = shown;
    await _prefs.setBool('reverse_tutorial_shown', shown);
  }

  static bool isHintTutorialShown() {
    return _cachedHintTutorialShown ?? _prefs.getBool('hint_tutorial_shown') ?? false;
  }

  static Future<void> setHintTutorialShown(bool shown) async {
    _cachedHintTutorialShown = shown;
    await _prefs.setBool('hint_tutorial_shown', shown);
  }

  static bool isExtraWordsTutorialShown() {
    return _cachedExtraWordsTutorialShown ?? _prefs.getBool('extra_words_tutorial_shown') ?? false;
  }

  static Future<void> setExtraWordsTutorialShown(bool shown) async {
    _cachedExtraWordsTutorialShown = shown;
    await _prefs.setBool('extra_words_tutorial_shown', shown);
  }

  static bool isRocketTutorialShown() {
    return _cachedRocketTutorialShown ?? _prefs.getBool('rocket_tutorial_shown') ?? false;
  }

  static Future<void> setRocketTutorialShown(bool shown) async {
    _cachedRocketTutorialShown = shown;
    await _prefs.setBool('rocket_tutorial_shown', shown);
  }

  // Free Booster Retention (Level 5 Hint & Level 7 Rocket)
  static bool hasUsedLevel5FreeHint() {
    return _cachedLevel5FreeHintUsed ?? _prefs.getBool('level_5_free_hint_used') ?? false;
  }

  static Future<void> setLevel5FreeHintUsed(bool used) async {
    _cachedLevel5FreeHintUsed = used;
    await _prefs.setBool('level_5_free_hint_used', used);
  }

  static bool hasUsedLevel7FreeRocket() {
    return _cachedLevel7FreeRocketUsed ?? _prefs.getBool('level_7_free_rocket_used') ?? false;
  }

  static Future<void> setLevel7FreeRocketUsed(bool used) async {
    _cachedLevel7FreeRocketUsed = used;
    await _prefs.setBool('level_7_free_rocket_used', used);
  }

  // Mid-Level Progress Persistence
  static Future<void> saveLevelProgress({
    required String language,
    required int levelNumber,
    required Set<String> solvedWords,
    required Set<String> foundExtraWords,
    required List<List<LetterTile>> grid,
    int invalidAttempts = 0,
    int boostersUsed = 0,
    int comboStreak = 0,
  }) async {
    final key = 'level_progress_${language}_$levelNumber';
    final gridData = grid.map((row) {
      return row.map((tile) => {
        'row': tile.row,
        'col': tile.col,
        'letter': tile.letter,
        'count': tile.count,
        'initialCount': tile.initialCount,
        'isCleared': tile.isCleared,
        'isObstacleLocked': tile.isObstacleLocked,
        'obstacleReq': tile.obstacleRequiredWords,
      }).toList();
    }).toList();

    final data = {
      'levelNumber': levelNumber,
      'solvedTargetWords': solvedWords.toList(),
      'foundExtraWords': foundExtraWords.toList(),
      'invalidAttempts': invalidAttempts,
      'boostersUsed': boostersUsed,
      'comboStreak': comboStreak,
      'grid': gridData,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _prefs.setString(key, jsonEncode(data));
  }

  static Map<String, dynamic>? getLevelProgress(String language, int levelNumber) {
    final key = 'level_progress_${language}_$levelNumber';
    final str = _prefs.getString(key);
    if (str == null || str.isEmpty) return null;
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearLevelProgress(String language, int levelNumber) async {
    final key = 'level_progress_${language}_$levelNumber';
    await _prefs.remove(key);
  }

  // No Ads Status
  static bool isNoAdsPurchased() {
    _cachedNoAdsPurchased ??= _prefs.getBool('is_no_ads_purchased') ?? false;
    return _cachedNoAdsPurchased!;
  }

  static Future<void> setNoAdsPurchased(bool value) async {
    _cachedNoAdsPurchased = value;
    noAdsNotifier.value = value;
    await _prefs.setBool('is_no_ads_purchased', value);
  }

  // No Ads Popup Seen State (Case 1 gatekeeper: user has seen popup anywhere)
  static bool hasEverSeenNoAdsPopup() {
    _cachedHasEverSeenNoAdsPopup ??= _prefs.getBool('has_ever_seen_no_ads_popup') ?? false;
    return _cachedHasEverSeenNoAdsPopup!;
  }

  static Future<void> setHasEverSeenNoAdsPopup(bool seen) async {
    _cachedHasEverSeenNoAdsPopup = seen;
    await _prefs.setBool('has_ever_seen_no_ads_popup', seen);
  }

  // Inter Endgame Watched State (Case 1 condition: user has completed >= 1 endgame inter)
  static bool hasWatchedInterEndgame() {
    _cachedHasWatchedInterEndgame ??= _prefs.getBool('has_watched_inter_endgame') ?? false;
    return _cachedHasWatchedInterEndgame!;
  }

  static Future<void> setHasWatchedInterEndgame(bool watched) async {
    _cachedHasWatchedInterEndgame = watched;
    await _prefs.setBool('has_watched_inter_endgame', watched);
  }

  // App Session Counter (Session 1 -> N=10, Session >= 2 -> N=5)
  static int getSessionCount() => _sessionCount;

  @visibleForTesting
  static void setMockSessionCount(int count) {
    _sessionCount = count;
  }

  // Ads Interstitial Gatekeeper
  static bool hasShownFirstInter() {
    return _prefs.getBool('has_shown_first_inter') ?? false;
  }

  static Future<void> setHasShownFirstInter(bool shown) async {
    await _prefs.setBool('has_shown_first_inter', shown);
  }

  // First Session Management
  static bool isFirstSession() {
    return !(_cachedHasCompletedFirstSession ?? _prefs.getBool('has_completed_first_session') ?? false);
  }

  static Future<void> markFirstSessionCompleted() async {
    _cachedHasCompletedFirstSession = true;
    await _prefs.setBool('has_completed_first_session', true);
  }

  @visibleForTesting
  static Future<void> resetFirstSessionForTesting() async {
    _cachedHasCompletedFirstSession = false;
    await _prefs.remove('has_completed_first_session');
  }

  // Reset Progress
  static Future<void> resetLanguageProgress(String language) async {
    await _prefs.remove('current_level_index_$language');
    await _prefs.remove('max_unlocked_level_index_$language');
    await _prefs.remove('level_stars_$language');
    await _prefs.remove('tutorial_completed');
    await _prefs.remove('count_tutorial_shown');
    await _prefs.remove('reverse_tutorial_shown');
    await _prefs.remove('hint_tutorial_shown');
    await _prefs.remove('extra_words_tutorial_shown');
    await _prefs.remove('rocket_tutorial_shown');
    await _prefs.remove('level_5_free_hint_used');
    await _prefs.remove('level_7_free_rocket_used');
    await _prefs.remove('has_shown_first_inter');

    _cachedTutorialCompleted = false;
    _cachedCountTutorialShown = false;
    _cachedReverseTutorialShown = false;
    _cachedHintTutorialShown = false;
    _cachedExtraWordsTutorialShown = false;
    _cachedRocketTutorialShown = false;
    _cachedLevel5FreeHintUsed = false;
    _cachedLevel7FreeRocketUsed = false;
  }

  // ==========================================
  // CHEAT & DEV TOOLS METHODS
  // ==========================================

  static bool isInfiniteBoostersEnabled() {
    _cachedInfiniteBoosters ??= _prefs.getBool('cheat_infinite_boosters') ?? false;
    return _cachedInfiniteBoosters!;
  }

  static Future<void> setInfiniteBoostersEnabled(bool enabled) async {
    _cachedInfiniteBoosters = enabled;
    infiniteBoostersNotifier.value = enabled;
    await _prefs.setBool('cheat_infinite_boosters', enabled);
  }

  static bool isDevOverlayEnabled() {
    _cachedDevOverlay ??= _prefs.getBool('cheat_dev_overlay_enabled') ?? true;
    return _cachedDevOverlay!;
  }

  static Future<void> setDevOverlayEnabled(bool enabled) async {
    _cachedDevOverlay = enabled;
    devOverlayNotifier.value = enabled;
    await _prefs.setBool('cheat_dev_overlay_enabled', enabled);
  }

  static bool isFirebaseAnalyticsTestEnabled() {
    _cachedFirebaseAnalyticsTest ??= _prefs.getBool('cheat_firebase_analytics_test_enabled') ?? false;
    return _cachedFirebaseAnalyticsTest!;
  }

  static Future<void> setFirebaseAnalyticsTestEnabled(bool enabled) async {
    _cachedFirebaseAnalyticsTest = enabled;
    firebaseAnalyticsTestNotifier.value = enabled;
    await _prefs.setBool('cheat_firebase_analytics_test_enabled', enabled);
  }

  /// Force-set current and max unlocked level progression (1-based levelNumber)
  static Future<void> forceSetLevelProgression(String language, int levelNumber) async {
    final maxCount = LevelLoader.totalLevelsPerLanguage[language] ?? 1500;
    final index = (levelNumber - 1).clamp(0, maxCount - 1);
    await setCurrentLevelIndex(language, index);
    await _prefs.setInt('max_unlocked_level_index_$language', index);
  }

  /// Unlock all levels for given language
  static Future<void> unlockAllLevels(String language) async {
    final maxIndex = (LevelLoader.totalLevelsPerLanguage[language] ?? 1500) - 1;
    await _prefs.setInt('max_unlocked_level_index_$language', maxIndex);
  }

  /// Clear daily gift timer so user can claim immediately
  static Future<void> resetDailyGiftCooldown() async {
    await _prefs.remove('last_daily_gift_claim_ms');
  }

  static bool isGameplayUIHidden() {
    _cachedHideGameplayUI ??= _prefs.getBool('cheat_hide_gameplay_ui') ?? false;
    return _cachedHideGameplayUI!;
  }

  static Future<void> setGameplayUIHidden(bool hidden) async {
    _cachedHideGameplayUI = hidden;
    hideGameplayUINotifier.value = hidden;
    await _prefs.setBool('cheat_hide_gameplay_ui', hidden);
  }

  static bool? _cachedTutorialTapOutsideOverride;

  static bool? getTutorialTapOutsideOverride() {
    if (_cachedTutorialTapOutsideOverride != null) return _cachedTutorialTapOutsideOverride;
    if (_prefs.containsKey('cheat_tutorial_tap_outside')) {
      _cachedTutorialTapOutsideOverride = _prefs.getBool('cheat_tutorial_tap_outside');
    }
    return _cachedTutorialTapOutsideOverride;
  }

  static Future<void> setTutorialTapOutsideOverride(bool? value) async {
    _cachedTutorialTapOutsideOverride = value;
    if (value == null) {
      await _prefs.remove('cheat_tutorial_tap_outside');
    } else {
      await _prefs.setBool('cheat_tutorial_tap_outside', value);
    }
  }

  // Dictionary Caching
  static String? getCachedWordDefinition(String word) {
    if (!_isInitialized) return null;
    return _prefs.getString('dict_cache_${word.toLowerCase().trim()}');
  }

  static Future<void> setCachedWordDefinition(String word, String jsonString) async {
    if (!_isInitialized) return;
    await _prefs.setString('dict_cache_${word.toLowerCase().trim()}', jsonString);
  }

  /// Wipe all game data and reset to fresh installation state
  static Future<void> resetAllData() async {
    await _prefs.clear();
    _cachedCoins = 250;
    coinsNotifier.value = 250;
    _cachedExtraWordsChestCount = 0;
    extraWordsNotifier.value = 0;
    _cachedHintCount = 2;
    hintCountNotifier.value = 2;
    _cachedRocketCount = 1;
    rocketCountNotifier.value = 1;
    _cachedTutorialCompleted = false;
    _cachedCountTutorialShown = false;
    _cachedReverseTutorialShown = false;
    _cachedHintTutorialShown = false;
    _cachedExtraWordsTutorialShown = false;
    _cachedRocketTutorialShown = false;
    _cachedHasCompletedFirstSession = false;
    _cachedInfiniteBoosters = false;
    infiniteBoostersNotifier.value = false;
    _cachedDevOverlay = true;
    devOverlayNotifier.value = true;
    _cachedHideGameplayUI = false;
    hideGameplayUINotifier.value = false;
    _cachedTutorialTapOutsideOverride = null;
    _cachedNoAdsPurchased = false;
    noAdsNotifier.value = false;
  }
}
