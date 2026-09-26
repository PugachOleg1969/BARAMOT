import 'package:baramot/economy_engine.dart';
import 'package:baramot/finance_content.dart';
import 'package:baramot/game_state.dart';
import 'package:baramot/tasks_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = EconomyEngine();

  group('Учебный контент (ТЗ 2.5.8, 2.6)', () {
    test('не менее 6 заданий по 3 темам, по 2 и более на тему', () {
      expect(FinanceContent.tasks.length, greaterThanOrEqualTo(6));
      for (final topic in FinanceTopic.values) {
        final count = FinanceContent.tasks.where((t) => t.topic == topic).length;
        expect(count, greaterThanOrEqualTo(2), reason: topic.title);
      }
    });

    test('у каждого задания уникальный id, ровно один лучший вариант и объяснения', () {
      final ids = FinanceContent.tasks.map((t) => t.id).toSet();
      expect(ids.length, FinanceContent.tasks.length);
      for (final task in FinanceContent.tasks) {
        expect(task.options.length, greaterThanOrEqualTo(2), reason: task.id);
        expect(task.options.where((o) => o.best).length, 1, reason: task.id);
        for (final option in task.options) {
          expect(option.feedback.trim(), isNotEmpty, reason: '${task.id}/${option.id}');
        }
      }
    });

    test('не менее 3 целей накопления с положительной стоимостью', () {
      expect(FinanceContent.goals.length, greaterThanOrEqualTo(3));
      expect(FinanceContent.goals.map((g) => g.id).toSet().length, FinanceContent.goals.length);
      for (final goal in FinanceContent.goals) {
        expect(goal.target, greaterThan(0));
      }
    });
  });

  group('Награды за задания', () {
    test('награда начисляется один раз, повторная отклоняется', () {
      final game = GameStateData(walletDar: 5);
      final task = FinanceContent.tasks.first;

      engine.addIncome(
        game,
        amount: FinanceContent.rewardBest,
        sourceId: 'task_${task.id}',
        sourceTitle: 'Задание',
        reason: 'тест',
        rewardKey: task.rewardKey,
      );
      expect(game.walletDar, 5 + FinanceContent.rewardBest);
      expect(FinanceTaskProgress.isCompleted(game, task), isTrue);

      expect(
        () => engine.addIncome(
          game,
          amount: FinanceContent.rewardBest,
          sourceId: 'task_${task.id}',
          sourceTitle: 'Задание',
          reason: 'тест',
          rewardKey: task.rewardKey,
        ),
        throwsA(isA<EconomyException>()),
      );
      expect(game.walletDar, 5 + FinanceContent.rewardBest);
    });

    test('активное задание — первое непройденное', () {
      final game = GameStateData();
      expect(FinanceTaskProgress.nextTask(game)?.id, FinanceContent.tasks.first.id);
      game.processedRewardKeys.add(FinanceContent.tasks.first.rewardKey);
      expect(FinanceTaskProgress.nextTask(game)?.id, FinanceContent.tasks[1].id);
    });
  });

  group('Снятие из накоплений (ТЗ 2.5.7)', () {
    test('снятие уменьшает накопления и увеличивает кошелёк', () {
      final game = GameStateData(walletDar: 2, savingsDar: 9);
      engine.withdrawSavings(game, amount: 6);
      expect(game.savingsDar, 3);
      expect(game.walletDar, 8);
    });

    test('нельзя снять больше, чем накоплено', () {
      final game = GameStateData(walletDar: 2, savingsDar: 3);
      expect(() => engine.withdrawSavings(game, amount: 4), throwsA(isA<EconomyException>()));
      expect(game.savingsDar, 3);
      expect(game.walletDar, 2);
    });
  });
}
