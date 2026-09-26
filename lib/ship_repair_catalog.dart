import 'ship_repair_models.dart';

/// Каталог ремонта корабля — 4 согласованные позиции запчастей.
///
/// Цены пересчитаны от реального дохода BAZAR (после наценки +3 Дар за
/// сделку — см. bazar_game_catalog.dart) так, чтобы весь ремонт закрывался
/// за 1–2 цикла (5–10 рабочих сессий), а не за много циклов подряд.
class ShipRepairCatalog {
  const ShipRepairCatalog._();

  /// Сколько позиций ремонта может находиться в активном Плане одновременно.
  /// Остальные ждут своей очереди в бэклоге.
  static const int activeSlotLimit = 2;

  static const List<ShipRepairItemDefinition> items = <ShipRepairItemDefinition>[
    ShipRepairItemDefinition(
      id: 'repair_protopositron',
      title: 'Протопозитрон',
      unitCost: 18,
      totalUnits: 1,
    ),
    ShipRepairItemDefinition(
      id: 'repair_khlopovik',
      title: 'Хлоповик',
      unitCost: 15,
      totalUnits: 1,
    ),
    ShipRepairItemDefinition(
      id: 'repair_fuel_sensor',
      title: 'Датчик топливный',
      unitCost: 8,
      totalUnits: 2,
    ),
    ShipRepairItemDefinition(
      id: 'repair_tumannik',
      title: 'Туманник',
      unitCost: 6,
      totalUnits: 3,
    ),
  ];

  static ShipRepairItemDefinition? byId(String id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }
}
