enum TransactionType {
  income,
  needExpense,
  wantExpense,
  transportExpense,
  savingDeposit,
  savingWithdrawal,
}


class PlanOwner {
  const PlanOwner._();

  static const String barry = 'barry';
  static const String pet = 'pet';
  static const String team = 'team';
}

class PlanCategory {
  const PlanCategory._();

  static const String need = 'need';
  static const String want = 'want';
  static const String planned = 'planned';
}

class PlanningItemDefinition {
  final String id;
  final String ownerId;
  final String category;
  final String title;
  final int cost;
  final bool mandatory;
  final String? petTypeId;

  const PlanningItemDefinition({
    required this.id,
    required this.ownerId,
    required this.category,
    required this.title,
    required this.cost,
    this.mandatory = false,
    this.petTypeId,
  });

  bool appliesToPet(String selectedPetTypeId) {
    return petTypeId == null || petTypeId == selectedPetTypeId;
  }

  PlannedItem toPlannedItem() {
    return PlannedItem(
      id: id,
      category: category,
      title: title,
      plannedCost: cost,
      contentRefId: id,
      ownerId: ownerId,
      mandatory: mandatory,
    );
  }
}

class EconomyCategory {
  const EconomyCategory._();

  static const String income = 'income';
  static const String need = 'need';
  static const String want = 'want';
  static const String transport = 'transport';
  static const String savings = 'savings';
}

class Transaction {
  final String id;
  final int periodId;
  final int sequence;
  final TransactionType type;
  final String category;
  final int amount;
  final String sourceId;
  final String sourceTitle;
  final String reason;
  final int walletBefore;
  final int walletAfter;
  final int savingsBefore;
  final int savingsAfter;

  const Transaction({
    required this.id,
    required this.periodId,
    required this.sequence,
    required this.type,
    required this.category,
    required this.amount,
    required this.sourceId,
    required this.sourceTitle,
    required this.reason,
    required this.walletBefore,
    required this.walletAfter,
    required this.savingsBefore,
    required this.savingsAfter,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'periodId': periodId,
      'sequence': sequence,
      'type': type.name,
      'category': category,
      'amount': amount,
      'sourceId': sourceId,
      'sourceTitle': sourceTitle,
      'reason': reason,
      'walletBefore': walletBefore,
      'walletAfter': walletAfter,
      'savingsBefore': savingsBefore,
      'savingsAfter': savingsAfter,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: _readString(map['id']),
      periodId: _readInt(map['periodId']),
      sequence: _readInt(map['sequence']),
      type: _transactionTypeFromName(map['type']),
      category: _readString(map['category']),
      amount: _readNonNegativeInt(map['amount']),
      sourceId: _readString(map['sourceId']),
      sourceTitle: _readString(map['sourceTitle']),
      reason: _readString(map['reason']),
      walletBefore: _readNonNegativeInt(map['walletBefore']),
      walletAfter: _readNonNegativeInt(map['walletAfter']),
      savingsBefore: _readNonNegativeInt(map['savingsBefore']),
      savingsAfter: _readNonNegativeInt(map['savingsAfter']),
    );
  }
}

class PlannedItem {
  final String id;
  final String category;
  final String title;
  final int plannedCost;
  final String contentRefId;
  final String ownerId;
  final bool mandatory;

  const PlannedItem({
    required this.id,
    required this.category,
    required this.title,
    required this.plannedCost,
    required this.contentRefId,
    this.ownerId = '',
    this.mandatory = false,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'category': category,
      'title': title,
      'plannedCost': plannedCost,
      'contentRefId': contentRefId,
      'ownerId': ownerId,
      'mandatory': mandatory,
    };
  }

  factory PlannedItem.fromMap(Map<String, dynamic> map) {
    return PlannedItem(
      id: _readString(map['id']),
      category: _readString(map['category']),
      title: _readString(map['title']),
      plannedCost: _readNonNegativeInt(map['plannedCost']),
      contentRefId: _readString(map['contentRefId']),
      ownerId: _readString(map['ownerId']),
      mandatory: _readBool(map['mandatory']),
    );
  }
}

class BudgetPlan {
  final int periodId;
  final int startingWallet;
  final int plannedNeed;
  final int plannedWant;
  final int plannedSavings;
  final List<PlannedItem> plannedItems;
  final String selectedGoalId;
  final bool confirmed;

