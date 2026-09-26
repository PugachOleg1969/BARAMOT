import 'package:baramot/economy_engine.dart';
import 'package:baramot/economy_models.dart';
import 'package:baramot/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = EconomyEngine();

  test('transport rental uses transport expense and reduces wallet once', () {
    final state = GameStateData(walletDar: 12, period: 1);

    final transaction = engine.purchaseTransport(
      state,
      price: 5,
      sourceId: 'bazar:test:rent:unter',
      sourceTitle: 'Аренда Унтер',
      reason: 'Аренда космотрактора для экспедиции BAZAR',
    );

    expect(state.walletDar, 7);
    expect(transaction.type, TransactionType.transportExpense);
    expect(transaction.category, EconomyCategory.transport);
    expect(transaction.amount, 5);
  });

  test('transport rental refuses insufficient wallet', () {
    final state = GameStateData(walletDar: 12, period: 1);

    expect(
      () => engine.purchaseTransport(
        state,
        price: 15,
        sourceId: 'bazar:test:rent:maestro',
        sourceTitle: 'Аренда Маэстро',
        reason: 'Аренда космотрактора для экспедиции BAZAR',
      ),
      throwsA(
        isA<EconomyException>().having(
          (error) => error.code,
          'code',
          'insufficient_wallet',
        ),
      ),
    );
    expect(state.walletDar, 12);
    expect(state.transactions, isEmpty);
  });
}
