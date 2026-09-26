import 'economy_models.dart';

class EconomyTuning {
  const EconomyTuning._();

  static const int mandatoryCostPerDependent = 3;
  static const int mandatoryCostPerPeriod = 6;
  static const int minimumPeriodIncome = 8;
  static const int normalPeriodIncome = 12;
  static const int maximumPeriodIncome = 18;
  static const int firstBazarOrderReward = 8;
  static const List<int> normalIncomeByPeriod = <int>[8, 10, 12, 14, 16];
}

class PlanningCatalog {
  const PlanningCatalog._();

  static const List<PlanningItemDefinition> items = <PlanningItemDefinition>[
    PlanningItemDefinition(
      id: 'barry_need_artesian_water',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Вода артезианская, 1 л',
      cost: 1,
      mandatory: true,
    ),
    PlanningItemDefinition(
      id: 'barry_need_oatmeal',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Каша овсяная из генератора',
      cost: 0,
      mandatory: true,
    ),
    PlanningItemDefinition(
      id: 'barry_need_cosmos_meals',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Комплект «Космос» — обед и ужин',
      cost: 2,
      mandatory: true,
    ),
    PlanningItemDefinition(
      id: 'barry_need_ready_meal',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Готовый обед',
      cost: 1,
    ),
    PlanningItemDefinition(
      id: 'barry_need_drink',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Напиток',
      cost: 1,
    ),
    PlanningItemDefinition(
      id: 'barry_need_hygiene',
      ownerId: PlanOwner.barry,
      category: PlanCategory.need,
      title: 'Предметы гигиены',
      cost: 2,
    ),
    PlanningItemDefinition(
      id: 'barry_want_pizza',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Пицца',
      cost: 3,
    ),
    PlanningItemDefinition(
      id: 'barry_want_chocolate_cake',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Торт шоколадный',
      cost: 4,
    ),
    PlanningItemDefinition(
      id: 'barry_want_duck_apples',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Утка с яблоками',
      cost: 5,
    ),
    PlanningItemDefinition(
      id: 'barry_want_engineer_boots',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Ботинки инженерные',
      cost: 6,
    ),
    PlanningItemDefinition(
      id: 'barry_want_spacesuit',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Комбинезон космонавта',
      cost: 8,
    ),
    PlanningItemDefinition(
      id: 'barry_want_tool_set',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Набор инструментов',
      cost: 10,
    ),
    PlanningItemDefinition(
      id: 'barry_want_engineer_kit',
      ownerId: PlanOwner.barry,
      category: PlanCategory.want,
      title: 'Комплект инженера',
      cost: 12,
    ),
    PlanningItemDefinition(
      id: 'barry_planned_helmet_filters',
      ownerId: PlanOwner.barry,
      category: PlanCategory.planned,
      title: 'Шлем от скафандра с фильтрами',
      cost: 18,
    ),

    // Общая позиция для всех видов Питомца (petTypeId не задан — значит
    // appliesToPet() пропускает её при любом выбранном Питомце). Позволяет
    // Командору честно закрыть сегодняшний выбор, не добавляя в План
    // платную позицию, если сегодня Питомцу правда ничего не нужно.
    PlanningItemDefinition(
      id: 'pet_want_nothing',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Ничего не надо',
      cost: 0,
    ),

    PlanningItemDefinition(
      id: 'pet_kwak_need_water',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Вода',
      cost: 1,
      mandatory: true,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_need_algae',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Водоросли',
      cost: 1,
      mandatory: true,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_need_care',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Гигиена и уход',
      cost: 1,
      mandatory: true,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_want_bubble_bath',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Ванна пузырьковая',
      cost: 2,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_want_umbrella',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Зонтик',
      cost: 4,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_want_costume',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Новый костюм',
      cost: 6,
      petTypeId: 'kwak',
    ),
    PlanningItemDefinition(
      id: 'pet_kwak_planned_rolls_royce',
      ownerId: PlanOwner.pet,
      category: PlanCategory.planned,
      title: 'Роллс-Ройс',
      cost: 60,
      petTypeId: 'kwak',
    ),

    PlanningItemDefinition(
      id: 'pet_skorohod_need_leaves',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Листья овощные',
      cost: 1,
      mandatory: true,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_need_water',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Вода для скороходов',
      cost: 1,
      mandatory: true,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_need_care',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Гигиена и уход',
      cost: 1,
      mandatory: true,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_want_energy_chocolate',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Шоколад «Энергия»',
      cost: 2,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_want_books',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Новые книги',
      cost: 4,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_want_led_sneakers',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Кроссовки светодиодные',
      cost: 6,
      petTypeId: 'skorohod',
    ),
    PlanningItemDefinition(
      id: 'pet_skorohod_planned_star_yacht',
      ownerId: PlanOwner.pet,
      category: PlanCategory.planned,
      title: 'Межзвёздная яхта',
      cost: 90,
      petTypeId: 'skorohod',
    ),

    PlanningItemDefinition(
      id: 'pet_tsvetik_need_soil',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Земля для площадки',
      cost: 1,
      mandatory: true,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_need_insect_protection',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Защита от насекомых',
      cost: 1,
      mandatory: true,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_need_water',
      ownerId: PlanOwner.pet,
      category: PlanCategory.need,
      title: 'Вода питьевая',
      cost: 1,
      mandatory: true,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_want_concert',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Участие в концерте',
      cost: 4,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_want_violin',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Скрипка',
      cost: 8,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_want_house',
      ownerId: PlanOwner.pet,
      category: PlanCategory.want,
      title: 'Новый домик',
      cost: 12,
      petTypeId: 'tsvetik',
    ),
    PlanningItemDefinition(
      id: 'pet_tsvetik_planned_flower_plantation',
      ownerId: PlanOwner.pet,
      category: PlanCategory.planned,
      title: 'Плантация цветов',
      cost: 80,
      petTypeId: 'tsvetik',
    ),

    PlanningItemDefinition(
      id: 'team_need_fuel_sensor',
      ownerId: PlanOwner.team,
      category: PlanCategory.need,
      title: 'Датчик топливный',
      cost: 12,
    ),
    PlanningItemDefinition(
      id: 'team_need_transformer',
      ownerId: PlanOwner.team,
      category: PlanCategory.need,
      title: 'Трансформатор',
      cost: 18,
    ),
    PlanningItemDefinition(
      id: 'team_need_welding_machine',
      ownerId: PlanOwner.team,
      category: PlanCategory.need,
      title: 'Сварочный аппарат',
      cost: 24,
    ),
    PlanningItemDefinition(
      id: 'team_need_protopositron',
      ownerId: PlanOwner.team,
      category: PlanCategory.need,
      title: 'Протопозитрон',
      cost: 30,
    ),
    PlanningItemDefinition(
      id: 'team_planned_star_dust',
      ownerId: PlanOwner.team,
      category: PlanCategory.planned,
      title: 'Светящаяся звёздная пыль',
      cost: 30,
    ),
    PlanningItemDefinition(
      id: 'team_planned_atomic_direction_finder',
      ownerId: PlanOwner.team,
      category: PlanCategory.planned,
      title: 'Атомный пеленгатор',
      cost: 40,
    ),
    PlanningItemDefinition(
      id: 'team_planned_veritation_singulator',
      ownerId: PlanOwner.team,
      category: PlanCategory.planned,
      title: 'Веритационный синглутатор',
      cost: 60,
    ),
    PlanningItemDefinition(
      id: 'team_planned_new_ship',
      ownerId: PlanOwner.team,
      category: PlanCategory.planned,
      title: 'Новый корабль',
      cost: 120,
    ),
  ];

