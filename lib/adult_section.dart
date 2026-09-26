import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'legal_texts.dart';
import 'title_screen.dart';

/// Барьер для взрослого (ТЗ 2.5.12): простой арифметический пример,
/// который ребёнку 7–11 лет решить заметно сложнее, чем взрослому.
/// Возвращает true, если ответ верный.
Future<bool> showAdultGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const _AdultGateDialog(),
  );
  return result == true;
}

class _AdultGateDialog extends StatefulWidget {
  const _AdultGateDialog();

  @override
  State<_AdultGateDialog> createState() => _AdultGateDialogState();
}

class _AdultGateDialogState extends State<_AdultGateDialog> {
  final TextEditingController _answer = TextEditingController();
  final math.Random _random = math.Random();
  late int _a;
  late int _b;
  late int _c;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newExample();
  }

  void _newExample() {
    _a = 6 + _random.nextInt(4); // 6..9
    _b = 6 + _random.nextInt(4); // 6..9
    _c = 11 + _random.nextInt(29); // 11..39
  }

  int get _expected => _a * _b + _c;

  void _check() {
    final value = int.tryParse(_answer.text.trim());
    if (value == _expected) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _error = 'Неверно. Попробуйте новый пример.';
      _answer.clear();
      _newExample();
    });
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('adult.gate'),
      title: const Text('Раздел для взрослого'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Чтобы войти, решите пример:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            '$_a × $_b + $_c = ?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('adult.gate.answer'),
            controller: _answer,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            onSubmitted: (_) => _check(),
            decoration: InputDecoration(
              labelText: 'Ответ',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        TextButton(
          key: const Key('adult.gate.submit'),
          onPressed: _check,
          child: const Text('Войти'),
        ),
      ],
    );
  }
}

/// Одна строка прогресса ребёнка — только нейтральные факты, без оценок.
class AdultProgressRow {
  final IconData icon;
  final String label;
  final String value;

  const AdultProgressRow({required this.icon, required this.label, required this.value});
}

/// Экран «Для взрослого» (ТЗ 2.3, 2.5.12, 3.5, 3.6).
class AdultSectionScreen extends StatelessWidget {
  final String playerName;
  final List<AdultProgressRow> progress;
  final List<String> completedTopics;
  final VoidCallback onBack;
  final VoidCallback onResetProfile;
  final VoidCallback onLoadDemoProfile;

  const AdultSectionScreen({
    super.key,
    required this.playerName,
    required this.progress,
    required this.completedTopics,
    required this.onBack,
    required this.onResetProfile,
    required this.onLoadDemoProfile,
  });

