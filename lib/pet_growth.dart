import 'economy_models.dart';

/// Правила роста питомца по итогам одного периода (после вечернего закрытия
/// Базы). Рост считается по трём факторам, каждый даёт +1 очко (максимум
/// +3 за период). Очки роста (`growthPoints`) и стадия (`growthStage`)
/// никогда не уменьшаются — как и ремонт корабля, это долгосрочный
/// прогресс, который не сбрасывается ни утром, ни на ПХД.
///
/// Три фактора периода:
/// 1. mandatoryPaid — оплачены все обязательные НАДО (в текущей логике
///    `_settleEveningAndClose` это фактически всегда true, потому что
///    период не закрывается, пока не хватает Дар на обязательное — но
///    фактор оставлен отдельным параметром на случай, если правила оплаты
///    усложнятся).
/// 2. planMatchedFact — вечерний выбор необязательных позиций (ХОЧУ/доп.
///    НАДО) совпал с тем, что было запланировано утром: игрок не пропустил
///    ничего из своего Плана и не отступил от него.
/// 3. savedThisPeriod — в этот период было отложено хотя бы 1 Дар в
///    накопления на цель.
///
/// Короткие показатели (`care`/`mood`/`energy`) — отдельная, «быстрая»
/// обратная связь, которая может расти и падать (диапазон -3..3), в отличие
/// от долгосрочных `growthPoints`/`growthStage`.
class PetGrowthCatalog {
  PetGrowthCatalog._();

  /// Сколько очков роста нужно набрать, чтобы достичь стадии с этим
  /// индексом. Индекс 0 — стартовая стадия (0 очков, использует уже
  /// существующий базовый арт питомца, новый арт не нужен).
  ///
  /// Всего 3 стадии (0, 1, 2) — под реальный набор арта из assets11.zip:
  /// у Скорохода и Цветика уже готово ровно по 2 подходящих под прогрессию
  /// изображения (кроме домашнего), у Квака — 1 готовое + 1 дорисовывает
  /// Архитектор (см. `PetTypeInfo.stageAssetPath` в game_state.dart).
  static const List<int> stageThresholds = <int>[0, 3, 8];

  static int get maxStage => stageThresholds.length - 1;

  static int stageForPoints(int points) {
    var stage = 0;
    for (var i = 0; i < stageThresholds.length; i++) {
      if (points >= stageThresholds[i]) {
        stage = i;
      }
    }
    return stage;
  }

  static String stageTitle(int stage) {
    switch (stage.clamp(0, maxStage)) {
      case 0:
        return 'Стадия 0 · Дома';
      case 1:
        return 'Стадия 1 · Втянулся';
      case 2:
      default:
        return 'Стадия 2 · Мастер';
    }
  }

  /// Сколько очков роста не хватает до следующей стадии. `null`, если
  /// питомец уже на максимальной стадии.
  static int? pointsToNextStage(int points) {
    final stage = stageForPoints(points);
    if (stage >= maxStage) return null;
    return stageThresholds[stage + 1] - points;
  }
}

class PetGrowthUpdate {
  final PetState previous;
  final PetState next;
  final bool mandatoryPaid;
  final bool planMatchedFact;
  final bool savedThisPeriod;
  final int pointsEarned;

  const PetGrowthUpdate({
    required this.previous,
    required this.next,
    required this.mandatoryPaid,
    required this.planMatchedFact,
    required this.savedThisPeriod,
    required this.pointsEarned,
  });

  bool get stageChanged => next.growthStage != previous.growthStage;

  /// Короткое пояснение для карточки «Итоги дня» — какие факторы
  /// сработали, что случилось с показателями и стадией.
  String get explanation {
    final lines = <String>[];
    lines.add(mandatoryPaid ? '✔ Все обязательные НАДО оплачены' : '✘ Не все обязательные НАДО оплачены');
    lines.add(planMatchedFact ? '✔ Вечерний выбор совпал с утренним Планом' : '✘ Вечерний выбор отличался от утреннего Плана');
    lines.add(savedThisPeriod ? '✔ В накопления отложено хотя бы немного Дар' : '✘ В этот период в накопления ничего не отложено');

    final buffer = StringBuffer(lines.join('\n'));
    buffer.write('\n\nОчки роста: +$pointsEarned (всего ${next.growthPoints}).');
    if (stageChanged) {
      buffer.write('\nПитомец перешёл на новую стадию: ${PetGrowthCatalog.stageTitle(next.growthStage)}!');
    }
    return buffer.toString();
  }
}

class PetGrowthEngine {
  const PetGrowthEngine();

  static int _clampShortTerm(int value) => value.clamp(-3, 3).toInt();

  PetGrowthUpdate applyPeriod(
    PetState current, {
    required bool mandatoryPaid,
    required bool planMatchedFact,
    required bool savedThisPeriod,
  }) {
    final pointsEarned = (mandatoryPaid ? 1 : 0) +
        (planMatchedFact ? 1 : 0) +
        (savedThisPeriod ? 1 : 0);

    final newPoints = current.growthPoints + pointsEarned;
    final newStage = PetGrowthCatalog.stageForPoints(newPoints).clamp(
      current.growthStage,
      PetGrowthCatalog.maxStage,
    );

    final newCare = _clampShortTerm(current.care + (mandatoryPaid ? 1 : -1));
    final newMood = _clampShortTerm(current.mood + (savedThisPeriod ? 1 : -1));
    final newEnergy = _clampShortTerm(current.energy + (planMatchedFact ? 1 : -1));

    final next = current.copyWith(
      care: newCare,
      mood: newMood,
      energy: newEnergy,
      growthPoints: newPoints,
      growthStage: newStage,
    );

    return PetGrowthUpdate(
      previous: current,
      next: next,
      mandatoryPaid: mandatoryPaid,
      planMatchedFact: planMatchedFact,
      savedThisPeriod: savedThisPeriod,
      pointsEarned: pointsEarned,
    );
  }
}
