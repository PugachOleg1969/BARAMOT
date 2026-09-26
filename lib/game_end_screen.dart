import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_settings.dart';

/// Итоги всей игры для финального экрана.
class GameEndSummary {
  final String playerName;
  final String petName;
  final String petEmoji;
  final String? petArtAsset;
  final String petStageTitle;
  final int workSessions;
  final int totalEarnedDar;
  final int repairSpentDar;
  final int savingsDar;

  /// true — альтернативный финал: корабль не починили, его увезла
  /// техничка (эвакуация). false — корабль починен и улетел сам.
  final bool evacuated;

  const GameEndSummary({
    required this.playerName,
    required this.petName,
    required this.petEmoji,
    required this.petArtAsset,
    required this.petStageTitle,
    required this.workSessions,
    required this.totalEarnedDar,
    required this.repairSpentDar,
    required this.savingsDar,
    this.evacuated = false,
  });
}

/// Экран «Конец игры». Сверчок прощается с Командором за всю команду.
/// Два финала:
/// - корабль починен → он улетает сам;
/// - эвакуация → корабль увозит техничка.
/// Дальше — «Начать заново» или «Выход».
class GameEndScreen extends StatefulWidget {
  final GameEndSummary summary;
  final VoidCallback onRestart;
  final VoidCallback onExitToTitle;

  const GameEndScreen({
    super.key,
    required this.summary,
    required this.onRestart,
    required this.onExitToTitle,
  });

  @override
  State<GameEndScreen> createState() => _GameEndScreenState();
}

enum _EndStage { farewell, launch, finale }

class _GameEndScreenState extends State<GameEndScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _launch;
  _EndStage _stage = _EndStage.farewell;

  @override
  void initState() {
    super.initState();
    _launch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _stage = _EndStage.finale);
        }
      });
  }

  @override
  void dispose() {
    _launch.dispose();
    super.dispose();
  }

  void _startLaunch() {
    // Анимации отключены взрослым — сразу показываем итоги.
    if (!AppSettings.instance.animationsEnabled) {
      setState(() => _stage = _EndStage.finale);
      return;
    }
    setState(() => _stage = _EndStage.launch);
    _launch.forward(from: 0);
  }

  Future<void> _confirmRestart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Начать заново?'),
        content: const Text(
          'Весь прогресс этой игры будет удалён, и приключение начнётся с самого начала.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            key: const Key('game_end.restart.confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Начать заново'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onRestart();
  }

  String get _speech {
    final s = widget.summary;
    final name = s.playerName.trim();
    final commander = name.isEmpty ? 'Командор' : 'Командор $name';
    final pet = s.petName.trim().isEmpty ? 'Питомец' : s.petName.trim();

    if (s.evacuated) {
      return 'Дорогой $commander! Позвольте сказать за всю команду.\n\n'
          'Корабль Барри в этот раз починить не успели, поэтому мы вызвали '
          'техничку. Она аккуратно отбуксирует корабль на ремонтную станцию, '
          'а Барри, Барт и Ия отправятся вместе с ним.\n\n'
          'Не расстраивайтесь: Вы многому научились — составлять План, '
          'различать НАДО и ХОЧУ, откладывать в накопления. $pet благодарит '
          'Вас за заботу, а Пчела-справочная ждёт Вас на новое дежурство.\n\n'
          'Попробуйте ещё раз — и в следующий раз корабль улетит сам!';
    }

    return 'Дорогой $commander! Позвольте сказать за всю команду.\n\n'
        'Корабль Барри снова цел: Протопозитрон, Хлоповик, датчики топлива и '
        'Туманники — всё на месте, и каждая деталь оплачена честно '
        'заработанными Дарами.\n\n'
        'Барт просил передать, что это лучший ремонт в его памяти. Ия гордится '
        'тем, как Вы научились планировать: сначала План, потом покупки и '
        'немного — в накопления. $pet говорит спасибо за заботу — посмотрите, '
        'как он вырос! А Пчела-справочная сдала последнее дежурство на «отлично».\n\n'
        'Барри и друзьям пора домой, на Барамот. До свидания, Командор! '
        'Прилетайте снова — Вам здесь всегда рады.';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _NightSky()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _EndHeader(evacuated: widget.summary.evacuated),
                    const SizedBox(height: 12),
                    _LaunchScene(
                      animation: _launch,
                      launched: _stage != _EndStage.farewell,
                      evacuated: widget.summary.evacuated,
                      petArtAsset: widget.summary.petArtAsset,
                      petEmoji: widget.summary.petEmoji,
                    ),
                    const SizedBox(height: 14),
                    if (_stage == _EndStage.farewell) ..._buildFarewell(),
                    if (_stage == _EndStage.launch)
                      widget.summary.evacuated
                          ? const _InfoPanel(
                              icon: Icons.local_shipping_rounded,
                              title: 'Техничка увозит корабль…',
                              text: 'Команда машет вслед. До свидания, друзья!',
                              accent: Color(0xFFFFA65A),
                            )
                          : const _InfoPanel(
                              icon: Icons.rocket_launch_rounded,
                              title: 'Корабль взлетает…',
                              text: 'Команда машет Барри вслед. До свидания, друзья!',
                              accent: Color(0xFF70D7FF),
                            ),
                    if (_stage == _EndStage.finale) ..._buildFinale(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFarewell() {
    return [
      _SverchokSpeech(text: _speech),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('game_end.launch'),
        onPressed: _startLaunch,
        icon: const Icon(Icons.waving_hand_rounded),
        label: Text(widget.summary.evacuated ? 'Проводить техничку' : 'Проводить корабль'),
      ),
    ];
  }

  List<Widget> _buildFinale() {
    final s = widget.summary;
    return [
      const Text(
        'КОНЕЦ ИГРЫ',
        key: Key('game_end.title'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Color(0xFFFFC85C),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        s.evacuated
            ? 'Техничка доставила корабль Барри на ремонтную станцию. Команда в безопасности!'
            : 'Корабль Барри вернулся на Барамот. Миссия Командора выполнена!',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: Color(0xFFD3DDF0), height: 1.4),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xE61B2743),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFC85C), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Итоги Командора',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _StatRow(icon: Icons.event_available_rounded, label: 'Рабочих сессий', value: '${s.workSessions}'),
            _StatRow(icon: Icons.auto_awesome_rounded, label: 'Заработано всего', value: '${s.totalEarnedDar} Дар'),
            _StatRow(icon: Icons.build_rounded, label: 'Вложено в ремонт', value: '${s.repairSpentDar} Дар'),
            _StatRow(icon: Icons.savings_rounded, label: 'В накоплениях', value: '${s.savingsDar} Дар'),
            _StatRow(icon: Icons.pets_rounded, label: 'Питомец', value: s.petStageTitle),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('game_end.restart'),
        onPressed: _confirmRestart,
        icon: const Icon(Icons.restart_alt_rounded),
        label: const Text('Начать заново'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        key: const Key('game_end.exit'),
        onPressed: widget.onExitToTitle,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Выход'),
      ),
    ];
  }
}

