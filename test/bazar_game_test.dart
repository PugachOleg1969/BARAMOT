import 'package:baramot/bazar_game_catalog.dart';
import 'package:baramot/bazar_game_engine.dart';
import 'package:baramot/bazar_game_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = BazarGameEngine();

  group('BAZAR catalog', () {
    test('contains four traders', () {
      expect(BazarGameCatalog.traders, hasLength(4));
      expect(BazarGameCatalog.offers, hasLength(4));
    });

    test('every first offer asks for three asteroid colors and SLON wood', () {
      for (final offer in BazarGameCatalog.offers) {
        expect(offer.requirements.blue, greaterThan(0), reason: offer.id);
        expect(offer.requirements.red, greaterThan(0), reason: offer.id);
        expect(offer.requirements.green, greaterThan(0), reason: offer.id);
        expect(offer.requirements.wood, greaterThan(0), reason: offer.id);
      }
    });

    test('Chikh-Pykh collects asteroids but does not fly to SLON', () {
      expect(BazarGameCatalog.chikhPykh.canCollectAsteroids, isTrue);
      expect(BazarGameCatalog.chikhPykh.canFlyToSlon, isFalse);
      expect(BazarGameCatalog.transports, hasLength(3));
      expect(BazarGameCatalog.chikhPykh.rentalCostDar, 0);
      expect(BazarGameCatalog.unter.rentalCostDar, 5);
      expect(BazarGameCatalog.maestro.rentalCostDar, 15);
      expect(BazarGameCatalog.chikhPykh.expeditionReady, isTrue);
      expect(BazarGameCatalog.unter.expeditionReady, isFalse);
      expect(BazarGameCatalog.maestro.expeditionReady, isFalse);
    });

    test('offer rewards equal the value of requested resources plus trade margin', () {
      // Осознанное изменение баланса: раньше сделка платила ровно
      // сырьевую стоимость груза (0 маржи). Теперь торговец сверху
      // платит фиксированную наценку (tradeMarginDar) — это увеличивает
      // свободный доход Командора и нужно, среди прочего, для того чтобы
      // ремонт корабля закрывался за разумное число сессий.
      for (final offer in BazarGameCatalog.offers) {
        expect(
          offer.rewardDar,
          BazarGameCatalog.cargoValueDar(offer.requirements) +
              BazarGameCatalog.tradeMarginDar,
          reason: offer.id,
        );
      }
    });
  });

  group('offer planning', () {
    test('pinning an offer is not a deal and does not create income', () {
      final state = BazarGameState();

      final offer = engine.pinOffer(
        state,
        BazarGameCatalog.mechanicOffer.id,
      );

      expect(offer.id, BazarGameCatalog.mechanicOffer.id);
      expect(state.pinnedOfferId, offer.id);
      expect(state.phase, BazarPhase.planning);
      expect(state.sessionEarningsDar, 0);
      expect(state.completedOfferId, isNull);
      expect(state.cargo.isEmpty, isTrue);
    });

    test('player may change the pinned offer before trading', () {
      final state = BazarGameState();

      engine.pinOffer(state, BazarGameCatalog.mechanicOffer.id);
      engine.pinOffer(state, BazarGameCatalog.reagentsOffer.id);

      expect(
        state.pinnedOfferId,
        BazarGameCatalog.reagentsOffer.id,
      );
      expect(state.sessionEarningsDar, 0);
    });
  });

  group('quest bridge', () {
    test('asteroid quest requires Garage transport', () {
      final state = BazarGameState();
      engine.pinOffer(state, BazarGameCatalog.mechanicOffer.id);

      expect(
        () => engine.createQuestRequest(
          state,
          BazarQuestKind.asteroids,
        ),
        throwsA(
          isA<BazarGameException>().having(
            (error) => error.code,
            'code',
            'transport_not_selected',
          ),
        ),
      );

      engine.selectTransport(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );
      engine.markTransportRentalPaid(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );

      final request = engine.createQuestRequest(
        state,
        BazarQuestKind.asteroids,
      );

      expect(request.transportId, BazarGameCatalog.chikhPykhTransportId);
      expect(request.cargoCapacity, BazarGameCatalog.chikhPykh.cargoCapacity);
      expect(request.missionTitle, BazarGameCatalog.mechanicOffer.title);
      expect(request.requiredCargo?.blue, 2);
      expect(request.requiredCargo?.red, 1);
      expect(request.requiredCargo?.green, 1);
      expect(request.requiredCargo?.wood, 0);
    });

    test('future transport cannot enter expedition before its mini-game exists', () {
      final state = BazarGameState();
      engine.pinOffer(state, BazarGameCatalog.mechanicOffer.id);

      expect(
        () => engine.selectTransport(
          state,
          BazarGameCatalog.unterTransportId,
        ),
        throwsA(
          isA<BazarGameException>().having(
            (error) => error.code,
            'code',
            'transport_expedition_not_ready',
          ),
        ),
      );
      expect(state.selectedTransportId, isNull);
      expect(state.rentedTransportId, isNull);
    });

    test('SLON request is separate from Garage transport', () {
      final state = BazarGameState();

      final request = engine.createQuestRequest(
        state,
        BazarQuestKind.slonWood,
      );

      expect(request.kind, BazarQuestKind.slonWood);
      expect(request.transportId, isNull);
      expect(request.cargoCapacity, isNull);
    });

    test('asteroid and SLON results merge into one BAZAR cargo', () {
      final state = BazarGameState();
      engine.pinOffer(state, BazarGameCatalog.mechanicOffer.id);
      engine.selectTransport(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );
      engine.markTransportRentalPaid(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );

      engine.receiveQuestCargo(
        state,
        const BazarQuestCargoResult(
          attemptId: 'asteroid_1',
          kind: BazarQuestKind.asteroids,
          cargo: BazarCargo(
            blue: 2,
            red: 2,
            green: 2,
          ),
        ),
      );

      final cargo = engine.receiveQuestCargo(
        state,
        const BazarQuestCargoResult(
          attemptId: 'slon_1',
          kind: BazarQuestKind.slonWood,
          cargo: BazarCargo(wood: 2),
        ),
      );

      expect(cargo.blue, 2);
      expect(cargo.red, 2);
      expect(cargo.green, 2);
      expect(cargo.wood, 2);
      expect(state.phase, BazarPhase.trading);
      expect(state.sessionEarningsDar, 0);
    });

    test('duplicate quest attempt is rejected', () {
      final state = BazarGameState();
      engine.pinOffer(state, BazarGameCatalog.mechanicOffer.id);
      engine.selectTransport(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );
      engine.markTransportRentalPaid(
        state,
        BazarGameCatalog.chikhPykhTransportId,
      );

      const result = BazarQuestCargoResult(
        attemptId: 'same_attempt',
        kind: BazarQuestKind.asteroids,
        cargo: BazarCargo(blue: 1),
      );

      engine.receiveQuestCargo(state, result);

      expect(
        () => engine.receiveQuestCargo(state, result),
        throwsA(
          isA<BazarGameException>().having(
            (error) => error.code,
            'code',
            'duplicate_quest_result',
          ),
        ),
      );
    });
  });

  group('trading', () {
    BazarGameState loadedState() {
      return BazarGameState(
        phase: BazarPhase.trading,
        pinnedOfferId: BazarGameCatalog.mechanicOffer.id,
        selectedTransportId: BazarGameCatalog.chikhPykhTransportId,
        rentedTransportId: BazarGameCatalog.chikhPykhTransportId,
        transportRentalPaidDar: 0,
        asteroidExpeditionCompleted: true,
        cargo: const BazarCargo(
          blue: 3,
          red: 3,
          green: 3,
          wood: 2,
        ),
      );
    }

    test('pinned offer does not lock the final buyer', () {
      final state = loadedState();

      final receipt = engine.completePrimaryDeal(
        state,
        traderId: BazarGameCatalog.reagentsTraderId,
      );

      expect(
        state.pinnedOfferId,
        BazarGameCatalog.mechanicOffer.id,
      );
      expect(
        receipt.traderId,
        BazarGameCatalog.reagentsTraderId,
      );
      expect(
        receipt.offerId,
        BazarGameCatalog.reagentsOffer.id,
      );
      expect(receipt.earnedDar, BazarGameCatalog.reagentsOffer.rewardDar);
      expect(receipt.remainingCargo.blue, 2);
      expect(receipt.remainingCargo.red, 1);
      expect(receipt.remainingCargo.green, 2);
      expect(receipt.remainingCargo.wood, 1);
      expect(state.cargo.blue, 2);
      expect(state.cargo.red, 1);
      expect(state.cargo.green, 2);
      expect(state.cargo.wood, 1);
      expect(state.sessionEarningsDar, receipt.earnedDar);
      expect(state.phase, BazarPhase.settling);
    });

    test('quotes show which trader can accept current cargo', () {
      final state = BazarGameState(
        cargo: const BazarCargo(
          blue: 2,
          red: 1,
          green: 1,
          wood: 1,
        ),
      );

      final mechanic = engine.quoteTrader(
        state,
        BazarGameCatalog.mechanicTraderId,
      );
      final reagents = engine.quoteTrader(
        state,
        BazarGameCatalog.reagentsTraderId,
      );

      expect(mechanic.canComplete, isTrue);
      expect(reagents.canComplete, isFalse);
      expect(reagents.missingCargo.red, 1);
    });

    test('deal does not allow a second primary trader sale in one run', () {
      final state = loadedState();

      engine.completePrimaryDeal(
        state,
        traderId: BazarGameCatalog.mechanicTraderId,
      );

      expect(
        () => engine.completePrimaryDeal(
          state,
          traderId: BazarGameCatalog.raritiesTraderId,
        ),
        throwsA(
          isA<BazarGameException>().having(
            (error) => error.code,
            'code',
            'primary_deal_already_completed',
          ),
        ),
      );
    });
  });

  group('leftovers', () {
    BazarGameState afterDeal() {
      final state = BazarGameState(
        phase: BazarPhase.trading,
        cargo: const BazarCargo(
          blue: 3,
          red: 2,
          green: 2,
          wood: 2,
        ),
      );

      engine.completePrimaryDeal(
        state,
        traderId: BazarGameCatalog.mechanicTraderId,
      );

      return state;
    }

    test('buyer pays 20 percent below the real leftover cargo value', () {
      final state = afterDeal();
      final before = state.sessionEarningsDar;

      // После сделки механика остаётся: 1 синий + 1 красный +
      // 1 зелёный + 1 дрова = 1 + 2 + 3 + 1 = 7 Дар.
      // Скупщик платит 80%. Экономика целочисленная: 5.6 -> 5 Дар.
      expect(engine.quoteBuyer(state), 5);

      final buyerPayout = engine.sellLeftoversToBuyer(state);
      final result = engine.finalizeRun(state);

      expect(buyerPayout, 5);
      expect(state.cargo.isEmpty, isTrue);
      expect(state.leftoverResolution, BazarLeftoverResolution.soldToBuyer);
      expect(result.primaryDealDar, before);
      expect(result.buyerDar, buyerPayout);
      expect(result.totalDarToBase, before + buyerPayout);
      expect(result.astroBoxLot, isNull);
    });

    test('control example uses resource prices 1 / 2 / 3', () {
      const fullCargo = BazarCargo(
        blue: 3,
        red: 2,
        green: 3,
      );
      const soldCargo = BazarCargo(
        blue: 2,
        red: 2,
        green: 2,
      );
      final leftovers = fullCargo.subtract(soldCargo);
      const policy = BazarBuyerPricePolicy();

      expect(BazarGameCatalog.cargoValueDar(fullCargo), 16);
      expect(BazarGameCatalog.cargoValueDar(soldCargo), 12);
      expect(BazarGameCatalog.cargoValueDar(leftovers), 4);
      expect(policy.quote(leftovers), 3); // 3.2 -> 3 целых Дар.
      expect(12 + policy.quote(leftovers), 15);
    });

    test('AstroBox clears current cargo for free and does not change earnings', () {
      final state = afterDeal();
      final before = state.sessionEarningsDar;

      final lot = engine.storeLeftoversInAstroBox(state);
      final result = engine.finalizeRun(state);

      expect(lot.cargo.isNotEmpty, isTrue);
      expect(state.cargo.isEmpty, isTrue);
      expect(
        state.leftoverResolution,
        BazarLeftoverResolution.storedInAstroBox,
      );
      expect(state.sessionEarningsDar, before);
      expect(state.astroBoxCargo.totalUnits, lot.cargo.totalUnits);
      expect(result.totalDarToBase, before);
      expect(result.buyerDar, 0);
      expect(result.astroBoxLot, isNotNull);
      expect(result.astroBoxLot!.cargo.totalUnits, lot.cargo.totalUnits);
    });

    test('exact trader cargo skips leftover settlement', () {
      final offer = BazarGameCatalog.mechanicOffer;
      final state = BazarGameState(
        phase: BazarPhase.trading,
        cargo: offer.requirements,
      );

      engine.completePrimaryDeal(
        state,
        traderId: offer.traderId,
      );

      expect(state.phase, BazarPhase.readyToBase);
      expect(state.cargo.isEmpty, isTrue);

      final result = engine.finalizeRun(state);
      expect(result.totalDarToBase, offer.rewardDar);
    });
  });

  group('persistence', () {
    test('BAZAR game state round-trip preserves run data', () {
      final original = BazarGameState(
        sessionId: 'session_test_1',
        phase: BazarPhase.settling,
        pinnedOfferId: BazarGameCatalog.mechanicOffer.id,
        selectedTransportId: BazarGameCatalog.chikhPykhTransportId,
        rentedTransportId: BazarGameCatalog.chikhPykhTransportId,
        transportRentalPaidDar: 0,
        asteroidExpeditionCompleted: true,
        cargo: const BazarCargo(
          blue: 1,
          green: 1,
          wood: 1,
        ),
        astroBoxCargo: const BazarCargo(
          blue: 4,
          red: 2,
        ),
        sessionEarningsDar: 8,
        completedTraderId: BazarGameCatalog.mechanicTraderId,
        completedOfferId: BazarGameCatalog.mechanicOffer.id,
        primaryDealDar: 8,
        processedQuestAttemptIds: const <String>{
          'asteroid_1',
          'slon_1',
        },
      );

      final restored = BazarGameState.fromMap(original.toMap());

      expect(restored.sessionId, 'session_test_1');
      expect(restored.phase, BazarPhase.settling);
      expect(restored.pinnedOfferId, original.pinnedOfferId);
      expect(restored.selectedTransportId, original.selectedTransportId);
      expect(restored.rentedTransportId, original.rentedTransportId);
      expect(restored.transportRentalPaidDar, 0);
      expect(restored.asteroidExpeditionCompleted, isTrue);
      expect(restored.cargo.blue, 1);
      expect(restored.cargo.green, 1);
      expect(restored.cargo.wood, 1);
      expect(restored.astroBoxCargo.isEmpty, isTrue);
      expect(original.astroBoxCargo.blue, 4);
      expect(original.toMap().containsKey('astroBoxCargo'), isFalse);
      expect(restored.sessionEarningsDar, 8);
      expect(restored.completedTraderId, original.completedTraderId);
      expect(restored.completedOfferId, original.completedOfferId);
      expect(
        restored.processedQuestAttemptIds,
        containsAll(<String>['asteroid_1', 'slon_1']),
      );
    });


    test('resetForNewRun clears in-memory AstroBox leftovers', () {
      final state = BazarGameState(
        astroBoxCargo: const BazarCargo(blue: 4, red: 2),
        leftoverResolution: BazarLeftoverResolution.storedInAstroBox,
        pendingAstroBoxLot: const BazarStoredLot(
          cargo: BazarCargo(blue: 4, red: 2),
        ),
      );

      state.resetForNewRun();

      expect(state.astroBoxCargo.isEmpty, isTrue);
      expect(state.pendingAstroBoxLot, isNull);
      expect(state.leftoverResolution, BazarLeftoverResolution.none);
    });

  });
}
