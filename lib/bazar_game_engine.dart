import 'bazar_game_catalog.dart';
import 'bazar_game_models.dart';

class BazarGameException implements Exception {
  final String code;
  final String message;

  const BazarGameException(this.code, this.message);

  @override
  String toString() => 'BazarGameException($code): $message';
}

class BazarBuyerPricePolicy {
  final int discountPercent;

  const BazarBuyerPricePolicy({
    this.discountPercent = 20,
  }) : assert(discountPercent >= 0 && discountPercent <= 100);

  int quote(BazarCargo cargo) {
    if (cargo.isEmpty) return 0;

    final fullValueDar = BazarGameCatalog.cargoValueDar(cargo);
    // Общая экономика хранит целые Дар, поэтому неполный Дар округляется вниз.
    return fullValueDar * (100 - discountPercent) ~/ 100;
  }
}

class BazarGameEngine {
  final BazarBuyerPricePolicy buyerPricePolicy;

  const BazarGameEngine({
    this.buyerPricePolicy = const BazarBuyerPricePolicy(),
  });

  BazarOffer pinOffer(
    BazarGameState state,
    String offerId,
  ) {
    _ensurePrimaryDealNotCompleted(state);

    final offer = _offerOrThrow(offerId);

    state.pinnedOfferId = offer.id;
    if (state.phase == BazarPhase.browsing) {
      state.phase = BazarPhase.planning;
    }

    return offer;
  }

  BazarOffer acceptOffer(
    BazarGameState state,
    String offerId,
  ) {
    return pinOffer(state, offerId);
  }

  void clearPinnedOffer(BazarGameState state) {
    _ensurePrimaryDealNotCompleted(state);

    state.pinnedOfferId = null;
    if (state.cargo.isEmpty && state.selectedTransportId == null) {
      state.phase = BazarPhase.browsing;
    }
  }

  BazarTransport selectTransport(
    BazarGameState state,
    String transportId,
  ) {
    _ensurePrimaryDealNotCompleted(state);

    if (state.asteroidExpeditionCompleted) {
      throw const BazarGameException(
        'asteroid_expedition_already_completed',
        'Asteroid expedition is already completed for this BAZAR run.',
      );
    }

    if (state.rentedTransportId != null &&
        state.rentedTransportId != transportId) {
      throw const BazarGameException(
        'transport_rental_already_paid',
        'Transport cannot be changed after rental has been paid.',
      );
    }

    final transport = _transportOrThrow(transportId);
    if (!transport.canCollectAsteroids) {
      throw BazarGameException(
        'transport_cannot_collect_asteroids',
        'Transport "${transport.id}" cannot collect asteroids.',
      );
    }
    if (!transport.expeditionReady) {
      throw BazarGameException(
        'transport_expedition_not_ready',
        'Экспедиция на ${transport.title} пока в разработке. Для текущего выезда выберите Чих-Пых.',
      );
    }

    state.selectedTransportId = transport.id;
    state.phase = BazarPhase.collecting;
    return transport;
  }

  BazarTransport markTransportRentalPaid(
    BazarGameState state,
    String transportId,
  ) {
    _ensurePrimaryDealNotCompleted(state);

    final transport = _transportOrThrow(transportId);
    if (state.selectedTransportId != transport.id) {
      throw const BazarGameException(
        'transport_not_selected',
        'Select this transport before paying its rental.',
      );
    }

    if (state.rentedTransportId != null &&
        state.rentedTransportId != transport.id) {
      throw const BazarGameException(
        'transport_rental_already_paid',
        'Another transport rental has already been paid.',
      );
    }

    state.rentedTransportId = transport.id;
    state.transportRentalPaidDar = transport.rentalCostDar;
    return transport;
  }

  BazarQuestRequest createQuestRequest(
    BazarGameState state,
    BazarQuestKind kind,
  ) {
    _ensurePrimaryDealNotCompleted(state);

    switch (kind) {
      case BazarQuestKind.asteroids:
        if (!state.hasPinnedOffer) {
          throw const BazarGameException(
            'offer_not_accepted',
            'Accept a trader order before going to the Garage expedition.',
          );
        }

        if (state.asteroidExpeditionCompleted) {
          throw const BazarGameException(
            'asteroid_expedition_already_completed',
            'Only one asteroid expedition is available in this BAZAR run.',
          );
        }

        final transportId = state.selectedTransportId;
        if (transportId == null || transportId.trim().isEmpty) {
          throw const BazarGameException(
            'transport_not_selected',
            'Select a space tractor in the Garage before asteroid quest.',
          );
        }

        final transport = _transportOrThrow(transportId);
        if (!transport.canCollectAsteroids) {
          throw BazarGameException(
            'transport_cannot_collect_asteroids',
            'Transport "${transport.id}" cannot collect asteroids.',
          );
        }
        if (!transport.expeditionReady) {
          throw BazarGameException(
            'transport_expedition_not_ready',
            'Экспедиция на ${transport.title} пока в разработке.',
          );
        }

        if (state.rentedTransportId != transport.id) {
          throw const BazarGameException(
            'transport_rental_not_confirmed',
            'Confirm the selected transport rental before expedition.',
          );
        }

        final offer = _offerOrThrow(state.pinnedOfferId!);
        final requiredAsteroids = BazarCargo(
          blue: offer.requirements.blue,
          red: offer.requirements.red,
          green: offer.requirements.green,
        );

        return BazarQuestRequest(
          kind: kind,
          transportId: transport.id,
          cargoCapacity: transport.cargoCapacity,
          requiredCargo: requiredAsteroids,
          missionTitle: offer.title,
        );

      case BazarQuestKind.slonWood:
        // СЛОН намеренно не связан с Гаражом и космотрактором.
        return const BazarQuestRequest(
          kind: BazarQuestKind.slonWood,
        );
    }
  }

