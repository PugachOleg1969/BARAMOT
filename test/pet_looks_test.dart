import 'dart:io';

import 'package:baramot/game_state.dart';
import 'package:baramot/pet_looks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('не менее 9 визуальных комбинаций питомца (ТЗ 2.6)', () {
    expect(PetLooks.combinations, greaterThanOrEqualTo(9));
    for (final pet in PetType.values) {
      expect(PetLooks.forPet(pet).length, greaterThanOrEqualTo(3), reason: pet.name);
    }
  });

  test('id образов уникальны, файлы образов лежат в assets', () {
    final all = PetType.values.expand(PetLooks.forPet).toList();
    expect(all.map((look) => look.id).toSet().length, all.length);
    for (final look in all) {
      expect(File(look.asset).existsSync(), isTrue, reason: look.asset);
    }
  });

  test('неизвестный номер образа не ломает игру', () {
    expect(PetLooks.of(PetType.kwak, 99).id, PetLooks.kwak.last.id);
    expect(PetLooks.of(PetType.kwak, -5).id, PetLooks.kwak.first.id);
  });
}
