import 'package:baramot/game_state.dart';
import 'package:baramot/ship_repair_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShipRepairCatalog', () {
    test('has exactly 4 positions with the agreed prices', () {
      expect(ShipRepairCatalog.items, hasLength(4));
      expect(ShipRepairCatalog.activeSlotLimit, 2);

      final protopositron = ShipRepairCatalog.byId('repair_protopositron')!;
      expect(protopositron.unitCost, 18);
      expect(protopositron.totalUnits, 1);
      expect(protopositron.totalCost, 18);

      final khlopovik = ShipRepairCatalog.byId('repair_khlopovik')!;
      expect(khlopovik.unitCost, 15);
      expect(khlopovik.totalUnits, 1);

      final fuelSensor = ShipRepairCatalog.byId('repair_fuel_sensor')!;
      expect(fuelSensor.unitCost, 8);
      expect(fuelSensor.totalUnits, 2);
      expect(fuelSensor.totalCost, 16);

      final tumannik = ShipRepairCatalog.byId('repair_tumannik')!;
      expect(tumannik.unitCost, 6);
      expect(tumannik.totalUnits, 3);
      expect(tumannik.totalCost, 18);
    });

    test('unknown id resolves to null', () {
      expect(ShipRepairCatalog.byId('repair_unknown'), isNull);
    });
  });

  group('GameStateData ship repair progress', () {
    test('starts with everything in the backlog and nothing active', () {
      final state = GameStateData();

      expect(state.shipRepairActiveItems, isEmpty);
      expect(state.shipRepairPendingItems, hasLength(4));
      expect(state.shipRepairRemainingUnits('repair_tumannik'), 3);
      expect(state.isShipRepairItemClosed('repair_tumannik'), isFalse);
    });

    test('activation respects the active-slot limit', () {
      final state = GameStateData();

      expect(state.activateShipRepairItem('repair_protopositron'), isTrue);
      expect(state.activateShipRepairItem('repair_khlopovik'), isTrue);
      // Третий слот занять нельзя — лимит 2.
      expect(state.activateShipRepairItem('repair_fuel_sensor'), isFalse);

      expect(state.shipRepairActiveItems.map((item) => item.id), containsAll(
        <String>['repair_protopositron', 'repair_khlopovik'],
      ));
      expect(state.shipRepairPendingItems.map((item) => item.id), containsAll(
        <String>['repair_fuel_sensor', 'repair_tumannik'],
      ));
    });

    test('unknown or already-active id cannot be activated twice', () {
      final state = GameStateData();

      expect(state.activateShipRepairItem('repair_unknown'), isFalse);
      expect(state.activateShipRepairItem('repair_tumannik'), isTrue);
      expect(state.activateShipRepairItem('repair_tumannik'), isFalse);
    });

    test('excluding an active item frees a slot but keeps paid progress', () {
      final state = GameStateData();
      state.activateShipRepairItem('repair_fuel_sensor');
      state.payShipRepairUnits('repair_fuel_sensor', 1);

      expect(state.shipRepairUnitsPaidFor('repair_fuel_sensor'), 1);

      expect(state.excludeShipRepairItem('repair_fuel_sensor'), isTrue);
      expect(state.shipRepairActiveItems, isEmpty);
      // Прогресс сохранился — позиция снова в бэклоге, а не закрыта.
      expect(state.shipRepairPendingItems.map((item) => item.id), contains('repair_fuel_sensor'));
      expect(state.shipRepairUnitsPaidFor('repair_fuel_sensor'), 1);

      // При повторной активации счётчик продолжается с той же суммы.
      expect(state.activateShipRepairItem('repair_fuel_sensor'), isTrue);
      expect(state.shipRepairRemainingUnits('repair_fuel_sensor'), 1);
    });

    test('paying more units than remaining is refused', () {
      final state = GameStateData();
      state.activateShipRepairItem('repair_khlopovik');

      expect(state.payShipRepairUnits('repair_khlopovik', 2), isFalse);
      expect(state.shipRepairUnitsPaidFor('repair_khlopovik'), 0);
    });

    test('paying the last unit closes the position and frees its slot', () {
      final state = GameStateData();
      state.activateShipRepairItem('repair_khlopovik');
      state.activateShipRepairItem('repair_tumannik');

      expect(state.payShipRepairUnits('repair_khlopovik', 1), isTrue);

      expect(state.isShipRepairItemClosed('repair_khlopovik'), isTrue);
      expect(
        state.shipRepairActiveItems.map((item) => item.id),
        isNot(contains('repair_khlopovik')),
      );
      expect(
        state.shipRepairPendingItems.map((item) => item.id),
        isNot(contains('repair_khlopovik')),
      );

      // Слот освободился — можно активировать ещё одну позицию.
      expect(state.activateShipRepairItem('repair_fuel_sensor'), isTrue);
    });

    test('partial payment across two sessions closes a multi-unit position', () {
      final state = GameStateData();
      state.activateShipRepairItem('repair_tumannik');

      expect(state.payShipRepairUnits('repair_tumannik', 2), isTrue);
      expect(state.isShipRepairItemClosed('repair_tumannik'), isFalse);
      expect(state.shipRepairRemainingUnits('repair_tumannik'), 1);

      expect(state.payShipRepairUnits('repair_tumannik', 1), isTrue);
      expect(state.isShipRepairItemClosed('repair_tumannik'), isTrue);
    });

    test('JSON round-trip preserves repair progress and active slots', () {
      final state = GameStateData();
      state.activateShipRepairItem('repair_fuel_sensor');
      state.payShipRepairUnits('repair_fuel_sensor', 1);
      state.activateShipRepairItem('repair_tumannik');

      final restored = GameStateData.fromJson(state.toJson());

      expect(restored.shipRepairUnitsPaidFor('repair_fuel_sensor'), 1);
      expect(
        restored.shipRepairActiveItems.map((item) => item.id),
        containsAll(<String>['repair_fuel_sensor', 'repair_tumannik']),
      );
    });

    test('old saves without ship repair fields default to an empty backlog state', () {
      // Имитация сохранения до этой версии схемы: ключей shipRepair* нет.
      final state = GameStateData.fromMap(const <String, dynamic>{
        'schemaVersion': 7,
        'profileCreated': true,
        'walletDar': 12,
      });

      expect(state.shipRepairUnitsPaid, isEmpty);
      expect(state.shipRepairActiveIds, isEmpty);
      expect(state.shipRepairPendingItems, hasLength(4));
    });
  });
}
