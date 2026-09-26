import 'package:flutter/material.dart';

import 'economy_engine.dart';
import 'finance_content.dart';
import 'game_state.dart';

/// Проверки заданий, которые нужны и экрану, и Базе, и разделу взрослого.
class FinanceTaskProgress {
  const FinanceTaskProgress._();

  static bool isCompleted(GameStateData game, FinanceTask task) {
    return game.processedRewardKeys.contains(task.rewardKey);
  }

  static List<FinanceTask> completed(GameStateData game) {
    return FinanceContent.tasks
        .where((task) => isCompleted(game, task))
        .toList(growable: false);
  }

  /// Первое ещё не пройденное задание — «активное задание» для главного экрана.
  static FinanceTask? nextTask(GameStateData game) {
    for (final task in FinanceContent.tasks) {
      if (!isCompleted(game, task)) return task;
    }
    return null;
  }
}

/// Экран «Задания» (ТЗ 2.5.8): игровые ситуации с выбором, последствием
/// и объяснением. В демонстрационном режиме все задания доступны сразу.
class TasksScreen extends StatefulWidget {
  final GameStateData game;
  final Future<void> Function() onSave;
  final VoidCallback onBack;
  final String? initialTaskId;

  const TasksScreen({
    super.key,
    required this.game,
    required this.onSave,
    required this.onBack,
    this.initialTaskId,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const EconomyEngine _engine = EconomyEngine();

  final ScrollController _taskScroll = ScrollController();

  FinanceTask? _task;
  FinanceTaskOption? _chosen;
  int _rewardGiven = 0;
  bool _rewardAlreadyReceived = false;

  @override
  void initState() {
    super.initState();
    final initialId = widget.initialTaskId;
    if (initialId != null) _task = FinanceContent.taskById(initialId);
  }

  @override
  void dispose() {
    _taskScroll.dispose();
    super.dispose();
  }

  /// После выбора прокручиваем вниз, чтобы объяснение и кнопки были видны
  /// сразу, даже на маленьком экране.
  void _scrollToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_taskScroll.hasClients) return;
      _taskScroll.animateTo(
        _taskScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _openTask(FinanceTask task) {
    setState(() {
      _task = task;
      _chosen = null;
      _rewardGiven = 0;
      _rewardAlreadyReceived = false;
    });
  }

  void _backToList() {
    setState(() {
      _task = null;
      _chosen = null;
    });
  }

  Future<void> _choose(FinanceTask task, FinanceTaskOption option) async {
    if (_chosen != null) return;
    final game = widget.game;
    var reward = 0;
    var already = FinanceTaskProgress.isCompleted(game, task);

    if (!already) {
      reward = option.best ? FinanceContent.rewardBest : FinanceContent.rewardOther;
      try {
        _engine.addIncome(
          game,
          amount: reward,
          sourceId: 'task_${task.id}',
          sourceTitle: 'Задание «${task.title}»',
          reason: 'Награда за задание: ${task.topic.title}',
          rewardKey: task.rewardKey,
        );
      } on EconomyException {
        // Награда уже была начислена (например, после перезапуска).
        reward = 0;
        already = true;
      }
    }

    setState(() {
      _chosen = option;
      _rewardGiven = reward;
      _rewardAlreadyReceived = already;
    });
    _scrollToFeedback();
    await widget.onSave();
  }

  void _retry() {
    setState(() {
      _chosen = null;
      _rewardGiven = 0;
      _rewardAlreadyReceived = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_task != null) {
          _backToList();
        } else {
          widget.onBack();
        }
      },
      child: ColoredBox(
        color: const Color(0xFF11182B),
        child: task == null ? _buildList() : _buildTask(task),
      ),
    );
  }

  Widget _header(String title, VoidCallback onBack) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Назад',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Widget _buildList() {
    final game = widget.game;
    final done = FinanceTaskProgress.completed(game).length;
    return ListView(
      key: const Key('tasks.list'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _header('Задания', widget.onBack),
        const SizedBox(height: 8),
        _IyaCard(
          text: 'Командор, вот задания от меня. В каждом — ситуация и выбор. '
              'За первое прохождение — Дар на счёт. Пройдено: $done из ${FinanceContent.tasks.length}.',
        ),
        const SizedBox(height: 12),
        for (final topic in FinanceTopic.values) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              '${topic.emoji}  ${topic.title}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          for (final task in FinanceContent.tasks.where((t) => t.topic == topic)) ...[
            _TaskTile(
              task: task,
              completed: FinanceTaskProgress.isCompleted(game, task),
              onTap: () => _openTask(task),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildTask(FinanceTask task) {
    final chosen = _chosen;
    return ListView(
      key: Key('tasks.task.${task.id}'),
      controller: _taskScroll,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _header(task.title, _backToList),
        const SizedBox(height: 4),
        Text(
          '${task.topic.emoji}  ${task.topic.title}',
          style: const TextStyle(fontSize: 14, color: Color(0xFF9FB0CC), fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _IyaCard(text: task.situation),
        const SizedBox(height: 14),
        for (final option in task.options) ...[
          _OptionButton(
            key: Key('tasks.option.${task.id}.${option.id}'),
            option: option,
            chosen: chosen,
            onTap: chosen == null ? () => _choose(task, option) : null,
          ),
          const SizedBox(height: 8),
        ],
        if (chosen != null) ...[
          const SizedBox(height: 6),
          _FeedbackCard(
            option: chosen,
            reward: _rewardGiven,
            rewardAlreadyReceived: _rewardAlreadyReceived && _rewardGiven == 0,
            taskTitle: task.title,
            walletDar: widget.game.walletDar,
          ),
          const SizedBox(height: 12),
          // Повторить можно после любого выбора: так легко посмотреть
          // и лучший, и другой вариант (награда при этом не повторяется).
          OutlinedButton.icon(
            key: const Key('tasks.retry'),
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(chosen.best ? 'Пройти ещё раз' : 'Попробовать ещё раз'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('tasks.back_to_list'),
            onPressed: _backToList,
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('К списку заданий'),
          ),
        ],
      ],
    );
  }
}

class _IyaCard extends StatelessWidget {
  final String text;

  const _IyaCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ия говорит: $text',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2743),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334564)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ия', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFFC85C))),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(fontSize: 17, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final FinanceTask task;
  final bool completed;
  final VoidCallback onTap;

  const _TaskTile({required this.task, required this.completed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = completed ? const Color(0xFF8DE5A1) : const Color(0xFF70D7FF);
    return Material(
      color: const Color(0xFF19243D),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('tasks.open.${task.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(
                completed ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Text(
                completed ? 'пройдено' : 'до +${FinanceContent.rewardBest} Дар',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final FinanceTaskOption option;
  final FinanceTaskOption? chosen;
  final VoidCallback? onTap;

  const _OptionButton({super.key, required this.option, required this.chosen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isChosen = chosen?.id == option.id;
    // Цвет — не единственный признак (ТЗ 3.6): у выбранного варианта ещё
    // и значок, и подпись «Ваш выбор».
    final accent = !isChosen
        ? const Color(0xFF3A4E70)
        : option.best
            ? const Color(0xFF8DE5A1)
            : const Color(0xFFFFB36B);
    return Material(
      color: isChosen ? accent.withValues(alpha: 0.12) : const Color(0xFF19243D),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent, width: isChosen ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(option.text, style: const TextStyle(fontSize: 16, height: 1.3)),
              ),
              if (isChosen) ...[
                const SizedBox(width: 8),
                Icon(
                  option.best ? Icons.check_circle_rounded : Icons.lightbulb_outline_rounded,
                  color: accent,
                ),
                const SizedBox(width: 4),
                const Text('Ваш выбор', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FinanceTaskOption option;
  final int reward;
  final bool rewardAlreadyReceived;
  final String taskTitle;
  final int walletDar;

  const _FeedbackCard({
    required this.option,
    required this.reward,
    required this.rewardAlreadyReceived,
    required this.taskTitle,
    required this.walletDar,
  });

  @override
  Widget build(BuildContext context) {
    final accent = option.best ? const Color(0xFF8DE5A1) : const Color(0xFFFFB36B);
    final String rewardText;
    if (reward > 0) {
      rewardText = '+$reward Дар · источник: задание «$taskTitle». В кошельке: $walletDar Дар.';
    } else if (rewardAlreadyReceived) {
      rewardText = 'Награда за это задание уже получена — Дар не меняется.';
    } else {
      rewardText = '';
    }

    return Container(
      key: const Key('tasks.feedback'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(option.best ? Icons.emoji_events_rounded : Icons.lightbulb_rounded, color: accent),
              const SizedBox(width: 8),
              Text(
                option.best ? 'Отличное решение!' : 'Давай разберёмся',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(option.feedback, style: const TextStyle(fontSize: 16, height: 1.4)),
          if (rewardText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFFFC85C)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rewardText,
                    style: const TextStyle(fontSize: 14.5, color: Color(0xFFFFC85C), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
