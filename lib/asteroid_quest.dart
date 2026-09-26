import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'economy_models.dart';

enum _AsteroidQuestPhase {
  intro,
  playing,
  success,
  timeout,
}

enum _MineralType {
  blue,
  red,
  green,
  black,
}

extension on _MineralType {
  String get label {
    switch (this) {
      case _MineralType.blue:
        return 'синий';
      case _MineralType.red:
        return 'красный';
      case _MineralType.green:
        return 'зелёный';
      case _MineralType.black:
        return 'чёрный';
    }
  }

  Color get color {
    switch (this) {
      case _MineralType.blue:
        return const Color(0xFF5CC8FF);
      case _MineralType.red:
        return const Color(0xFFFF7A72);
      case _MineralType.green:
        return const Color(0xFF78E49A);
      case _MineralType.black:
        return const Color(0xFF8A93A8);
    }
  }
}

class _AsteroidData {
  final int id;
  final double size;
  final bool catchable;
  final _MineralType mineralType;
  final double rotationSpeed;

  Offset position;
  Offset velocity;
  double rotation;

  _AsteroidData({
    required this.id,
    required this.size,
    required this.catchable,
    required this.mineralType,
    required this.position,
    required this.velocity,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class AsteroidCollectionQuest extends StatefulWidget {
  final VoidCallback onExit;
  final ValueChanged<QuestResult> onCompleted;
  final String questId;
  final String transportId;
  final String transportTitle;
  final int cargoCapacity;
  final Cargo? targetCargo;
  final String? missionTitle;

  const AsteroidCollectionQuest({
    super.key,
    required this.onExit,
    required this.onCompleted,
    this.questId = 'asteroid_training',
    this.transportId = 'chikh_pykh',
    this.transportTitle = 'Чих-Пых',
    this.cargoCapacity = 4,
    this.targetCargo,
    this.missionTitle,
  }) : assert(cargoCapacity > 0);

  @override
  State<AsteroidCollectionQuest> createState() =>
      _AsteroidCollectionQuestState();
}

class _AsteroidCollectionQuestState extends State<AsteroidCollectionQuest>
    with SingleTickerProviderStateMixin {
  static const int _defaultTargetCount = 4;
  static const double _questDurationSeconds = 50;
  static const double _tractorWidth = 170;
  static const double _tractorHeight = 104;

  late final AnimationController _gameLoop;

  _AsteroidQuestPhase _phase = _AsteroidQuestPhase.intro;
  math.Random _random = math.Random(73);

  final List<_AsteroidData> _asteroids = [];
  final Map<_MineralType, int> _cargoByType = {
    _MineralType.blue: 0,
    _MineralType.red: 0,
    _MineralType.green: 0,
    _MineralType.black: 0,
  };

  static const Offset _tractorPosition = Offset(0.50, 0.78);
  static const bool _facingRight = true;

  Size _fieldSize = Size.zero;
  DateTime? _lastFrameAt;
  Timer? _waveTransitionTimer;
  bool _waveTransitioning = false;
  int _currentWave = 1;

  double _remainingSeconds = _questDurationSeconds;
  double _spawnCountdown = 0;
  int _nextAsteroidId = 1;
  int _cargoCount = 0;
  int _caughtTotal = 0;
  int _attemptSerial = 0;
  DateTime? _attemptStartedAt;
  String _attemptId = '';
  QuestResult? _completedResult;
  bool _completionReported = false;

  String _botHint =
      'Тапни по небольшому астероиду, когда он подсветится в зоне космотрактора.';

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tickGame);
  }

  @override
  void dispose() {
    _waveTransitionTimer?.cancel();
    _gameLoop.dispose();
    super.dispose();
  }

  bool get _isPlaying => _phase == _AsteroidQuestPhase.playing;

  int get _displaySeconds => math.max(0, _remainingSeconds.ceil());

  int get _cargoCapacity => widget.cargoCapacity;

  Cargo? get _targetCargo => widget.targetCargo;

  int get _targetCount {
    final target = _targetCargo;
    if (target == null || target.capacityUsed <= 0) {
      return math.min(_defaultTargetCount, _cargoCapacity);
    }
    return math.min(target.capacityUsed, _cargoCapacity);
  }

  int get _firstWaveTarget => math.max(1, math.min(2, _targetCount - 1));

  bool get _hasTargetCargo {
    final target = _targetCargo;
    if (target == null || target.capacityUsed <= 0) {
      return _cargoCount >= _targetCount;
    }
    return (_cargoByType[_MineralType.blue] ?? 0) >= target.blue &&
        (_cargoByType[_MineralType.red] ?? 0) >= target.red &&
        (_cargoByType[_MineralType.green] ?? 0) >= target.green &&
        (_cargoByType[_MineralType.black] ?? 0) >= target.black;
  }

  List<_MineralType> get _missionMineralPool {
    final target = _targetCargo;
    if (target == null || target.capacityUsed <= 0) {
      return _MineralType.values;
    }
    final pool = <_MineralType>[
      _MineralType.blue,
      _MineralType.red,
      _MineralType.green,
    ];
    if (target.black > 0) pool.add(_MineralType.black);
    return pool;
  }

  List<_MineralType> get _missingTargetMinerals {
    final target = _targetCargo;
    if (target == null || target.capacityUsed <= 0) return const <_MineralType>[];
    final missing = <_MineralType>[];
    void addMissing(_MineralType type, int targetCount) {
      final current = _cargoByType[type] ?? 0;
      for (var i = current; i < targetCount; i++) {
        missing.add(type);
      }
    }
    addMissing(_MineralType.blue, target.blue);
    addMissing(_MineralType.red, target.red);
    addMissing(_MineralType.green, target.green);
    addMissing(_MineralType.black, target.black);
    return missing;
  }

  String get _targetText {
    final target = _targetCargo;
    if (target == null || target.capacityUsed <= 0) {
      return 'любые $_targetCount небольших астероида';
    }
    final parts = <String>[];
    if (target.blue > 0) parts.add('синие ${target.blue}');
    if (target.red > 0) parts.add('красные ${target.red}');
    if (target.green > 0) parts.add('зелёные ${target.green}');
    if (target.black > 0) parts.add('чёрные ${target.black}');
    return parts.join(' · ');
  }

  void _startQuest() {
    _gameLoop.stop();
    _random = math.Random(73);
    final startedAt = DateTime.now();
    _attemptSerial += 1;
    _attemptStartedAt = startedAt;
    _attemptId =
        'asteroid_${startedAt.microsecondsSinceEpoch}_$_attemptSerial';
    _completedResult = null;
    _completionReported = false;
    _asteroids.clear();
    for (final key in _cargoByType.keys) {
      _cargoByType[key] = 0;
    }

    _phase = _AsteroidQuestPhase.playing;
    _remainingSeconds = _questDurationSeconds;
    _spawnCountdown = 0.9;
    _nextAsteroidId = 1;
    _cargoCount = 0;
    _caughtTotal = 0;
    _waveTransitionTimer?.cancel();
    _currentWave = 1;
    _waveTransitioning = false;
    _botHint =
        'Задача: $_targetText. Тапни по нужному камню, когда он подсветится!';
    _lastFrameAt = startedAt;

    for (var i = 0; i < 6; i++) {
      _spawnAsteroid(initial: true, forceLarge: i == 2);
    }

    _gameLoop.repeat();
    setState(() {});
  }

  void _tickGame() {
    if (!_isPlaying) {
      return;
    }

    final now = DateTime.now();
    final previous = _lastFrameAt ?? now;
    final rawDelta = now.difference(previous).inMicroseconds / 1000000.0;
    final delta = rawDelta.clamp(0.0, 0.05).toDouble();
    _lastFrameAt = now;

    _remainingSeconds -= delta;
    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _finishQuest(success: false);
      return;
    }

    for (final asteroid in _asteroids) {
      asteroid.position += asteroid.velocity * delta;
      asteroid.rotation += asteroid.rotationSpeed * delta;
    }

    _asteroids.removeWhere(
      (asteroid) =>
          asteroid.position.dx < -0.22 ||
          asteroid.position.dx > 1.22 ||
          asteroid.position.dy < 0.12 ||
          asteroid.position.dy > 1.08,
    );

    _spawnCountdown -= delta;
    if (_spawnCountdown <= 0 && _asteroids.length < 9) {
      _spawnAsteroid();
      _spawnCountdown = 1.35 + _random.nextDouble() * 1.15;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _spawnAsteroid({
    bool initial = false,
    bool forceLarge = false,
  }) {
    final isLarge = forceLarge || _random.nextDouble() < 0.22;
    final size = isLarge
        ? 88.0 + _random.nextDouble() * 24.0
        : 46.0 + _random.nextDouble() * 26.0;

    final missing = _missingTargetMinerals;
    final missionPool = _missionMineralPool;
    final mineralType = missing.isNotEmpty && _random.nextDouble() < 0.72
        ? missing[_random.nextInt(missing.length)]
        : missionPool[_random.nextInt(missionPool.length)];

    late Offset position;
    late Offset velocity;

    final speed = 0.065 + _random.nextDouble() * 0.055;
    final verticalDrift = (_random.nextDouble() - 0.5) * 0.035;

    if (initial) {
      position = Offset(
        0.12 + _random.nextDouble() * 0.76,
        0.26 + _random.nextDouble() * 0.36,
      );
      final toLeft = _random.nextBool();
      velocity = Offset(
        toLeft ? -speed : speed,
        verticalDrift,
      );
    } else {
      final fromRight = _random.nextBool();
      position = Offset(
        fromRight ? 1.12 : -0.12,
        0.24 + _random.nextDouble() * 0.47,
      );
      velocity = Offset(
        fromRight ? -speed : speed,
        verticalDrift,
      );
    }

    _asteroids.add(
      _AsteroidData(
        id: _nextAsteroidId++,
        size: size,
        catchable: !isLarge,
        mineralType: mineralType,
        position: position,
        velocity: velocity,
        rotation: _random.nextDouble() * math.pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.75,
      ),
    );
  }

  Offset _asteroidCenterInPixels(_AsteroidData asteroid) {
    return Offset(
      asteroid.position.dx * _fieldSize.width,
      asteroid.position.dy * _fieldSize.height,
    );
  }

  Offset _tractorCenterInPixels() {
    return Offset(
      _tractorPosition.dx * _fieldSize.width,
      _tractorPosition.dy * _fieldSize.height,
    );
  }

  /// Зона действия космотрактора — купол прямо над кабиной. Трактор неподвижен,
  /// астероид, залетевший в купол, подсвечивается и становится доступен тапу.
  Offset _zoneCenterInPixels() {
    final tractor = _tractorCenterInPixels();
    return tractor + const Offset(0, -78);
  }

  double _distanceToZone(_AsteroidData asteroid) {
    if (_fieldSize.isEmpty) {
      return double.infinity;
    }
    return (_asteroidCenterInPixels(asteroid) - _zoneCenterInPixels())
        .distance;
  }

  bool _isInZone(_AsteroidData asteroid) {
    final radius = 96 + asteroid.size * 0.22;
    return _distanceToZone(asteroid) <= radius;
  }

  bool _isHighlighted(_AsteroidData asteroid) {
    return asteroid.catchable && _isInZone(asteroid);
  }


  void _handleAsteroidTap(_AsteroidData asteroid) {
    if (!_isPlaying || _waveTransitioning || !_asteroids.contains(asteroid)) {
      return;
    }

    if (!asteroid.catchable) {
      setState(() {
        _botHint =
            'Этот астероид слишком большой для ${widget.transportTitle}. Ищи камень поменьше!';
      });
      return;
    }

    if (!_isInZone(asteroid)) {
      // Тап мимо зоны действия — просто игнорируется, без штрафа.
      return;
    }

    HapticFeedback.selectionClick();

    setState(() {
      _asteroids.remove(asteroid);
      _cargoCount += 1;
      _caughtTotal += 1;
      _cargoByType[asteroid.mineralType] =
          (_cargoByType[asteroid.mineralType] ?? 0) + 1;
      _botHint =
          'Есть! ${asteroid.mineralType.label} минерал — собрано $_cargoCount/$_cargoCapacity. Цель: $_targetText.';
    });

    if (_hasTargetCargo) {
      _finishQuest(success: true);
    } else if (_cargoCount >= _cargoCapacity) {
      _finishQuest(success: false);
    } else if (_cargoCount >= _firstWaveTarget && _currentWave < 2) {
      _startNextWave();
    }
  }

  void _startNextWave() {
    _gameLoop.stop();
    _waveTransitionTimer?.cancel();
    setState(() {
      _waveTransitioning = true;
      _botHint =
          'Первая партия собрана. ${widget.transportTitle} готовится ко второй волне.';
    });

    _waveTransitionTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted || !_isPlaying) {
        return;
      }
      setState(() {
        _currentWave = 2;
        _waveTransitioning = false;
        _asteroids.clear();
        _spawnCountdown = 0.6;
        for (var i = 0; i < 6; i++) {
          _spawnAsteroid(initial: true, forceLarge: i == 1);
        }
        _botHint = 'Вторая волна. Осталось собрать: $_targetText.';
      });
      _lastFrameAt = DateTime.now();
      _gameLoop.repeat();
    });
  }

  Cargo _buildCargo() {
    return Cargo(
      blue: _cargoByType[_MineralType.blue] ?? 0,
      red: _cargoByType[_MineralType.red] ?? 0,
      green: _cargoByType[_MineralType.green] ?? 0,
      black: _cargoByType[_MineralType.black] ?? 0,
      capacityMax: _cargoCapacity,
    );
  }

  void _finishQuest({required bool success}) {
    _gameLoop.stop();
    final finishedAt = DateTime.now();
    if (success) {
      HapticFeedback.mediumImpact();
      final startedAt = _attemptStartedAt ?? finishedAt;
      _completedResult = QuestResult(
        questId: widget.questId,
        transportId: widget.transportId,
        cargo: _buildCargo(),
        success: true,
        duration: finishedAt.difference(startedAt),
        attemptId: _attemptId,
      );
    }
    _lastFrameAt = null;
    _waveTransitionTimer?.cancel();
    _waveTransitioning = false;

    setState(() {
      _phase = success
          ? _AsteroidQuestPhase.success
          : _AsteroidQuestPhase.timeout;
      _botHint = success
          ? 'Заявка собрана! ${widget.transportTitle} возвращается на BAZAR.'
          : _cargoCount >= _cargoCapacity
              ? 'Кузов заполнен, но нужный набор не собран. Можно попробовать ещё раз.'
              : 'Время вышло. Ничего не потеряно — можно попробовать ещё раз.';
    });
  }

  void _returnCompletedResult() {
    final result = _completedResult;
    if (result == null || _completionReported) {
      return;
    }

    _completionReported = true;
    widget.onCompleted(result);
  }

  void _exitQuest() {
    if (_phase == _AsteroidQuestPhase.success &&
        _completedResult != null &&
        !_completionReported) {
      _returnCompletedResult();
      return;
    }

    widget.onExit();
  }

  Widget _buildCargoLegend() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _MineralType.values.map((type) {
        final count = _cargoByType[type] ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xCC14223B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: type.color.withValues(alpha: 0.70),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildIntroOverlay() {
    return _QuestOverlay(
      icon: '🚜',
      title: widget.missionTitle == null
          ? 'Первый выезд ${widget.transportTitle}'
          : widget.missionTitle!,
      text:
          'Цель экспедиции: $_targetText.\n\n'
          '${widget.transportTitle} работает из фиксированной позиции. Когда небольшой астероид влетит в зону над кабиной и подсветится — тапни по нему пальцем.\n\n'
          'Экспедиция идёт в две волны. Большие астероиды пока не поднимаем. Промах по пустому месту ничего не портит.',
      primaryLabel: 'Поехали!',
      primaryIcon: Icons.rocket_launch_rounded,
      onPrimary: _startQuest,
      secondaryLabel: 'Вернуться на BAZAR',
      onSecondary: widget.onExit,
    );
  }

  Widget _buildResultOverlay({required bool success}) {
    final caughtText = _cargoByType.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.key.label}: ${entry.value}')
        .join(' · ');

    return _QuestOverlay(
      icon: success ? '🎉' : '🤖',
      title: success ? 'Заявка собрана!' : 'Экспедиция завершена',
      text: success
          ? '${widget.transportTitle} собрал нужный набор: $_caughtTotal/$_cargoCapacity.\n\n'
              '${caughtText.isEmpty ? 'Минералы пойманы.' : caughtText}\n\n'
              'Бот: «Заявка собрана! Возвращаемся на BAZAR с добычей.»'
          : 'Поймано: $_caughtTotal/$_cargoCapacity.\n\n'
              '${caughtText.isEmpty ? 'В этот раз кузов остался пустым.' : caughtText}\n\n'
              'Никакого штрафа нет. Можно сразу попробовать ещё раз.',
      primaryLabel: success ? 'Сохранить добычу' : 'Ещё раз',
      primaryIcon: success
          ? Icons.inventory_2_rounded
          : Icons.refresh_rounded,
      onPrimary: success ? _returnCompletedResult : _startQuest,
      secondaryLabel: 'Вернуться на BAZAR',
      onSecondary: success ? _returnCompletedResult : widget.onExit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final compact = width < 390;
        _fieldSize = Size(width, height);

        final minTractorCenterX = _tractorWidth / 2;
        final maxTractorCenterX = math.max(
          minTractorCenterX,
          width - _tractorWidth / 2,
        );
        final minTractorCenterY = 142.0 + _tractorHeight / 2;
        final maxTractorCenterY = math.max(
          minTractorCenterY,
          height - 154.0 - _tractorHeight / 2,
        );

        final tractorCenterX = (_tractorPosition.dx * width)
            .clamp(minTractorCenterX, maxTractorCenterX)
            .toDouble();
        final tractorCenterY = (_tractorPosition.dy * height)
            .clamp(minTractorCenterY, maxTractorCenterY)
            .toDouble();

        final zoneSize = compact ? 128.0 : 150.0;
        final zoneLeft = tractorCenterX - zoneSize / 2;
        final zoneTop = tractorCenterY - 78 - zoneSize / 2;
        final zoneActive = _asteroids.any(_isHighlighted);

        return Container(
          color: const Color(0xFF07111F),
          child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF06101D),
                          Color(0xFF10264C),
                          Color(0xFF201A42),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -width * 0.22,
                  top: height * 0.18,
                  child: Container(
                    width: width * 0.58,
                    height: width * 0.58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xAA7769D8),
                          Color(0x55332966),
                          Color(0x00332966),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -width * 0.18,
                  top: height * 0.28,
                  child: Container(
                    width: width * 0.48,
                    height: width * 0.48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF70D7FF).withValues(alpha: 0.20),
                        width: 10,
                      ),
                      color: const Color(0x22194F77),
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.08,
                  top: height * 0.14,
                  child: const _SpaceStar(size: 4),
                ),
                Positioned(
                  right: width * 0.19,
                  top: height * 0.18,
                  child: const _SpaceStar(size: 3),
                ),
                Positioned(
                  left: width * 0.43,
                  top: height * 0.29,
                  child: const _SpaceStar(size: 5),
                ),
                Positioned(
                  right: width * 0.08,
                  top: height * 0.49,
                  child: const _SpaceStar(size: 4),
                ),
                Positioned(
                  left: zoneLeft,
                  top: zoneTop,
                  child: IgnorePointer(
                    child: _CatchZoneRing(
                      size: zoneSize,
                      active: zoneActive,
                    ),
                  ),
                ),
                for (final asteroid in _asteroids)
                  Positioned(
                    key: ValueKey(asteroid.id),
                    // Тап-мишень чуть шире самого астероида — удобнее пальцем.
                    left: asteroid.position.dx * width -
                        asteroid.size / 2 -
                        10,
                    top: asteroid.position.dy * height -
                        asteroid.size / 2 -
                        10,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleAsteroidTap(asteroid),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Transform.rotate(
                          angle: asteroid.rotation,
                          child: _PrototypeAsteroid(
                            size: asteroid.size,
                            highlighted: _isHighlighted(asteroid),
                            accent: asteroid.mineralType.color,
                            tooLarge: !asteroid.catchable,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: tractorCenterX - _tractorWidth / 2,
                  top: tractorCenterY - _tractorHeight / 2,
                  child: IgnorePointer(
                    child: _ChikhPykhPrototype(
                      motion: Offset.zero,
                      moving: _waveTransitioning,
                      facingRight: _facingRight,
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton.filledTonal(
                    onPressed: _exitQuest,
                    tooltip: 'Вернуться на BAZAR',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                if (_phase != _AsteroidQuestPhase.intro)
                  Positioned(
                    top: 12,
                    left: 62,
                    right: 12,
                    child: Row(
                      children: [
                        Expanded(
                          child: _GameHudChip(
                            icon: Icons.timer_outlined,
                            label: compact
                                ? '$_displaySeconds c'
                                : 'Время $_displaySeconds c',
                            accent: _displaySeconds <= 10
                                ? const Color(0xFFFF9A8E)
                                : const Color(0xFF70D7FF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GameHudChip(
                            icon: Icons.inventory_2_rounded,
                            label: compact
                                ? '$_cargoCount/$_cargoCapacity'
                                : 'Кузов $_cargoCount/$_cargoCapacity',
                            accent: const Color(0xFFFFC85C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _GameHudChip(
                            icon: Icons.local_shipping_rounded,
                            label: compact
                                ? 'Волна $_currentWave/2'
                                : 'Волна $_currentWave из 2',
                            accent: const Color(0xFF9AF7AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 68,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xD8101C34),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF304A75),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '🤖',
                          style: TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _botHint,
                            maxLines: compact ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.25,
                              color: Color(0xFFD7E6FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_phase != _AsteroidQuestPhase.intro)
                  Positioned(
                    left: 14,
                    bottom: 92,
                    child: _buildCargoLegend(),
                  ),
                if (_isPlaying)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC13223E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF355A8A),
                        ),
                      ),
                      child: const Text(
                        'Тапай по нужному астероиду, когда он влетит в зону над кабиной и подсветится.',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          color: Color(0xFFCFE1FF),
                        ),
                      ),
                    ),
                  ),
                if (_phase == _AsteroidQuestPhase.intro)
                  Positioned.fill(
                    child: _buildIntroOverlay(),
                  ),
                if (_phase == _AsteroidQuestPhase.success)
                  Positioned.fill(
                    child: _buildResultOverlay(success: true),
                  ),
                if (_phase == _AsteroidQuestPhase.timeout)
                  Positioned.fill(
                    child: _buildResultOverlay(success: false),
                  ),
              ],
            ),
        );
      },
    );
  }
}

class _CatchZoneRing extends StatefulWidget {
  final double size;
  final bool active;

  const _CatchZoneRing({
    required this.size,
    required this.active,
  });

  @override
  State<_CatchZoneRing> createState() => _CatchZoneRingState();
}

class _CatchZoneRingState extends State<_CatchZoneRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.active
        ? const Color(0xFF9AF7AA)
        : const Color(0xFF70D7FF);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulseValue = widget.active ? _pulse.value : 0.0;
        final opacity = widget.active ? 0.55 + pulseValue * 0.35 : 0.22;
        final borderWidth = widget.active ? 2.6 + pulseValue * 1.4 : 1.6;

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: baseColor.withValues(alpha: 0.06 + (widget.active ? pulseValue * 0.08 : 0)),
            border: Border.all(
              color: baseColor.withValues(alpha: opacity),
              width: borderWidth,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.35 + pulseValue * 0.25),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

class _QuestOverlay extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _QuestOverlay({
    required this.icon,
    required this.title,
    required this.text,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD9081020),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF182641),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: const Color(0xFF4A648F),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    icon,
                    style: const TextStyle(fontSize: 52),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: Color(0xFFD3DDF0),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onPrimary,
                    icon: Icon(primaryIcon),
                    label: Text(primaryLabel),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpaceStar extends StatelessWidget {
  final double size;

  const _SpaceStar({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF70D7FF).withValues(alpha: 0.8),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _GameHudChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;

  const _GameHudChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: const Color(0xDD172744),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrototypeAsteroid extends StatelessWidget {
  final double size;
  final bool highlighted;
  final Color accent;
  final bool tooLarge;

  const _PrototypeAsteroid({
    required this.size,
    required this.accent,
    this.highlighted = false,
    this.tooLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final outer = tooLarge
        ? const Color(0xFF4A5260)
        : Color.lerp(const Color(0xFF46515F), accent, 0.24)!;
    final middle = tooLarge
        ? const Color(0xFF6A7381)
        : Color.lerp(const Color(0xFF6B7584), accent, 0.38)!;
    final inner = tooLarge
        ? const Color(0xFFA0A8B3)
        : Color.lerp(const Color(0xFF9AA4B2), accent, 0.44)!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            inner,
            middle,
            outer,
          ],
        ),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF9AF7AA)
              : tooLarge
                  ? const Color(0xFFFFB36B)
                  : accent.withValues(alpha: 0.78),
          width: highlighted ? 3.5 : 1.5,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF9AF7AA).withValues(alpha: 0.70),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ]
            : tooLarge
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFB36B).withValues(alpha: 0.22),
                      blurRadius: 12,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 10,
                    ),
                  ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.19,
            top: size * 0.20,
            child: _AsteroidCrater(size: size * 0.20),
          ),
          Positioned(
            right: size * 0.18,
            top: size * 0.39,
            child: _AsteroidCrater(size: size * 0.16),
          ),
          Positioned(
            left: size * 0.36,
            bottom: size * 0.16,
            child: _AsteroidCrater(size: size * 0.13),
          ),
          if (!tooLarge)
            Positioned(
              right: size * 0.14,
              top: size * 0.14,
              child: Container(
                width: size * 0.15,
                height: size * 0.15,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.70),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AsteroidCrater extends StatelessWidget {
  final double size;

  const _AsteroidCrater({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x55303947),
      ),
    );
  }
}

