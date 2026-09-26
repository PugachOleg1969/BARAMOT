/// Учебный контент игры: финансовые задания и цели накоплений.
///
/// Контент отделён от интерфейса и логики (ТЗ 3.2, 2.5.14): чтобы добавить
/// новое задание или цель, достаточно дописать запись в [FinanceContent.tasks]
/// или [FinanceContent.goals] — экраны и экономика подхватят её сами.
library;

enum FinanceTopic {
  budget,
  savings,
  purchases,
}

extension FinanceTopicInfo on FinanceTopic {
  String get title {
    switch (this) {
      case FinanceTopic.budget:
        return 'Планирование бюджета';
      case FinanceTopic.savings:
        return 'Формирование сбережений';
      case FinanceTopic.purchases:
        return 'Платежи и покупки';
    }
  }

  String get emoji {
    switch (this) {
      case FinanceTopic.budget:
        return '📋';
      case FinanceTopic.savings:
        return '🐷';
      case FinanceTopic.purchases:
        return '🛒';
    }
  }
}

class FinanceTaskOption {
  final String id;
  final String text;

  /// Лучший вариант. Остальные варианты — не «ошибка», а повод разобраться:
  /// объяснение показывается всегда.
  final bool best;
  final String feedback;

  const FinanceTaskOption({
    required this.id,
    required this.text,
    required this.best,
    required this.feedback,
  });
}

class FinanceTask {
  final String id;
  final FinanceTopic topic;
  final String title;
  final String situation;
  final List<FinanceTaskOption> options;

  const FinanceTask({
    required this.id,
    required this.topic,
    required this.title,
    required this.situation,
    required this.options,
  });

  /// Ключ награды в экономике: награда за задание начисляется один раз
  /// (EconomyEngine.addIncome отклоняет повторный rewardKey).
  String get rewardKey => 'task:$id';
}

class SavingsGoal {
  final String id;
  final String title;
  final String emoji;
  final int target;

  const SavingsGoal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.target,
  });
}

class FinanceContent {
  const FinanceContent._();

  /// Награда за первое прохождение задания.
  static const int rewardBest = 3;
  static const int rewardOther = 1;