  BazarCargo receiveQuestCargo(
    BazarGameState state,
    BazarQuestCargoResult result,
  ) {
    _ensurePrimaryDealNotCompleted(state);

    final attemptId = result.attemptId.trim();
    if (attemptId.isEmpty) {
      throw const BazarGameException(
        'invalid_attempt_id',
        'Quest attempt id must not be empty.',
      );
    }

    if (!result.success) {
      throw const BazarGameException(
        'quest_failed',
        'Failed quest result cannot be added to BAZAR cargo.',
      );
    }

    if (result.cargo.isEmpty) {
      throw const BazarGameException(
        'empty_cargo',
        'Quest result does not contain cargo.',
      );
    }

    if (state.processedQuestAttemptIds.contains(attemptId)) {
      throw BazarGameException(
        'duplicate_quest_result',
        'Quest attempt "$attemptId" has already been processed.',
      );
    }

    if (result.kind == BazarQuestKind.asteroids) {
      if (!state.hasPinnedOffer) {
        throw const BazarGameException(
          'offer_not_accepted',
          'Asteroid cargo requires an accepted trader order.',
        );
      }

      if (state.asteroidExpeditionCompleted) {
        throw const BazarGameException(
          'asteroid_expedition_already_completed',
          'Asteroid expedition has already been completed.',
        );
      }

      final transportId = state.selectedTransportId;
      if (transportId == null || transportId.trim().isEmpty) {
        throw const BazarGameException(
          'transport_not_selected',
          'Asteroid cargo requires a selected Garage transport.',
        );
      }

      final transport = _transportOrThrow(transportId);
      if (state.rentedTransportId != transport.id) {
        throw const BazarGameException(
          'transport_rental_not_confirmed',
          'Asteroid cargo requires a confirmed Garage rental.',
        );
      }

      final asteroidUnits =
          result.cargo.blue + result.cargo.red + result.cargo.green;

      if (result.cargo.wood > 0) {
        throw const BazarGameException(
          'wrong_resource_source',
          'Wood cannot be returned by asteroid quest.',
        );
      }

      if (asteroidUnits > transport.cargoCapacity) {
        throw BazarGameException(
          'cargo_over_capacity',
          'Asteroid cargo exceeds capacity of "${transport.title}".',
        );
      }

      state.asteroidExpeditionCompleted = true;
    }

    if (result.kind == BazarQuestKind.slonWood) {
      if (result.cargo.blue > 0 ||
          result.cargo.red > 0 ||
          result.cargo.green > 0) {
        throw const BazarGameException(
          'wrong_resource_source',
          'SLON quest may return wood, not asteroids.',
        );
      }
    }

    state.processedQuestAttemptIds.add(attemptId);
    state.cargo = state.cargo.add(result.cargo);
    state.phase = BazarPhase.trading;
    return state.cargo;
  }

  BazarDealQuote quoteTrader(
    BazarGameState state,
    String traderId,
  ) {
    final trader = _traderOrThrow(traderId);
    final offer = BazarGameCatalog.offerForTrader(trader.id);
    if (offer == null) {
      throw BazarGameException(
        'missing_trader_offer',
        'Trader "${trader.id}" has no active BAZAR offer.',
      );
    }

    return BazarDealQuote(
      offer: offer,
      availableCargo: state.cargo,
      missingCargo: state.cargo.missingFor(offer.requirements),
    );
  }

  List<BazarDealQuote> quoteAllTraders(BazarGameState state) {
    return BazarGameCatalog.traders
        .map((trader) => quoteTrader(state, trader.id))
        .toList(growable: false);
  }

