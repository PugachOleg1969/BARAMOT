/// Одна позиция ремонта корабля: покупается по частям (поштучно),
/// поэтому у неё есть цена за штуку и общее нужное количество штук.
class ShipRepairItemDefinition {
  final String id;
  final String title;
  final int unitCost;
  final int totalUnits;

  const ShipRepairItemDefinition({
    required this.id,
    required this.title,
    required this.unitCost,
    required this.totalUnits,
  });

  /// Полная стоимость позиции, если купить все штуки разом.
  int get totalCost => unitCost * totalUnits;
}