  static const List<FinanceTask> tasks = <FinanceTask>[
    // --- Планирование бюджета ------------------------------------------
    FinanceTask(
      id: 'budget_need_first',
      topic: FinanceTopic.budget,
      title: 'Сначала НАДО',
      situation: 'У Командора 10 Дар. Питомцу нужны вода (1 Дар) и корм (2 Дар). '
          'А в лавке блестит новая игрушка за 8 Дар. Что сделать?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: 'Купить воду и корм, остаток оставить',
          best: true,
          feedback: 'Верно! Сначала обязательное: питомец сыт и напоен, '
              'а 7 Дар остаются на другие решения.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: 'Купить игрушку',
          best: false,
          feedback: 'Игрушка радует, но после неё останется 2 Дар — на воду и корм '
              'не хватит. Обязательные расходы всегда идут первыми.',
        ),
        FinanceTaskOption(
          id: 'c',
          text: 'Ничего не покупать',
          best: false,
          feedback: 'Беречь Дар полезно, но питомец останется голодным. '
              'Обязательное пропускать нельзя.',
        ),
      ],
    ),
    FinanceTask(
      id: 'budget_day_plan',
      topic: FinanceTopic.budget,
      title: 'План на день',
      situation: 'На день есть 12 Дар. Какой План подходит?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: 'НАДО 5 · ХОЧУ 4 · копим 3',
          best: true,
          feedback: 'Верно! 5 + 4 + 3 = 12 — ровно столько, сколько есть. '
              'И обязательное учтено, и на цель отложено.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: 'НАДО 5 · ХОЧУ 9 · копим 3',
          best: false,
          feedback: '5 + 9 + 3 = 17 — это больше, чем 12. '
              'План не может быть больше бюджета.',
        ),
        FinanceTaskOption(
          id: 'c',
          text: 'НАДО 0 · ХОЧУ 12 · копим 0',
          best: false,
          feedback: 'Сумма сходится, но обязательное забыто — питомец останется '
              'без еды, а на цель ничего не отложено.',
        ),
      ],
    ),

    // --- Формирование сбережений ---------------------------------------
    FinanceTask(
      id: 'savings_piggy',
      topic: FinanceTopic.savings,
      title: 'Копилка',
      situation: 'Цель стоит 12 Дар. Командор откладывает по 3 Дар в день. '
          'Сколько дней нужно копить?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: '4 дня',
          best: true,
          feedback: 'Верно! 3 × 4 = 12. Небольшие регулярные суммы '
              'быстро складываются в цель.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: '3 дня',
          best: false,
          feedback: 'За 3 дня накопится 3 × 3 = 9 Дар — до цели не хватит 3 Дар. '
              'Нужен ещё один день.',
        ),
        FinanceTaskOption(
          id: 'c',
          text: '12 дней',
          best: false,
          feedback: '12 дней понадобилось бы, если откладывать по 1 Дар. '
              'По 3 Дар в день выходит 12 : 3 = 4 дня.',
        ),
      ],
    ),
    FinanceTask(
      id: 'savings_keep',
      topic: FinanceTopic.savings,
      title: 'Снять из копилки?',
      situation: 'В копилке 9 Дар, до цели осталось 3 дня. '
          'На ярмарке продают воздушный шарик за 6 Дар. Что сделать?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: 'Не трогать копилку',
          best: true,
          feedback: 'Верно! Цель совсем близко. Шарик можно купить потом '
              'из обычного бюджета — в ХОЧУ.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: 'Снять 6 Дар на шарик',
          best: false,
          feedback: 'В копилке останется 3 Дар, и до цели придётся копить ещё '
              '2 дня. Снимать можно, но цель отодвинется.',
        ),
      ],
    ),

    // --- Платежи и покупки ---------------------------------------------
    FinanceTask(
      id: 'purchase_compare',
      topic: FinanceTopic.purchases,
      title: 'Сравни цены',
      situation: 'Одинаковые фильтры для шлема продают в двух лавках: '
          'у механика — 5 Дар, в лавке редкостей — 8 Дар. Где купить?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: 'У механика за 5 Дар',
          best: true,
          feedback: 'Верно! Товар тот же, а 3 Дар остаются у Командора. '
              'Перед покупкой полезно сравнить цены.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: 'В лавке редкостей — там вывеска красивее',
          best: false,
          feedback: 'Фильтры одинаковые, а платить придётся на 3 Дар больше. '
              'Красивая вывеска не делает товар лучше.',
        ),
      ],
    ),
    FinanceTask(
      id: 'purchase_not_enough',
      topic: FinanceTopic.purchases,
      title: 'Не хватает',
      situation: 'Напиток стоит 2 Дар, а в кошельке только 1 Дар. Что сделать?',
      options: [
        FinanceTaskOption(
          id: 'a',
          text: 'Отложить покупку и заработать на BAZAR',
          best: true,
          feedback: 'Верно! Когда не хватает, можно сначала заработать, '
              'а купить позже — вечером на Совещании.',
        ),
        FinanceTaskOption(
          id: 'b',
          text: 'Взять в долг у Барта',
          best: false,
          feedback: 'Долг придётся вернуть из следующего дохода — и тогда Дар '
              'будет меньше. Лучше сначала заработать.',
        ),
      ],
    ),
  ];

  static const List<SavingsGoal> goals = <SavingsGoal>[
    SavingsGoal(id: 'pet_gift', title: 'Подарок Питомцу', emoji: '🎁', target: 8),
    SavingsGoal(id: 'fuel_sensor', title: 'Датчик топлива', emoji: '⛽', target: 12),
    SavingsGoal(id: 'telescope', title: 'Телескоп для Базы', emoji: '🔭', target: 20),
  ];

  static FinanceTask? taskById(String id) {
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  static SavingsGoal? goalById(String id) {
    for (final goal in goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }
}