  BazarDealReceipt completePrimaryDeal(
    BazarGameState state, {
    required String traderId,
  }) {
    if (state.hasPrimaryDeal) {
      throw const BazarGameException(
        'primary_deal_already_completed',
        'Only one primary trader deal is allowed in one BAZAR run.',
      );
    }

    final quote = quoteTrader(state, traderId);
    if (!quote.canComplete) {
      throw BazarGameException(
        'insufficient_cargo',
        'Cargo does not satisfy offer "${quote.offer.id}".',
      );
    }

    final remaining = state.cargo.subtract(quote.offer.requirements);

    state.completedTraderId = quote.offer.traderId;
    state.completedOfferId = quote.offer.id;
    state.primaryDealDar = quote.offer.rewardDar;
    state.sessionEarningsDar += quote.offer.rewardDar;
    state.cargo = remaining;
    state.phase =
        remaining.isEmpty ? BazarPhase.readyToBase : BazarPhase.settling;

    return BazarDealReceipt(
      traderId: quote.offer.traderId,
      offerId: quote.offer.id,
      earnedDar: quote.offer.rewardDar,
      spentCargo: quote.offer.requirements,
      remainingCargo: remaining,
    );
  }

  int quoteBuyer(BazarGameState state) {
    _ensureCanSettleLeftovers(state);
    return buyerPricePolicy.quote(state.cargo);
  }

  int sellLeftoversToBuyer(BazarGameState state) {
    _ensureCanSettleLeftovers(state);

    final payout = buyerPricePolicy.quote(state.cargo);

    state.buyerDar = payout;
    state.sessionEarningsDar += payout;
    state.cargo = const BazarCargo();
    state.leftoverResolution = BazarLeftoverResolution.soldToBuyer;
    state.pendingAstroBoxLot = null;
    state.phase = BazarPhase.readyToBase;

    return payout;
  }

  BazarStoredLot storeLeftoversInAstroBox(BazarGameState state) {
    _ensureCanSettleLeftovers(state);

    final lot = BazarStoredLot(
      cargo: state.cargo,
    );

    state.pendingAstroBoxLot = lot;
    state.astroBoxCargo = state.astroBoxCargo.add(lot.cargo);
    state.cargo = const BazarCargo();
    state.leftoverResolution = BazarLeftoverResolution.storedInAstroBox;
    state.phase = BazarPhase.readyToBase;

    return lot;
  }

  BazarRunResult finalizeRun(BazarGameState state) {
    if (!state.hasPrimaryDeal) {
      throw const BazarGameException(
        'no_primary_deal',
        'BAZAR run cannot finish before a primary trader deal.',
      );
    }

    if (!state.canReturnToBase) {
      throw const BazarGameException(
        'run_not_ready',
        'Resolve leftover cargo before returning to Base.',
      );
    }

    return BazarRunResult(
      totalDarToBase: state.sessionEarningsDar,
      primaryTraderId: state.completedTraderId,
      primaryOfferId: state.completedOfferId,
      primaryDealDar: state.primaryDealDar,
      buyerDar: state.buyerDar,
      astroBoxLot: state.pendingAstroBoxLot,
    );
  }

  BazarOffer _offerOrThrow(String offerId) {
    final normalized = offerId.trim();
    if (normalized.isEmpty) {
      throw const BazarGameException(
        'invalid_offer_id',
        'Offer id must not be empty.',
      );
    }

    final offer = BazarGameCatalog.offerById(normalized);
    if (offer == null) {
      throw BazarGameException(
        'unknown_offer',
        'Unknown BAZAR offer "$normalized".',
      );
    }

    return offer;
  }

  BazarTrader _traderOrThrow(String traderId) {
    final normalized = traderId.trim();
    if (normalized.isEmpty) {
      throw const BazarGameException(
        'invalid_trader_id',
        'Trader id must not be empty.',
      );
    }

    final trader = BazarGameCatalog.traderById(normalized);
    if (trader == null) {
      throw BazarGameException(
        'unknown_trader',
        'Unknown BAZAR trader "$normalized".',
      );
    }

    return trader;
  }

  BazarTransport _transportOrThrow(String transportId) {
    final normalized = transportId.trim();
    if (normalized.isEmpty) {
      throw const BazarGameException(
        'invalid_transport_id',
        'Transport id must not be empty.',
      );
    }

    final transport = BazarGameCatalog.transportById(normalized);
    if (transport == null) {
      throw BazarGameException(
        'unknown_transport',
        'Unknown BAZAR transport "$normalized".',
      );
    }

    return transport;
  }

  void _ensurePrimaryDealNotCompleted(BazarGameState state) {
    if (state.hasPrimaryDeal) {
      throw const BazarGameException(
        'primary_deal_already_completed',
        'Primary deal is already completed for this BAZAR run.',
      );
    }
  }

  void _ensureCanSettleLeftovers(BazarGameState state) {
    if (!state.hasPrimaryDeal) {
      throw const BazarGameException(
        'no_primary_deal',
        'Leftovers can be resolved only after a primary trader deal.',
      );
    }

    if (state.phase != BazarPhase.settling || state.cargo.isEmpty) {
      throw const BazarGameException(
        'no_leftovers',
        'There is no leftover cargo to resolve.',
      );
    }
  }
}