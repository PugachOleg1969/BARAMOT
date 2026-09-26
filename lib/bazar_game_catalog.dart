import 'bazar_game_models.dart';

class BazarGameCatalog {
  const BazarGameCatalog._();

  // Базовая стоимость ресурсов в целых Дар.
  // Синие / красные / зелёные соответствуют учебной шкале 1 / 2 / 3.
  // Дрова СЛОНа пока остаются в текущем прототипе со стоимостью 1 Дар.
  static const int blueAsteroidPriceDar = 1;
  static const int redAsteroidPriceDar = 2;
  static const int greenAsteroidPriceDar = 3;
  static const int woodPriceDar = 1;

  static int cargoValueDar(BazarCargo cargo) {
    return cargo.blue * blueAsteroidPriceDar +
        cargo.red * redAsteroidPriceDar +
        cargo.green * greenAsteroidPriceDar +
        cargo.wood * woodPriceDar;
  }

  // Наценка торговца сверх сырьевой стоимости груза: раньше сделка
  // платила ровно cargoValueDar(requirements) — 0 маржи за работу и
  // логистику. Добавлена сознательно, чтобы поднять свободный доход
  // Командора (нужно для ремонта корабля и общего темпа игры) и заодно
  // показать ребёнку идею прибыли/наценки в торговле.
  static const int tradeMarginDar = 3;

  static const String mechanicTraderId = 'mechanic';
  static const String reagentsTraderId = 'reagents';
  static const String raritiesTraderId = 'rarities';
  static const String fourthTraderId = 'trader_4';

  static const BazarTrader mechanic = BazarTrader(
    id: mechanicTraderId,
    title: 'Лавка механика',
    subtitle: 'Механика, ремонт и полезный лом',
  );

  static const BazarTrader reagents = BazarTrader(
    id: reagentsTraderId,
    title: 'Лавка реагентов',
    subtitle: 'Минералы и сырьё для опытов',
  );

  static const BazarTrader rarities = BazarTrader(
    id: raritiesTraderId,
    title: 'Лавка редкостей',
    subtitle: 'Необычные находки и коллекционные ресурсы',
  );

  // Рабочее название до утверждения четвёртого торговца.
  static const BazarTrader fourth = BazarTrader(
    id: fourthTraderId,
    title: 'Лавка №4',
    subtitle: 'Рабочее название',
  );

  static const List<BazarTrader> traders = <BazarTrader>[
    mechanic,
    reagents,
    rarities,
    fourth,
  ];

  // Значения первой балансной итерации. Они вынесены в каталог,
  // чтобы менять требования и награды без изменения BazarGameEngine.
  static const BazarOffer mechanicOffer = BazarOffer(
    id: 'mechanic_supply_1',
    traderId: mechanicTraderId,
    title: 'Поставка для механика',
    requirements: BazarCargo(
      blue: 2,
      red: 1,
      green: 1,
      wood: 1,
    ),
    rewardDar: 8 + tradeMarginDar,
  );

  static const BazarOffer reagentsOffer = BazarOffer(
    id: 'reagents_supply_1',
    traderId: reagentsTraderId,
    title: 'Поставка для реагентов',
    requirements: BazarCargo(
      blue: 1,
      red: 2,
      green: 1,
      wood: 1,
    ),
    rewardDar: 9 + tradeMarginDar,
  );

  static const BazarOffer raritiesOffer = BazarOffer(
    id: 'rarities_supply_1',
    traderId: raritiesTraderId,
    title: 'Поставка редкостей',
    requirements: BazarCargo(
      blue: 1,
      red: 1,
      green: 2,
      wood: 1,
    ),
    rewardDar: 10 + tradeMarginDar,
  );

  static const BazarOffer fourthOffer = BazarOffer(
    id: 'trader_4_supply_1',
    traderId: fourthTraderId,
    title: 'Поставка четвёртой лавке',
    requirements: BazarCargo(
      blue: 2,
      red: 1,
      green: 2,
      wood: 1,
    ),
    rewardDar: 11 + tradeMarginDar,
  );

  static const List<BazarOffer> offers = <BazarOffer>[
    mechanicOffer,
    reagentsOffer,
    raritiesOffer,
    fourthOffer,
  ];

  static const String chikhPykhTransportId = 'chikh_pykh';
  static const String unterTransportId = 'unter';
  static const String maestroTransportId = 'maestro';

  // Вместимости 8 / 12 / 16 — рабочие значения вертикального среза.
  // Стоимость аренды Чих-Пых / Унтер / Маэстро зафиксирована: 0 / 5 / 15 Дар.
  static const BazarTransport chikhPykh = BazarTransport(
    id: chikhPykhTransportId,
    title: 'Чих-Пых',
    cargoCapacity: 8,
    rentalCostDar: 0,
    description: 'Бесплатный, медленный, маленький кузов. Барт помогает вручную.',
    feature: 'Учебный космотрактор',
    canCollectAsteroids: true,
    canFlyToSlon: false,
    expeditionReady: true,
  );

  static const BazarTransport unter = BazarTransport(
    id: unterTransportId,
    title: 'Унтер',
    cargoCapacity: 12,
    rentalCostDar: 5,
    description: 'Быстрее Чих-Пыха, вместительнее, есть роболапа.',
    feature: 'Роболапа и средний кузов',
    canCollectAsteroids: true,
    canFlyToSlon: false,
    expeditionReady: false,
  );

  static const BazarTransport maestro = BazarTransport(
    id: maestroTransportId,
    title: 'Маэстро',
    cargoCapacity: 16,
    rentalCostDar: 15,
    description: 'Мощный космотрактор для тяжёлой работы.',
    feature: 'Большие астероиды и защита от молнии',
    canCollectAsteroids: true,
    canFlyToSlon: false,
    expeditionReady: false,
  );

  static const List<BazarTransport> transports = <BazarTransport>[
    chikhPykh,
    unter,
    maestro,
  ];

  static BazarTrader? traderById(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    for (final trader in traders) {
      if (trader.id == normalized) return trader;
    }
    return null;
  }

  static BazarOffer? offerById(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    for (final offer in offers) {
      if (offer.id == normalized) return offer;
    }
    return null;
  }

  static BazarOffer? offerForTrader(String? traderId) {
    final normalized = traderId?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    for (final offer in offers) {
      if (offer.traderId == normalized) return offer;
    }
    return null;
  }

  static BazarTransport? transportById(String? id) {
    final normalized = id?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    for (final transport in transports) {
      if (transport.id == normalized) return transport;
    }
    return null;
  }
}