import 'dart:convert';

import 'economy_models.dart';
import 'pet_growth.dart';
import 'ship_repair_catalog.dart';
import 'ship_repair_models.dart';

enum PetType {
  skorohod,
  kwak,
  tsvetik,
}

extension PetTypeInfo on PetType {
  String get id => name;

  String get title {
    switch (this) {
      case PetType.skorohod:
        return 'Скороход';
      case PetType.kwak:
        return 'Квак';
      case PetType.tsvetik:
        return 'Цветик-Семицветик';
    }
  }

  String get emoji {
    switch (this) {
      case PetType.skorohod:
        return '🐌';
      case PetType.kwak:
        return '🐸';
      case PetType.tsvetik:
        return '🌈';
    }
  }

  String? get assetPath {
    switch (this) {
      case PetType.skorohod:
        return 'assets/pets/skorohod_home.png';
      case PetType.kwak:
        return 'assets/pets/kwak_star.png';
      case PetType.tsvetik:
        return 'assets/pets/tsvetik_home.png';
    }
  }

  /// Путь к арту питомца для конкретной стадии роста ([PetGrowthCatalog]).
  /// Для стадии 0 возвращает `null` — на ней используется уже существующий
  /// базовый арт ([assetPath]), новый файл не нужен.
  ///
  /// Для стадий 1 и 2 — конкретные файлы из уже готового набора ассетов
  /// (assets11.zip), подобранные по смыслу под прогрессию роста:
  /// - Скороход: спокойный спорт → тренировка на велотренажёре;
  /// - Цветик: садовник-думает → концерт во фраке;
  /// - Квак: базовый образ персонажа сейчас меняется (новый дизайн без
  ///   шляпы и мантии), поэтому стадии 1 и 2 временно возвращают `null`
  ///   (используется базовый [assetPath]) — старые `star_thinking.png` /
  ///   `star_sad.png` в старом стиле подставлять нельзя, будет виден разнобой
  ///   стилей. Как только появятся stage-арты Квака в НОВОМ стиле — вписать
  ///   их сюда по тому же образцу, что у Скорохода/Цветика.
  ///
  /// Если файла ещё нет на диске, `_CharacterArt` в main.dart сам откатится
  /// на [assetPath], а затем на эмодзи — приложение не упадёт.
  String? stageAssetPath(int stage) {
    final clamped = stage.clamp(0, PetGrowthCatalog.maxStage);
    if (clamped == 0) return null;
    switch (this) {
      case PetType.skorohod:
        return clamped == 1
            ? 'assets/pets/skorohod/active_calm.png'
            : 'assets/pets/skorohod/training_bike.png';
      case PetType.kwak:
        return null;
      case PetType.tsvetik:
        return clamped == 1
            ? 'assets/pets/tsvetik/garden_thinking.png'
            : 'assets/pets/tsvetik/concert.png';
    }
  }

  static PetType fromId(String? value) {
    return PetType.values.firstWhere(
      (pet) => pet.name == value,
      orElse: () => PetType.kwak,
    );
  }
}

enum BaseSessionPhase {
  prologue,
  closed,
  morning,
  day,
  evening,
  phd,
}

extension BaseSessionPhaseInfo on BaseSessionPhase {
  String get id => name;
}

BaseSessionPhase _baseSessionPhaseFromId(
  String? value, {
  required bool profileCreated,
}) {
  for (final phase in BaseSessionPhase.values) {
    if (phase.name == value) return phase;
  }
  return profileCreated ? BaseSessionPhase.morning : BaseSessionPhase.prologue;
}

class GameStateData {
  static const int schemaVersion = 8;

  bool introSeen;
  int onboardingStep;
  bool profileCreated;
  String playerName;
  PetType selectedPet;
  int petStyle;
  String petName;

  int walletDar;
  int savingsDar;
  int period;

  String activeGoalId;
  String activeGoalTitle;
  int activeGoalTarget;

  bool budgetPlanConfirmed;
  int planNeed;
  int planWant;
  int planSave;

  bool asteroidTrainingCompleted;

  BudgetPlan? currentPlan;
  List<Transaction> transactions;
  PetState petState;
  Set<String> processedRewardKeys;
  AstroBox astroBox;
  Set<String> processedQuestAttemptIds;
  Set<String> selectedPlanningItemIds;

  BaseSessionPhase sessionPhase;
  int totalWorkSessionsCompleted;
  bool morningPetVisited;
  bool morningBarryVisited;
  List<String> petRequestIdsBySession;
  List<String> barryRequestIdsBySession;
  Set<String> eveningSelectedItemIds;

