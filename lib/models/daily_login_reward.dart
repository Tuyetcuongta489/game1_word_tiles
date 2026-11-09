/// Model representing a daily login reward for a specific day in the 7-day streak.
class DailyLoginReward {
  final int day;
  final int coins;
  final int hints;
  final int rockets;
  final String title;

  const DailyLoginReward({
    required this.day,
    required this.coins,
    this.hints = 0,
    this.rockets = 0,
    required this.title,
  });

  bool get isGrandPrize => day == 7;
}

/// The standard 7-day reward schedule with highly attractive coin and booster progression
const List<DailyLoginReward> kDailyLoginRewards = [
  DailyLoginReward(day: 1, coins: 150, title: 'Day 1'),
  DailyLoginReward(day: 2, coins: 150, hints: 1, title: 'Day 2'),
  DailyLoginReward(day: 3, coins: 200, rockets: 1, title: 'Day 3'),
  DailyLoginReward(day: 4, coins: 250, hints: 1, title: 'Day 4'),
  DailyLoginReward(day: 5, coins: 300, rockets: 1, title: 'Day 5'),
  DailyLoginReward(day: 6, coins: 400, hints: 1, rockets: 1, title: 'Day 6'),
  DailyLoginReward(day: 7, coins: 800, hints: 3, rockets: 3, title: 'Day 7'),
];
