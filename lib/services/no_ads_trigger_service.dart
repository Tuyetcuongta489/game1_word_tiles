import 'package:flutter/foundation.dart';
import 'game_storage.dart';

/// Manages trigger rules and session benchmarks for the No Ads popup.
///
/// Rules:
/// - Case 1: When launching into Home, shows once in user lifetime if:
///   1. Current level >= 3 (levels 1-2 go straight into gameplay).
///   2. !isNoAdsPurchased.
///   3. !hasEverSeenNoAdsPopup (user has never seen the popup anywhere, even via icon).
///   4. hasWatchedInterEndgame (user has completed at least 1 Next level Interstitial in any previous session).
///   After closing, Starter Pack popup (if any) may appear next.
///
/// - Case 2: Periodic automatic appearance after winning N levels in current session:
///   N = 10 for Session 1, N = 5 for Session >= 2.
///   Timing: On Win screen, user taps Next (or Claim x2) to advance directly to next level.
///   Loses, replays, and revives do NOT count. Only won levels count.
///   Benchmark is in-memory only (kill app resets to 0).
///   Case 1 and Case 3 do not reset the benchmark.
///
/// - Case 3: Player clicks No Ads icon at Home or Ingame (unlimited).
///   Icon is hidden once No Ads is purchased.
class NoAdsTriggerService {
  NoAdsTriggerService._();

  // In-memory counter of won levels since benchmark in current session
  static int _wonLevelsSinceBenchmark = 0;

  /// Required wins threshold N: 10 in session 1, 5 in session >= 2
  static int get requiredWinsThreshold {
    return GameStorage.getSessionCount() <= 1 ? 10 : 5;
  }

  /// Current won levels count since benchmark (for inspection or test)
  static int get wonLevelsSinceBenchmark => _wonLevelsSinceBenchmark;

  /// Called strictly upon level victory!
  static void onLevelWon() {
    _wonLevelsSinceBenchmark++;
    debugPrint(
      '[NoAdsTriggerService] onLevelWon: count=$_wonLevelsSinceBenchmark, '
      'threshold=$requiredWinsThreshold (session=${GameStorage.getSessionCount()})',
    );
  }

  /// Evaluates whether Case 1 (Startup at Home) conditions are satisfied:
  /// 1. Level >= 3
  /// 2. !isNoAdsPurchased
  /// 3. !hasEverSeenNoAdsPopup
  /// 4. hasWatchedInterEndgame
  static bool shouldShowCase1(int currentLevelNumber) {
    if (currentLevelNumber < 3) {
      debugPrint('[NoAdsTriggerService] Case 1 bypassed: level $currentLevelNumber < 3');
      return false;
    }
    if (GameStorage.isNoAdsPurchased()) {
      debugPrint('[NoAdsTriggerService] Case 1 bypassed: No Ads already purchased');
      return false;
    }
    if (GameStorage.hasEverSeenNoAdsPopup()) {
      debugPrint('[NoAdsTriggerService] Case 1 bypassed: user has already seen popup before');
      return false;
    }
    if (!GameStorage.hasWatchedInterEndgame()) {
      debugPrint('[NoAdsTriggerService] Case 1 bypassed: user has not watched any endgame inter ad');
      return false;
    }
    debugPrint('[NoAdsTriggerService] Case 1 conditions met -> showing startup No Ads popup');
    return true;
  }

  /// Evaluates whether Case 2 (Periodic Win Next) conditions are satisfied:
  /// 1. !isNoAdsPurchased
  /// 2. wonLevelsSinceBenchmark >= requiredWinsThreshold
  static bool shouldShowCase2() {
    if (GameStorage.isNoAdsPurchased()) {
      return false;
    }
    final eligible = _wonLevelsSinceBenchmark >= requiredWinsThreshold;
    debugPrint(
      '[NoAdsTriggerService] shouldShowCase2: won=$_wonLevelsSinceBenchmark, '
      'threshold=$requiredWinsThreshold -> eligible=$eligible',
    );
    return eligible;
  }

  /// Resets benchmark counter when Case 2 popup is triggered
  static void onCase2Triggered() {
    debugPrint('[NoAdsTriggerService] Case 2 triggered -> resetting won levels counter.');
    _wonLevelsSinceBenchmark = 0;
  }

  @visibleForTesting
  static void resetForTest({int wonCount = 0}) {
    _wonLevelsSinceBenchmark = wonCount;
  }
}
