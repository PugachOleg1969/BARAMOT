import 'package:flutter/material.dart';

/// «Справочная» на Базе: окно, в котором сидит пожилая Пчела.
/// Тап по окну открывает памятку о порядке дня Командора.
///
/// Арт: assets/characters/spravochnaya_bee.png (папка assets/characters/
/// уже подключена в pubspec.yaml). Если файла нет — вместо арта показывается
/// эмодзи 🐝, приложение не падает.
class SpravochnayaCatalog {
  const SpravochnayaCatalog._();

  static const String artAsset = 'assets/characters/spravochnaya_bee.png';
  static const String speaker = 'Пчела-справочная';

  static const String greeting =
      'Здравствуйте, Справочная! Прочитайте до конца, прежде чем выходить на дежурство.';

  /// Пункты памятки. Порядок = порядок игрового дня.
  static const List<String> rules = <String>[
    'Утро Командора начинается с обхода: загляните к Питомцу и к Барри. '
        'Выберите, что им нужно сегодня, — это попадёт в План. План вы увидите в Палатке.',
    'План утверждаем утром на Совещании. Что не нравится — можно исключить.',
    'Дар зарабатывается на квестах. Дорога на Базар — через окно Базы.',
    'Вечером возвращаетесь домой и на Совещании утверждаете расходы — '
        'только тогда покупки совершаются.',
    'Откладывайте хоть немного Дар в накопления — так Питомец растёт!',
  ];
}

/// Окно Справочной с Пчелой для сцены Базы.
class SpravochnayaWindow extends StatelessWidget {
  final VoidCallback onTap;

  const SpravochnayaWindow({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Справочная',
      child: GestureDetector(
        key: const Key('base.info.hotspot'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Image.asset(
          SpravochnayaCatalog.artAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => const _BeeFallback(),
        ),
      ),
    );
  }
}

class _BeeFallback extends StatelessWidget {
  const _BeeFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD9142037),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFC85C), width: 2),
      ),
      alignment: Alignment.center,
      child: const FittedBox(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🐝', style: TextStyle(fontSize: 30)),
              Text('Справочная', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Открывает памятку Пчелы.
Future<void> showSpravochnayaDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _SpravochnayaDialog(),
  );
}

class _SpravochnayaDialog extends StatelessWidget {
  const _SpravochnayaDialog();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Dialog(
      key: const Key('spravochnaya.dialog'),
      backgroundColor: const Color(0xFF182641),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: Color(0xFFFFC85C), width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: Image.asset(
                  SpravochnayaCatalog.artAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text('🐝', style: TextStyle(fontSize: 64)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                SpravochnayaCatalog.speaker,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFFFC85C),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                SpravochnayaCatalog.greeting,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < SpravochnayaCatalog.rules.length; i++)
                _RuleRow(number: i + 1, text: SpravochnayaCatalog.rules[i]),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('spravochnaya.close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Понятно, на дежурство!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final int number;
  final String text;

  const _RuleRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC85C),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF182641),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Color(0xFFD3DDF0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