class _ChikhPykhPrototype extends StatefulWidget {
  final Offset motion;
  final bool moving;
  final bool facingRight;

  const _ChikhPykhPrototype({
    required this.motion,
    required this.moving,
    required this.facingRight,
  });

  @override
  State<_ChikhPykhPrototype> createState() => _ChikhPykhPrototypeState();
}

class _ChikhPykhPrototypeState extends State<_ChikhPykhPrototype>
    with SingleTickerProviderStateMixin {
  late final AnimationController _engineController;

  @override
  void initState() {
    super.initState();
    _engineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat();
  }

  @override
  void dispose() {
    _engineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetTilt = widget.motion.dy * 0.035 + widget.motion.dx * 0.025;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetTilt),
      duration: Duration(milliseconds: widget.moving ? 100 : 240),
      curve: widget.moving ? Curves.easeOut : Curves.elasticOut,
      builder: (context, tilt, child) {
        return AnimatedBuilder(
          animation: _engineController,
          child: child,
          builder: (context, child) {
            final phase = _engineController.value * math.pi * 2;
            final idleShakeX = math.sin(phase * 2.0) * 0.55;
            final idleBob = math.sin(phase) * 0.75;
            final movingBob = math.sin(phase * 1.45) * 1.7;
            final verticalResponse = widget.motion.dy * 1.2;
            final bob = widget.moving ? movingBob : idleBob;

            return Transform.translate(
              offset: Offset(
                idleShakeX,
                bob + verticalResponse,
              ),
              child: Transform.rotate(
                angle: tilt,
                alignment: Alignment.center,
                child: child,
              ),
            );
          },
        );
      },
      child: AnimatedBuilder(
        animation: _engineController,
        builder: (context, _) {
          final phase = _engineController.value * math.pi * 2;
          final botBounce = math.sin(phase * 1.6) *
              (widget.moving ? 1.8 : 0.7);
          final wheelAngle = phase * (widget.moving ? 0.45 : 0.08);

          return Transform.scale(
            scaleX: widget.facingRight ? 1 : -1,
            child: SizedBox(
              width: 170,
              height: 104,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 26,
                    top: 29,
                    child: Container(
                      width: 126,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFB8B4A8),
                            Color(0xFF6D706E),
                            Color(0xFF4B5156),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFCEC2A4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 31,
                    top: 34,
                    child: Transform.scale(
                      scaleX: widget.facingRight ? 1 : -1,
                      child: Container(
                        width: 78,
                        height: 31,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xCC313A41),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFB9A77D),
                          ),
                        ),
                        child: const Text(
                          'ЧИХ-ПЫХ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFFE8AF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 45,
                    top: 4.0 + botBounce,
                    child: Container(
                      width: 62,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF23466D),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border.all(
                          color: const Color(0xFF70D7FF),
                          width: 2,
                        ),
                      ),
                      child: Transform.scale(
                        scaleX: widget.facingRight ? 1 : -1,
                        child: const Center(
                          child: Text(
                            '🤖',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 118,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF71797D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 116,
                    top: 5,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD95B4C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 2,
                    child: Transform.rotate(
                      angle: wheelAngle,
                      child: const _TractorWheel(),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 2,
                    child: Transform.rotate(
                      angle: wheelAngle,
                      child: const _TractorWheel(),
                    ),
                  ),
                  Positioned(
                    right: -5,
                    top: 43,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: widget.moving ? 32.0 : 25.0,
                      height: 17,
                      decoration: BoxDecoration(
                        color: const Color(0xFF70D7FF),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF70D7FF).withValues(
                              alpha: widget.moving ? 0.95 : 0.55,
                            ),
                            blurRadius: widget.moving ? 18.0 : 10.0,
                            spreadRadius: widget.moving ? 2.0 : 0.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TractorWheel extends StatelessWidget {
  const _TractorWheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF202838),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF69758A),
          width: 4,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.circle,
          size: 13,
          color: Color(0xFF70D7FF),
        ),
      ),
    );
  }
}

