import 'package:flutter/material.dart';

import 'bazar_game_catalog.dart';
import 'bazar_game_engine.dart';
import 'bazar_game_models.dart';
import 'bazar_game_storage.dart';

typedef BazarIncomeHandler = Future<void> Function(BazarIncomeEvent event);
typedef BazarExpenseHandler = Future<void> Function(BazarExpenseEvent event);
typedef BazarQuestLauncher = Future<BazarQuestCargoResult?> Function(
  BazarQuestRequest request,
);

enum _BazarView {
  market,
  trader,
  garage,
  slon,
  settlement,
  result,
}

class BazarGameScreen extends StatefulWidget {
  final VoidCallback onExit;
  final ValueChanged<BazarRunResult> onFinished;
  final BazarIncomeHandler onIncome;
  final BazarExpenseHandler? onExpense;
  final BazarQuestLauncher? onAsteroidQuest;
  final int commanderBalanceDar;
  final BazarGameStateStore? store;

  const BazarGameScreen({
    super.key,
    required this.onExit,
    required this.onFinished,
    required this.onIncome,
    this.onExpense,
    this.onAsteroidQuest,
    required this.commanderBalanceDar,
    this.store,
  });

  @override
  State<BazarGameScreen> createState() => _BazarGameScreenState();
}

class _BazarGameScreenState extends State<BazarGameScreen> {
  static const _engine = BazarGameEngine();

  late final BazarGameStateStore _store;

