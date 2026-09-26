enum BazarResource {
  blueAsteroid,
  redAsteroid,
  greenAsteroid,
  wood,
}

extension BazarResourceLabel on BazarResource {
  String get title {
    switch (this) {
      case BazarResource.blueAsteroid:
        return 'Синий астероид';
      case BazarResource.redAsteroid:
        return 'Красный астероид';
      case BazarResource.greenAsteroid:
        return 'Зелёный астероид';
      case BazarResource.wood:
        return 'Дрова СЛОН';
    }
  }
}

class BazarCargo {
  final int blue;
  final int red;
  final int green;
  final int wood;

  const BazarCargo({
    this.blue = 0,
    this.red = 0,
    this.green = 0,
    this.wood = 0,
  })  : assert(blue >= 0),
        assert(red >= 0),
        assert(green >= 0),
        assert(wood >= 0);

  int get totalUnits => blue + red + green + wood;
  bool get isEmpty => totalUnits == 0;
  bool get isNotEmpty => !isEmpty;

  int amountOf(BazarResource resource) {
    switch (resource) {
      case BazarResource.blueAsteroid:
        return blue;
      case BazarResource.redAsteroid:
        return red;
      case BazarResource.greenAsteroid:
        return green;
      case BazarResource.wood:
        return wood;
    }
  }

  bool hasAtLeast(BazarCargo required) {
    return blue >= required.blue &&
        red >= required.red &&
        green >= required.green &&
        wood >= required.wood;
  }

  BazarCargo add(BazarCargo other) {
    return BazarCargo(
      blue: blue + other.blue,
      red: red + other.red,
      green: green + other.green,
      wood: wood + other.wood,
    );
  }

  BazarCargo subtract(BazarCargo required) {
    if (!hasAtLeast(required)) {
      throw StateError('BAZAR cargo does not contain required resources.');
    }

    return BazarCargo(
      blue: blue - required.blue,
      red: red - required.red,
      green: green - required.green,
      wood: wood - required.wood,
    );
  }

  BazarCargo missingFor(BazarCargo required) {
    int missing(int current, int target) => current >= target ? 0 : target - current;

    return BazarCargo(
      blue: missing(blue, required.blue),
      red: missing(red, required.red),
      green: missing(green, required.green),
      wood: missing(wood, required.wood),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'blue': blue,
      'red': red,
      'green': green,
      'wood': wood,
    };
  }

  factory BazarCargo.fromMap(Map<String, dynamic> map) {
    int read(String key) {
      final value = map[key];
      return value is num && value >= 0 ? value.toInt() : 0;
    }

    return BazarCargo(
      blue: read('blue'),
      red: read('red'),
      green: read('green'),
      wood: read('wood'),
    );
  }

  @override
  String toString() {
    return 'BazarCargo(blue: $blue, red: $red, green: $green, wood: $wood)';
  }
}

class BazarTrader {
  final String id;
  final String title;
  final String subtitle;

  const BazarTrader({
    required this.id,
    required this.title,
    this.subtitle = '',
  });
}

class BazarOffer {
  final String id;
  final String traderId;
  final String title;
  final BazarCargo requirements;
  final int rewardDar;

  const BazarOffer({
    required this.id,
    required this.traderId,
    required this.title,
    required this.requirements,
    required this.rewardDar,
  }) : assert(rewardDar > 0);
}

class BazarTransport {
  final String id;
  final String title;
  final int cargoCapacity;
  final int rentalCostDar;
  final String description;
  final String feature;
  final bool canCollectAsteroids;
  final bool canFlyToSlon;
  final bool expeditionReady;

  const BazarTransport({
    required this.id,
    required this.title,
    required this.cargoCapacity,
    this.rentalCostDar = 0,
    this.description = '',
    this.feature = '',
    this.canCollectAsteroids = true,
    this.canFlyToSlon = false,
    this.expeditionReady = true,
  })  : assert(cargoCapacity > 0),
        assert(rentalCostDar >= 0);
}

enum BazarQuestKind {
  asteroids,
  slonWood,
}

class BazarQuestRequest {
  final BazarQuestKind kind;
  final String? transportId;
  final int? cargoCapacity;
  final BazarCargo? requiredCargo;
  final String? missionTitle;

  const BazarQuestRequest({
    required this.kind,
    this.transportId,
    this.cargoCapacity,
    this.requiredCargo,
    this.missionTitle,
  });
}

class BazarQuestCargoResult {
  final String attemptId;
  final BazarQuestKind kind;
  final BazarCargo cargo;
  final bool success;