  // Ремонт корабля: сколько штук по каждой позиции уже оплачено (не
  // сбрасывается ни утром, ни на ПХД — это долгосрочный проект) и какие
  // позиции сейчас в активном Плане (максимум ShipRepairCatalog.activeSlotLimit).
  Map<String, int> shipRepairUnitsPaid;
  Set<String> shipRepairActiveIds;

  // Альтернативный финал: корабль не починили, его увезла техничка
  // (эвакуация). После этого игра показывает экран «Конец игры».
  bool shipEvacuated;

  // Тестовый профиль для экспертной проверки (ТЗ 2.5.13): включает
  // отметку «ДЕМО» на Базе. Сбрасывается вместе с профилем.
  bool demoProfile;

  GameStateData({
    this.introSeen = false,
    this.onboardingStep = 0,
    this.profileCreated = false,
    this.playerName = '',
    this.selectedPet = PetType.kwak,
    this.petStyle = 0,
    this.petName = '',
    int walletDar = 0,
    int savingsDar = 0,
    int period = 1,
    this.activeGoalId = 'fuel_sensor',
    this.activeGoalTitle = 'Датчик топлива',
    int activeGoalTarget = 12,
    this.budgetPlanConfirmed = false,
    int planNeed = 0,
    int planWant = 0,
    int planSave = 0,
    this.asteroidTrainingCompleted = false,
    this.currentPlan,
    List<Transaction>? transactions,
    PetState? petState,
    Set<String>? processedRewardKeys,
    AstroBox? astroBox,
    Set<String>? processedQuestAttemptIds,
    Set<String>? selectedPlanningItemIds,
    BaseSessionPhase? sessionPhase,
    int totalWorkSessionsCompleted = 0,
    this.morningPetVisited = false,
    this.morningBarryVisited = false,
    List<String>? petRequestIdsBySession,
    List<String>? barryRequestIdsBySession,
    Set<String>? eveningSelectedItemIds,
    Map<String, int>? shipRepairUnitsPaid,
    Set<String>? shipRepairActiveIds,
    this.shipEvacuated = false,
    this.demoProfile = false,
  })  : sessionPhase = sessionPhase ??
            (profileCreated ? BaseSessionPhase.morning : BaseSessionPhase.prologue),
        totalWorkSessionsCompleted = _nonNegative(totalWorkSessionsCompleted),
        walletDar = _nonNegative(walletDar),
        savingsDar = _nonNegative(savingsDar),
        period = period <= 0 ? 1 : period,
        activeGoalTarget = _nonNegative(activeGoalTarget),
        planNeed = _nonNegative(planNeed),
        planWant = _nonNegative(planWant),
        planSave = _nonNegative(planSave),
        transactions = List<Transaction>.from(
          transactions ?? const <Transaction>[],
        ),
        petState = petState ?? PetState.neutral,
        processedRewardKeys = Set<String>.from(
          processedRewardKeys ?? const <String>{},
        ),
        astroBox = astroBox ?? AstroBox.empty,
        processedQuestAttemptIds = Set<String>.from(
          processedQuestAttemptIds ?? const <String>{},
        ),
        selectedPlanningItemIds = Set<String>.from(
          selectedPlanningItemIds ?? const <String>{},
        ),
        petRequestIdsBySession = _normalizeRequestHistory(petRequestIdsBySession),
        barryRequestIdsBySession = _normalizeRequestHistory(barryRequestIdsBySession),
        eveningSelectedItemIds = Set<String>.from(
          eveningSelectedItemIds ?? const <String>{},
        ),
        shipRepairUnitsPaid = Map<String, int>.from(
          shipRepairUnitsPaid ?? const <String, int>{},
        ),
        shipRepairActiveIds = Set<String>.from(
          shipRepairActiveIds ?? const <String>{},
        );

  int get goalRemaining =>
      (activeGoalTarget - savingsDar).clamp(0, activeGoalTarget).toInt();

  int get plannedTotal => planNeed + planWant + planSave;

  String? get currentPetRequestId => _requestForPeriod(petRequestIdsBySession, period);
  String? get currentBarryRequestId => _requestForPeriod(barryRequestIdsBySession, period);

  bool get morningRoundComplete =>
      morningPetVisited &&
      morningBarryVisited &&
      currentPetRequestId != null &&
      currentBarryRequestId != null;