  BudgetPlan({
    required this.periodId,
    required this.startingWallet,
    required this.plannedNeed,
    required this.plannedWant,
    required this.plannedSavings,
    List<PlannedItem> plannedItems = const <PlannedItem>[],
    required this.selectedGoalId,
    required this.confirmed,
  }) : plannedItems = List<PlannedItem>.unmodifiable(plannedItems);

  int get plannedTotal => plannedNeed + plannedWant + plannedSavings;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'periodId': periodId,
      'startingWallet': startingWallet,
      'plannedNeed': plannedNeed,
      'plannedWant': plannedWant,
      'plannedSavings': plannedSavings,
      'plannedItems': plannedItems.map((item) => item.toMap()).toList(),
      'selectedGoalId': selectedGoalId,
      'confirmed': confirmed,
    };
  }

  factory BudgetPlan.fromMap(Map<String, dynamic> map) {
    final plannedItems = <PlannedItem>[];
    final rawItems = map['plannedItems'];

    if (rawItems is List) {
      for (final rawItem in rawItems) {
        final itemMap = _asStringDynamicMap(rawItem);
        if (itemMap != null) {
          plannedItems.add(PlannedItem.fromMap(itemMap));
        }
      }
    }

    return BudgetPlan(
      periodId: _readPositiveInt(map['periodId'], fallback: 1),
      startingWallet: _readNonNegativeInt(map['startingWallet']),
      plannedNeed: _readNonNegativeInt(map['plannedNeed']),
      plannedWant: _readNonNegativeInt(map['plannedWant']),
      plannedSavings: _readNonNegativeInt(map['plannedSavings']),
      plannedItems: plannedItems,
      selectedGoalId: _readString(map['selectedGoalId']),
      confirmed: _readBool(map['confirmed']),
    );
  }
}

class PeriodFact {
  final int periodId;
  final int actualNeed;
  final int actualWant;
  final int actualSavings;
  final int income;
  final int walletEnd;
  final int savingsEnd;

  const PeriodFact({
    required this.periodId,
    required this.actualNeed,
    required this.actualWant,
    required this.actualSavings,
    required this.income,
    required this.walletEnd,
    required this.savingsEnd,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'periodId': periodId,
      'actualNeed': actualNeed,
      'actualWant': actualWant,
      'actualSavings': actualSavings,
      'income': income,
      'walletEnd': walletEnd,
      'savingsEnd': savingsEnd,
    };
  }

  factory PeriodFact.fromMap(Map<String, dynamic> map) {
    return PeriodFact(
      periodId: _readPositiveInt(map['periodId'], fallback: 1),
      actualNeed: _readNonNegativeInt(map['actualNeed']),
      actualWant: _readNonNegativeInt(map['actualWant']),
      actualSavings: _readInt(map['actualSavings']),
      income: _readNonNegativeInt(map['income']),
      walletEnd: _readNonNegativeInt(map['walletEnd']),
      savingsEnd: _readNonNegativeInt(map['savingsEnd']),
    );
  }
}

class Cargo {
  final int blue;
  final int red;
  final int green;
  final int black;
  final int capacityMax;

  const Cargo({
    this.blue = 0,
    this.red = 0,
    this.green = 0,
    this.black = 0,
    this.capacityMax = 0,
  });

  int get capacityUsed => blue + red + green + black;

  bool get isWithinCapacity => capacityUsed <= capacityMax;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'blue': blue,
      'red': red,
      'green': green,
      'black': black,
      'capacityUsed': capacityUsed,
      'capacityMax': capacityMax,
    };
  }

  factory Cargo.fromMap(Map<String, dynamic> map) {
    return Cargo(
      blue: _readNonNegativeInt(map['blue']),
      red: _readNonNegativeInt(map['red']),
      green: _readNonNegativeInt(map['green']),
      black: _readNonNegativeInt(map['black']),
      capacityMax: _readNonNegativeInt(map['capacityMax']),
    );
  }
}

class AstroBox {
  final int blue;
  final int red;
  final int green;
  final int black;

  const AstroBox({
    this.blue = 0,
    this.red = 0,
    this.green = 0,
    this.black = 0,
  });

