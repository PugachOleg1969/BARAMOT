import 'package:baramot/commander_school.dart';
import 'package:baramot/finance_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Школа командиров: ранги', () {
    test('ранги идут по возрастанию, высший — «Профи» за все задания', () {
      final ranks = CommanderSchool.ranks;
      expect(ranks.first.tasksRequired, 0);
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i].level, greaterThan(ranks[i - 1].level));
        expect(ranks[i].tasksRequired, greaterThan(ranks[i - 1].tasksRequired));
      }
      expect(ranks.last.title, 'Профи');
      expect(ranks.last.tasksRequired, FinanceContent.tasks.length);
    });

    test('ранг по числу пройденных заданий', () {
      expect(CommanderSchool.rankFor(0).title, 'Слушатель курсов');
      expect(CommanderSchool.rankFor(1).title, 'Слушатель курсов');
      expect(CommanderSchool.rankFor(2).title, 'Командир 1-го ранга');
      expect(CommanderSchool.rankFor(3).title, 'Командир 1-го ранга');
      expect(CommanderSchool.rankFor(4).title, 'Командир 2-го ранга');
      expect(CommanderSchool.rankFor(6).title, 'Профи');
      expect(CommanderSchool.rankFor(99).title, 'Профи');
    });

    test('сколько осталось до следующего ранга', () {
      expect(CommanderSchool.tasksToNext(0), 2);
      expect(CommanderSchool.tasksToNext(1), 1);
      expect(CommanderSchool.tasksToNext(5), 1);
      expect(CommanderSchool.tasksToNext(6), 0);
      expect(CommanderSchool.nextRank(6), isNull);
    });

    test('повышение фиксируется только при смене ранга и никогда не понижает', () {
      expect(CommanderSchool.promotion(1, 2)?.title, 'Командир 1-го ранга');
      expect(CommanderSchool.promotion(2, 3), isNull);
      expect(CommanderSchool.promotion(5, 6)?.title, 'Профи');
      expect(CommanderSchool.promotion(6, 6), isNull);
      expect(CommanderSchool.promotion(4, 2), isNull);
    });

    test('строка статуса понятна ребёнку', () {
      expect(CommanderSchool.statusLine(0), contains('до следующего ранга 2 задания'));
      expect(CommanderSchool.statusLine(1), contains('до следующего ранга 1 задание'));
      expect(CommanderSchool.statusLine(6), contains('высший ранг'));
    });
  });
}
