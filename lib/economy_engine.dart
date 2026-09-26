import 'economy_models.dart';
import 'game_state.dart';

class EconomyException implements Exception {
  final String code;
  final String message;

  const EconomyException(this.code, this.message);

  @override
  String toString() => 'EconomyException($code): $message';
}

class EconomyEngine {
  const EconomyEngine();

  Transaction addIncome(
    GameStateData state, {
    required int amount,
    required String sourceId,
    required String sourceTitle,
    required String reason,
    String category = EconomyCategory.income,
    String? rewardKey,
  }) {
    _validateStateBalances(state);
    _validatePositiveAmount(amount);

    final normalizedRewardKey = rewardKey?.trim();
    if (normalizedRewardKey != null &&
        normalizedRewardKey.isNotEmpty &&
        state.processedRewardKeys.contains(normalizedRewardKey)) {
      throw EconomyException(
        'duplicate_reward',
        'Reward "$normalizedRewardKey" has already been processed.',
      );
    }

    final walletBefore = state.walletDar;
    final savingsBefore = state.savingsDar;

    state.walletDar += amount;

    final transaction = _appendTransaction(
      state,
      type: TransactionType.income,
      category: category,
      amount: amount,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
      walletBefore: walletBefore,
      savingsBefore: savingsBefore,
    );

    if (normalizedRewardKey != null && normalizedRewardKey.isNotEmpty) {
      state.processedRewardKeys.add(normalizedRewardKey);
    }

    return transaction;
  }

  Transaction purchaseNeed(
    GameStateData state, {
    required int price,
    required String sourceId,
    required String sourceTitle,
    required String reason,
  }) {
    return _purchase(
      state,
      price: price,
      type: TransactionType.needExpense,
      category: EconomyCategory.need,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
    );
  }

  Transaction purchaseWant(
    GameStateData state, {
    required int price,
    required String sourceId,
    required String sourceTitle,
    required String reason,
  }) {
    return _purchase(
      state,
      price: price,
      type: TransactionType.wantExpense,
      category: EconomyCategory.want,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
    );
  }

  Transaction purchaseTransport(
    GameStateData state, {
    required int price,
    required String sourceId,
    required String sourceTitle,
    required String reason,
  }) {
    return _purchase(
      state,
      price: price,
      type: TransactionType.transportExpense,
      category: EconomyCategory.transport,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
    );
  }

  Transaction depositSavings(
    GameStateData state, {
    required int amount,
    String sourceId = 'savings_deposit',
    String sourceTitle = 'Накопления',
    String reason = 'Перевод в накопления',
  }) {
    _validateStateBalances(state);
    _validatePositiveAmount(amount);

    if (amount > state.walletDar) {
      throw const EconomyException(
        'insufficient_wallet',
        'Not enough Dar in wallet for savings deposit.',
      );
    }

    final walletBefore = state.walletDar;
    final savingsBefore = state.savingsDar;

    state.walletDar -= amount;
    state.savingsDar += amount;

    return _appendTransaction(
      state,
      type: TransactionType.savingDeposit,
      category: EconomyCategory.savings,
      amount: amount,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
      walletBefore: walletBefore,
      savingsBefore: savingsBefore,
    );
  }

  Transaction withdrawSavings(
    GameStateData state, {
    required int amount,
    String sourceId = 'savings_withdrawal',
    String sourceTitle = 'Накопления',
    String reason = 'Возврат из накоплений',
  }) {
    _validateStateBalances(state);
    _validatePositiveAmount(amount);

    if (amount > state.savingsDar) {
      throw const EconomyException(
        'insufficient_savings',
        'Not enough Dar in savings for withdrawal.',
      );
    }

    final walletBefore = state.walletDar;
    final savingsBefore = state.savingsDar;

    state.walletDar += amount;
    state.savingsDar -= amount;

    return _appendTransaction(
      state,
      type: TransactionType.savingWithdrawal,
      category: EconomyCategory.savings,
      amount: amount,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
      walletBefore: walletBefore,
      savingsBefore: savingsBefore,
    );
  }

  PeriodFact calculateFact(
    GameStateData state, {
    int? periodId,
  }) {
    final targetPeriodId = periodId ?? state.period;
    final periodTransactions = state.transactions
        .where((transaction) => transaction.periodId == targetPeriodId)
        .toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    var actualNeed = 0;
    var actualWant = 0;
    var actualSavings = 0;
    var income = 0;

    for (final transaction in periodTransactions) {
      switch (transaction.type) {
        case TransactionType.income:
          income += transaction.amount;
          break;
        case TransactionType.needExpense:
          actualNeed += transaction.amount;
          break;
        case TransactionType.wantExpense:
          actualWant += transaction.amount;
          break;
        case TransactionType.transportExpense:
          actualNeed += transaction.amount;
          break;
        case TransactionType.savingDeposit:
          actualSavings += transaction.amount;
          break;
        case TransactionType.savingWithdrawal:
          actualSavings -= transaction.amount;
          break;
      }
    }

    final walletEnd = periodTransactions.isNotEmpty
        ? periodTransactions.last.walletAfter
        : targetPeriodId == state.period
            ? state.walletDar
            : 0;
    final savingsEnd = periodTransactions.isNotEmpty
        ? periodTransactions.last.savingsAfter
        : targetPeriodId == state.period
            ? state.savingsDar
            : 0;

    return PeriodFact(
      periodId: targetPeriodId,
      actualNeed: actualNeed,
      actualWant: actualWant,
      actualSavings: actualSavings,
      income: income,
      walletEnd: walletEnd,
      savingsEnd: savingsEnd,
    );
  }

  Transaction _purchase(
    GameStateData state, {
    required int price,
    required TransactionType type,
    required String category,
    required String sourceId,
    required String sourceTitle,
    required String reason,
  }) {
    _validateStateBalances(state);
    _validatePositiveAmount(price);

    if (price > state.walletDar) {
      throw const EconomyException(
        'insufficient_wallet',
        'Not enough Dar in wallet for purchase.',
      );
    }

    final walletBefore = state.walletDar;
    final savingsBefore = state.savingsDar;

    state.walletDar -= price;

    return _appendTransaction(
      state,
      type: type,
      category: category,
      amount: price,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
      walletBefore: walletBefore,
      savingsBefore: savingsBefore,
    );
  }

  Transaction _appendTransaction(
    GameStateData state, {
    required TransactionType type,
    required String category,
    required int amount,
    required String sourceId,
    required String sourceTitle,
    required String reason,
    required int walletBefore,
    required int savingsBefore,
  }) {
    var maxSequence = 0;
    for (final transaction in state.transactions) {
      if (transaction.sequence > maxSequence) {
        maxSequence = transaction.sequence;
      }
    }

    final sequence = maxSequence + 1;
    final transaction = Transaction(
      id: 'tx_${state.period}_$sequence',
      periodId: state.period,
      sequence: sequence,
      type: type,
      category: category,
      amount: amount,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      reason: reason,
      walletBefore: walletBefore,
      walletAfter: state.walletDar,
      savingsBefore: savingsBefore,
      savingsAfter: state.savingsDar,
    );

    state.transactions.add(transaction);
    return transaction;
  }

  void _validatePositiveAmount(int amount) {
    if (amount <= 0) {
      throw ArgumentError.value(
        amount,
        'amount',
        'Economy amount must be greater than zero.',
      );
    }
  }

  void _validateStateBalances(GameStateData state) {
    if (state.walletDar < 0 || state.savingsDar < 0) {
      throw StateError('Economy balances cannot be negative.');
    }
  }
}