import 'package:flutter/foundation.dart';
import 'package:funtap_global_sdk/funtap_global_sdk.dart';
import 'game_storage.dart';

/// Remote Config Service for Word Tiles Ads & Gameplay parameters.
/// Reads values from Funtap Global SDK with robust defaults matching the ad spec.
class RemoteConfigService {
  RemoteConfigService._();

  // Keys from Ad Specification & Gameplay
  static const String keyInterLevelX = 'Inter_level_x';
  static const String keyAdsInterval = 'Ads_interval';
  static const String keyAoaFormat = 'Aoa_format';
  static const String keyAdsReplay = 'Ads_replay';
  static const String keyAdsResume = 'Ads_resume';
  static const String keyTutorialTapOutsideClose = 'tutorial_tap_outside_close';
  static const String keyCheatEnabled = 'cheat_enabled';
  static const String keyEnableCheat = 'enable_cheat';
  static const String keyDictionaryMinLevel = 'dictionary_min_level';
  static const String keyDictionaryEnabled = 'dictionary_enabled';

  // Cached values with defaults
  static int _interLevelX = 10;
  static int _adsInterval = 25;
  static bool _aoaFormat = false; // false = AdMob, true = MAX
  static bool _adsReplay = false; // false = Inter, true = Native full screen
  static bool _adsResume = false; // false = AOA, true = Inter
  static bool _tutorialTapOutsideClose = kDebugMode; // Default true in debug for local testing, false in production
  static bool _cheatEnabled = kDebugMode; // Default true in debug for local testing, false in production
  static int _dictionaryMinLevel = 5;
  static bool _dictionaryEnabled = true;

  static int get interLevelX => _interLevelX;
  static int get adsInterval => _adsInterval;
  static bool get aoaFormat => _aoaFormat;
  static bool get adsReplay => _adsReplay;
  static bool get adsResume => _adsResume;
  static bool get cheatEnabled => _cheatEnabled;
  static int get dictionaryMinLevel => _dictionaryMinLevel;
  static bool get dictionaryEnabled => _dictionaryEnabled;
  static bool isDictionaryAvailableForLevel(int level) =>
      _dictionaryEnabled && level >= _dictionaryMinLevel;
  static bool get tutorialTapOutsideClose {
    final override = GameStorage.getTutorialTapOutsideOverride();
    if (override != null) return override;
    return _tutorialTapOutsideClose;
  }

  /// Fetch all Remote Configs from FGSDK
  static Future<void> fetchConfigs() async {
    try {
      final isReady = await FGSDK.isRemoteConfigReady();
      debugPrint('[RemoteConfig] isRemoteConfigReady: $isReady');

      _interLevelX = await _fetchInt(keyInterLevelX, 10);
      _adsInterval = await _fetchInt(keyAdsInterval, 25);
      _aoaFormat = await _fetchBool(keyAoaFormat, false);
      _adsReplay = await _fetchBool(keyAdsReplay, false);
      _adsResume = await _fetchBool(keyAdsResume, false);
      _tutorialTapOutsideClose = await _fetchBool(keyTutorialTapOutsideClose, false);
      _dictionaryMinLevel = await _fetchInt(keyDictionaryMinLevel, 5);
      _dictionaryEnabled = await _fetchBool(keyDictionaryEnabled, true);

      final cheat1 = await _fetchBool(keyCheatEnabled, false);
      final cheat2 = await _fetchBool(keyEnableCheat, false);
      if (cheat1 || cheat2) {
        _cheatEnabled = true;
      } else {
        _cheatEnabled = await _fetchBool(keyCheatEnabled, kDebugMode);
      }

      debugPrint(
        '[RemoteConfig] Configs loaded -> '
        'interLevelX: $_interLevelX, '
        'adsInterval: ${_adsInterval}s, '
        'aoaFormat: $_aoaFormat, '
        'adsReplay: $_adsReplay, '
        'adsResume: $_adsResume, '
        'tutorialTapOutsideClose: $_tutorialTapOutsideClose, '
        'cheatEnabled: $_cheatEnabled, '
        'dictionaryMinLevel: $_dictionaryMinLevel, '
        'dictionaryEnabled: $_dictionaryEnabled',
      );
    } catch (e) {
      debugPrint('[RemoteConfig] Error fetching remote configs: $e');
    }
  }

  /// Listen to real-time remote config fetched event
  static void listenToUpdates() {
    FGSDK.onRemoteConfigFetched.listen((_) {
      debugPrint('[RemoteConfig] onRemoteConfigFetched triggered, refreshing...');
      fetchConfigs();
    });
  }

  @visibleForTesting
  static void setMockValues({
    int? interLevelX,
    int? adsInterval,
    bool? aoaFormat,
    bool? adsReplay,
    bool? adsResume,
    bool? tutorialTapOutsideClose,
    bool? cheatEnabled,
    int? dictionaryMinLevel,
    bool? dictionaryEnabled,
  }) {
    if (interLevelX != null) _interLevelX = interLevelX;
    if (adsInterval != null) _adsInterval = adsInterval;
    if (aoaFormat != null) _aoaFormat = aoaFormat;
    if (adsReplay != null) _adsReplay = adsReplay;
    if (adsResume != null) _adsResume = adsResume;
    if (tutorialTapOutsideClose != null) _tutorialTapOutsideClose = tutorialTapOutsideClose;
    if (cheatEnabled != null) _cheatEnabled = cheatEnabled;
    if (dictionaryMinLevel != null) _dictionaryMinLevel = dictionaryMinLevel;
    if (dictionaryEnabled != null) _dictionaryEnabled = dictionaryEnabled;
  }

  static Future<bool> _fetchBool(String key, bool defaultValue) async {
    try {
      final s = (await FGSDK.getRemoteConfigString(key, '')).toLowerCase().trim();
      if (s.isEmpty) return defaultValue;
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return await FGSDK.getRemoteConfigBool(key, defaultValue);
    } catch (_) {
      return defaultValue;
    }
  }

  static Future<int> _fetchInt(String key, int defaultValue) async {
    try {
      final s = (await FGSDK.getRemoteConfigString(key, '')).trim();
      if (s.isEmpty) return defaultValue;
      final parsed = int.tryParse(s);
      if (parsed != null) return parsed;
      return await FGSDK.getRemoteConfigInt(key, defaultValue);
    } catch (_) {
      return defaultValue;
    }
  }
}
