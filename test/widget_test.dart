import 'dart:convert';

import 'package:baramot/economy_engine.dart';
import 'package:baramot/economy_models.dart';
import 'package:baramot/game_state.dart';
import 'package:baramot/planning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameStateData baseline', () {
    test('uses safe defaults', () {
      final state = GameStateData();

      expect(GameStateData.schemaVersion, 8);
      expect(state.walletDar, 0);
      expect(state.savingsDar, 0);
      expect(state.period, 1);
      expect(state.activeGoalId, 'fuel_sensor');
      expect(state.activeGoalTarget, 12);
      expect(state.budgetPlanConfirmed, isFalse);
      expect(state.transactions, isEmpty);
      expect(state.currentPlan, isNull);
      expect(state.petState.care, 0);
      expect(state.petState.mood, 0);
      expect(state.petState.energy, 0);
      expect(state.processedRewardKeys, isEmpty);
      expect(state.astroBox.totalResources, 0);
      expect(state.processedQuestAttemptIds, isEmpty);
      expect(state.selectedPlanningItemIds, isEmpty);
      expect(state.shipRepairUnitsPaid, isEmpty);
      expect(state.shipRepairActiveIds, isEmpty);
    });

    test(
      'schema v8 JSON round-trip preserves economy, planning and resource fields',
      () {
        final state = GameStateData(
          introSeen: true,
          onboardingStep: 10,
          profileCreated: true,
          playerName: 'Архитектор',
          selectedPet: PetType.skorohod,
          petStyle: 2,
          petName: 'Лучик',
          walletDar: 14,
          savingsDar: 5,
          period: 2,
          activeGoalId: 'fuel_sensor',
          activeGoalTitle: 'Датчик топлива',
          activeGoalTarget: 12,
          budgetPlanConfirmed: true,
          planNeed: 4,
          planWant: 3,
          planSave: 5,
          asteroidTrainingCompleted: true,
          currentPlan: BudgetPlan(
            periodId: 2,
            startingWallet: 12,
            plannedNeed: 4,
            plannedWant: 3,
            plannedSavings: 5,
            plannedItems: const <PlannedItem>[
              PlannedItem(
                id: 'need_1',
                category: EconomyCategory.need,
                title: 'Ремонт',
                plannedCost: 4,
                contentRefId: 'repair_1',
                ownerId: PlanOwner.team,
                mandatory: true,
              ),
            ],
            selectedGoalId: 'fuel_sensor',
            confirmed: true,
          ),
          transactions: const <Transaction>[
            Transaction(
              id: 'tx_2_1',
              periodId: 2,
              sequence: 1,
              type: TransactionType.income,
              category: EconomyCategory.income,
              amount: 2,
              sourceId: 'order_1',
              sourceTitle: 'Первый заказ',
              reason: 'За выполненный заказ',
              walletBefore: 12,
              walletAfter: 14,
              savingsBefore: 5,
              savingsAfter: 5,
            ),
          ],
          petState: const PetState(
            care: 1,
            mood: 2,
            energy: 3,
            growthPoints: 4,
            growthStage: 1,
          ),
          processedRewardKeys: const <String>{'reward:first_order'},
          astroBox: const AstroBox(
            blue: 3,
            red: 2,
            green: 1,
            black: 4,
          ),
          processedQuestAttemptIds: const <String>{'attempt_001'},
          selectedPlanningItemIds: const <String>{
            'barry_want_pizza',
            'pet_skorohod_want_books',
          },
          shipRepairUnitsPaid: const <String, int>{
            'repair_fuel_sensor': 1,
          },
          shipRepairActiveIds: const <String>{
            'repair_fuel_sensor',
            'repair_tumannik',
          },
        );

        final json = state.toJson();
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        final restored = GameStateData.fromJson(json);

        expect(decoded['schemaVersion'], 8);
        expect(restored.playerName, 'Архитектор');
        expect(restored.selectedPet, PetType.skorohod);
        expect(restored.walletDar, 14);
        expect(restored.savingsDar, 5);
        expect(restored.currentPlan, isNotNull);
        expect(restored.currentPlan!.startingWallet, 12);
        expect(restored.currentPlan!.plannedItems, hasLength(1));
        expect(
          restored.currentPlan!.plannedItems.single.ownerId,
          PlanOwner.team,
        );
        expect(restored.currentPlan!.plannedItems.single.mandatory, isTrue);
        expect(restored.transactions, hasLength(1));
        expect(restored.transactions.single.type, TransactionType.income);
        expect(restored.transactions.single.walletBefore, 12);
        expect(restored.transactions.single.walletAfter, 14);
        expect(restored.petState.growthPoints, 4);
        expect(
          restored.processedRewardKeys,
          contains('reward:first_order'),
        );
        expect(restored.astroBox.blue, 3);
        expect(restored.astroBox.red, 2);
        expect(restored.astroBox.green, 1);
        expect(restored.astroBox.black, 4);
        expect(restored.astroBox.totalResources, 10);
        expect(
          restored.processedQuestAttemptIds,
          contains('attempt_001'),
        );
        expect(
          restored.selectedPlanningItemIds,
          containsAll(<String>[
            'barry_want_pizza',
            'pet_skorohod_want_books',
          ]),
        );
        expect(restored.shipRepairUnitsPaidFor('repair_fuel_sensor'), 1);
        expect(
          restored.shipRepairActiveIds,
          containsAll(<String>['repair_fuel_sensor', 'repair_tumannik']),
        );
      },
    );

    test('loads old schema v3 and restores a basic confirmed plan', () {
      final oldJson = jsonEncode(<String, Object?>{
        'schemaVersion': 3,
        'introSeen': true,
        'onboardingStep': 10,
        'profileCreated': true,
        'playerName': 'Игрок',
        'selectedPet': 'tsvetik',
        'petStyle': 1,
        'petName': 'Радуга',
        'walletDar': 12,
        'savingsDar': 3,
        'period': 2,
        'activeGoalId': 'fuel_sensor',
        'activeGoalTitle': 'Датчик топлива',
        'activeGoalTarget': 11,
        'budgetPlanConfirmed': true,
        'planNeed': 4,
        'planWant': 2,
        'planSave': 6,
        'asteroidTrainingCompleted': true,
      });

      final state = GameStateData.fromJson(oldJson);

      expect(state.walletDar, 12);
      expect(state.savingsDar, 3);
      expect(state.transactions, isEmpty);
      expect(state.petState.care, 0);
      expect(state.processedRewardKeys, isEmpty);
      expect(state.currentPlan, isNotNull);
      expect(state.currentPlan!.periodId, 2);
      expect(state.currentPlan!.startingWallet, 12);
      expect(state.currentPlan!.plannedNeed, 4);
      expect(state.currentPlan!.plannedWant, 2);
      expect(state.currentPlan!.plannedSavings, 6);
      expect(state.currentPlan!.selectedGoalId, 'fuel_sensor');
      expect(state.currentPlan!.confirmed, isTrue);
    });

    test('loads schema v4 state with empty AstroBox defaults', () {
      final oldJson = jsonEncode(<String, Object?>{
        'schemaVersion': 4,
        'profileCreated': true,
        'walletDar': 12,
        'savingsDar': 0,
        'period': 1,
        'transactions': <Object?>[],
        'processedRewardKeys': <String>[],
      });

      final state = GameStateData.fromJson(oldJson);

      expect(state.walletDar, 12);
      expect(state.astroBox.totalResources, 0);
      expect(state.processedQuestAttemptIds, isEmpty);
    });

    test('loads schema v5 and migrates fuel sensor target to 12', () {
      final oldJson = jsonEncode(<String, Object?>{
        'schemaVersion': 5,
        'profileCreated': true,
        'walletDar': 12,
        'savingsDar': 0,
        'period': 1,
        'activeGoalId': 'fuel_sensor',
        'activeGoalTitle': 'Датчик топлива',
        'activeGoalTarget': 11,
        'transactions': <Object?>[],
        'processedRewardKeys': <String>[],
        'processedQuestAttemptIds': <String>[],
      });

      final state = GameStateData.fromJson(oldJson);

      expect(state.activeGoalTarget, 12);
      expect(state.selectedPlanningItemIds, isEmpty);
    });

    test('loads schema v6 with planning item ids preserved', () {
      final oldJson = jsonEncode(<String, Object?>{
        'schemaVersion': 6,
        'profileCreated': true,
        'walletDar': 12,
        'savingsDar': 0,
        'period': 1,
        'activeGoalId': 'fuel_sensor',
        'activeGoalTitle': 'Датчик топлива',
        'activeGoalTarget': 12,
        'transactions': <Object?>[],
        'processedRewardKeys': <String>[],
        'processedQuestAttemptIds': <String>[],
        'selectedPlanningItemIds': <String>['barry_want_pizza'],
      });

      final state = GameStateData.fromJson(oldJson);

      expect(state.walletDar, 12);
      expect(state.selectedPlanningItemIds, contains('barry_want_pizza'));
    });

    test('loads old or partial JSON with safe defaults', () {
      final state = GameStateData.fromJson(
        jsonEncode(<String, Object?>{
          'introSeen': true,
          'playerName': 'Пилот',
          'walletDar': 7,
        }),
      );

      expect(state.introSeen, isTrue);
      expect(state.playerName, 'Пилот');
      expect(state.onboardingStep, 2);
      expect(state.walletDar, 7);
      expect(state.savingsDar, 0);
      expect(state.period, 1);
      expect(state.selectedPet, PetType.kwak);
      expect(state.transactions, isEmpty);
      expect(state.currentPlan, isNull);
    });

    test('planning item selection helpers are idempotent and ignore empty ids', () {
      final state = GameStateData();

      expect(state.selectPlanningItem('barry_want_pizza'), isTrue);
      expect(state.selectPlanningItem('barry_want_pizza'), isFalse);
      expect(state.isPlanningItemSelected('barry_want_pizza'), isTrue);
      expect(state.selectPlanningItem('   '), isFalse);
      expect(state.unselectPlanningItem('barry_want_pizza'), isTrue);
      expect(state.unselectPlanningItem('barry_want_pizza'), isFalse);
      expect(state.isPlanningItemSelected('barry_want_pizza'), isFalse);
    });

    test('goalRemaining and plannedTotal stay compatible', () {
      final state = GameStateData(
        savingsDar: 4,
        activeGoalTarget: 11,
        planNeed: 3,
        planWant: 2,
        planSave: 5,
      );

      expect(state.goalRemaining, 7);
      expect(state.plannedTotal, 10);
    });
  });

  group('Quest cargo and AstroBox', () {
    test('AstroBox adds cargo without changing cargo object', () {
      const box = AstroBox(blue: 1, red: 2);
      const cargo = Cargo(
        blue: 2,
        red: 1,
        green: 1,
        black: 0,
        capacityMax: 4,
      );

      final updated = box.addCargo(cargo);

      expect(box.totalResources, 3);
      expect(updated.blue, 3);
      expect(updated.red, 3);
      expect(updated.green, 1);
      expect(updated.black, 0);
      expect(updated.totalResources, 7);
      expect(cargo.capacityUsed, 4);
    });

    test('successful QuestResult is stored once by attemptId', () {
      final state = GameStateData();
      const result = QuestResult(
        questId: 'asteroid_training',
        transportId: 'chikh_pykh',
        cargo: Cargo(
          blue: 1,
          red: 1,
          green: 1,
          black: 1,
          capacityMax: 4,
        ),
        success: true,
        duration: Duration(seconds: 18),
        attemptId: 'attempt_unique_1',
      );

      final firstStored = state.storeQuestCargo(result);
      final secondStored = state.storeQuestCargo(result);

      expect(firstStored, isTrue);
      expect(secondStored, isFalse);
      expect(state.astroBox.totalResources, 4);
      expect(state.processedQuestAttemptIds, <String>{'attempt_unique_1'});
      expect(state.walletDar, 0);
      expect(state.transactions, isEmpty);
    });

    test('failed or invalid QuestResult is not stored', () {
      final state = GameStateData();
      const failed = QuestResult(
        questId: 'asteroid_training',
        transportId: 'chikh_pykh',
        cargo: Cargo(blue: 2, capacityMax: 4),
        success: false,
        duration: Duration(seconds: 45),
        attemptId: 'attempt_failed',
      );
      const overCapacity = QuestResult(
        questId: 'asteroid_training',
        transportId: 'chikh_pykh',
        cargo: Cargo(blue: 5, capacityMax: 4),
        success: true,
        duration: Duration(seconds: 10),
        attemptId: 'attempt_over_capacity',
      );

      expect(state.storeQuestCargo(failed), isFalse);
      expect(state.storeQuestCargo(overCapacity), isFalse);
      expect(state.astroBox.totalResources, 0);
      expect(state.processedQuestAttemptIds, isEmpty);
    });
  });

  group('AstroBox resource helpers', () {
    const requirements = AstroBox(
      blue: 2,
      red: 1,
      black: 1,
    );

    test('AstroBox checks whether order requirements are available', () {
      const enough = AstroBox(blue: 3, red: 1, green: 5, black: 2);
      const missing = AstroBox(blue: 1, red: 1, green: 5, black: 2);

      expect(enough.hasAtLeast(requirements), isTrue);
      expect(missing.hasAtLeast(requirements), isFalse);
    });

    test('AstroBox subtracts only requested resources', () {
      const box = AstroBox(blue: 3, red: 2, green: 4, black: 1);

      final remaining = box.subtract(requirements);

      expect(remaining.blue, 1);
      expect(remaining.red, 1);
      expect(remaining.green, 4);
      expect(remaining.black, 0);
      expect(box.blue, 3);
      expect(
        () => const AstroBox(blue: 1).subtract(requirements),
        throwsStateError,
      );
    });

  });

  group('EconomyTuning', () {
    test('approved five-period economy constants stay coherent', () {
      expect(EconomyTuning.mandatoryCostPerDependent, 3);
      expect(EconomyTuning.mandatoryCostPerPeriod, 6);
      expect(EconomyTuning.minimumPeriodIncome, 8);
      expect(EconomyTuning.normalPeriodIncome, 12);
      expect(EconomyTuning.maximumPeriodIncome, 18);
      expect(EconomyTuning.firstBazarOrderReward, 8);
      expect(
        EconomyTuning.normalIncomeByPeriod,
        orderedEquals(<int>[8, 10, 12, 14, 16]),
      );
      expect(
        EconomyTuning.normalIncomeByPeriod.reduce((a, b) => a + b),
        60,
      );
      expect(EconomyTuning.mandatoryCostPerPeriod * 5, 30);
    });
  });

  group('PlanningCatalog', () {
    test('Barry mandatory maintenance costs exactly 3 Dar', () {
      final items = PlanningCatalog.mandatoryForOwner(PlanOwner.barry);

      expect(items, hasLength(3));
      expect(PlanningCatalog.sumCost(items), 3);
      expect(
        items.map((item) => item.title),
        containsAll(<String>[
          'Вода артезианская, 1 л',
          'Каша овсяная из генератора',
          'Комплект «Космос» — обед и ужин',
        ]),
      );
    });

    test('every pet has exactly 3 Dar of mandatory maintenance', () {
      for (final pet in PetType.values) {
        final items = PlanningCatalog.mandatoryForOwner(
          PlanOwner.pet,
          petTypeId: pet.id,
        );

        expect(items, hasLength(3), reason: pet.id);
        expect(PlanningCatalog.sumCost(items), 3, reason: pet.id);
      }
    });

    test('pet wants and dreams keep the approved price ladder', () {
      final kwak = PlanningCatalog.forOwner(
        PlanOwner.pet,
        petTypeId: PetType.kwak.id,
      );
      final skorohod = PlanningCatalog.forOwner(
        PlanOwner.pet,
        petTypeId: PetType.skorohod.id,
      );
      final tsvetik = PlanningCatalog.forOwner(
        PlanOwner.pet,
        petTypeId: PetType.tsvetik.id,
      );

      expect(
        kwak.firstWhere((item) => item.id == 'pet_kwak_want_costume').cost,
        6,
      );
      expect(
        kwak
            .firstWhere(
              (item) => item.id == 'pet_kwak_planned_rolls_royce',
            )
            .cost,
        60,
      );
      expect(
        skorohod
            .firstWhere(
              (item) => item.id == 'pet_skorohod_planned_star_yacht',
            )
            .cost,
        90,
      );
      expect(
        tsvetik
            .firstWhere(
              (item) => item.id == 'pet_tsvetik_planned_flower_plantation',
            )
            .cost,
        80,
      );
    });

    test('"nothing needed" is a free choice available for every pet type', () {
      for (final pet in PetType.values) {
        final items = PlanningCatalog.forOwner(PlanOwner.pet, petTypeId: pet.id);
        final nothing = items.firstWhere(
          (item) => item.id == 'pet_want_nothing',
          orElse: () => throw StateError('missing for ${pet.id}'),
        );

        expect(nothing.cost, 0, reason: pet.id);
        expect(nothing.mandatory, isFalse, reason: pet.id);
      }
    });

    test('team repair ladder starts at 12 Dar for fuel sensor', () {
      final team = PlanningCatalog.forOwner(PlanOwner.team);
      final fuelSensor = team.firstWhere(
        (item) => item.id == 'team_need_fuel_sensor',
      );
      final newShip = team.firstWhere(
        (item) => item.id == 'team_planned_new_ship',
      );

      expect(fuelSensor.cost, 12);
      expect(newShip.cost, 120);
    });

    test('commander plan always includes 6 Dar mandatory maintenance', () {
      final items = PlanningCatalog.commanderPlanItems(
        selectedIds: const <String>{
          'barry_want_pizza',
          'pet_kwak_want_umbrella',
          'team_need_fuel_sensor',
        },
        petTypeId: PetType.kwak.id,
      );

      final mandatory = items.where((item) => item.mandatory);
      final selected = items.where((item) => !item.mandatory);

      expect(PlanningCatalog.sumCost(mandatory), 6);
      expect(
        selected.map((item) => item.id),
        contains('barry_want_pizza'),
      );
      expect(
        selected.map((item) => item.id),
        contains('pet_kwak_want_umbrella'),
      );
      expect(
        selected.map((item) => item.id),
        contains('team_need_fuel_sensor'),
      );
    });

    test(
      'budget plan counts current needs and wants but keeps future goals separate',
      () {
        final plan = PlanningCatalog.buildBudgetPlan(
          periodId: 1,
          startingWallet: 12,
          selectedIds: const <String>{
            'barry_want_pizza',
            'pet_kwak_want_umbrella',
            'pet_kwak_planned_rolls_royce',
          },
          petTypeId: PetType.kwak.id,
          selectedGoalId: 'fuel_sensor',
          plannedSavings: 2,
        );

        expect(plan.plannedNeed, 6);
        expect(plan.plannedWant, 7);
        expect(plan.plannedSavings, 2);
        expect(plan.plannedTotal, 15);
        expect(
          plan.plannedItems.map((item) => item.id),
          contains('pet_kwak_planned_rolls_royce'),
        );
        final dream = plan.plannedItems.firstWhere(
          (item) => item.id == 'pet_kwak_planned_rolls_royce',
        );
        expect(dream.category, PlanCategory.planned);
        expect(dream.ownerId, PlanOwner.pet);
        expect(dream.plannedCost, 60);
        expect(dream.mandatory, isFalse);
      },
    );

    test('selected item from another pet is ignored by commander plan', () {
      final items = PlanningCatalog.commanderPlanItems(
        selectedIds: const <String>{
          'pet_skorohod_want_books',
          'pet_kwak_want_umbrella',
        },
        petTypeId: PetType.kwak.id,
      );

      expect(
        items.map((item) => item.id),
        isNot(contains('pet_skorohod_want_books')),
      );
      expect(
        items.map((item) => item.id),
        contains('pet_kwak_want_umbrella'),
      );
    });
  });

  group('EconomyEngine', () {
    const engine = EconomyEngine();

    test('addIncome updates wallet and creates income transaction', () {
      final state = GameStateData(walletDar: 12, savingsDar: 2);

      final transaction = engine.addIncome(
        state,
        amount: 5,
        sourceId: 'order_001',
        sourceTitle: 'Заказ Рура',
        reason: 'За выполненный заказ',
      );

      expect(state.walletDar, 17);
      expect(state.savingsDar, 2);
      expect(state.transactions, hasLength(1));
      expect(transaction.type, TransactionType.income);
      expect(transaction.amount, 5);
      expect(transaction.walletBefore, 12);
      expect(transaction.walletAfter, 17);
      expect(transaction.savingsBefore, 2);
      expect(transaction.savingsAfter, 2);
    });

    test('engine refuses to operate on a negative balance state', () {
      final state = GameStateData(walletDar: 1);
      state.walletDar = -1;

      expect(
        () => engine.addIncome(
          state,
          amount: 1,
          sourceId: 'invalid_state_test',
          sourceTitle: 'Тест',
          reason: 'Проверка инварианта',
        ),
        throwsStateError,
      );
      expect(state.transactions, isEmpty);
    });

    test('successful need purchase updates wallet and transaction', () {
      final state = GameStateData(walletDar: 12, savingsDar: 3);

      final transaction = engine.purchaseNeed(
        state,
        price: 4,
        sourceId: 'repair_sensor',
        sourceTitle: 'Ремонт датчика',
        reason: 'Необходимый ремонт',
      );

      expect(state.walletDar, 8);
      expect(state.savingsDar, 3);
      expect(state.transactions, hasLength(1));
      expect(transaction.type, TransactionType.needExpense);
      expect(transaction.category, EconomyCategory.need);
      expect(transaction.amount, 4);
      expect(transaction.walletBefore, 12);
      expect(transaction.walletAfter, 8);
    });

    test('purchase with insufficient funds does not change state', () {
      final state = GameStateData(walletDar: 3, savingsDar: 5);

      expect(
        () => engine.purchaseWant(
          state,
          price: 4,
          sourceId: 'toy_1',
          sourceTitle: 'Игрушка',
          reason: 'Покупка ХОЧУ',
        ),
        throwsA(
          isA<EconomyException>().having(
            (error) => error.code,
            'code',
            'insufficient_wallet',
          ),
        ),
      );

      expect(state.walletDar, 3);
      expect(state.savingsDar, 5);
      expect(state.transactions, isEmpty);
    });

    test('depositSavings moves Dar from wallet to savings', () {
      final state = GameStateData(walletDar: 10, savingsDar: 2);

      final transaction = engine.depositSavings(state, amount: 4);

      expect(state.walletDar, 6);
      expect(state.savingsDar, 6);
      expect(transaction.type, TransactionType.savingDeposit);
      expect(transaction.amount, 4);
      expect(transaction.walletBefore, 10);
      expect(transaction.walletAfter, 6);
      expect(transaction.savingsBefore, 2);
      expect(transaction.savingsAfter, 6);
    });

    test('withdrawSavings moves Dar from savings to wallet', () {
      final state = GameStateData(walletDar: 4, savingsDar: 8);

      final transaction = engine.withdrawSavings(state, amount: 3);

      expect(state.walletDar, 7);
      expect(state.savingsDar, 5);
      expect(transaction.type, TransactionType.savingWithdrawal);
      expect(transaction.amount, 3);
      expect(transaction.walletBefore, 4);
      expect(transaction.walletAfter, 7);
      expect(transaction.savingsBefore, 8);
      expect(transaction.savingsAfter, 5);
    });

    test('saving operations refuse insufficient balances', () {
      final depositState = GameStateData(walletDar: 2, savingsDar: 0);
      final withdrawalState = GameStateData(walletDar: 2, savingsDar: 1);

      expect(
        () => engine.depositSavings(depositState, amount: 3),
        throwsA(
          isA<EconomyException>().having(
            (error) => error.code,
            'code',
            'insufficient_wallet',
          ),
        ),
      );
      expect(
        () => engine.withdrawSavings(withdrawalState, amount: 2),
        throwsA(
          isA<EconomyException>().having(
            (error) => error.code,
            'code',
            'insufficient_savings',
          ),
        ),
      );

      expect(depositState.walletDar, 2);
      expect(depositState.savingsDar, 0);
      expect(depositState.transactions, isEmpty);
      expect(withdrawalState.walletDar, 2);
      expect(withdrawalState.savingsDar, 1);
      expect(withdrawalState.transactions, isEmpty);
    });

    test('every successful operation creates ordered transaction snapshots', () {
      final state = GameStateData(
        walletDar: 10,
        savingsDar: 2,
        period: 3,
      );

      engine.addIncome(
        state,
        amount: 5,
        sourceId: 'income',
        sourceTitle: 'Доход',
        reason: 'Тест',
      );
      engine.purchaseNeed(
        state,
        price: 2,
        sourceId: 'need',
        sourceTitle: 'НАДО',
        reason: 'Тест',
      );
      engine.purchaseWant(
        state,
        price: 1,
        sourceId: 'want',
        sourceTitle: 'ХОЧУ',
        reason: 'Тест',
      );
      engine.depositSavings(state, amount: 3);
      engine.withdrawSavings(state, amount: 1);

      expect(state.transactions, hasLength(5));
      expect(
        state.transactions.map((transaction) => transaction.sequence),
        orderedEquals(<int>[1, 2, 3, 4, 5]),
      );
      expect(
        state.transactions.map((transaction) => transaction.id),
        orderedEquals(<String>[
          'tx_3_1',
          'tx_3_2',
          'tx_3_3',
          'tx_3_4',
          'tx_3_5',
        ]),
      );
      expect(
        state.transactions.map((transaction) => transaction.type),
        orderedEquals(<TransactionType>[
          TransactionType.income,
          TransactionType.needExpense,
          TransactionType.wantExpense,
          TransactionType.savingDeposit,
          TransactionType.savingWithdrawal,
        ]),
      );
    });

    test('calculateFact derives values only from transactions', () {
      final state = GameStateData(walletDar: 10, savingsDar: 2, period: 1);

      engine.addIncome(
        state,
        amount: 10,
        sourceId: 'order',
        sourceTitle: 'Заказ',
        reason: 'Доход за работу',
      );
      engine.purchaseNeed(
        state,
        price: 3,
        sourceId: 'need',
        sourceTitle: 'НАДО',
        reason: 'Обязательная покупка',
      );
      engine.purchaseWant(
        state,
        price: 4,
        sourceId: 'want',
        sourceTitle: 'ХОЧУ',
        reason: 'Желаемая покупка',
      );
      engine.depositSavings(state, amount: 5);
      engine.withdrawSavings(state, amount: 2);

      final fact = engine.calculateFact(state);

      expect(fact.periodId, 1);
      expect(fact.income, 10);
      expect(fact.actualNeed, 3);
      expect(fact.actualWant, 4);
      expect(fact.actualSavings, 3);
      expect(fact.walletEnd, 10);
      expect(fact.savingsEnd, 5);
    });

    test('rewardKey prevents duplicate income without second transaction', () {
      final state = GameStateData(walletDar: 0);

      engine.addIncome(
        state,
        amount: 5,
        sourceId: 'training_reward',
        sourceTitle: 'Тренировка',
        reason: 'Одноразовая награда',
        rewardKey: 'reward:asteroid_training',
      );

      expect(
        () => engine.addIncome(
          state,
          amount: 5,
          sourceId: 'training_reward',
          sourceTitle: 'Тренировка',
          reason: 'Одноразовая награда',
          rewardKey: 'reward:asteroid_training',
        ),
        throwsA(
          isA<EconomyException>().having(
            (error) => error.code,
            'code',
            'duplicate_reward',
          ),
        ),
      );

      expect(state.walletDar, 5);
      expect(state.transactions, hasLength(1));
      expect(
        state.processedRewardKeys,
        contains('reward:asteroid_training'),
      );
    });
  });
}