  const BazarQuestCargoResult({
    required this.attemptId,
    required this.kind,
    required this.cargo,
    this.success = true,
  });
}

enum BazarPhase {
  browsing,
  planning,
  collecting,
  trading,
  settling,
  readyToBase,
}

class BazarDealQuote {
  final BazarOffer offer;
  final BazarCargo availableCargo;
  final BazarCargo missingCargo;

  const BazarDealQuote({
    required this.offer,
    required this.availableCargo,
    required this.missingCargo,
  });

  bool get canComplete => missingCargo.isEmpty;
}

class BazarDealReceipt {
  final String traderId;
  final String offerId;
  final int earnedDar;
  final BazarCargo spentCargo;
  final BazarCargo remainingCargo;

  const BazarDealReceipt({
    required this.traderId,
    required this.offerId,
    required this.earnedDar,
    required this.spentCargo,
    required this.remainingCargo,
  });
}

class BazarIncomeEvent {
  final String rewardKey;
  final int amountDar;
  final String sourceId;
  final String sourceTitle;
  final String reason;

  const BazarIncomeEvent({
    required this.rewardKey,
    required this.amountDar,
    required this.sourceId,
    required this.sourceTitle,
    required this.reason,
  }) : assert(amountDar >= 0);
}

class BazarExpenseEvent {
  final String expenseKey;
  final int amountDar;
  final String sourceId;
  final String sourceTitle;
  final String reason;

  const BazarExpenseEvent({
    required this.expenseKey,
    required this.amountDar,
    required this.sourceId,
    required this.sourceTitle,
    required this.reason,
  }) : assert(amountDar >= 0);
}


enum BazarLeftoverResolution {
  none,
  soldToBuyer,
  storedInAstroBox,
}

class BazarStoredLot {
  final BazarCargo cargo;

  // Legacy compatibility only. AstroBox in the current vertical slice
  // clears/stores cargo for free and does not create income.
  final int markdownPercent;

  const BazarStoredLot({
    required this.cargo,
    this.markdownPercent = 0,
  }) : assert(markdownPercent >= 0 && markdownPercent <= 100);

  int get retainedValuePercent => 100 - markdownPercent;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'cargo': cargo.toMap(),
      'markdownPercent': markdownPercent,
    };
  }

  factory BazarStoredLot.fromMap(Map<String, dynamic> map) {
    final rawCargo = map['cargo'];
    final rawMarkdown = map['markdownPercent'];
    return BazarStoredLot(
      cargo: rawCargo is Map
          ? BazarCargo.fromMap(
              rawCargo.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const BazarCargo(),
      markdownPercent: rawMarkdown is num
          ? rawMarkdown.toInt().clamp(0, 100).toInt()
          : 0,
    );
  }
}


class BazarRunResult {
  final int totalDarToBase;
  final String? primaryTraderId;
  final String? primaryOfferId;
  final int primaryDealDar;
  final int buyerDar;
  final BazarStoredLot? astroBoxLot;

  const BazarRunResult({
    required this.totalDarToBase,
    required this.primaryTraderId,
    required this.primaryOfferId,
    required this.primaryDealDar,
    required this.buyerDar,
    required this.astroBoxLot,
  });
}

class BazarGameState {
  String? sessionId;
  BazarPhase phase;
  String? pinnedOfferId;
  String? selectedTransportId;
  String? rentedTransportId;
  int transportRentalPaidDar;
  bool asteroidExpeditionCompleted;
  BazarCargo cargo;
  // Только память текущего захода. В сейв не пишем и со старых сейвов не поднимаем.
  BazarCargo astroBoxCargo;
  int sessionEarningsDar;
  String? completedTraderId;
  String? completedOfferId;
  int primaryDealDar;
  int buyerDar;
  BazarLeftoverResolution leftoverResolution;
  BazarStoredLot? pendingAstroBoxLot;
  final Set<String> processedQuestAttemptIds;

  BazarGameState({
    this.sessionId,
    this.phase = BazarPhase.browsing,
    this.pinnedOfferId,
    this.selectedTransportId,
    this.rentedTransportId,
    this.transportRentalPaidDar = 0,
    this.asteroidExpeditionCompleted = false,
    this.cargo = const BazarCargo(),
    this.astroBoxCargo = const BazarCargo(),
    this.sessionEarningsDar = 0,
    this.completedTraderId,
    this.completedOfferId,
    this.primaryDealDar = 0,
    this.buyerDar = 0,
    this.leftoverResolution = BazarLeftoverResolution.none,
    this.pendingAstroBoxLot,
    Set<String>? processedQuestAttemptIds,
  }) : processedQuestAttemptIds = <String>{
          ...?processedQuestAttemptIds,
        };