  static List<PlanningItemDefinition> forOwner(
    String ownerId, {
    String? petTypeId,
  }) {
    return items.where((item) {
      if (item.ownerId != ownerId) {
        return false;
      }
      if (ownerId != PlanOwner.pet) {
        return true;
      }
      if (petTypeId == null) {
        return false;
      }
      return item.appliesToPet(petTypeId);
    }).toList(growable: false);
  }

  static List<PlanningItemDefinition> mandatoryForOwner(
    String ownerId, {
    String? petTypeId,
  }) {
    return forOwner(ownerId, petTypeId: petTypeId)
        .where((item) => item.mandatory)
        .toList(growable: false);
  }

  static int mandatoryCostForOwner(
    String ownerId, {
    String? petTypeId,
  }) {
    return mandatoryForOwner(ownerId, petTypeId: petTypeId).fold<int>(
      0,
      (sum, item) => sum + item.cost,
    );
  }

  static PlanningItemDefinition? byId(String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  static List<PlanningItemDefinition> resolveSelected(
    Set<String> selectedIds, {
    required String petTypeId,
  }) {
    final result = <PlanningItemDefinition>[];

    for (final id in selectedIds) {
      final item = byId(id);
      if (item == null || item.mandatory) {
        continue;
      }
      if (item.ownerId == PlanOwner.pet && !item.appliesToPet(petTypeId)) {
        continue;
      }
      result.add(item);
    }

    result.sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  static List<PlanningItemDefinition> commanderPlanItems({
    required Set<String> selectedIds,
    required String petTypeId,
  }) {
    final result = <PlanningItemDefinition>[
      ...mandatoryForOwner(PlanOwner.barry),
      ...mandatoryForOwner(PlanOwner.pet, petTypeId: petTypeId),
      ...resolveSelected(selectedIds, petTypeId: petTypeId),
    ];

    result.sort((a, b) {
      final ownerCompare = a.ownerId.compareTo(b.ownerId);
      if (ownerCompare != 0) {
        return ownerCompare;
      }
      final categoryCompare = a.category.compareTo(b.category);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return a.id.compareTo(b.id);
    });

    return result;
  }

  static BudgetPlan buildBudgetPlan({
    required int periodId,
    required int startingWallet,
    required Set<String> selectedIds,
    required String petTypeId,
    required String selectedGoalId,
    int plannedSavings = 0,
    bool confirmed = false,
  }) {
    final items = commanderPlanItems(
      selectedIds: selectedIds,
      petTypeId: petTypeId,
    );

    return BudgetPlan(
      periodId: periodId,
      startingWallet: startingWallet,
      plannedNeed: sumCost(items, category: PlanCategory.need),
      plannedWant: sumCost(items, category: PlanCategory.want),
      plannedSavings: plannedSavings < 0 ? 0 : plannedSavings,
      plannedItems: items.map((item) => item.toPlannedItem()).toList(),
      selectedGoalId: selectedGoalId,
      confirmed: confirmed,
    );
  }

  static int sumCost(
    Iterable<PlanningItemDefinition> source, {
    String? category,
  }) {
    var total = 0;
    for (final item in source) {
      if (category != null && item.category != category) {
        continue;
      }
      total += item.cost;
    }
    return total;
  }
}