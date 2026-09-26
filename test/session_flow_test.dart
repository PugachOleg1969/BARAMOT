import 'package:baramot/game_state.dart';
import 'package:baramot/economy_models.dart';
import 'package:baramot/planning_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session flow', () {
    test('new profile starts in prologue phase', () {
      final state = GameStateData();
      expect(state.sessionPhase, BaseSessionPhase.prologue);
      expect(state.totalWorkSessionsCompleted, 0);
      expect(state.period, 1);
    });

    test('session state survives JSON round-trip', () {
      final state = GameStateData(
        profileCreated: true,
        period: 3,
        sessionPhase: BaseSessionPhase.evening,
        totalWorkSessionsCompleted: 2,
        morningPetVisited: true,
        morningBarryVisited: true,
        petRequestIdsBySession: const <String>[
          'pet_kwak_want_umbrella',
          'pet_kwak_want_costume',
          'pet_kwak_want_bubble_bath',
        ],
        barryRequestIdsBySession: const <String>[
          'barry_want_pizza',
          'barry_need_hygiene',
          'barry_want_tool_set',
        ],
        eveningSelectedItemIds: const <String>{'barry_want_tool_set'},
      );

      final restored = GameStateData.fromJson(state.toJson());
      expect(restored.sessionPhase, BaseSessionPhase.evening);
      expect(restored.totalWorkSessionsCompleted, 2);
      expect(restored.morningPetVisited, isTrue);
      expect(restored.morningBarryVisited, isTrue);
      expect(restored.currentPetRequestId, 'pet_kwak_want_bubble_bath');
      expect(restored.currentBarryRequestId, 'barry_want_tool_set');
      expect(restored.eveningSelectedItemIds, contains('barry_want_tool_set'));
    });

    test('only one current request per owner is kept for a day', () {
      final state = GameStateData(profileCreated: true, period: 1);
      state.prepareMorningSession();
      state.setDailyRequest(
        ownerId: PlanOwner.pet,
        itemId: 'pet_kwak_want_umbrella',
      );
      state.setDailyRequest(
        ownerId: PlanOwner.pet,
        itemId: 'pet_kwak_want_costume',
      );
      state.setDailyRequest(
        ownerId: PlanOwner.barry,
        itemId: 'barry_want_pizza',
      );

      expect(state.currentPetRequestId, 'pet_kwak_want_costume');
      expect(state.currentBarryRequestId, 'barry_want_pizza');
      expect(
        state.selectedPlanningItemIds,
        containsAll(<String>['pet_kwak_want_costume', 'barry_want_pizza']),
      );
      expect(
        state.selectedPlanningItemIds,
        isNot(contains('pet_kwak_want_umbrella')),
      );
    });

    test('morning round requires both visits and both requests', () {
      final state = GameStateData(profileCreated: true);
      state.prepareMorningSession();
      state.morningPetVisited = true;
      state.setDailyRequest(
        ownerId: PlanOwner.pet,
        itemId: 'pet_kwak_want_umbrella',
      );
      expect(state.morningRoundComplete, isFalse);

      state.morningBarryVisited = true;
      state.setDailyRequest(
        ownerId: PlanOwner.barry,
        itemId: 'barry_want_pizza',
      );
      expect(state.morningRoundComplete, isTrue);
    });

    test('morning plan includes permanent 6 Dar maintenance', () {
      final state = GameStateData(profileCreated: true, walletDar: 12);
      state.prepareMorningSession();
      state.setDailyRequest(
        ownerId: PlanOwner.pet,
        itemId: 'pet_kwak_want_umbrella',
      );
      state.setDailyRequest(
        ownerId: PlanOwner.barry,
        itemId: 'barry_want_pizza',
      );

      final plan = PlanningCatalog.buildBudgetPlan(
        periodId: 1,
        startingWallet: 12,
        selectedIds: state.selectedPlanningItemIds,
        petTypeId: 'kwak',
        selectedGoalId: 'fuel_sensor',
        confirmed: true,
      );

      final mandatory = plan.plannedItems.where((item) => item.mandatory);
      expect(mandatory.fold<int>(0, (sum, item) => sum + item.plannedCost), 6);
      expect(plan.plannedWant, 7);
    });

    test('PHD clears temporary five-day requests but keeps total progress', () {
      final state = GameStateData(
        profileCreated: true,
        period: 5,
        totalWorkSessionsCompleted: 5,
        sessionPhase: BaseSessionPhase.phd,
        petRequestIdsBySession: const <String>['a', 'b', 'c', 'd', 'e'],
        barryRequestIdsBySession: const <String>['f', 'g', 'h', 'i', 'j'],
      );

      state.resetAfterPhd();

      expect(state.period, 1);
      expect(state.petRequestIdsBySession, isEmpty);
      expect(state.barryRequestIdsBySession, isEmpty);
      expect(state.totalWorkSessionsCompleted, 5);
      expect(state.sessionPhase, BaseSessionPhase.closed);
    });
  });
}