  void setDailyRequest({
    required String ownerId,
    required String itemId,
  }) {
    final normalized = itemId.trim();
    if (normalized.isEmpty) return;

    final history = ownerId == PlanOwner.pet
        ? petRequestIdsBySession
        : ownerId == PlanOwner.barry
            ? barryRequestIdsBySession
            : null;
    if (history == null) return;

    final previous = _requestForPeriod(history, period);
    if (previous != null) selectedPlanningItemIds.remove(previous);

    while (history.length < period && history.length < 5) {
      history.add('');
    }
    if (period >= 1 && period <= 5) {
      history[period - 1] = normalized;
    }
    selectedPlanningItemIds.add(normalized);
  }

  void prepareMorningSession() {
    sessionPhase = BaseSessionPhase.morning;
    morningPetVisited = false;
    morningBarryVisited = false;
    selectedPlanningItemIds.clear();
    eveningSelectedItemIds.clear();
    currentPlan = null;
    budgetPlanConfirmed = false;
    planNeed = 0;
    planWant = 0;
    planSave = 0;
    asteroidTrainingCompleted = false;
  }

  void resetAfterPhd() {
    period = 1;
    petRequestIdsBySession.clear();
    barryRequestIdsBySession.clear();
    selectedPlanningItemIds.clear();
    eveningSelectedItemIds.clear();
    morningPetVisited = false;
    morningBarryVisited = false;
    currentPlan = null;
    budgetPlanConfirmed = false;
    planNeed = 0;
    planWant = 0;
    planSave = 0;
    asteroidTrainingCompleted = false;
    sessionPhase = BaseSessionPhase.closed;
  }

  bool selectPlanningItem(String itemId) {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return selectedPlanningItemIds.add(normalized);
  }

  bool unselectPlanningItem(String itemId) {
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    return selectedPlanningItemIds.remove(normalized);
  }

  bool isPlanningItemSelected(String itemId) {
    return selectedPlanningItemIds.contains(itemId);
  }

  // --- Ремонт корабля ---------------------------------------------------

  int shipRepairUnitsPaidFor(String itemId) => shipRepairUnitsPaid[itemId] ?? 0;

  int shipRepairRemainingUnits(String itemId) {
    final definition = ShipRepairCatalog.byId(itemId);
    if (definition == null) return 0;
    final remaining = definition.totalUnits - shipRepairUnitsPaidFor(itemId);
    return remaining < 0 ? 0 : remaining;
  }

  bool isShipRepairItemClosed(String itemId) {
    final definition = ShipRepairCatalog.byId(itemId);
    if (definition == null) return false;
    return shipRepairRemainingUnits(itemId) <= 0;
  }

  /// Позиции, сейчас входящие в активный План ремонта (максимум
  /// ShipRepairCatalog.activeSlotLimit штук).
  List<ShipRepairItemDefinition> get shipRepairActiveItems {
    return ShipRepairCatalog.items
        .where((item) => shipRepairActiveIds.contains(item.id))
        .toList(growable: false);
  }

  /// Позиции в бэклоге: ещё не закрыты и сейчас не в активном Плане.
  List<ShipRepairItemDefinition> get shipRepairPendingItems {
    return ShipRepairCatalog.items
        .where(
          (item) =>
              !shipRepairActiveIds.contains(item.id) &&
              !isShipRepairItemClosed(item.id),
        )
        .toList(growable: false);
  }

  /// Добавить позицию в активный План ремонта. Отказывает, если позиция
  /// неизвестна, уже закрыта, уже активна или все слоты заняты.
  bool activateShipRepairItem(String itemId) {
    final normalized = itemId.trim();
    if (normalized.isEmpty) return false;
    if (ShipRepairCatalog.byId(normalized) == null) return false;
    if (shipRepairActiveIds.contains(normalized)) return false;
    if (isShipRepairItemClosed(normalized)) return false;
    if (shipRepairActiveIds.length >= ShipRepairCatalog.activeSlotLimit) {
      return false;
    }
    shipRepairActiveIds.add(normalized);
    return true;
  }

  /// Исключить позицию из активного Плана. Уже оплаченные штуки не
  /// сгорают — при повторной активации счётчик продолжится с той же суммы.
  bool excludeShipRepairItem(String itemId) {
    return shipRepairActiveIds.remove(itemId.trim());
  }

