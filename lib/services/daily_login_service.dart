import 'package:flutter/foundation.dart';
import '../models/daily_login_reward.dart';
import 'analytics_service.dart';
import 'game_storage.dart';

/// Service managing the 7-Day Daily Login streak, reward distribution, and x2 multipliers.
class DailyLoginService {
  DailyLoginService._();

  static const String _keyLastClaimDate = 'daily_login_last_claim_date';
  static const String _keyCurrentStreakDay = 'daily_login_current_streak_day';

  static final ValueNotifier<bool> canClaimNotifier = ValueNotifier<bool>(true);

  /// Helper to get formatted date string: YYYY-MM-DD
  static String _formatDate(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Whether today's reward can be claimed
  static bool canClaimToday([DateTime? now]) {
    final prefs = GameStorage.prefs;
    final lastClaimDateStr = prefs.getString(_keyLastClaimDate);
    if (lastClaimDateStr == null || lastClaimDateStr.isEmpty) {
      return true;
    }

    final todayStr = _formatDate(now ?? DateTime.now());
    return lastClaimDateStr != todayStr;
  }

  /// Gets the current day of the streak (1 through 7)
  static int getCurrentStreakDay([DateTime? now]) {
    final prefs = GameStorage.prefs;
    final lastClaimDateStr = prefs.getString(_keyLastClaimDate);
    final savedStreakDay = prefs.getInt(_keyCurrentStreakDay) ?? 1;

    if (lastClaimDateStr == null || lastClaimDateStr.isEmpty) {
      return 1;
    }

    final currentDate = now ?? DateTime.now();
    final todayStr = _formatDate(currentDate);

    // If already claimed today, current active day is savedStreakDay
    if (lastClaimDateStr == todayStr) {
      return savedStreakDay.clamp(1, 7);
    }

    try {
      final lastDateParts = lastClaimDateStr.split('-').map(int.parse).toList();
      final lastDate = DateTime(lastDateParts[0], lastDateParts[1], lastDateParts[2]);
      final todayDate = DateTime(currentDate.year, currentDate.month, currentDate.day);

      final diffDays = todayDate.difference(lastDate).inDays;

      if (diffDays == 1) {
        // Logged in on consecutive day -> advance streak (loops back to 1 after day 7)
        if (savedStreakDay >= 7) {
          return 1;
        } else {
          return (savedStreakDay + 1).clamp(1, 7);
        }
      } else if (diffDays > 1) {
        // Missed a day -> reset to Day 1
        return 1;
      }
    } catch (_) {}

    return 1;
  }

  /// Checks if a specific day is claimed in the current cycle
  static bool isDayClaimed(int day, [DateTime? now]) {
    final currentDay = getCurrentStreakDay(now);
    final claimedToday = !canClaimToday(now);

    if (claimedToday) {
      return day <= currentDay;
    } else {
      return day < currentDay;
    }
  }

  /// Returns the reward configuration for a day
  static DailyLoginReward getRewardForDay(int day) {
    final index = (day - 1).clamp(0, kDailyLoginRewards.length - 1);
    return kDailyLoginRewards[index];
  }

  /// Claim today's daily login reward.
  /// If [isDouble] is true, rewards are doubled via Rewarded Video Ads!
  static Future<DailyLoginReward> claimToday({
    required bool isDouble,
    int? currentLevel,
    DateTime? now,
  }) async {
    final targetDay = getCurrentStreakDay(now);
    final baseReward = getRewardForDay(targetDay);

    final multiplier = isDouble ? 2 : 1;
    final grantedCoins = baseReward.coins * multiplier;
    final grantedHints = baseReward.hints * multiplier;
    final grantedRockets = baseReward.rockets * multiplier;

    // Grant items to storage
    if (grantedCoins > 0) {
      await GameStorage.addCoins(grantedCoins);
    }
    if (grantedHints > 0) {
      await GameStorage.addHints(grantedHints);
    }
    if (grantedRockets > 0) {
      await GameStorage.addRockets(grantedRockets);
    }

    // Update streak state
    final prefs = GameStorage.prefs;
    final currentDate = now ?? DateTime.now();
    await prefs.setString(_keyLastClaimDate, _formatDate(currentDate));
    await prefs.setInt(_keyCurrentStreakDay, targetDay);

    canClaimNotifier.value = false;

    // Log analytics
    final reason = isDouble ? 'daily_login_x2' : 'daily_login';
    final lvl = currentLevel ?? 1;

    if (grantedCoins > 0) {
      AnalyticsService.logEarnResource(
        level: lvl,
        type: 'currency',
        name: 'gold',
        amount: grantedCoins.toDouble(),
        reason: reason,
        balance: GameStorage.getCoins().toDouble(),
      );
    }
    if (grantedHints > 0) {
      AnalyticsService.logEarnResource(
        level: lvl,
        type: 'booster',
        name: 'hint',
        amount: grantedHints.toDouble(),
        reason: reason,
        balance: GameStorage.getHints().toDouble(),
      );
    }
    if (grantedRockets > 0) {
      AnalyticsService.logEarnResource(
        level: lvl,
        type: 'booster',
        name: 'rocket',
        amount: grantedRockets.toDouble(),
        reason: reason,
        balance: GameStorage.getRockets().toDouble(),
      );
    }

    debugPrint(
      '[DailyLoginService] Claimed Day $targetDay (x$multiplier): '
      '+$grantedCoins coins, +$grantedHints hints, +$grantedRockets rockets.',
    );

    return DailyLoginReward(
      day: targetDay,
      coins: grantedCoins,
      hints: grantedHints,
      rockets: grantedRockets,
      title: baseReward.title,
    );
  }

  /// Reset streak data for developer/QA testing
  static Future<void> resetStreakForTest() async {
    final prefs = GameStorage.prefs;
    await prefs.remove(_keyLastClaimDate);
    await prefs.remove(_keyCurrentStreakDay);
    canClaimNotifier.value = true;
    debugPrint('[DailyLoginService] Streak reset for testing.');
  }

  /// Refresh canClaim state
  static void refreshStatus() {
    canClaimNotifier.value = canClaimToday();
  }
}