  BazarGameState _state = BazarGameState();
  _BazarView _view = _BazarView.market;
  String? _selectedTraderId;
  BazarRunResult? _result;
  bool _loading = true;
  int _attemptSequence = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? BazarGameStorage();
    _restore();
  }

  Future<void> _restore() async {
    final loaded = await _store.load();
    loaded.sessionId ??= _newSessionId();
    await _store.save(loaded);
    if (!mounted) return;

    setState(() {
      _state = loaded;
      _view = loaded.hasPrimaryDeal && loaded.phase == BazarPhase.settling
          ? _BazarView.settlement
          : _BazarView.market;
      _loading = false;
    });

    await _syncKnownIncome();
  }

  String _newSessionId() =>
      'bazar_${DateTime.now().microsecondsSinceEpoch}';

  String get _sessionId {
    final existing = _state.sessionId?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final created = _newSessionId();
    _state.sessionId = created;
    return created;
  }

  BazarIncomeEvent _primaryIncomeEvent(
    BazarOffer offer,
    BazarTrader trader,
  ) {
    return BazarIncomeEvent(
      rewardKey: 'bazar:$_sessionId:primary:${offer.id}',
      amountDar: offer.rewardDar,
      sourceId: offer.id,
      sourceTitle: trader.title,
      reason: 'Сделка BAZAR: ${offer.title}',
    );
  }

  BazarIncomeEvent _buyerIncomeEvent(int amountDar) {
    return BazarIncomeEvent(
      rewardKey: 'bazar:$_sessionId:buyer',
      amountDar: amountDar,
      sourceId: 'bazar_buyer',
      sourceTitle: 'Скупщик BAZAR',
      reason: 'Продажа остатка груза Скупщику',
    );
  }

  Future<void> _syncKnownIncome() async {
    final offer = BazarGameCatalog.offerById(_state.completedOfferId);
    if (offer != null && _state.primaryDealDar > 0) {
      final trader = BazarGameCatalog.traderById(offer.traderId);
      if (trader != null) {
        await widget.onIncome(_primaryIncomeEvent(offer, trader));
      }
    }

    if (_state.buyerDar > 0) {
      await widget.onIncome(_buyerIncomeEvent(_state.buyerDar));
    }
  }

  Future<void> _save() => _store.save(_state);

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(text),
        ),
      );
  }

  Future<void> _openTrader(String traderId) async {
    setState(() {
      _selectedTraderId = traderId;
      _view = _BazarView.trader;
    });
  }

  Future<void> _pinCurrentOffer() async {
    final traderId = _selectedTraderId;
    if (traderId == null) return;

    final offer = BazarGameCatalog.offerForTrader(traderId);
    if (offer == null) return;

    try {
      _engine.acceptOffer(_state, offer.id);
      await _save();
      if (!mounted) return;
      setState(() {});
      _message(
        'Заявка принята. Ия: теперь идём в Гараж и выбираем космотрактор.',
      );
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _openGarage() async {
    if (!_state.hasPinnedOffer) {
      _message('Сначала познакомьтесь с заказами торговцев и примите одну заявку.');
      return;
    }
    setState(() => _view = _BazarView.garage);
  }

  Future<void> _selectTransport(String transportId) async {
    try {
      final transport = _engine.selectTransport(_state, transportId);
      await _save();
      if (!mounted) return;
      setState(() {});
      final rent = transport.rentalCostDar == 0
          ? 'бесплатно'
          : '${transport.rentalCostDar} Дар';
      _message('${transport.title} выбран · аренда $rent.');
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  BazarExpenseEvent _transportExpenseEvent(BazarTransport transport) {
    return BazarExpenseEvent(
      expenseKey: 'bazar:$_sessionId:rent:${transport.id}',
      amountDar: transport.rentalCostDar,
      sourceId: 'bazar_rent_${transport.id}',
      sourceTitle: 'Аренда ${transport.title}',
      reason: 'Аренда космотрактора ${transport.title} для экспедиции BAZAR',
    );
  }

  String _nextAttemptId(String prefix) {
    _attemptSequence += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_attemptSequence';
  }

  Future<void> _launchAsteroidQuest() async {
    try {
      final selectedId = _state.selectedTransportId;
      final transport = BazarGameCatalog.transportById(selectedId);
      if (transport == null) {
        _message('Сначала выберите космотрактор.');
        return;
      }

      if (!transport.expeditionReady) {
        _message(
          '${transport.title} уже стоит в Гараже, но его мини-игра ещё в разработке. '
          'Для этой экспедиции выберите Чих-Пых.',
        );
        return;
      }

      if (_state.rentedTransportId != transport.id) {
        if (transport.rentalCostDar > widget.commanderBalanceDar) {
          _message(
            'Для аренды ${transport.title} нужно ${transport.rentalCostDar} Дар. '
            'На счёте сейчас ${widget.commanderBalanceDar} Дар.',
          );
          return;
        }

        if (transport.rentalCostDar > 0) {
          final handler = widget.onExpense;
          if (handler == null) {
            _message('Оплата аренды пока не подключена к общей экономике.');
            return;
          }
          await handler(_transportExpenseEvent(transport));
        }

        _engine.markTransportRentalPaid(_state, transport.id);
        await _save();
        if (!mounted) return;
        setState(() {});
      }

      final request = _engine.createQuestRequest(
        _state,
        BazarQuestKind.asteroids,
      );

      BazarQuestCargoResult? result;
      final launcher = widget.onAsteroidQuest;
      if (launcher != null) {
        result = await launcher(request);
      } else {
        final capacity = request.cargoCapacity ?? 0;
        if (capacity < 6) {
          throw const BazarGameException(
            'test_capacity_too_small',
            'Для тестового груза требуется вместимость не меньше 6.',
          );
        }
        result = BazarQuestCargoResult(
          attemptId: _nextAttemptId('asteroids'),
          kind: BazarQuestKind.asteroids,
          cargo: const BazarCargo(blue: 2, red: 2, green: 2),
        );
      }

      if (result == null) {
        _message('Экспедиция отменена. Заявка и выбранный транспорт сохранены.');
        return;
      }

      _engine.receiveQuestCargo(_state, result);
      await _save();
      if (!mounted) return;
      setState(() => _view = _BazarView.market);
      _message(
        'Экспедиция завершена. Чих-Пых доставил добычу на BAZAR. Проверьте заказ и при необходимости отправляйтесь на СЛОН за дровами.',
      );
    } on BazarGameException catch (error) {
      _message(error.message);
    } catch (error) {
      _message('Не удалось начать экспедицию: $error');
    }
  }

  Future<void> _simulateSlonQuest() async {
    try {
      _engine.createQuestRequest(
        _state,
        BazarQuestKind.slonWood,
      );

      _engine.receiveQuestCargo(
        _state,
        BazarQuestCargoResult(
          attemptId: _nextAttemptId('slon'),
          kind: BazarQuestKind.slonWood,
          cargo: const BazarCargo(wood: 2),
        ),
      );

      await _save();
      if (!mounted) return;
      setState(() => _view = _BazarView.market);
      _message('Квест СЛОН вернул тестовый результат: 2 единицы дров.');
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _completeTraderDeal() async {
    final traderId = _selectedTraderId;
    if (traderId == null) return;

    try {
      final receipt = _engine.completePrimaryDeal(
        _state,
        traderId: traderId,
      );
      await _save();

      final offer = BazarGameCatalog.offerById(receipt.offerId);
      final trader = BazarGameCatalog.traderById(receipt.traderId);
      if (offer != null && trader != null) {
        await widget.onIncome(_primaryIncomeEvent(offer, trader));
      }

      if (!mounted) return;

      setState(() {
        _view = receipt.remainingCargo.isEmpty
            ? _BazarView.result
            : _BazarView.settlement;
      });

      if (receipt.remainingCargo.isEmpty) {
        await _finalizeIfReady();
      } else {
        _message(
          'Сделка завершена: +${receipt.earnedDar} Дар уже на счёте Командора. Теперь решаем судьбу остатка.',
        );
      }
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _sellLeftovers() async {
    try {
      final payout = _engine.sellLeftoversToBuyer(_state);
      await _save();
      await widget.onIncome(_buyerIncomeEvent(payout));
      if (!mounted) return;
      _message('Скупщик забрал остатки за $payout Дар. Деньги уже на счёте Командора.');
      await _finalizeIfReady();
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _storeLeftovers() async {
    try {
      final lot = _engine.storeLeftoversInAstroBox(_state);
      await _save();
      if (!mounted) return;
      _message(
        'В AstroBox отправлено ${lot.cargo.totalUnits} ед. груза. Счёт Командора не изменился.',
      );
      await _finalizeIfReady();
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _finalizeIfReady() async {
    try {
      final result = _engine.finalizeRun(_state);
      if (!mounted) return;
      setState(() {
        _result = result;
        _view = _BazarView.result;
      });
    } on BazarGameException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _finishAndReturn() async {
    final result = _result;
    if (result == null) return;

    _state.resetForNewRun();
    await _store.save(_state);

    if (!mounted) return;
    widget.onFinished(result);
  }

  Future<void> _resetRun() async {
    setState(() {
      _state = BazarGameState();
      _selectedTraderId = null;
      _result = null;
      _view = _BazarView.market;
    });
    await _store.clear();
    _message('Тестовый цикл BAZAR сброшен.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        const Positioned.fill(child: _BazarBackground()),
        SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: KeyedSubtree(
              key: ValueKey(_view),
              child: switch (_view) {
                _BazarView.market => _buildMarket(),
                _BazarView.trader => _buildTrader(),
                _BazarView.garage => _buildGarage(),
                _BazarView.slon => _buildSlon(),
                _BazarView.settlement => _buildSettlement(),
                _BazarView.result => _buildResult(),
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _page(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildMarket() {
    final quotes = {
      for (final quote in _engine.quoteAllTraders(_state))
        quote.offer.traderId: quote,
    };

    final pinned = BazarGameCatalog.offerById(_state.pinnedOfferId);

    return _page([
      Row(
        children: [
          IconButton(
            key: const Key('bazar.market.back'),
            tooltip: 'Вернуться на Базу',
            onPressed: widget.onExit,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'BAZAR',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
          _Badge(text: 'СЧЁТ ${widget.commanderBalanceDar} ДАР'),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Планета торга и возможностей',
        style: TextStyle(
          color: Color(0xFF70D7FF),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: Image.asset(
            'assets/scenes/bazar_market.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF17203A),
              alignment: Alignment.center,
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Добавьте assets/scenes/bazar_market.jpg — главный арт BAZAR.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _InfoCard(
        icon: Icons.auto_awesome_rounded,
        title: 'Ия',
        text: _marketHint(pinned),
        accent: const Color(0xFFB68CFF),
      ),
      if (_state.cargo.isNotEmpty) ...[
        const SizedBox(height: 12),
        _CargoCard(
          title: 'Груз на BAZAR',
          cargo: _state.cargo,
        ),
      ],
      if (_state.astroBoxCargo.isNotEmpty) ...[
        const SizedBox(height: 12),
        _CargoCard(
          title: 'В AstroBox',
          cargo: _state.astroBoxCargo,
        ),
      ],
      const SizedBox(height: 16),
      const Text(
        'Торговцы',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      ...BazarGameCatalog.traders.map((trader) {
        final offer = BazarGameCatalog.offerForTrader(trader.id)!;
        final quote = quotes[trader.id]!;
        final isPinned = offer.id == _state.pinnedOfferId;

        final status = _state.cargo.isEmpty
            ? 'Задание: ${_requirementsText(offer.requirements)}'
            : quote.canComplete
                ? 'Груз подходит · сделка ${offer.rewardDar} Дар'
                : 'Не хватает: ${_requirementsText(quote.missingCargo)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: _BazarActionCard(
            key: Key('bazar.market.trader.${trader.id}'),
            icon: _traderIcon(trader.id),
            title: trader.title,
            subtitle: status,
            trailing: isPinned
                ? const Icon(
                    Icons.push_pin_rounded,
                    color: Color(0xFFFFC85C),
                  )
                : null,
            accent: quote.canComplete && _state.cargo.isNotEmpty
                ? const Color(0xFF8DE5A1)
                : _traderAccent(trader.id),
            neon: true,
            onTap: () => _openTrader(trader.id),
          ),
        );
      }),
      const SizedBox(height: 4),
      const Text(
        'Направления и сервисы',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      _BazarActionCard(
        key: const Key('bazar.market.garage'),
        icon: Icons.garage_rounded,
        title: 'Гараж',
        subtitle: !_state.hasPinnedOffer
            ? 'Сначала примите заявку у одного из торговцев'
            : _state.asteroidExpeditionCompleted
                ? 'Экспедиция за астероидами на сегодня завершена'
                : _state.selectedTransportId == null
                    ? 'Заявка принята · пора выбрать космотрактор'
                    : '${BazarGameCatalog.transportById(_state.selectedTransportId)?.title ?? 'Транспорт'} выбран · можно в экспедицию',
        accent: const Color(0xFFFFA65A),
        neon: _state.hasPinnedOffer && !_state.asteroidExpeditionCompleted,
        onTap: _openGarage,
      ),
      const SizedBox(height: 9),
      _BazarActionCard(
        key: const Key('bazar.market.slon'),
        icon: Icons.park_rounded,
        title: 'Планета СЛОН',
        subtitle: 'Отдельный квест за дровами · без космотрактора',
        accent: const Color(0xFF8DE5A1),
        neon: true,
        onTap: () => setState(() => _view = _BazarView.slon),
      ),
      const SizedBox(height: 9),
      _BazarActionCard(
        key: const Key('bazar.market.tartil'),
        icon: Icons.public_rounded,
        title: 'Планета Тортилл',
        subtitle: 'В разработке',
        accent: const Color(0xFF657B85),
        muted: true,
        trailing: const _DevelopmentBadge(),
        onTap: () => _message('Планета Тортилл ещё в разработке.'),
      ),
      const SizedBox(height: 9),
      _BazarActionCard(
        key: const Key('bazar.market.puzzles'),
        icon: Icons.extension_rounded,
        title: 'Головоломки',
        subtitle: 'В разработке',
        accent: const Color(0xFF7A6E96),
        muted: true,
        trailing: const _DevelopmentBadge(),
        onTap: () => _message('Головоломки ещё в разработке.'),
      ),
      const SizedBox(height: 9),
      _BazarActionCard(
        icon: Icons.currency_exchange_rounded,
        title: 'Скупщик',
        subtitle: _state.hasPrimaryDeal
            ? 'Здесь можно быстро продать остатки по низкой цене'
            : 'Работает только после основной сделки',
        accent: const Color(0xFF70D7FF),
        neon: _state.phase == BazarPhase.settling,
        onTap: _state.phase == BazarPhase.settling
            ? () => setState(() => _view = _BazarView.settlement)
            : () => _message('Сначала проведите основную сделку с торговцем.'),
      ),
      const SizedBox(height: 18),
      const Text(
        'Скоро на BAZAR',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      _BazarActionCard(
        key: const Key('bazar.market.ghost'),
        icon: Icons.visibility_off_rounded,
        title: 'Призрак',
        subtitle: 'В разработке',
        accent: const Color(0xFF6E7486),
        muted: true,
        trailing: const _DevelopmentBadge(),
        onTap: () => _message('Призрак ещё в разработке.'),
      ),
      const SizedBox(height: 14),
      TextButton.icon(
        key: const Key('bazar.market.reset'),
        onPressed: _resetRun,
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Сбросить только тестовый цикл BAZAR'),
      ),
    ]);
  }

  String _marketHint(BazarOffer? pinned) {
    if (_state.phase == BazarPhase.settling) {
      return 'Основная сделка завершена. Остаток нужно продать Скупщику или отправить в AstroBox.';
    }

    if (_state.cargo.isNotEmpty) {
      return 'Груз уже на площади. Сверьте заявки торговцев и выберите, кому сейчас выгоднее выполнить поставку.';
    }

    if (_state.asteroidExpeditionCompleted) {
      return 'Астероидная ходка завершена. Если для заявки нужны дрова, отправляйтесь на СЛОН, затем возвращайтесь к торговцам.';
    }

    if (pinned != null) {
      final trader = BazarGameCatalog.traderById(pinned.traderId);
      return 'Заявка ${trader?.title ?? pinned.traderId} принята. Следующий шаг — Гараж: выберите космотрактор и отправляйтесь в экспедицию.';
    }

    return 'Сначала познакомьтесь с заказами торговцев. Выберите одну заявку на сегодня и примите её — после этого откроется следующий шаг: Гараж.';
  }

  Widget _buildTrader() {
    final traderId = _selectedTraderId;
    final trader = BazarGameCatalog.traderById(traderId);

    if (trader == null) {
      return _page([
        const _InfoCard(
          icon: Icons.error_outline_rounded,
          title: 'Торговец не найден',
          text: 'Вернитесь на главную площадь.',
          accent: Color(0xFFFF8A80),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() => _view = _BazarView.market),
          child: const Text('На BAZAR'),
        ),
      ]);
    }

    final offer = BazarGameCatalog.offerForTrader(trader.id)!;
    final quote = _engine.quoteTrader(_state, trader.id);
    final isPinned = _state.pinnedOfferId == offer.id;

    return _page([
      _BackHeader(
        title: trader.title,
        onBack: () => setState(() => _view = _BazarView.market),
      ),
      const SizedBox(height: 10),
      _InfoCard(
        icon: _traderIcon(trader.id),
        title: trader.title,
        text: trader.subtitle,
        accent: _traderAccent(trader.id),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xE8172038),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isPinned
                ? const Color(0xFFFFC85C)
                : const Color(0xFF344463),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${offer.rewardDar} Дар',
                  style: const TextStyle(
                    color: Color(0xFFFFC85C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RequirementRow(
              title: 'Синий астероид',
              current: _state.cargo.blue,
              target: offer.requirements.blue,
              accent: const Color(0xFF5CC8FF),
            ),
            _RequirementRow(
              title: 'Красный астероид',
              current: _state.cargo.red,
              target: offer.requirements.red,
              accent: const Color(0xFFFF7A72),
            ),
            _RequirementRow(
              title: 'Зелёный астероид',
              current: _state.cargo.green,
              target: offer.requirements.green,
              accent: const Color(0xFF78E49A),
            ),
            _RequirementRow(
              title: 'Дрова СЛОН',
              current: _state.cargo.wood,
              target: offer.requirements.wood,
              accent: const Color(0xFFD9B47A),
            ),
            const SizedBox(height: 12),
            if (!_state.hasPrimaryDeal && _state.cargo.isEmpty)
              FilledButton.icon(
                key: const Key('bazar.trader.pin'),
                onPressed: isPinned ? null : _pinCurrentOffer,
                icon: Icon(
                  isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                ),
                label: Text(
                  isPinned
                      ? 'Заявка принята'
                      : 'Принять заявку',
                ),
              ),
            if (!_state.hasPrimaryDeal && _state.cargo.isEmpty && isPinned) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('bazar.trader.to_garage'),
                onPressed: _openGarage,
                icon: const Icon(Icons.garage_rounded),
                label: const Text('Теперь в Гараж'),
              ),
            ],
            if (!_state.hasPrimaryDeal && _state.cargo.isNotEmpty) ...[
              if (!quote.canComplete)
                _InfoCard(
                  icon: Icons.info_outline_rounded,
                  title: 'Пока не хватает',
                  text: _requirementsText(quote.missingCargo),
                  accent: const Color(0xFFFFB36B),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const Key('bazar.trader.deal'),
                onPressed: quote.canComplete ? _completeTraderDeal : null,
                icon: const Icon(Icons.handshake_rounded),
                label: Text(
                  quote.canComplete
                      ? 'СДЕЛКА · +${offer.rewardDar} Дар'
                      : 'Сделка пока недоступна',
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() => _view = _BazarView.market),
        icon: const Icon(Icons.storefront_rounded),
        label: const Text('Сравнить остальных торговцев'),
      ),
    ]);
  }

  Widget _buildGarage() {
    final acceptedOffer = BazarGameCatalog.offerById(_state.pinnedOfferId);
    final acceptedTrader =
        BazarGameCatalog.traderById(acceptedOffer?.traderId);
    final selected =
        BazarGameCatalog.transportById(_state.selectedTransportId);

    return _page([
      _BackHeader(
        title: 'Гараж BAZAR',
        onBack: () => setState(() => _view = _BazarView.market),
      ),
      const SizedBox(height: 10),
      _InfoCard(
        icon: Icons.assignment_turned_in_outlined,
        title: acceptedOffer == null
            ? 'Сначала нужна заявка'
            : 'Заявка: ${acceptedTrader?.title ?? acceptedOffer.traderId}',
        text: acceptedOffer == null
            ? 'Вернитесь на BAZAR, изучите заказы и примите одну заявку.'
            : '${acceptedOffer.title}: ${_requirementsText(acceptedOffer.requirements)} · награда ${acceptedOffer.rewardDar} Дар.',
        accent: const Color(0xFFFFC85C),
      ),
      if (acceptedOffer != null) ...[
        const SizedBox(height: 10),
        _InfoCard(
          icon: Icons.filter_alt_outlined,
          title: 'Цель астероидной экспедиции',
          text: 'Соберите для этой заявки: '
              '${_asteroidRequirementsText(acceptedOffer.requirements)}. '
              'Дрова добываются отдельно на планете СЛОН.',
          accent: const Color(0xFF70D7FF),
        ),
      ],
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            'assets/scenes/bazar_garage.jpg',
            key: const Key('bazar.garage.art'),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF17203A),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Не найден арт Гаража BAZAR.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const _InfoCard(
        icon: Icons.garage_rounded,
        title: 'Выберите космотрактор',
        text:
            'Аренда списывается только при выезде. До старта экспедиции выбор можно изменить. На СЛОН эти машины не летают.',
        accent: Color(0xFFFFA65A),
      ),
      const SizedBox(height: 12),
      ...BazarGameCatalog.transports.map((transport) {
        final isSelected = selected?.id == transport.id;
        final canAfford = transport.rentalCostDar <= widget.commanderBalanceDar;
        final ready = transport.expeditionReady;
        final rentText = transport.rentalCostDar == 0
            ? 'аренда бесплатно'
            : 'аренда ${transport.rentalCostDar} Дар';
        final paid = _state.rentedTransportId == transport.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _BazarActionCard(
            key: Key('bazar.garage.select.${transport.id}'),
            icon: Icons.agriculture_rounded,
            title: transport.title,
            subtitle: ready
                ? '$rentText · ${transport.feature}\n${transport.description}'
                : '$rentText · ${transport.feature}\n${transport.description}\nВ РАЗРАБОТКЕ',
            trailing: paid
                ? const Icon(
                    Icons.paid_rounded,
                    color: Color(0xFF8DE5A1),
                  )
                : isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFFFC85C),
                      )
                    : !ready
                        ? const Icon(
                            Icons.construction_rounded,
                            color: Color(0xFFAEBBD1),
                          )
                        : !canAfford
                            ? const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFAEBBD1),
                              )
                            : null,
            accent: paid
                ? const Color(0xFF8DE5A1)
                : isSelected
                    ? const Color(0xFFFFC85C)
                    : const Color(0xFF70D7FF),
            neon: isSelected || paid,
            muted: (!ready || !canAfford) && !paid,
            onTap: _state.asteroidExpeditionCompleted
                ? () => _message('Астероидная экспедиция на сегодня уже завершена.')
                : !ready
                    ? () => _message(
                          '${transport.title}: мини-игра этого космотрактора пока в разработке. Сейчас доступен Чих-Пых.',
                        )
                    : !canAfford && !paid
                        ? () => _message(
                              'Для аренды ${transport.title} нужно ${transport.rentalCostDar} Дар.',
                            )
                        : () => _selectTransport(transport.id),
          ),
        );
      }),
      if (selected != null) ...[
        const SizedBox(height: 4),
        FilledButton.icon(
          key: const Key('bazar.garage.simulate_asteroids'),
          onPressed: _state.asteroidExpeditionCompleted || !selected.expeditionReady
              ? null
              : _launchAsteroidQuest,
          icon: const Icon(Icons.rocket_launch_rounded),
          label: Text(
            _state.asteroidExpeditionCompleted
                ? 'Экспедиция завершена'
                : 'В экспедицию на ${selected.title}',
          ),
        ),
      ],
      const SizedBox(height: 10),
      const Text(
        'Чих-Пых подключён к астероидной мини-игре. Унтер и Маэстро уже стоят в Гараже и сохраняют свои цены, но их игровые режимы пока помечены «В РАЗРАБОТКЕ» — Дар за них не списываются.',
        style: TextStyle(
          color: Color(0xFFAEBBD1),
          height: 1.4,
        ),
      ),
    ]);
  }

  Widget _buildSlon() {
    return _page([
      _BackHeader(
        title: 'Планета СЛОН',
        onBack: () => setState(() => _view = _BazarView.market),
      ),
      const SizedBox(height: 10),
      const _InfoCard(
        icon: Icons.park_rounded,
        title: 'Староста СЛОНа',
        text:
            'Староста встречает Командора и подтверждает отгрузку древесины. СЛОН — отдельное направление: космотрактор из Гаража BAZAR сюда не летает.',
        accent: Color(0xFF8DE5A1),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 3 / 2,
          child: Image.asset(
            'assets/scenes/slon_elder.jpg',
            key: const Key('bazar.slon.elder_art'),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF17203A),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Не найден арт Старосты СЛОНа.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      const _InfoCard(
        icon: Icons.local_shipping_outlined,
        title: 'Отгрузка дров',
        text:
            'После разговора со Старостой дрова грузят на транспорт. Результат экспедиции возвращается в BAZAR как груз, а не как деньги.',
        accent: Color(0xFFD9B47A),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            'assets/scenes/slon_wood_loading.jpg',
            key: const Key('bazar.slon.loading_art'),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF17203A),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Не найден арт отгрузки дров.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const Key('bazar.slon.simulate_wood'),
        onPressed: _simulateSlonQuest,
        icon: const Icon(Icons.forest_rounded),
        label: const Text('Принять дрова и вернуться на BAZAR'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Пока кнопка формирует тот же BazarQuestCargoResult, который позже вернёт отдельный квест СЛОНа. Торговую логику BAZAR после подключения квеста менять не придётся.',
        style: TextStyle(
          color: Color(0xFFAEBBD1),
          height: 1.4,
        ),
      ),
    ]);
  }

  Widget _buildSettlement() {
    final buyerQuote = _engine.quoteBuyer(_state);

    return _page([
      _BackHeader(
        title: 'Остаток груза',
        onBack: () => setState(() => _view = _BazarView.market),
      ),
      const SizedBox(height: 10),
      _CargoCard(
        title: 'После основной сделки осталось',
        cargo: _state.cargo,
      ),
      const SizedBox(height: 12),
      _BazarActionCard(
        key: const Key('bazar.settlement.buyer'),
        icon: Icons.currency_exchange_rounded,
        title: 'Скупщик',
        subtitle: 'Продать всё · на 20% ниже стоимости груза: $buyerQuote Дар · выплата целыми Дар',
        accent: const Color(0xFF70D7FF),
        neon: true,
        onTap: _sellLeftovers,
      ),
      const SizedBox(height: 10),
      _BazarActionCard(
        key: const Key('bazar.settlement.astrobox'),
        icon: Icons.inventory_2_rounded,
        title: 'AstroBox',
        subtitle:
            'Сбросить остаток бесплатно · груз очистится, счёт не изменится',
        accent: const Color(0xFFB68CFF),
        neon: true,
        onTap: _storeLeftovers,
      ),
      const SizedBox(height: 12),
      const _InfoCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Деньги начисляются сразу',
        text:
            'Основная сделка и продажа Скупщику сразу меняют счёт Командора. AstroBox денег не приносит — он только очищает текущий груз.',
        accent: Color(0xFFFFC85C),
      ),
    ]);
  }

  Widget _buildResult() {
    final result = _result;

    if (result == null) {
      return _page([
        const _InfoCard(
          icon: Icons.hourglass_empty_rounded,
          title: 'Считаем результат',
          text: 'Завершите выбор по остатку груза.',
          accent: Color(0xFF70D7FF),
        ),
      ]);
    }

    return _page([
      const SizedBox(height: 20),
      const Icon(
        Icons.verified_rounded,
        size: 68,
        color: Color(0xFF8DE5A1),
      ),
      const SizedBox(height: 12),
      const Text(
        'Торговый цикл завершён',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 18),
      Container(
        key: const Key('bazar.result.total'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xE8172038),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFFC85C),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            const Text(
              'ЗАРАБОТАНО НА BAZAR',
              style: TextStyle(
                color: Color(0xFFAEBBD1),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${result.totalDarToBase} Дар',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFC85C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Основная сделка: ${result.primaryDealDar} · '
              'Скупщик: ${result.buyerDar}',
              textAlign: TextAlign.center,
            ),
            if (result.astroBoxLot != null) ...[
              const SizedBox(height: 8),
              Text(
                'AstroBox: ${result.astroBoxLot!.cargo.totalUnits} ед. · без начисления Дар',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      _InfoCard(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Счёт Командора: ${widget.commanderBalanceDar} Дар',
        text:
            'Доход уже записан в общую Transaction-экономику. Возврат на Базу ничего дополнительно не начисляет.',
        accent: const Color(0xFF70D7FF),
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        key: const Key('bazar.result.to_base'),
        onPressed: _finishAndReturn,
        icon: const Icon(Icons.home_rounded),
        label: const Text('Вернуться на Базу'),
      ),
    ]);
  }

  static IconData _traderIcon(String traderId) {
    switch (traderId) {
      case BazarGameCatalog.mechanicTraderId:
        return Icons.build_circle_outlined;
      case BazarGameCatalog.reagentsTraderId:
        return Icons.science_outlined;
      case BazarGameCatalog.raritiesTraderId:
        return Icons.diamond_outlined;
      default:
        return Icons.storefront_outlined;
    }
  }

  static Color _traderAccent(String traderId) {
    switch (traderId) {
      case BazarGameCatalog.mechanicTraderId:
        return const Color(0xFFFFA65A);
      case BazarGameCatalog.reagentsTraderId:
        return const Color(0xFFC67CFF);
      case BazarGameCatalog.raritiesTraderId:
        return const Color(0xFF7DE2B8);
      default:
        return const Color(0xFF70D7FF);
    }
  }

  static String _asteroidRequirementsText(BazarCargo cargo) {
    final parts = <String>[];
    if (cargo.blue > 0) parts.add('синие ${cargo.blue}');
    if (cargo.red > 0) parts.add('красные ${cargo.red}');
    if (cargo.green > 0) parts.add('зелёные ${cargo.green}');
    return parts.isEmpty ? 'астероиды не нужны' : parts.join(' · ');
  }

  static String _requirementsText(BazarCargo cargo) {
    final parts = <String>[];
    if (cargo.blue > 0) parts.add('синие ${cargo.blue}');
    if (cargo.red > 0) parts.add('красные ${cargo.red}');
    if (cargo.green > 0) parts.add('зелёные ${cargo.green}');
    if (cargo.wood > 0) parts.add('дрова ${cargo.wood}');
    return parts.isEmpty ? 'всё собрано' : parts.join(' · ');
  }
}

class _BackHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _BackHeader({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _BazarBackground extends StatelessWidget {
  const _BazarBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF120D25),
            Color(0xFF17122C),
            Color(0xFF0E1726),
          ],
        ),
      ),
      child: CustomPaint(
        painter: _StarsPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x22FFFFFF);
    const points = <Offset>[
      Offset(.08, .11),
      Offset(.21, .08),
      Offset(.37, .14),
      Offset(.49, .06),
      Offset(.63, .13),
      Offset(.78, .09),
      Offset(.91, .17),
      Offset(.14, .31),
      Offset(.72, .29),
      Offset(.88, .38),
      Offset(.32, .47),
      Offset(.57, .44),
      Offset(.09, .61),
      Offset(.83, .66),
      Offset(.45, .76),
      Offset(.67, .84),
      Offset(.23, .91),
    ];

    for (final point in points) {
      canvas.drawCircle(
        Offset(point.dx * size.width, point.dy * size.height),
        1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC18223A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF42577A)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xE8172038),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFFC5D0E4),
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BazarActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool neon;
  final bool muted;

  const _BazarActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    this.trailing,
    this.neon = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = muted
        ? const Color(0xFF3D4556)
        : accent.withValues(alpha: neon ? 0.95 : 0.72);
    final iconColor = muted ? const Color(0xFF7E8799) : accent;
    final titleColor = muted ? const Color(0xFF9AA3B4) : Colors.white;
    final subtitleColor =
        muted ? const Color(0xFF737D90) : const Color(0xFFB8C4D9);

    return Material(
      color: muted ? const Color(0xCC141B2C) : const Color(0xE8172038),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: neon ? 1.5 : 1,
            ),
            boxShadow: neon
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.26),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (muted ? const Color(0xFF6E7486) : accent)
                      .withValues(alpha: muted ? 0.08 : 0.14),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: neon
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else
                Icon(
                  Icons.chevron_right_rounded,
                  color: muted
                      ? const Color(0xFF5D6575)
                      : const Color(0xFF93A3BE),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevelopmentBadge extends StatelessWidget {
  const _DevelopmentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF252C3A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF4A5365)),
      ),
      child: const Text(
        'В РАЗРАБОТКЕ',
        style: TextStyle(
          color: Color(0xFF9AA3B4),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _CargoCard extends StatelessWidget {
  final String title;
  final BazarCargo cargo;

  const _CargoCard({
    required this.title,
    required this.cargo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xE8172038),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC85C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _ResourcePill(
                label: 'Синие',
                value: cargo.blue,
                accent: const Color(0xFF5CC8FF),
              ),
              _ResourcePill(
                label: 'Красные',
                value: cargo.red,
                accent: const Color(0xFFFF7A72),
              ),
              _ResourcePill(
                label: 'Зелёные',
                value: cargo.green,
                accent: const Color(0xFF78E49A),
              ),
              _ResourcePill(
                label: 'Дрова',
                value: cargo.wood,
                accent: const Color(0xFFD9B47A),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResourcePill extends StatelessWidget {
  final String label;
  final int value;
  final Color accent;

  const _ResourcePill({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.60)),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String title;
  final int current;
  final int target;
  final Color accent;

  const _RequirementRow({
    required this.title,
    required this.current,
    required this.target,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final enough = current >= target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(title)),
          Text(
            '$current / $target',
            style: TextStyle(
              color: enough
                  ? const Color(0xFF8DE5A1)
                  : const Color(0xFFFFB36B),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}