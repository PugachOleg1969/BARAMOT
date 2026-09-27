/// «Школа командиров» — курсы повышения квалификации Командора.
///
/// Финансовые задания (ТЗ 2.5.8) собраны в отдельной Школе на Базе, чтобы
/// учёба не смешивалась с основным сюжетом (утренний обход → Совещание в
/// Палатке → BAZAR → вечер). За пройденные задания Командор получает
/// ранги. Ранг только растёт: он не понижается и не является оценкой
/// ребёнка (ТЗ 2.5.12, 3.5). Награда Дар за задания сохраняется (ТЗ 2.5.4).
library;

/// Один ранг Школы: сколько заданий нужно пройти, чтобы его получить.
class CommanderRank {
  final int level;
  final String title;
  final String emoji;
  final int tasksRequired;

  const CommanderRank({
    required this.level,
    required this.title,
    required this.emoji,
    required this.tasksRequired,
  });
}

class CommanderSchool {
  const CommanderSchool._();

  static const String title = 'Школа командиров';

  /// Ранги по возрастанию. Чтобы изменить пороги или названия, достаточно
  /// поправить этот список — экраны подхватят изменения сами.
  static const List<CommanderRank> ranks = <CommanderRank>[
    CommanderRank(level: 0, title: 'Слушатель курсов', emoji: '📘', tasksRequired: 0),
    CommanderRank(level: 1, title: 'Командир 1-го ранга', emoji: '🎖️', tasksRequired: 2),
    CommanderRank(level: 2, title: 'Командир 2-го ранга', emoji: '🏅', tasksRequired: 4),
    CommanderRank(level: 3, title: 'Профи', emoji: '🏆', tasksRequired: 6),
  ];

  /// Текущий ранг по числу пройденных заданий.
  static CommanderRank rankFor(int completedTasks) {
    var result = ranks.first;
    for (final rank in ranks) {
      if (completedTasks >= rank.tasksRequired) result = rank;
    }
    return result;
  }

  /// Следующий ранг или `null`, если достигнут высший.
  static CommanderRank? nextRank(int completedTasks) {
    final current = rankFor(completedTasks);
    for (final rank in ranks) {
      if (rank.level > current.level) return rank;
    }
    return null;
  }

  /// Сколько заданий осталось до следующего ранга (0 — если ранг высший).
  static int tasksToNext(int completedTasks) {
    final next = nextRank(completedTasks);
    if (next == null) return 0;
    final left = next.tasksRequired - completedTasks;
    return left < 0 ? 0 : left;
  }

  /// Новый ранг, если он получен при переходе от [before] к [after]
  /// пройденных заданий; иначе `null`.
  static CommanderRank? promotion(int before, int after) {
    final was = rankFor(before);
    final now = rankFor(after);
    return now.level > was.level ? now : null;
  }

  /// Короткая строка для карточек: «🎖️ Командир 1-го ранга · до следующего: 2».
  static String statusLine(int completedTasks) {
    final rank = rankFor(completedTasks);
    final left = tasksToNext(completedTasks);
    if (left == 0) return '${rank.emoji} ${rank.title} · высший ранг';
    final word = left == 1 ? 'задание' : 'задания';
    return '${rank.emoji} ${rank.title} · до следующего ранга $left $word';
  }
}
