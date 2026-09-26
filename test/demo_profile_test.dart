import 'package:baramot/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('тестовый профиль сохраняется и восстанавливается (ТЗ 2.5.13)', () {
    final demo = GameStateData(
      introSeen: true,
      onboardingStep: 11,
      profileCreated: true,
      playerName: 'Тестовый Командор',
      selectedPet: PetType.kwak,
      petName: 'Квак',
      walletDar: 30,
      sessionPhase: BaseSessionPhase.morning,
      demoProfile: true,
    )..prepareMorningSession();

    final restored = GameStateData.fromJson(demo.toJson());
    expect(restored.demoProfile, isTrue);
    expect(restored.profileCreated, isTrue);
    expect(restored.sessionPhase, BaseSessionPhase.morning);
    expect(restored.walletDar, 30);
    expect(restored.period, 1);
  });

  test('обычный профиль не помечен как демо, старые сохранения читаются', () {
    expect(GameStateData().demoProfile, isFalse);
    final legacy = GameStateData.fromMap(<String, dynamic>{'profileCreated': true});
    expect(legacy.demoProfile, isFalse);
    expect(legacy.shipEvacuated, isFalse);
  });
}