  /// Зафиксировать оплату N штук по позиции (сам расход в Дар списывается
  /// отдельно через EconomyEngine — этот метод только обновляет прогресс).
  /// Если после оплаты позиция закрыта на 100%, она автоматически
  /// покидает активный План, освобождая слот для следующей.
  bool payShipRepairUnits(String itemId, int units) {
    if (units <= 0) return false;
    final normalized = itemId.trim();
    if (normalized.isEmpty) return false;
    final remaining = shipRepairRemainingUnits(normalized);
    if (units > remaining) return false;

    shipRepairUnitsPaid[normalized] = shipRepairUnitsPaidFor(normalized) + units;
    if (isShipRepairItemClosed(normalized)) {
      shipRepairActiveIds.remove(normalized);
    }
    return true;
  }

  // --- Рост питомца ------------------------------------------------------

  static const PetGrowthEngine _petGrowthEngine = PetGrowthEngine();

  /// Начисляет очки роста питомцу по итогам закрытого периода. Вызывается
  /// один раз при вечернем закрытии Базы (см. `_settleEveningAndClose` в
  /// main.dart). `petState` — долгосрочное состояние, оно НЕ сбрасывается
  /// ни в [prepareMorningSession], ни в [resetAfterPhd] (как и ремонт
  /// корабля), поэтому прогресс копится через весь прототип.
  PetGrowthUpdate applyPeriodGrowth({
    required bool mandatoryPaid,
    required bool planMatchedFact,
    required bool savedThisPeriod,
  }) {
    final update = _petGrowthEngine.applyPeriod(
      petState,
      mandatoryPaid: mandatoryPaid,
      planMatchedFact: planMatchedFact,
      savedThisPeriod: savedThisPeriod,
    );
    petState = update.next;
    return update;
  }

  bool storeQuestCargo(QuestResult result) {
    final attemptId = result.attemptId.trim();
    if (!result.success ||
        attemptId.isEmpty ||
        result.cargo.capacityUsed <= 0 ||
        !result.cargo.isWithinCapacity ||
        processedQuestAttemptIds.contains(attemptId)) {
      return false;
    }

    astroBox = astroBox.addCargo(result.cargo);
    processedQuestAttemptIds.add(attemptId);
    return true;
  }

