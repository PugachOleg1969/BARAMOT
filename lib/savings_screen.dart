import 'package:flutter/material.dart';

import 'economy_engine.dart';
import 'finance_content.dart';
import 'game_state.dart';

/// Экран «Накопления и цели» (ТЗ 2.5.7): выбор цели из готового набора,
/// прогресс по цели, снятие из накоплений только после подтверждения.
///
/// Пополнение накоплений происходит вечером на Совещании в Палатке —
/// там же, где подтверждаются расходы дня.
class SavingsScreen extends StatefulWidget {
  final GameStateData game;
  final Future<void> Function() onSave;
  final VoidCallback onBack;

  const SavingsScreen({
    super.key,
    required this.game,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  static const EconomyEngine _engine = EconomyEngine();

  int _withdrawAmount = 1;

  GameStateData get _game => widget.game;

  Future<void> _selectGoal(SavingsGoal goal) async {
    if (_game.activeGoalId == goal.id) return;
    setState(() {
      _game.activeGoalId = goal.id;
      _game.activeGoalTitle = goal.title;
      _game.activeGoalTarget = goal.target;
    });
    await widget.onSave();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Новая цель: «${goal.title}» · ${goal.target} Дар. Накопления сохранены.'),
        ),
      );
  }

  Future<void> _confirmWithdraw() async {
    final amount = _withdrawAmount.clamp(1, _game.savingsDar).toInt();
    final savingsBefore = _game.savingsDar;
    final savingsAfter = savingsBefore - amount;
    final remainingBefore = (_game.activeGoalTarget - savingsBefore).clamp(0, _game.activeGoalTarget).toInt();
    final remainingAfter = (_game.activeGoalTarget - savingsAfter).clamp(0, _game.activeGoalTarget).toInt();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Снять из накоплений?'),
        content: Text(
          'В кошелёк: +$amount Дар.\n'
          'Накопления: $savingsBefore → $savingsAfter Дар.\n'
          'До цели «${_game.activeGoalTitle}»: было $remainingBefore Дар, станет $remainingAfter Дар.\n\n'
          'Цель отодвинется. Точно снять?',
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Оставить в копилке'),
          ),
          TextButton(
            key: const Key('savings.withdraw.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Снять'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      _engine.withdrawSavings(
        _game,
        amount: amount,
        sourceTitle: 'Накопления на цель',
        reason: 'Снято из накоплений на цель «${_game.activeGoalTitle}»',
      );
    } on EconomyException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    setState(() => _withdrawAmount = 1);
    await widget.onSave();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Снято $amount Дар. В кошельке: ${_game.walletDar} Дар, в накоплениях: ${_game.savingsDar} Дар.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final savings = _game.savingsDar;
    final maxWithdraw = savings;
    if (_withdrawAmount > maxWithdraw && maxWithdraw > 0) _withdrawAmount = maxWithdraw;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onBack();
      },
      child: ColoredBox(
        color: const Color(0xFF11182B),
        child: ListView(
          key: const Key('savings.screen'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Вернуться на Базу',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text('Накопления и цели', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x1AFFC85C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFC85C).withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  const Text('🐷', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('В накоплениях: $savings Дар',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('В кошельке: ${_game.walletDar} Дар',
                            style: const TextStyle(fontSize: 15, color: Color(0xFFC5D0E4))),
                        const SizedBox(height: 4),
                        const Text(
                          'Отложить в накопления можно вечером на Совещании в Палатке.',
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF9FB0CC)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text('Выберите цель', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            for (final goal in FinanceContent.goals) ...[
              _GoalCard(
                goal: goal,
                savings: savings,
                active: _game.activeGoalId == goal.id,
                onSelect: () => _selectGoal(goal),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2743),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334564)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Снять из накоплений', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    savings == 0
                        ? 'В накоплениях пока пусто — снимать нечего.'
                        : 'Если очень нужно, часть накоплений можно вернуть в кошелёк. Цель при этом отодвинется.',
                    style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFFC5D0E4)),
                  ),
                  if (savings > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Меньше',
                          onPressed: _withdrawAmount > 1 ? () => setState(() => _withdrawAmount -= 1) : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        const SizedBox(width: 14),
                        Text('$_withdrawAmount Дар', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 14),
                        IconButton.filledTonal(
                          tooltip: 'Больше',
                          onPressed: _withdrawAmount < maxWithdraw ? () => setState(() => _withdrawAmount += 1) : null,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('savings.withdraw'),
                      onPressed: _confirmWithdraw,
                      icon: const Icon(Icons.outbox_rounded),
                      label: const Text('Снять…'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final int savings;
  final bool active;
  final VoidCallback onSelect;

  const _GoalCard({required this.goal, required this.savings, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final progress = (savings / goal.target).clamp(0.0, 1.0).toDouble();
    final remaining = (goal.target - savings).clamp(0, goal.target).toInt();
    final accent = active ? const Color(0xFF8DE5A1) : const Color(0xFF3A4E70);

    return Material(
      color: active ? const Color(0x148DE5A1) : const Color(0xFF19243D),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('savings.goal.${goal.id}'),
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent, width: active ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(goal.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(goal.title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)),
                        Text('Стоимость: ${goal.target} Дар',
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFFB8C7E3))),
                      ],
                    ),
                  ),
                  if (active)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, color: Color(0xFF8DE5A1)),
                        SizedBox(width: 4),
                        Text('Моя цель', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                      ],
                    )
                  else
                    const Text('Выбрать', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF70D7FF))),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFF2A3754),
                  color: active ? const Color(0xFF8DE5A1) : const Color(0xFF70D7FF),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                remaining == 0
                    ? 'Накоплено: ${goal.target} из ${goal.target} Дар — цель достигнута!'
                    : 'Накоплено: ${savings.clamp(0, goal.target)} из ${goal.target} Дар · осталось $remaining Дар',
                style: const TextStyle(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