  static const AstroBox empty = AstroBox();

  int get totalResources => blue + red + green + black;

  bool get isNonNegative =>
      blue >= 0 && red >= 0 && green >= 0 && black >= 0;

  bool hasAtLeast(AstroBox required) {
    if (!required.isNonNegative) {
      return false;
    }

    return blue >= required.blue &&
        red >= required.red &&
        green >= required.green &&
        black >= required.black;
  }

  AstroBox subtract(AstroBox required) {
    if (!hasAtLeast(required)) {
      throw StateError('AstroBox does not contain enough resources.');
    }

    return AstroBox(
      blue: blue - required.blue,
      red: red - required.red,
      green: green - required.green,
      black: black - required.black,
    );
  }

  AstroBox addCargo(Cargo cargo) {
    return AstroBox(
      blue: blue + cargo.blue,
      red: red + cargo.red,
      green: green + cargo.green,
      black: black + cargo.black,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'blue': blue,
      'red': red,
      'green': green,
      'black': black,
    };
  }

  factory AstroBox.fromMap(Map<String, dynamic> map) {
    return AstroBox(
      blue: _readNonNegativeInt(map['blue']),
      red: _readNonNegativeInt(map['red']),
      green: _readNonNegativeInt(map['green']),
      black: _readNonNegativeInt(map['black']),
    );
  }
}

class QuestResult {
  final String questId;
  final String transportId;
  final Cargo cargo;
  final bool success;
  final Duration duration;
  final String attemptId;

  const QuestResult({
    required this.questId,
    required this.transportId,
    required this.cargo,
    required this.success,
    required this.duration,
    required this.attemptId,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'questId': questId,
      'transportId': transportId,
      'cargo': cargo.toMap(),
      'success': success,
      'durationMs': duration.inMilliseconds,
      'attemptId': attemptId,
    };
  }

  factory QuestResult.fromMap(Map<String, dynamic> map) {
    final cargoMap = _asStringDynamicMap(map['cargo']);

    return QuestResult(
      questId: _readString(map['questId']),
      transportId: _readString(map['transportId']),
      cargo: cargoMap == null ? const Cargo() : Cargo.fromMap(cargoMap),
      success: _readBool(map['success']),
      duration: Duration(
        milliseconds: _readNonNegativeInt(map['durationMs']),
      ),
      attemptId: _readString(map['attemptId']),
    );
  }
}

class PetState {
  final int care;
  final int mood;
  final int energy;
  final int growthPoints;
  final int growthStage;

  const PetState({
    this.care = 0,
    this.mood = 0,
    this.energy = 0,
    this.growthPoints = 0,
    this.growthStage = 0,
  });

  static const PetState neutral = PetState();

  /// Копия состояния питомца с заменой только переданных полей.
  /// Используется `PetGrowthEngine.applyPeriod` (lib/pet_growth.dart).
  PetState copyWith({
    int? care,
    int? mood,
    int? energy,
    int? growthPoints,
    int? growthStage,
  }) {
    return PetState(
      care: care ?? this.care,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      growthPoints: growthPoints ?? this.growthPoints,
      growthStage: growthStage ?? this.growthStage,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'care': care,
      'mood': mood,
      'energy': energy,
      'growthPoints': growthPoints,
      'growthStage': growthStage,
    };
  }

  factory PetState.fromMap(Map<String, dynamic> map) {
    return PetState(
      care: _readInt(map['care']),
      mood: _readInt(map['mood']),
      energy: _readInt(map['energy']),
      growthPoints: _readNonNegativeInt(map['growthPoints']),
      growthStage: _readNonNegativeInt(map['growthStage']),
    );
  }
}

TransactionType _transactionTypeFromName(Object? value) {
  if (value is String) {
    for (final type in TransactionType.values) {
      if (type.name == value) {
        return type;
      }
    }
  }

  return TransactionType.income;
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

bool _readBool(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return fallback;
}

int _readNonNegativeInt(Object? value, {int fallback = 0}) {
  final result = _readInt(value, fallback: fallback);
  return result < 0 ? 0 : result;
}

int _readPositiveInt(Object? value, {required int fallback}) {
  final result = _readInt(value, fallback: fallback);
  return result <= 0 ? fallback : result;
}