class _EndHeader extends StatelessWidget {
  final bool evacuated;

  const _EndHeader({required this.evacuated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF202E4B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC85C).withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(
            evacuated ? Icons.local_shipping_rounded : Icons.celebration_rounded,
            color: const Color(0xFFFFC85C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              evacuated
                  ? 'Выезд технички · эвакуация корабля'
                  : 'Корабль починен! Команда прощается',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SverchokSpeech extends StatelessWidget {
  final String text;

  const _SverchokSpeech({required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Сверчок говорит: $text',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xE61B2743),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334564)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 170,
              child: Image.asset(
                'assets/characters/sverchok.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('🦗', style: TextStyle(fontSize: 72)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Сверчок',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFFC85C)),
            ),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(fontSize: 16, height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _LaunchScene extends StatelessWidget {
  final Animation<double> animation;
  final bool launched;
  final bool evacuated;
  final String? petArtAsset;
  final String petEmoji;

  const _LaunchScene({
    required this.animation,
    required this.launched,
    required this.evacuated,
    required this.petArtAsset,
    required this.petEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/scenes/base_night.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Color(0xFF0B1424)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0010172A), Color(0x9910172A)],
                    ),
                  ),
                ),
                // Команда внизу сцены.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: h * 0.04,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CrewFace(emoji: '🤖'),
                      _CrewFace(emoji: '✨'),
                      _CrewFace(emoji: '🐝'),
                    ],
                  ),
                ),
                Positioned(
                  left: w * 0.04,
                  bottom: h * 0.03,
                  width: w * 0.2,
                  height: h * 0.3,
                  child: petArtAsset == null
                      ? Center(child: Text(petEmoji, style: const TextStyle(fontSize: 40)))
                      : Image.asset(
                          petArtAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Center(child: Text(petEmoji, style: const TextStyle(fontSize: 40))),
                        ),
                ),
                if (evacuated)
                  // Эвакуация: техничка увозит корабль по земле влево.
                  AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      final t = launched ? Curves.easeInOut.transform(animation.value) : 0.0;
                      final dx = -w * 1.1 * t;
                      return Positioned(
                        left: w * 0.40 + dx,
                        top: h * 0.46,
                        child: child!,
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('🚚', style: TextStyle(fontSize: 54)),
                        Text('🔗', style: TextStyle(fontSize: 22)),
                        Text('🚀', style: TextStyle(fontSize: 46)),
                      ],
                    ),
                  )
                else
                // Корабль: стоит, пока прощаются, затем улетает вверх.
                AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final t = launched ? Curves.easeIn.transform(animation.value) : 0.0;
                    final shake = launched && t < 0.15 ? math.sin(animation.value * 120) * 3 : 0.0;
                    final left = w * 0.62 + shake + w * 0.12 * t;
                    final top = h * 0.42 - (h * 0.42 + 120) * t;
                    return Positioned(
                      left: left,
                      top: top,
                      child: Opacity(
                        opacity: (1 - t * 0.6).clamp(0.0, 1.0),
                        child: Transform.rotate(
                          angle: -math.pi / 4 + t * 0.3,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: const Text('🚀', style: TextStyle(fontSize: 58)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CrewFace extends StatelessWidget {
  final String emoji;

  const _CrewFace({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xCC17243D),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.6)),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  const _InfoPanel({required this.icon, required this.title, required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(fontSize: 14.5, color: Color(0xFFC5D0E4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF70D7FF)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFFC85C)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NightSky extends StatelessWidget {
  const _NightSky();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1122), Color(0xFF131D33), Color(0xFF1B1636)],
        ),
      ),
    );
  }
}