  bool get hasPinnedOffer {
    final id = pinnedOfferId?.trim();
    return id != null && id.isNotEmpty;
  }

  bool get hasPrimaryDeal => completedOfferId != null;
  bool get canReturnToBase => phase == BazarPhase.readyToBase;

  void resetForNewRun() {
    sessionId = null;
    phase = BazarPhase.browsing;
    pinnedOfferId = null;
    selectedTransportId = null;
    rentedTransportId = null;
    transportRentalPaidDar = 0;
    asteroidExpeditionCompleted = false;
    cargo = const BazarCargo();
    astroBoxCargo = const BazarCargo();
    sessionEarningsDar = 0;
    completedTraderId = null;
    completedOfferId = null;
    primaryDealDar = 0;
    buyerDar = 0;
    leftoverResolution = BazarLeftoverResolution.none;
    pendingAstroBoxLot = null;
    processedQuestAttemptIds.clear();
  }

  Map<String, Object?> toMap() {
    final attempts = processedQuestAttemptIds.toList()..sort();

    return <String, Object?>{
      'sessionId': sessionId,
      'phase': phase.name,
      'pinnedOfferId': pinnedOfferId,
      'selectedTransportId': selectedTransportId,
      'rentedTransportId': rentedTransportId,
      'transportRentalPaidDar': transportRentalPaidDar,
      'asteroidExpeditionCompleted': asteroidExpeditionCompleted,
      'cargo': cargo.toMap(),
      'sessionEarningsDar': sessionEarningsDar,
      'completedTraderId': completedTraderId,
      'completedOfferId': completedOfferId,
      'primaryDealDar': primaryDealDar,
      'buyerDar': buyerDar,
      'leftoverResolution': leftoverResolution.name,
      'pendingAstroBoxLot': pendingAstroBoxLot?.toMap(),
      'processedQuestAttemptIds': attempts,
    };
  }

  factory BazarGameState.fromMap(Map<String, dynamic> map) {
    T enumByName<T extends Enum>(
      List<T> values,
      Object? raw,
      T fallback,
    ) {
      if (raw is String) {
        for (final value in values) {
          if (value.name == raw) {
            return value;
          }
        }
      }
      return fallback;
    }

    Map<String, dynamic>? asMap(Object? raw) {
      if (raw is Map<String, dynamic>) {
        return raw;
      }
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    String? readString(Object? raw) {
      if (raw is! String) return null;
      final value = raw.trim();
      return value.isEmpty ? null : value;
    }

    int readInt(Object? raw) {
      return raw is num && raw >= 0 ? raw.toInt() : 0;
    }

    final attempts = <String>{};
    final rawAttempts = map['processedQuestAttemptIds'];
    if (rawAttempts is List) {
      for (final raw in rawAttempts) {
        final id = readString(raw);
        if (id != null) attempts.add(id);
      }
    }

    final cargoMap = asMap(map['cargo']);
    final lotMap = asMap(map['pendingAstroBoxLot']);

    return BazarGameState(
      sessionId: readString(map['sessionId']),
      phase: enumByName(
        BazarPhase.values,
        map['phase'],
        BazarPhase.browsing,
      ),
      pinnedOfferId: readString(map['pinnedOfferId']),
      selectedTransportId: readString(map['selectedTransportId']),
      rentedTransportId: readString(map['rentedTransportId']),
      transportRentalPaidDar: readInt(map['transportRentalPaidDar']),
      asteroidExpeditionCompleted: map['asteroidExpeditionCompleted'] == true,
      cargo: cargoMap == null
          ? const BazarCargo()
          : BazarCargo.fromMap(cargoMap),
      astroBoxCargo: const BazarCargo(),
      sessionEarningsDar: readInt(map['sessionEarningsDar']),
      completedTraderId: readString(map['completedTraderId']),
      completedOfferId: readString(map['completedOfferId']),
      primaryDealDar: readInt(map['primaryDealDar']),
      buyerDar: readInt(map['buyerDar']),
      leftoverResolution: enumByName(
        BazarLeftoverResolution.values,
        map['leftoverResolution'],
        BazarLeftoverResolution.none,
      ),
      pendingAstroBoxLot:
          lotMap == null ? null : BazarStoredLot.fromMap(lotMap),
      processedQuestAttemptIds: attempts,
    );
  }
}