  Map<String, Object?> toMap() {
    final rewardKeys = processedRewardKeys.toList()..sort();
    final questAttemptIds = processedQuestAttemptIds.toList()..sort();
    final planningItemIds = selectedPlanningItemIds.toList()..sort();

    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'introSeen': introSeen,
      'onboardingStep': onboardingStep,
      'profileCreated': profileCreated,
      'playerName': playerName,
      'selectedPet': selectedPet.id,
      'petStyle': petStyle,
      'petName': petName,
      'walletDar': walletDar,
      'savingsDar': savingsDar,
      'period': period,
      'activeGoalId': activeGoalId,
      'activeGoalTitle': activeGoalTitle,
      'activeGoalTarget': activeGoalTarget,
      'budgetPlanConfirmed': budgetPlanConfirmed,
      'planNeed': planNeed,
      'planWant': planWant,
      'planSave': planSave,
      'asteroidTrainingCompleted': asteroidTrainingCompleted,
      'currentPlan': currentPlan?.toMap(),
      'transactions': transactions
          .map((transaction) => transaction.toMap())
          .toList(),
      'petState': petState.toMap(),
      'processedRewardKeys': rewardKeys,
      'astroBox': astroBox.toMap(),
      'processedQuestAttemptIds': questAttemptIds,
      'selectedPlanningItemIds': planningItemIds,
      'sessionPhase': sessionPhase.id,
      'totalWorkSessionsCompleted': totalWorkSessionsCompleted,
      'morningPetVisited': morningPetVisited,
      'morningBarryVisited': morningBarryVisited,
      'petRequestIdsBySession': List<String>.from(petRequestIdsBySession),
      'barryRequestIdsBySession': List<String>.from(barryRequestIdsBySession),
      'eveningSelectedItemIds': (eveningSelectedItemIds.toList()..sort()),
      'shipRepairUnitsPaid': Map<String, int>.from(shipRepairUnitsPaid),
      'shipRepairActiveIds': (shipRepairActiveIds.toList()..sort()),
      'shipEvacuated': shipEvacuated,
      'demoProfile': demoProfile,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory GameStateData.fromMap(Map<String, dynamic> map) {
    final savedSchemaVersion = _readNonNegativeInt(map['schemaVersion']);
    final introSeen = _readBool(map['introSeen']);
    final profileCreated = _readBool(map['profileCreated']);
    final playerName = _readString(map['playerName']);
    final savedOnboardingStep = _readNullableInt(map['onboardingStep']);
    final onboardingStep = savedOnboardingStep ??
        (profileCreated
            ? 10
            : playerName.isNotEmpty
                ? 2
                : introSeen
                    ? 1
                    : 0);

    final walletDar = _readNonNegativeInt(map['walletDar']);
    final savingsDar = _readNonNegativeInt(map['savingsDar']);
    final period = _readPositiveInt(map['period'], fallback: 1);
    final activeGoalId = _readString(
      map['activeGoalId'],
      fallback: 'fuel_sensor',
    );
    final activeGoalTitle = _readString(
      map['activeGoalTitle'],
      fallback: 'Датчик топлива',
    );
    var activeGoalTarget = _readNonNegativeInt(
      map['activeGoalTarget'],
      fallback: 12,
    );
    if (savedSchemaVersion < 6 &&
        activeGoalId == 'fuel_sensor' &&
        activeGoalTarget == 11) {
      activeGoalTarget = 12;
    }

    var budgetPlanConfirmed = _readBool(map['budgetPlanConfirmed']);
    var planNeed = _readNonNegativeInt(map['planNeed']);
    var planWant = _readNonNegativeInt(map['planWant']);
    var planSave = _readNonNegativeInt(map['planSave']);

    BudgetPlan? currentPlan;
    final currentPlanMap = _asStringDynamicMap(map['currentPlan']);
    if (currentPlanMap != null) {
      currentPlan = BudgetPlan.fromMap(currentPlanMap);

      if (!map.containsKey('budgetPlanConfirmed')) {
        budgetPlanConfirmed = currentPlan.confirmed;
      }
      if (!map.containsKey('planNeed')) {
        planNeed = currentPlan.plannedNeed;
      }
      if (!map.containsKey('planWant')) {
        planWant = currentPlan.plannedWant;
      }
      if (!map.containsKey('planSave')) {
        planSave = currentPlan.plannedSavings;
      }
    }

    if (currentPlan == null && budgetPlanConfirmed) {
      currentPlan = BudgetPlan(
        periodId: period,
        startingWallet: walletDar,
        plannedNeed: planNeed,
        plannedWant: planWant,
        plannedSavings: planSave,
        selectedGoalId: activeGoalId,
        confirmed: true,
      );
    }

    final transactions = <Transaction>[];
    final rawTransactions = map['transactions'];
    if (rawTransactions is List) {
      for (final rawTransaction in rawTransactions) {
        final transactionMap = _asStringDynamicMap(rawTransaction);
        if (transactionMap != null) {
          transactions.add(Transaction.fromMap(transactionMap));
        }
      }
    }

    final petStateMap = _asStringDynamicMap(map['petState']);
    final petState = petStateMap == null
        ? PetState.neutral
        : PetState.fromMap(petStateMap);

    final processedRewardKeys = <String>{};
    final rawRewardKeys = map['processedRewardKeys'];
    if (rawRewardKeys is List) {
      for (final rawKey in rawRewardKeys) {
        if (rawKey is String && rawKey.isNotEmpty) {
          processedRewardKeys.add(rawKey);
        }
      }
    }

    final astroBoxMap = _asStringDynamicMap(map['astroBox']);
    final astroBox = astroBoxMap == null
        ? AstroBox.empty
        : AstroBox.fromMap(astroBoxMap);

    final processedQuestAttemptIds = <String>{};
    final rawQuestAttemptIds = map['processedQuestAttemptIds'];
    if (rawQuestAttemptIds is List) {
      for (final rawAttemptId in rawQuestAttemptIds) {
        if (rawAttemptId is String && rawAttemptId.isNotEmpty) {
          processedQuestAttemptIds.add(rawAttemptId);
        }
      }
    }

    final selectedPlanningItemIds = <String>{};
    final rawPlanningItemIds = map['selectedPlanningItemIds'];
    if (rawPlanningItemIds is List) {
      for (final rawItemId in rawPlanningItemIds) {
        if (rawItemId is String && rawItemId.isNotEmpty) {
          selectedPlanningItemIds.add(rawItemId);
        }
      }
    }

    final eveningSelectedItemIds = <String>{};
    final rawEveningItemIds = map['eveningSelectedItemIds'];
    if (rawEveningItemIds is List) {
      for (final rawItemId in rawEveningItemIds) {
        if (rawItemId is String && rawItemId.isNotEmpty) {
          eveningSelectedItemIds.add(rawItemId);
        }
      }
    }

    final petRequestIdsBySession = _readStringList(map['petRequestIdsBySession']);
    final barryRequestIdsBySession = _readStringList(map['barryRequestIdsBySession']);

    final shipRepairUnitsPaid = <String, int>{};
    final rawShipRepairUnitsPaid = map['shipRepairUnitsPaid'];
    if (rawShipRepairUnitsPaid is Map) {
      rawShipRepairUnitsPaid.forEach((key, value) {
        final id = key.toString();
        final units = _readNonNegativeInt(value);
        if (id.isNotEmpty && units > 0) {
          shipRepairUnitsPaid[id] = units;
        }
      });
    }

    final shipRepairActiveIds = <String>{};
    final rawShipRepairActiveIds = map['shipRepairActiveIds'];
    if (rawShipRepairActiveIds is List) {
      for (final rawId in rawShipRepairActiveIds) {
        if (rawId is String && rawId.isNotEmpty) {
          shipRepairActiveIds.add(rawId);
        }
      }
    }

    final sessionPhase = _baseSessionPhaseFromId(
      _readNullableString(map['sessionPhase']),
      profileCreated: profileCreated,
    );

    return GameStateData(
      introSeen: introSeen,
      onboardingStep: onboardingStep,
      profileCreated: profileCreated,
      playerName: playerName,
      selectedPet: PetTypeInfo.fromId(
        _readNullableString(map['selectedPet']),
      ),
      petStyle: _readNonNegativeInt(map['petStyle']),
      petName: _readString(map['petName']),
      walletDar: walletDar,
      savingsDar: savingsDar,
      period: period,
      activeGoalId: activeGoalId,
      activeGoalTitle: activeGoalTitle,
      activeGoalTarget: activeGoalTarget,
      budgetPlanConfirmed: budgetPlanConfirmed,
      planNeed: planNeed,
      planWant: planWant,
      planSave: planSave,
      asteroidTrainingCompleted: _readBool(
        map['asteroidTrainingCompleted'],
      ),
      currentPlan: currentPlan,
      transactions: transactions,
      petState: petState,
      processedRewardKeys: processedRewardKeys,
      astroBox: astroBox,
      processedQuestAttemptIds: processedQuestAttemptIds,
      selectedPlanningItemIds: selectedPlanningItemIds,
      sessionPhase: sessionPhase,
      totalWorkSessionsCompleted: _readNonNegativeInt(
        map['totalWorkSessionsCompleted'],
      ),
      morningPetVisited: _readBool(map['morningPetVisited']),
      morningBarryVisited: _readBool(map['morningBarryVisited']),
      petRequestIdsBySession: petRequestIdsBySession,
      barryRequestIdsBySession: barryRequestIdsBySession,
      eveningSelectedItemIds: eveningSelectedItemIds,
      shipRepairUnitsPaid: shipRepairUnitsPaid,
      shipRepairActiveIds: shipRepairActiveIds,
      shipEvacuated: _readBool(map['shipEvacuated']),
      demoProfile: _readBool(map['demoProfile']),
    );
  }

  factory GameStateData.fromJson(String source) {
    final decoded = jsonDecode(source);
    final map = _asStringDynamicMap(decoded);
    if (map == null) {
      return GameStateData();
    }
    return GameStateData.fromMap(map);
  }
}

Map<String, dynamic>? _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  return null;
}

String _readString(Object? value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

String? _readNullableString(Object? value) {
  return value is String ? value : null;
}

bool _readBool(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

int? _readNullableInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return null;
}

int _readNonNegativeInt(Object? value, {int fallback = 0}) {
  final result = _readNullableInt(value) ?? fallback;
  return _nonNegative(result);
}

int _readPositiveInt(Object? value, {required int fallback}) {
  final result = _readNullableInt(value) ?? fallback;
  return result <= 0 ? fallback : result;
}

List<String> _normalizeRequestHistory(List<String>? values) {
  if (values == null || values.isEmpty) {
    return <String>[];
  }

  return values
      .take(5)
      .map((value) => value.trim())
      .toList(growable: true);
}

String? _requestForPeriod(List<String> history, int period) {
  if (period <= 0 || period > history.length || period > 5) {
    return null;
  }

  final value = history[period - 1].trim();
  return value.isEmpty ? null : value;
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return <String>[];
  }

  final result = <String>[];
  for (final rawValue in value.take(5)) {
    result.add(rawValue is String ? rawValue.trim() : '');
  }
  return result;
}

int _nonNegative(int value) => value < 0 ? 0 : value;