  static const List<String> _learningGoals = <String>[
    'Понимать назначение личного бюджета: расходы не должны превышать доходов.',
    'Различать обязательные и необязательные расходы — «НАДО» и «ХОЧУ».',
    'Планировать покупки при ограниченном бюджете и сверять План с Фактом.',
    'Ставить краткосрочную цель и регулярно откладывать часть средств.',
    'Оценивать свои решения и объяснять, к чему они привели.',
    'Пользоваться приложением для планирования вместе со взрослым.',
  ];

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: const Text(
          'Будут удалены игровой образ, питомец, Дар, накопления и весь прогресс '
          'на этом устройстве. Действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('adult.reset.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) onResetProfile();
  }

  Future<void> _confirmDemo(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Загрузить тестовый профиль?'),
        content: const Text(
          'Текущий прогресс будет заменён готовым тестовым профилем: Командор, '
          'питомец Квак и 30 Дар. Игра сразу откроет Базу утром первого дня — '
          'пролог пропускается. Вернуться к обычной игре можно сбросом профиля.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('adult.demo.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
    if (confirmed == true) onLoadDemoProfile();
  }

  void _openDocument(BuildContext context, LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = playerName.trim().isEmpty ? 'Командор' : playerName.trim();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBack();
      },
      child: ColoredBox(
        color: const Color(0xFF11182B),
        child: ListView(
          key: const Key('adult.section'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('adult.back'),
                  tooltip: 'Вернуться в игру',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Для взрослого',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                ),
                const Icon(Icons.family_restroom_rounded, color: Color(0xFFFFC85C)),
              ],
            ),
            const SizedBox(height: 10),
            _Section(
              title: 'Прогресс: $name',
              icon: Icons.insights_rounded,
              child: Column(
                children: [
                  for (final row in progress) _ProgressLine(row: row),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Пройденные темы',
              icon: Icons.task_alt_rounded,
              child: completedTopics.isEmpty
                  ? const Text(
                      'Пока ни одно задание не пройдено — всё впереди.',
                      style: TextStyle(fontSize: 15, color: Color(0xFFC5D0E4)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final topic in completedTopics)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_rounded, size: 18, color: Color(0xFF8DE5A1)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(topic, style: const TextStyle(fontSize: 15))),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Чему учит игра',
              icon: Icons.school_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'По Единой рамке компетенций в области финансовой грамотности '
                    '(начальное общее образование):',
                    style: TextStyle(fontSize: 14, color: Color(0xFF9FB0CC)),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < _learningGoals.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        '${i + 1}. ${_learningGoals[i]}',
                        style: const TextStyle(fontSize: 15, height: 1.35),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Настройки',
              icon: Icons.tune_rounded,
              child: ListenableBuilder(
                listenable: AppSettings.instance,
                builder: (context, _) {
                  final settings = AppSettings.instance;
                  return Column(
                    children: [
                      SwitchListTile(
                        key: const Key('adult.sound'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Звуки'),
                        subtitle: const Text('Фоновые звуки, видео и звуки тира'),
                        value: settings.soundEnabled,
                        onChanged: settings.setSoundEnabled,
                      ),
                      SwitchListTile(
                        key: const Key('adult.animations'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Анимации'),
                        subtitle: const Text('Переходы между экранами и сцены финала'),
                        value: settings.animationsEnabled,
                        onChanged: settings.setAnimationsEnabled,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Демонстрационный режим',
              icon: Icons.science_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Для экспертной проверки: готовый профиль без пролога. Игровые '
                    'периоды идут подряд, без ожидания реального времени — '
                    'все 5 сессий и ПХД можно пройти за одну демонстрацию.',
                    style: TextStyle(fontSize: 15, height: 1.35, color: Color(0xFFC5D0E4)),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('adult.demo'),
                    onPressed: () => _confirmDemo(context),
                    icon: const Icon(Icons.play_circle_outline_rounded),
                    label: const Text('Загрузить тестовый профиль'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Данные и документы',
              icon: Icons.privacy_tip_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Игра не собирает персональные данные и не выходит в интернет. '
                    'Весь прогресс хранится только на этом устройстве.',
                    style: TextStyle(fontSize: 15, height: 1.35, color: Color(0xFFC5D0E4)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _openDocument(context, LegalTexts.privacy),
                        child: const Text('Политика конфиденциальности'),
                      ),
                      TextButton(
                        onPressed: () => _openDocument(context, LegalTexts.terms),
                        child: const Text('Пользовательское соглашение'),
                      ),
                      TextButton(
                        onPressed: () => _openDocument(context, LegalTexts.about),
                        child: const Text('Об игре'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('adult.reset'),
                    onPressed: () => _confirmReset(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8A80),
                      side: const BorderSide(color: Color(0xFFFF8A80), width: 1.5),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Сбросить и удалить профиль'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${LegalInfo.appName} · версия ${LegalInfo.appVersion} · ${LegalInfo.ageRating}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8C9BB8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2743),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334564)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF70D7FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final AdultProgressRow row;

  const _ProgressLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(row.icon, size: 20, color: const Color(0xFFFFC85C)),
          const SizedBox(width: 10),
          Expanded(child: Text(row.label, style: const TextStyle(fontSize: 15))),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
