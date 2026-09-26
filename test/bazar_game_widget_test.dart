import 'package:baramot/bazar_game_catalog.dart';
import 'package:baramot/bazar_game_models.dart';
import 'package:baramot/bazar_game_screen.dart';
import 'package:baramot/bazar_game_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBazarStore implements BazarGameStateStore {
  BazarGameState state = BazarGameState();

  @override
  Future<void> clear() async {
    state = BazarGameState();
  }

  @override
  Future<BazarGameState> load() async {
    return BazarGameState.fromMap(state.toMap());
  }

  @override
  Future<void> save(BazarGameState newState) async {
    state = BazarGameState.fromMap(newState.toMap());
  }
}

Widget _app({
  required _MemoryBazarStore store,
  ValueChanged<BazarRunResult>? onFinished,
  BazarIncomeHandler? onIncome,
  BazarExpenseHandler? onExpense,
  BazarQuestLauncher? onAsteroidQuest,
  int commanderBalanceDar = 0,
}) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: BazarGameScreen(
        store: store,
        commanderBalanceDar: commanderBalanceDar,
        onIncome: onIncome ?? (_) async {},
        onExpense: onExpense,
        onAsteroidQuest: onAsteroidQuest,
        onExit: () {},
        onFinished: onFinished ?? (_) {},
      ),
    ),
  );
}

Future<void> _tap(
  WidgetTester tester,
  Key key,
) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'main BAZAR screen exposes all four traders, Garage and SLON',
    (tester) async {
      final store = _MemoryBazarStore();

      await tester.pumpWidget(_app(store: store));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('bazar.market.trader.mechanic')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.trader.reagents')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.trader.rarities')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.trader.trader_4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.garage')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.slon')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.puzzles')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.tartil')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.market.ghost')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pinning an offer is planning only and creates no BAZAR income',
    (tester) async {
      final store = _MemoryBazarStore();

      await tester.pumpWidget(_app(store: store));
      await tester.pumpAndSettle();

      await _tap(
        tester,
        const Key('bazar.market.trader.mechanic'),
      );
      await _tap(tester, const Key('bazar.trader.pin'));

      expect(store.state.pinnedOfferId, isNotNull);
      expect(store.state.sessionEarningsDar, 0);
      expect(store.state.completedOfferId, isNull);
    },
  );

  testWidgets(
    'full prototype run may pin one trader and sell to another',
    (tester) async {
      final store = _MemoryBazarStore();
      BazarRunResult? result;
      final incomeEvents = <BazarIncomeEvent>[];

      await tester.pumpWidget(
        _app(
          store: store,
          onFinished: (value) => result = value,
          onIncome: (event) async => incomeEvents.add(event),
        ),
      );
      await tester.pumpAndSettle();

      // План: механик.
      await _tap(
        tester,
        const Key('bazar.market.trader.mechanic'),
      );
      await _tap(tester, const Key('bazar.trader.pin'));
      await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
      await tester.pumpAndSettle();

      // Астероиды через Гараж / Чих-Пых.
      await _tap(tester, const Key('bazar.market.garage'));
      await _tap(
        tester,
        const Key('bazar.garage.select.chikh_pykh'),
      );
      await _tap(
        tester,
        const Key('bazar.garage.simulate_asteroids'),
      );

      // Дрова отдельным квестом СЛОН.
      await _tap(tester, const Key('bazar.market.slon'));
      await _tap(
        tester,
        const Key('bazar.slon.simulate_wood'),
      );

      // Факт: продаём реагентщику, хотя планировали механика.
      await _tap(
        tester,
        const Key('bazar.market.trader.reagents'),
      );
      await _tap(tester, const Key('bazar.trader.deal'));

      // Основная сделка начисляется немедленно, до решения по остатку.
      // Значение берём из каталога символически (не литералом), чтобы
      // тест не ломался при пересчёте наценки/баланса в bazar_game_catalog.dart.
      expect(incomeEvents, hasLength(1));
      expect(incomeEvents.single.amountDar, BazarGameCatalog.reagentsOffer.rewardDar);
      expect(incomeEvents.single.sourceId, 'reagents_supply_1');

      // Остаток продаём Скупщику.
      await _tap(
        tester,
        const Key('bazar.settlement.buyer'),
      );

      expect(
        find.byKey(const Key('bazar.result.total')),
        findsOneWidget,
      );

      await _tap(tester, const Key('bazar.result.to_base'));

      expect(result, isNotNull);
      expect(result!.primaryTraderId, 'reagents');
      expect(result!.primaryDealDar, BazarGameCatalog.reagentsOffer.rewardDar);
      expect(result!.buyerDar, 4);
      expect(
        result!.totalDarToBase,
        BazarGameCatalog.reagentsOffer.rewardDar + 4,
      );
      expect(incomeEvents, hasLength(2));
      expect(incomeEvents[1].amountDar, 4);
      expect(incomeEvents[1].sourceId, 'bazar_buyer');
    },
  );

  testWidgets(
    'accepted order opens Garage and launches real quest bridge on Chikh-Pykh',
    (tester) async {
      final store = _MemoryBazarStore();
      final expenses = <BazarExpenseEvent>[];
      BazarQuestRequest? launchedRequest;

      await tester.pumpWidget(
        _app(
          store: store,
          commanderBalanceDar: 12,
          onExpense: (event) async => expenses.add(event),
          onAsteroidQuest: (request) async {
            launchedRequest = request;
            return const BazarQuestCargoResult(
              attemptId: 'widget_real_quest_1',
              kind: BazarQuestKind.asteroids,
              cargo: BazarCargo(blue: 2, red: 1, green: 1),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, const Key('bazar.market.trader.mechanic'));
      await _tap(tester, const Key('bazar.trader.pin'));
      await _tap(tester, const Key('bazar.trader.to_garage'));

      expect(find.byKey(const Key('bazar.garage.art')), findsOneWidget);
      expect(
        find.byKey(const Key('bazar.garage.select.chikh_pykh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.garage.select.unter')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.garage.select.maestro')),
        findsOneWidget,
      );

      await _tap(tester, const Key('bazar.garage.select.chikh_pykh'));
      await _tap(tester, const Key('bazar.garage.simulate_asteroids'));

      expect(expenses, isEmpty);
      expect(launchedRequest, isNotNull);
      expect(launchedRequest!.transportId, 'chikh_pykh');
      expect(launchedRequest!.requiredCargo?.blue, 2);
      expect(launchedRequest!.requiredCargo?.red, 1);
      expect(launchedRequest!.requiredCargo?.green, 1);
      expect(store.state.rentedTransportId, 'chikh_pykh');
      expect(store.state.transportRentalPaidDar, 0);
      expect(store.state.asteroidExpeditionCompleted, isTrue);
      expect(store.state.cargo.blue, 2);
      expect(store.state.cargo.red, 1);
      expect(store.state.cargo.green, 1);
    },
  );

  testWidgets(
    'future Garage tractors stay visible but cannot charge rent yet',
    (tester) async {
      final store = _MemoryBazarStore();
      final expenses = <BazarExpenseEvent>[];

      await tester.pumpWidget(
        _app(
          store: store,
          commanderBalanceDar: 20,
          onExpense: (event) async => expenses.add(event),
        ),
      );
      await tester.pumpAndSettle();

      await _tap(tester, const Key('bazar.market.trader.mechanic'));
      await _tap(tester, const Key('bazar.trader.pin'));
      await _tap(tester, const Key('bazar.trader.to_garage'));
      await _tap(tester, const Key('bazar.garage.select.unter'));

      expect(expenses, isEmpty);
      expect(store.state.selectedTransportId, isNull);
      expect(store.state.rentedTransportId, isNull);
      expect(find.textContaining('В РАЗРАБОТКЕ'), findsWidgets);
    },
  );

  testWidgets(
    'SLON screen contains elder and wood loading scenes',
    (tester) async {
      final store = _MemoryBazarStore();

      await tester.pumpWidget(_app(store: store));
      await tester.pumpAndSettle();

      await _tap(tester, const Key('bazar.market.slon'));

      expect(
        find.byKey(const Key('bazar.slon.elder_art')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('bazar.slon.loading_art')),
        findsOneWidget,
      );
    },
  );

}