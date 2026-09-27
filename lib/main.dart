import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'adult_section.dart';
import 'app_settings.dart';
import 'asteroid_quest.dart';
import 'bazar_game_catalog.dart';
import 'bazar_game_models.dart';
import 'bazar_game_screen.dart';
import 'bazar_game_storage.dart';
import 'commander_school.dart';
import 'economy_engine.dart';
import 'economy_models.dart';
import 'finance_content.dart';
import 'game_end_screen.dart';
import 'game_state.dart';
import 'game_storage.dart';
import 'pet_growth.dart';
import 'pet_looks.dart';
import 'planning_catalog.dart';
import 'savings_screen.dart';
import 'ship_repair_catalog.dart';
import 'ship_repair_models.dart';
import 'spravochnaya.dart';
import 'tasks_screen.dart';
import 'tir_web_screen.dart';
import 'title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Вся игра свёрстана вертикально — фиксируем портретную ориентацию.
  // Исключение — «Весёлый тир»: на время игры он сам поворачивает экран
  // в альбомную ориентацию и при выходе возвращает портретную
  // (см. tir_web_screen.dart).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  // Настройки взрослого (звук, анимации) — до первого кадра.
  await AppSettings.instance.load();
  runApp(const BaramotApp());
}

class BaramotApp extends StatelessWidget {
  const BaramotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Принц с Барамота',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF11182B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFC85C),
          secondary: Color(0xFF70D7FF),
          surface: Color(0xFF1B2743),
          error: Color(0xFFFF8A80),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 18, height: 1.45),
          bodyMedium: TextStyle(fontSize: 16, height: 1.4),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            side: const BorderSide(color: Color(0xFF70D7FF), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF18223A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF344463)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFFC85C), width: 2),
          ),
        ),
      ),
      // Если взрослый отключил анимации — сообщаем об этом всем виджетам,
      // которые учитывают MediaQuery.disableAnimations.
      builder: (context, child) => ListenableBuilder(
        listenable: AppSettings.instance,
        builder: (context, _) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: !AppSettings.instance.animationsEnabled,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const BaramotRoot(),
    );
  }
}

class MyApp extends BaramotApp {
  const MyApp({super.key});
}

enum AppScreen {
  loading,
  title,
  guestWelcome,
  commanderIntro,
  baseIntro,
  barryPrologue,
  barryMeeting,
  iyaPrologue,
  iyaMeeting,
  choosePet,
  namePet,
  teamHome,
  firstCouncil,
  sessionClosed,
  phd,
  base,
  tent,
  bazar,
  petDetail,
  shipDetail,
  commanderReport,
  tir,
  gameEnd,
  adult,
  tasks,
  savings,
}

class BaramotRoot extends StatefulWidget {
  const BaramotRoot({super.key});

  @override
  State<BaramotRoot> createState() => _BaramotRootState();
}

class _BaramotRootState extends State<BaramotRoot> {
  final GameStorage _storage = GameStorage();
  final BazarGameStorage _bazarStorage = BazarGameStorage();
  final EconomyEngine _economyEngine = const EconomyEngine();
  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _petNameController = TextEditingController();

  GameStateData _game = GameStateData();
  AppScreen _screen = AppScreen.loading;
  PetType? _draftPet;
  int _eveningSaveAmount = 0;
  int _lastPeriodIncome = 0;
  int _lastPeriodSpent = 0;
  int _lastPeriodSaved = 0;
  final Map<String, int> _eveningRepairUnits = <String, int>{};
  int _lastPeriodRepairUnitsBought = 0;
  int _lastPeriodRepairDarSpent = 0;
  // Рост питомца за последний закрытый период — для карточки в «Итогах дня».
  PetGrowthUpdate? _lastGrowthUpdate;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _petNameController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final loaded = await _storage.load();
    if (!mounted) return;

    _playerNameController.text = loaded.playerName;
    _petNameController.text = loaded.petName;
    _draftPet = loaded.profileCreated || loaded.onboardingStep >= 8 ? loaded.selectedPet : null;

    setState(() {
      _game = loaded;
      // Каждый запуск начинается с титульного экрана; дальше «Играть»
      // ведёт туда, где игрок остановился (_screenForState).
      _screen = AppScreen.title;
    });
  }

  /// Корабль полностью починен: все позиции каталога ремонта оплачены.
  bool _isShipRepairComplete(GameStateData state) {
    return ShipRepairCatalog.items.every((item) => state.isShipRepairItemClosed(item.id));
  }

  bool get _hasProgress =>
      _game.profileCreated || _game.introSeen || _game.onboardingStep > 0;

  // Экран, с которого открыли раздел для взрослого, — туда и вернёмся.
  AppScreen _screenBeforeAdult = AppScreen.base;

  Future<void> _openAdultSection() async {
    final allowed = await showAdultGate(context);
    if (!allowed || !mounted) return;
    setState(() {
      _screenBeforeAdult = _screen;
      _screen = AppScreen.adult;
    });
  }

  Widget _buildAdultSection() {
    final totalEarned = _game.transactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<int>(0, (sum, transaction) => sum + transaction.amount);
    final repairTotal = ShipRepairCatalog.items
        .fold<int>(0, (sum, item) => sum + item.totalCost);
    final repairPaid = ShipRepairCatalog.items.fold<int>(
      0,
      (sum, item) => sum + _game.shipRepairUnitsPaidFor(item.id) * item.unitCost,
    );
    final pet = _game.selectedPet;
    final petName = _game.petName.isEmpty ? pet.title : _game.petName;

    return AdultSectionScreen(
      playerName: _game.playerName,
      progress: <AdultProgressRow>[
        AdultProgressRow(
          icon: Icons.event_available_rounded,
          label: 'Рабочих сессий пройдено',
          value: '${_game.totalWorkSessionsCompleted}',
        ),
        AdultProgressRow(
          icon: Icons.auto_awesome_rounded,
          label: 'Заработано Дар всего',
          value: '$totalEarned',
        ),
        AdultProgressRow(
          icon: Icons.wallet_rounded,
          label: 'Сейчас в кошельке',
          value: '${_game.walletDar} Дар',
        ),
        AdultProgressRow(
          icon: Icons.savings_rounded,
          label: 'Цель «${_game.activeGoalTitle}»',
          value: '${_game.savingsDar} / ${_game.activeGoalTarget} Дар',
        ),
        AdultProgressRow(
          icon: Icons.build_rounded,
          label: 'Ремонт корабля',
          value: '$repairPaid / $repairTotal Дар',
        ),
        AdultProgressRow(
          icon: Icons.school_rounded,
          label: CommanderSchool.title,
          value: CommanderSchool.rankFor(FinanceTaskProgress.completed(_game).length).title,
        ),
        AdultProgressRow(
          icon: Icons.pets_rounded,
          label: petName,
          value: PetGrowthCatalog.stageTitle(_game.petState.growthStage),
        ),
      ],
      completedTopics: FinanceTaskProgress.completed(_game)
          .map((task) => '${task.topic.title}: «${task.title}»')
          .toList(growable: false),
      onBack: () => setState(() => _screen = _screenBeforeAdult),
      onResetProfile: _resetProfile,
      onLoadDemoProfile: _loadDemoProfile,
    );
  }

  // --- Задания и накопления ------------------------------------------

  String? _tasksInitialId;

  void _openTasks({String? taskId}) {
    setState(() {
      _tasksInitialId = taskId;
      _screen = AppScreen.tasks;
    });
  }

  void _openSavings() {
    setState(() => _screen = AppScreen.savings);
  }

  Future<void> _saveAndRefresh() async {
    await _save();
    if (mounted) setState(() {});
  }

  /// Тестовый профиль для экспертной проверки (ТЗ 2.5.13): пролог пропущен,
  /// База открыта утром первой сессии, в кошельке запас Дар на демонстрацию.
  Future<void> _loadDemoProfile() async {
    await _bazarStorage.clear();
    if (!mounted) return;
    final demo = GameStateData(
      introSeen: true,
      onboardingStep: 11,
      profileCreated: true,
      playerName: 'Тестовый Командор',
      selectedPet: PetType.kwak,
      petStyle: 0,
      petName: 'Квак',
      walletDar: 30,
      sessionPhase: BaseSessionPhase.morning,
      demoProfile: true,
    )..prepareMorningSession();
    _playerNameController.text = demo.playerName;
    _petNameController.text = demo.petName;
    setState(() {
      _game = demo;
      _draftPet = demo.selectedPet;
      _lastGrowthUpdate = null;
      _morningPlannedSave = 0;
      _screen = AppScreen.base;
    });
    await _save();
    _showMessage('Тестовый профиль загружен: База, утро первой сессии, 30 Дар.');
  }

  Future<void> _exitToTitle() async {
    await _save();
    if (!mounted) return;
    setState(() => _screen = AppScreen.title);
  }

  AppScreen _screenForState(GameStateData state) {
    if (state.profileCreated &&
        (state.shipEvacuated || _isShipRepairComplete(state))) {
      return AppScreen.gameEnd;
    }
    if (state.profileCreated) {
      return switch (state.sessionPhase) {
        BaseSessionPhase.closed => AppScreen.sessionClosed,
        BaseSessionPhase.phd => AppScreen.phd,
        _ => AppScreen.base,
      };
    }

    switch (state.onboardingStep) {
      case 1:
        return AppScreen.commanderIntro;
      case 2:
        return AppScreen.baseIntro;
      case 3:
        return AppScreen.barryPrologue;
      case 4:
        return AppScreen.barryMeeting;
      case 5:
        return AppScreen.iyaPrologue;
      case 6:
        return AppScreen.iyaMeeting;
      case 7:
        return AppScreen.choosePet;
      case 8:
        return AppScreen.namePet;
      case 9:
        return AppScreen.teamHome;
      case 10:
        return AppScreen.firstCouncil;
      default:
        return AppScreen.guestWelcome;
    }
  }

  Future<void> _save() => _storage.save(_game);

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      );
  }

  Future<void> _go(AppScreen screen, int onboardingStep) async {
    setState(() {
      _screen = screen;
      _game.onboardingStep = onboardingStep;
    });
    await _save();
  }

  Future<void> _finishWelcome() async {
    setState(() {
      _game.introSeen = true;
      _game.onboardingStep = 1;
      _screen = AppScreen.commanderIntro;
    });
    await _save();
  }

  Future<void> _acceptCommand() async {
    final value = _playerNameController.text.trim();
    if (value.isEmpty) {
      _showMessage('Пожалуйста, придумайте, как к Вам обращаться.');
      return;
    }

    setState(() {
      _game.playerName = value;
      _game.walletDar = 12;
      _game.savingsDar = 0;
      _game.planNeed = 0;
      _game.planWant = 0;
      _game.planSave = 0;
      _game.budgetPlanConfirmed = false;
      _game.onboardingStep = 2;
      _screen = AppScreen.baseIntro;
    });
    await _save();
  }

  Future<void> _openPetSelection() => _go(AppScreen.choosePet, 7);
  Future<void> _openPetNaming() => _go(AppScreen.namePet, 8);
  Future<void> _openFirstCouncil() => _go(AppScreen.firstCouncil, 10);

  void _openTent() {
    if (_game.sessionPhase == BaseSessionPhase.day) {
      _showMessage('Утренний План уже утверждён. Сейчас время дневных дел и BAZAR.');
      return;
    }
    if (_game.sessionPhase != BaseSessionPhase.morning &&
        _game.sessionPhase != BaseSessionPhase.evening) {
      _showMessage('Палатка сейчас закрыта.');
      return;
    }
    setState(() => _screen = AppScreen.tent);
  }

  void _openBazar() {
    if (_game.sessionPhase != BaseSessionPhase.day) {
      _showMessage(
        _game.sessionPhase == BaseSessionPhase.morning
            ? 'Сначала завершите утренний обход и утвердите План на Совещании.'
            : 'BAZAR доступен в дневной части рабочей сессии.',
      );
      return;
    }
    setState(() => _screen = AppScreen.bazar);
  }

  void _openTir() {
    setState(() => _screen = AppScreen.tir);
  }

  Future<void> _selectPet(PetType pet) async {
    setState(() {
      _draftPet = pet;
      _game.selectedPet = pet;
    });
    await _save();
  }

  /// Выбор образа питомца (ТЗ 2.5.2) — при создании и повторно на экране Питомца.
  Future<void> _selectPetLook(int style) async {
    setState(() => _game.petStyle = style);
    await _save();
  }

  Future<void> _savePetName() async {
    final value = _petNameController.text.trim();
    if (value.isEmpty) {
      _showMessage('Давайте всё-таки дадим нашему питомцу имя.');
      return;
    }

    setState(() {
      _game.petName = value;
      _game.onboardingStep = 9;
      _screen = AppScreen.teamHome;
    });
    await _save();
  }

  Future<void> _finishAcquaintance() async {
    setState(() {
      _game.profileCreated = true;
      _game.onboardingStep = 11;
      _game.sessionPhase = BaseSessionPhase.closed;
      _game.currentPlan = null;
      _game.budgetPlanConfirmed = false;
      _game.planNeed = 0;
      _game.planWant = 0;
      _game.planSave = 0;
      _screen = AppScreen.sessionClosed;
    });
    await _save();
  }

  Future<void> _enterBaseForMorning() async {
    final phdNext = _game.totalWorkSessionsCompleted > 0 &&
        _game.totalWorkSessionsCompleted % 5 == 0 &&
        _game.period >= 5;
    if (phdNext) {
      setState(() {
        _game.sessionPhase = BaseSessionPhase.phd;
        _screen = AppScreen.phd;
      });
      await _save();
      return;
    }

    await _bazarStorage.clear();
    if (!mounted) return;
    setState(() {
      _game.prepareMorningSession();
      _screen = AppScreen.base;
    });
    await _save();
  }

  Future<void> _openPetDetail() async {
    setState(() {
      if (_game.sessionPhase == BaseSessionPhase.morning) {
        _game.morningPetVisited = true;
      }
      _screen = AppScreen.petDetail;
    });
    await _save();
  }

  Future<void> _openShipDetail() async {
    setState(() {
      if (_game.sessionPhase == BaseSessionPhase.morning) {
        _game.morningBarryVisited = true;
      }
      _screen = AppScreen.shipDetail;
    });
    await _save();
  }

  Future<void> _selectMorningRequest({
    required String ownerId,
    required String itemId,
  }) async {
    if (_game.sessionPhase != BaseSessionPhase.morning) return;
    setState(() {
      _game.setDailyRequest(ownerId: ownerId, itemId: itemId);
      if (ownerId == PlanOwner.pet) _game.morningPetVisited = true;
      if (ownerId == PlanOwner.barry) _game.morningBarryVisited = true;
    });
    await _save();
  }

  // --- Утренний План: 3 направления и контроль бюджета (ТЗ 2.5.5) -------

  /// Сколько Дар Командор планирует утром отложить в накопления.
  int _morningPlannedSave = 0;

  /// План дохода на день — столько Дар обычно приносит дневная работа.
  /// Нужен, чтобы утром можно было спланировать обязательное даже при
  /// пустом кошельке (иначе игра зашла бы в тупик).
  int get _plannedDayIncome {
    const table = EconomyTuning.normalIncomeByPeriod;
    final index = (_game.period - 1).clamp(0, table.length - 1).toInt();
    return table[index];
  }

  /// Доступный бюджет дня: кошелёк + план дохода.
  int get _morningAvailableBudget => _game.walletDar + _plannedDayIncome;

  BudgetPlan _draftMorningPlan({bool confirmed = false}) {
    return PlanningCatalog.buildBudgetPlan(
      periodId: _game.period,
      startingWallet: _game.walletDar,
      selectedIds: _game.selectedPlanningItemIds,
      petTypeId: _game.selectedPet.id,
      selectedGoalId: _game.activeGoalId,
      plannedSavings: _morningPlannedSave,
      confirmed: confirmed,
    );
  }

  /// Сколько ещё можно отложить утром, не выходя за бюджет.
  int _maxMorningSave() {
    final draft = _draftMorningPlan();
    final free = _morningAvailableBudget - draft.plannedNeed - draft.plannedWant;
    return free < 0 ? 0 : free;
  }

  void _adjustMorningSave(int delta) {
    setState(() {
      _morningPlannedSave = (_morningPlannedSave + delta).clamp(0, _maxMorningSave()).toInt();
    });
  }

  Future<void> _confirmMorningPlan() async {
    if (!_game.morningRoundComplete) {
      _showMessage('Сначала обойдите Питомца и Барри и выберите по одной заявке на сегодня.');
      return;
    }

    _morningPlannedSave = _morningPlannedSave.clamp(0, _maxMorningSave()).toInt();
    final plan = _draftMorningPlan(confirmed: true);
    final overBy = plan.plannedTotal - _morningAvailableBudget;
    if (overBy > 0) {
      _showMessage(
        'План больше бюджета на $overBy Дар. Выберите у Питомца или Барри позицию '
        'подешевле (или «Ничего не надо») — и План сойдётся.',
      );
      return;
    }

    setState(() {
      _game.currentPlan = plan;
      _game.planNeed = plan.plannedNeed;
      _game.planWant = plan.plannedWant;
      _game.planSave = plan.plannedSavings;
      _game.budgetPlanConfirmed = true;
      _game.sessionPhase = BaseSessionPhase.day;
      _morningPlannedSave = 0;
      _screen = AppScreen.base;
    });
    await _save();
  }

  Future<void> _creditBazarIncome(BazarIncomeEvent income) async {
    final scopedRewardKey =
        '${income.rewardKey}:work_session:${_game.totalWorkSessionsCompleted + 1}';
    if (income.amountDar <= 0 ||
        _game.processedRewardKeys.contains(scopedRewardKey)) {
      return;
    }

    _economyEngine.addIncome(
      _game,
      amount: income.amountDar,
      sourceId: income.sourceId,
      sourceTitle: income.sourceTitle,
      reason: income.reason,
      rewardKey: scopedRewardKey,
    );

    if (mounted) setState(() {});
    await _save();
  }

  Future<void> _chargeBazarExpense(BazarExpenseEvent expense) async {
    if (expense.amountDar <= 0) {
      return;
    }

    final scopedExpenseKey =
        '${expense.expenseKey}:work_session:${_game.totalWorkSessionsCompleted + 1}';
    final alreadyCharged = _game.transactions.any(
      (transaction) => transaction.sourceId == scopedExpenseKey,
    );
    if (alreadyCharged) {
      return;
    }

    _economyEngine.purchaseTransport(
      _game,
      price: expense.amountDar,
      sourceId: scopedExpenseKey,
      sourceTitle: expense.sourceTitle,
      reason: expense.reason,
    );

    if (mounted) setState(() {});
    await _save();
  }

  Future<BazarQuestCargoResult?> _launchBazarAsteroidQuest(
    BazarQuestRequest request,
  ) async {
    if (request.kind != BazarQuestKind.asteroids) {
      return null;
    }

    final transportId = request.transportId;
    final transport = BazarGameCatalog.transportById(transportId);
    if (transport == null) {
      _showMessage('Гараж не передал выбранный космотрактор.');
      return null;
    }
    if (!transport.expeditionReady) {
      _showMessage(
        '${transport.title}: мини-игра этого космотрактора пока в разработке.',
      );
      return null;
    }

    final capacity = request.cargoCapacity ?? transport.cargoCapacity;
    final required = request.requiredCargo ?? const BazarCargo();
    final target = Cargo(
      blue: required.blue,
      red: required.red,
      green: required.green,
      capacityMax: capacity,
    );

    final questResult = await Navigator.of(context).push<QuestResult>(
      MaterialPageRoute<QuestResult>(
        builder: (questContext) => Scaffold(
          body: SafeArea(
            child: AsteroidCollectionQuest(
              questId: 'bazar_asteroid_order',
              transportId: transport.id,
              transportTitle: transport.title,
              cargoCapacity: capacity,
              targetCargo: target,
              missionTitle: request.missionTitle,
              onExit: () => Navigator.of(questContext).pop(),
              onCompleted: (result) =>
                  Navigator.of(questContext).pop(result),
            ),
          ),
        ),
      ),
    );

    if (questResult == null) {
      return null;
    }
    if (!questResult.success || questResult.transportId != transport.id) {
      _showMessage('Экспедиция завершилась без подтверждённого груза.');
      return null;
    }

    final cargo = questResult.cargo;
    return BazarQuestCargoResult(
      attemptId: questResult.attemptId,
      kind: BazarQuestKind.asteroids,
      cargo: BazarCargo(
        blue: cargo.blue,
        red: cargo.red,
        green: cargo.green,
      ),
      success: true,
    );
  }

  void _finishBazarPrototype(BazarRunResult result) {
    final purchaseableIds = _game.currentPlan?.plannedItems
            .where((item) => item.category != PlanCategory.planned)
            .map((item) => item.id)
            .toSet() ??
        <String>{};

    setState(() {
      _game.asteroidTrainingCompleted = true;
      _game.sessionPhase = BaseSessionPhase.evening;
      _game.eveningSelectedItemIds
        ..clear()
        ..addAll(purchaseableIds);
      _eveningSaveAmount = 0;
      _eveningRepairUnits.clear();
      _screen = AppScreen.base;
    });
    unawaited(_save());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showMessage(
        'BAZAR завершён: заработано ${result.totalDarToBase} Дар. '
        'На Базе наступил вечер — теперь доступно вечернее Совещание.',
      );
    });
  }

  List<PlannedItem> _eveningPurchaseables() {
    final plan = _game.currentPlan;
    if (plan == null) return const <PlannedItem>[];
    return plan.plannedItems
        .where((item) => item.category != PlanCategory.planned)
        .toList(growable: false);
  }

  int _eveningSelectedCost() {
    return _eveningPurchaseables().where((item) {
      return item.mandatory || _game.eveningSelectedItemIds.contains(item.id);
    }).fold<int>(0, (sum, item) => sum + item.plannedCost);
  }

  /// Сколько Дар остаётся из кошелька после НАДО/ХОЧУ, но ДО того, как их
  /// разделили между накоплениями и ремонтом корабля — это общий пул,
  /// который эти два вечерних решения делят между собой.
  int _eveningFreeDarBeforeSaveAndRepair() {
    final available = _game.walletDar - _eveningSelectedCost();
    return available < 0 ? 0 : available;
  }

  int _eveningRepairUnitsFor(String itemId) => _eveningRepairUnits[itemId] ?? 0;

  /// Сколько Дар уже отложено сегодня в ремонт (по всем активным позициям,
  /// кроме excludingId — используется, чтобы посчитать предел для самой
  /// этой позиции, не учитывая её же текущий выбор).
  int _eveningRepairReservedDar({String? excludingId}) {
    var total = 0;
    for (final item in _game.shipRepairActiveItems) {
      if (item.id == excludingId) continue;
      total += _eveningRepairUnitsFor(item.id) * item.unitCost;
    }
    return total;
  }

  /// Сколько Дар из текущего кошелька можно отложить в накопления сегодня
  /// вечером — общий пул за вычетом уже зарезервированного на ремонт.
  int _maxEveningSaveAmount() {
    final available =
        _eveningFreeDarBeforeSaveAndRepair() - _eveningRepairReservedDar();
    return available < 0 ? 0 : available;
  }

  /// Сколько штук позиции ремонта можно купить сегодня — общий пул за
  /// вычетом уже выбранных накоплений и других позиций ремонта, но не
  /// больше, чем реально остаётся купить по самой позиции.
  int _maxEveningRepairUnits(ShipRepairItemDefinition item) {
    final remainingUnits = _game.shipRepairRemainingUnits(item.id);
    if (remainingUnits <= 0 || item.unitCost <= 0) return 0;

    final freeDar = _eveningFreeDarBeforeSaveAndRepair() -
        _eveningSaveAmount -
        _eveningRepairReservedDar(excludingId: item.id);
    if (freeDar <= 0) return 0;

    final affordableUnits = freeDar ~/ item.unitCost;
    return affordableUnits < remainingUnits ? affordableUnits : remainingUnits;
  }

  /// После любого изменения общего пула подчищает уже выбранные штуки
  /// ремонта, если они вдруг превысили новый доступный предел.
  void _clampEveningRepairUnits() {
    for (final item in _game.shipRepairActiveItems) {
      final maxUnits = _maxEveningRepairUnits(item);
      final current = _eveningRepairUnitsFor(item.id);
      if (current > maxUnits) {
        _eveningRepairUnits[item.id] = maxUnits < 0 ? 0 : maxUnits;
      }
    }
  }

  void _toggleEveningItem(PlannedItem item, bool selected) {
    if (item.mandatory || item.category == PlanCategory.planned) return;
    setState(() {
      if (selected) {
        _game.eveningSelectedItemIds.add(item.id);
      } else {
        _game.eveningSelectedItemIds.remove(item.id);
      }
      _eveningSaveAmount = _eveningSaveAmount.clamp(0, _maxEveningSaveAmount()).toInt();
      _clampEveningRepairUnits();
    });
    unawaited(_save());
  }

  void _adjustEveningSave(int delta) {
    setState(() {
      final maxSave = _maxEveningSaveAmount();
      _eveningSaveAmount = (_eveningSaveAmount + delta).clamp(0, maxSave).toInt();
      _clampEveningRepairUnits();
    });
  }

  void _adjustEveningRepairUnits(ShipRepairItemDefinition item, int delta) {
    setState(() {
      final maxUnits = _maxEveningRepairUnits(item);
      final current = _eveningRepairUnitsFor(item.id);
      _eveningRepairUnits[item.id] = (current + delta).clamp(0, maxUnits).toInt();
      _eveningSaveAmount = _eveningSaveAmount.clamp(0, _maxEveningSaveAmount()).toInt();
      _clampEveningRepairUnits();
    });
  }

  void _excludeShipRepairItem(String itemId) {
    if (_game.sessionPhase != BaseSessionPhase.morning) return;
    setState(() {
      _game.excludeShipRepairItem(itemId);
    });
    unawaited(_save());
  }

  void _activateShipRepairItem(String itemId) {
    if (_game.sessionPhase != BaseSessionPhase.morning) return;
    setState(() {
      _game.activateShipRepairItem(itemId);
    });
    unawaited(_save());
  }

  Future<void> _settleEveningAndClose() async {
    if (_game.sessionPhase != BaseSessionPhase.evening) return;
    final plan = _game.currentPlan;
    if (plan == null) {
      _showMessage('Нет утверждённого утреннего Плана.');
      return;
    }

    final toBuy = _eveningPurchaseables().where((item) {
      return item.mandatory || _game.eveningSelectedItemIds.contains(item.id);
    }).toList(growable: false);
    final total = toBuy.fold<int>(0, (sum, item) => sum + item.plannedCost);
    if (total > _game.walletDar) {
      _showMessage(
        'Для выбранных покупок нужно $total Дар, а в кошельке ${_game.walletDar}. '
        'Снимите необязательную позицию или заработайте больше.',
      );
      return;
    }

    // Сколько штук ремонта решили купить сегодня по каждой активной позиции.
    final repairPurchases = <MapEntry<ShipRepairItemDefinition, int>>[];
    for (final item in _game.shipRepairActiveItems) {
      final units = _eveningRepairUnitsFor(item.id);
      if (units > 0) {
        repairPurchases.add(MapEntry(item, units));
      }
    }
    final repairTotal = repairPurchases.fold<int>(
      0,
      (sum, entry) => sum + entry.value * entry.key.unitCost,
    );

    // Сколько Дар можно было отложить в накопления, если оплатить всё
    // отмеченное выше и весь выбранный ремонт, — фиксируем как План для
    // строки ЗАПАС в Отчёте.
    final recommendedSave = _maxEveningSaveAmount();
    final saveAmount = _eveningSaveAmount.clamp(0, recommendedSave).toInt();

    if (total + repairTotal + saveAmount > _game.walletDar) {
      _showMessage(
        'Не хватает Дар на всё сразу: покупки, ремонт и накопления вместе. '
        'Уменьшите одну из статей и попробуйте снова.',
      );
      return;
    }

    for (final item in toBuy) {
      if (item.plannedCost <= 0) continue;
      if (item.category == PlanCategory.need) {
        _economyEngine.purchaseNeed(
          _game,
          price: item.plannedCost,
          sourceId: 'evening:${_game.period}:${item.id}',
          sourceTitle: item.title,
          reason: 'Вечерняя покупка по Плану',
        );
      } else if (item.category == PlanCategory.want) {
        _economyEngine.purchaseWant(
          _game,
          price: item.plannedCost,
          sourceId: 'evening:${_game.period}:${item.id}',
          sourceTitle: item.title,
          reason: 'Вечерняя покупка по Плану',
        );
      }
    }

    var repairUnitsBought = 0;
    var repairDarSpent = 0;
    for (final entry in repairPurchases) {
      final item = entry.key;
      final units = entry.value;
      final price = units * item.unitCost;
      if (price <= 0) continue;
      _economyEngine.purchaseNeed(
        _game,
        price: price,
        sourceId: 'evening:${_game.period}:repair:${item.id}',
        sourceTitle: item.title,
        reason: 'Ремонт корабля: ${item.title} ($units шт.)',
      );
      _game.payShipRepairUnits(item.id, units);
      repairUnitsBought += units;
      repairDarSpent += price;
    }

    if (saveAmount > 0) {
      _economyEngine.depositSavings(
        _game,
        amount: saveAmount,
        sourceId: 'evening:${_game.period}:savings',
        sourceTitle: 'Накопления на цель',
        reason: 'Отложено на цель «${_game.activeGoalTitle}»',
      );
    }

    // Рост питомца по итогам периода: оплачены ли обязательные НАДО,
    // совпал ли вечерний выбор с утренним Планом, отложено ли в накопления.
    final optionalPlanned = _eveningPurchaseables()
        .where((item) => !item.mandatory)
        .toList(growable: false);
    final planMatchedFact = optionalPlanned
        .every((item) => _game.eveningSelectedItemIds.contains(item.id));
    final growthUpdate = _game.applyPeriodGrowth(
      mandatoryPaid: toBuy.where((item) => item.mandatory).length ==
          _eveningPurchaseables().where((item) => item.mandatory).length,
      planMatchedFact: planMatchedFact,
      savedThisPeriod: saveAmount > 0,
    );
    final gameCompleted = _isShipRepairComplete(_game);

    // Снимок дня до того, как период сменится и утро очистит План —
    // показывается на экране «БАЗА ЗАКРЫТА».
    final closingFact = _economyEngine.calculateFact(_game);

    setState(() {
      _game.planSave = recommendedSave;
      _lastPeriodIncome = closingFact.income;
      _lastPeriodSpent = closingFact.actualNeed + closingFact.actualWant;
      _lastPeriodSaved = closingFact.actualSavings;
      _lastPeriodRepairUnitsBought = repairUnitsBought;
      _lastPeriodRepairDarSpent = repairDarSpent;
      _lastGrowthUpdate = growthUpdate;
      _game.totalWorkSessionsCompleted += 1;
      if (_game.period < 5) {
        _game.period += 1;
      }
      _game.sessionPhase = BaseSessionPhase.closed;
      _eveningSaveAmount = 0;
      _eveningRepairUnits.clear();
      _screen = gameCompleted ? AppScreen.gameEnd : AppScreen.sessionClosed;
    });
    await _save();
  }

  Future<void> _completePhd() async {
    await _bazarStorage.clear();
    if (!mounted) return;
    setState(() {
      _game.resetAfterPhd();
      _game.prepareMorningSession();
      _screen = AppScreen.base;
    });
    await _save();
  }

  Future<void> _resetProfile() async {
    await Future.wait(<Future<void>>[
      _storage.reset(),
      _bazarStorage.clear(),
    ]);
    if (!mounted) return;
    _playerNameController.clear();
    _petNameController.clear();
    setState(() {
      _game = GameStateData();
      _draftPet = null;
      _lastGrowthUpdate = null;
      // После сброса — на титульный экран: «Начать игру» откроет
      // «Встречу гостей» со Сверчком (_screenForState для нового профиля).
      _screen = AppScreen.title;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AppSettings.instance,
          builder: (context, _) => AnimatedSwitcher(
            duration: AppSettings.instance.animationsEnabled
                ? const Duration(milliseconds: 320)
                : Duration.zero,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_screen),
              child: _buildScreen(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case AppScreen.loading:
        return const _LoadingScreen();
      case AppScreen.title:
        return TitleScreen(
          hasProgress: _hasProgress,
          playerName: _game.playerName,
          onPlay: () => setState(() => _screen = _screenForState(_game)),
          onNewGame: _confirmReset,
        );
      case AppScreen.gameEnd:
        return _buildGameEnd();
      case AppScreen.adult:
        return _buildAdultSection();
      case AppScreen.tasks:
        return TasksScreen(
          game: _game,
          initialTaskId: _tasksInitialId,
          onSave: _saveAndRefresh,
          onBack: () => setState(() => _screen = AppScreen.base),
        );
      case AppScreen.savings:
        return SavingsScreen(
          game: _game,
          onSave: _saveAndRefresh,
          onBack: () => setState(() => _screen = AppScreen.base),
        );
      case AppScreen.guestWelcome:
        return _buildGuestWelcome();
      case AppScreen.commanderIntro:
        return _buildCommanderIntro();
      case AppScreen.baseIntro:
        return _buildBaseIntro();
      case AppScreen.barryPrologue:
        return _buildBarryPrologue();
      case AppScreen.barryMeeting:
        return _buildBarryMeeting();
      case AppScreen.iyaPrologue:
        return _buildIyaPrologue();
      case AppScreen.iyaMeeting:
        return _buildIyaMeeting();
      case AppScreen.choosePet:
        return _buildPetSelection();
      case AppScreen.namePet:
        return _buildPetNaming();
      case AppScreen.teamHome:
        return _buildTeamHome();
      case AppScreen.firstCouncil:
        return _buildFirstCouncil();
      case AppScreen.sessionClosed:
        return _buildSessionClosed();
      case AppScreen.phd:
        return _buildPhd();
      case AppScreen.base:
        return _buildBase();
      case AppScreen.tent:
        return _buildTent();
      case AppScreen.bazar:
        return BazarGameScreen(
          commanderBalanceDar: _game.walletDar,
          store: _bazarStorage,
          onIncome: _creditBazarIncome,
          onExpense: _chargeBazarExpense,
          onAsteroidQuest: _launchBazarAsteroidQuest,
          onExit: () => setState(() => _screen = AppScreen.base),
          onFinished: _finishBazarPrototype,
        );
      case AppScreen.petDetail:
        return _buildPetDetail();
      case AppScreen.shipDetail:
        return _buildShipDetail();
      case AppScreen.commanderReport:
        return _buildCommanderReport();
      case AppScreen.tir:
        return TirWebScreen(onExit: () => setState(() => _screen = AppScreen.base));
    }
  }

  Widget _page(List<Widget> children) {
    return Stack(
      children: [
        const Positioned.fill(child: _TechBackground()),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SystemRibbon(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _confirmReset,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        side: const BorderSide(color: Color(0xFFFFC85C), width: 1.2),
                        foregroundColor: const Color(0xFFFFC85C),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Сброс теста', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestWelcome() {
    return _page([
      const _ScreenNumber(number: '1', title: 'Встреча гостей'),
      const SizedBox(height: 12),
      const _CharacterArt(
        asset: 'assets/characters/sverchok.png',
        height: 320,
        fallback: '🦗',
      ),
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Сверчок',
        text:
            'Доброго дня! Рад Вас приветствовать в нашем мире приключений.\n\n'
            'Сегодня я открою для Вас нашу вселенную «12 Дар», где мои друзья помогут Вам познакомиться с основами расчётов и планирования.\n\n'
            'Надеюсь, Вам будет интересно!',
      ),
      const SizedBox(height: 12),
      const _StatusCard(
        icon: Icons.shield_outlined,
        title: 'Локальная экспедиция',
        text: 'Игровой профиль хранится на этом устройстве. Для знакомства достаточно игрового образа.',
        accent: Color(0xFF70D7FF),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _finishWelcome,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Продолжить'),
      ),
    ]);
  }

  Widget _buildCommanderIntro() {
    return _page([
      const _ScreenNumber(number: '2', title: 'Знакомство с Командором'),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Image.asset(
          'assets/scenes/sverchok_portal.jpg',
          height: 360,
          width: double.infinity,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 14),
      const _DialogueCard(
        speaker: 'Сверчок',
        text:
            'Пока наши друзья летят по своему маршруту, позвольте с Вами познакомиться.\n\n'
            'Как я могу к Вам обращаться? Можете придумать себе любой образ.',
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _playerNameController,
        maxLength: 18,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _acceptCommand(),
        decoration: const InputDecoration(
          labelText: 'Ваш игровой образ',
          hintText: 'Например: Звездочёт',
          helperText: 'Настоящее имя указывать не обязательно — на Ваше усмотрение.',
        ),
      ),
      const SizedBox(height: 6),
      const _DialogueCard(
        speaker: 'Сверчок',
        text:
            'Спасибо! Поздравляю, Вас зачислили в основной состав Базы на должность Командора! Браво!\n\n'
            'На первое время Командование выделило Вам 12 Дар. На Базе Вы сами решите, как ими распорядиться, а друзья всегда помогут советом.\n\n'
            'Ну что, Командор, в путь?',
      ),
      const SizedBox(height: 12),
      const _StatusCard(
        icon: Icons.auto_awesome_rounded,
        title: '+12 Дар',
        text: 'Источник начисления: Командование галактики. Дары поступят на баланс после подтверждения.',
        accent: Color(0xFFFFC85C),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _acceptCommand,
        icon: const Icon(Icons.meeting_room_rounded),
        label: const Text('Открыть Базу'),
      ),
    ]);
  }

  Widget _buildBaseIntro() {
    return _page([
      const _ScreenNumber(number: '3', title: 'Первое знакомство с Базой'),
      const SizedBox(height: 12),
      Stack(
        alignment: Alignment.bottomLeft,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Image.asset(
              'assets/scenes/base_prologue.png',
              height: 310,
              width: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xD9152036),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.65)),
              ),
              child: const Text('БАЗА // СЕКТОР 01 // ONLINE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFBDEEFF))),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 8),
            child: SizedBox(
              width: 130,
              child: _CharacterArt(
                asset: 'assets/characters/sverchok.png',
                height: 170,
                fallback: '🦗',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const _DialogueCard(
        speaker: 'Сверчок',
        text:
            'Это наша База — место силы и вдохновения.\n\n'
            'Пока друзья летят по своему маршруту, нам надо подготовиться. Вы — Командор этой Базы, её надежда и опора.\n\n'
            'Командование выделило Вам три сундука. В них мы будем планировать управление Базой: НАДО, ХОЧУ и ЗАПАС.\n\n'
            'Пока ничего распределять не нужно. Сначала дождёмся команды и вместе проведём первое Совещание.\n\n'
            'Тише... Я слышу какой-то шум за окном.',
      ),
      const SizedBox(height: 14),
      const Row(
        children: [
          Expanded(child: _ChestCard(title: 'НАДО', value: 'важное', accent: Color(0xFF8DE5A1))),
          SizedBox(width: 8),
          Expanded(child: _ChestCard(title: 'ХОЧУ', value: 'желания', accent: Color(0xFFFFA7D1))),
          SizedBox(width: 8),
          Expanded(child: _ChestCard(title: 'ЗАПАС', value: 'будущее', accent: Color(0xFFFFC85C))),
        ],
      ),
      const SizedBox(height: 12),
      const _StatusCard(
        icon: Icons.info_outline_rounded,
        title: '12 Дар пока остаются на общем балансе',
        text: 'План появится позже — на Совещании команды. До подтверждения его можно будет менять.',
        accent: Color(0xFF70D7FF),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _go(AppScreen.barryPrologue, 3),
        icon: const Icon(Icons.hearing_rounded),
        label: const Text('Прислушаться'),
      ),
    ]);
  }

  Widget _buildBarryPrologue() {
    return _page([
      const _ScreenNumber(number: '4', title: 'Прибытие команды'),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.sensors_rounded,
        title: 'Внешнее событие',
        text: 'Система Базы фиксирует приближение корабля Барри к окну.',
        accent: Color(0xFFFFB36B),
      ),
      const SizedBox(height: 12),
      _PrologueVideo(
        assetPath: 'assets/videos/barry_arrival.mp4',
        skipLabel: 'Пропустить прибытие',
        onFinished: () => _go(AppScreen.barryMeeting, 4),
      ),
    ]);
  }

  Widget _buildBarryMeeting() {
    return _page([
      const _ScreenNumber(number: '5', title: 'Барри и Барт на Базе'),
      const SizedBox(height: 12),
      _DialogueCard(
        speaker: 'Барри',
        text:
            'Командор ${_game.playerName}, разрешите у Вас остановиться на ремонт? Спасибо!',
      ),
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Барри',
        text:
            'Ой, чуть не забыл — это мой верный бортинженер Барт.',
      ),
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Барт',
        text: 'Рад знакомству, Командор.',
      ),
      const SizedBox(height: 12),
      const _StatusCard(
        icon: Icons.build_circle_outlined,
        title: 'Кораблю нужен ремонт',
        text:
            'Барри и Барт временно остаются на Базе. Что именно понадобится для ремонта, команда разберёт позже.',
        accent: Color(0xFFFFC85C),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: () => _go(AppScreen.iyaPrologue, 5),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Хлопок?..'),
      ),
    ]);
  }

  Widget _buildIyaPrologue() {
    return _page([
      const _ScreenNumber(number: '6', title: 'Неожиданное появление'),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.auto_awesome_rounded,
        title: 'Магическая вспышка',
        text: 'В воздухе раздаётся хлопок — на Базе появляется ещё одна гостья.',
        accent: Color(0xFF9B8CFF),
      ),
      const SizedBox(height: 12),
      _PrologueVideo(
        assetPath: 'assets/videos/iya_arrival.mp4',
        skipLabel: 'Пропустить появление Ии',
        onFinished: () => _go(AppScreen.iyaMeeting, 6),
      ),
    ]);
  }

  Widget _buildIyaMeeting() {
    return _page([
      const _ScreenNumber(number: '7', title: 'Знакомство с Ией'),
      const SizedBox(height: 12),
      const _DialogueCard(
        speaker: 'Ия',
        text:
            'Мальчики, что опять случилось?..',
      ),
      const SizedBox(height: 8),
      const _DialogueCard(
        speaker: 'Ия',
        text:
            'Ой, здравствуйте, Командор! Я фея Ия. Присматриваю за этими парнями.',
      ),
      const SizedBox(height: 8),
      const _DialogueCard(
        speaker: 'Ия',
        text:
            'А ещё у меня есть магазин «Всякая ксячина». К Вашим услугам!',
      ),
      const SizedBox(height: 12),
      const _DialogueCard(
        speaker: 'Барри',
        text:
            'Ой, чуть не забыл — мои спутники! Командор, выберите одного из них. '
            'Пусть поживёт с нами, остальных заберёт Ия.',
      ),
      const SizedBox(height: 12),
      const _StatusCard(
        icon: Icons.tablet_mac_rounded,
        title: 'Голографический планшет Барри',
        text:
            'Барри открывает планшет и показывает своих друзей. Выбранный спутник останется на Базе и получит своё место на столе.',
        accent: Color(0xFF70D7FF),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _openPetSelection,
        icon: const Icon(Icons.view_in_ar_rounded),
        label: const Text('Открыть голографический планшет'),
      ),
    ]);
  }

  Widget _buildPetSelection() {
    return _page([
      const _ScreenNumber(number: '8', title: 'Спутники Барри'),
      const SizedBox(height: 10),
      const _TechBadge(text: 'ГОЛОГРАФИЧЕСКИЙ ПЛАНШЕТ // 3 СПУТНИКА'),
      const SizedBox(height: 12),
      const Text(
        'Кого оставим жить с нами на Базе?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 6),
      const Text(
        'Выберите одного друга. Остальных заберёт Ия — они никуда не исчезнут и ещё встретятся нам в приключениях.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xFFB8C7E3)),
      ),
      const SizedBox(height: 16),
      _PetChoiceCard(
        pet: PetType.skorohod,
        selected: _draftPet == PetType.skorohod,
        description: 'Любит путешествия, истории и уютные вечера.',
        onTap: () => _selectPet(PetType.skorohod),
      ),
      const SizedBox(height: 10),
      _PetChoiceCard(
        pet: PetType.kwak,
        selected: _draftPet == PetType.kwak,
        description: 'Любознательный, весёлый и иногда очень задумчивый.',
        onTap: () => _selectPet(PetType.kwak),
      ),
      const SizedBox(height: 10),
      _PetChoiceCard(
        pet: PetType.tsvetik,
        selected: _draftPet == PetType.tsvetik,
        description: 'Музыкальный, добрый и любит внимание.',
        onTap: () => _selectPet(PetType.tsvetik),
      ),
      const SizedBox(height: 18),
      FilledButton(
        onPressed: _draftPet == null ? null : _openPetNaming,
        child: const Text('Пусть остаётся с нами'),
      ),
    ]);
  }

  Widget _buildPetNaming() {
    final pet = _draftPet ?? _game.selectedPet;
    return _page([
      const _ScreenNumber(number: '9', title: 'Новый житель Базы'),
      const SizedBox(height: 10),
      _PetStageArt(pet: pet, style: _game.petStyle, stage: 0, height: 280),
      const SizedBox(height: 10),
      _PetLookPicker(
        pet: pet,
        selected: _game.petStyle,
        onSelected: _selectPetLook,
      ),
      const SizedBox(height: 10),
      _DialogueCard(
        speaker: 'Сверчок',
        text:
            '${pet.title} остаётся с нами. Давайте дадим новому другу имя, а затем разместим его на площадке на столе Базы.',
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _petNameController,
        maxLength: 18,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _savePetName(),
        decoration: InputDecoration(labelText: 'Имя питомца', hintText: pet.title),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _savePetName,
        icon: const Icon(Icons.home_rounded),
        label: const Text('Разместить на столе'),
      ),
    ]);
  }

  Widget _buildTeamHome() {
    final pet = _draftPet ?? _game.selectedPet;
    final petName = _game.petName.isEmpty ? pet.title : _game.petName;
    return _page([
      const _ScreenNumber(number: '10', title: 'Команда дома'),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Image.asset(
              'assets/scenes/base_prologue_evening.jpg',
              height: 285,
              width: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, const Color(0xFF11182B).withValues(alpha: 0.82)],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              child: _TechBadge(text: 'ЛУННАЯ ДОРОГА // КАНАЛ ОТКРЫТ'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const _CrewPresenceCard(icon: '🧭', name: 'Барри', place: 'корабль и ремонт'),
          const _CrewPresenceCard(icon: '🤖', name: 'Барт', place: 'аналитический терминал'),
          const _CrewPresenceCard(icon: '✨', name: 'Ия', place: 'Лунная дорога'),
          _CrewPresenceCard(icon: pet.emoji, name: petName, place: 'место питомца'),
        ],
      ),
      const SizedBox(height: 12),
      const _DialogueCard(speaker: 'Сверчок', text: 'Вот теперь все в сборе. Новый житель уже устроился на своей площадке на столе.'),
      const SizedBox(height: 8),
      const _DialogueCard(speaker: 'Ия', text: 'На Совещании я покажу, как команда может раздобыть новые Дары, и открою Лунную дорогу из окна Базы прямо на BAZAR.'),
      const SizedBox(height: 8),
      const _DialogueCard(speaker: 'Барт', text: 'База готова к работе. Почти.'),
      const SizedBox(height: 8),
      const _DialogueCard(speaker: 'Барри', text: 'Протопозитрон всё ещё сгорел.'),
      const SizedBox(height: 8),
      const _DialogueCard(speaker: 'Барт', text: 'Именно поэтому — почти. После Совещания появится понятный план действий.'),
      const SizedBox(height: 14),
      const _StatusCard(
        icon: Icons.groups_2_outlined,
        title: 'Команда в сборе',
        text: 'Сегодня никаких планов. Сначала познакомимся и закончим этот длинный первый день вместе.',
        accent: Color(0xFF8DE5A1),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        onPressed: _openFirstCouncil,
        icon: const Icon(Icons.groups_rounded),
        label: const Text('В Палатку · знакомство'),
      ),
    ]);
  }

  Widget _buildFirstCouncil() {
    return _page([
      const _ScreenNumber(number: '11', title: 'Первая сессия · Знакомство'),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/scenes/tent_council.png',
          width: double.infinity,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 12),
      const _TechBadge(text: 'СЕССИЯ 0 // ЗНАКОМСТВО'),
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Барри',
        text: 'Вот теперь можно познакомиться как следует. Я Барри. Корабль мой, поломки тоже в основном мои.',
      ),
      const SizedBox(height: 8),
      const _DialogueCard(
        speaker: 'Барт',
        text: 'Барт. Бортинженер. Постараюсь, чтобы количество поломок постепенно уменьшалось.',
      ),
      const SizedBox(height: 8),
      const _DialogueCard(
        speaker: 'Ия',
        text: 'А я Ия. Если понадобится подсказка — я рядом. Но решения на Базе принимает Командор.',
      ),
      const SizedBox(height: 8),
      _DialogueCard(
        speaker: _game.petName.isEmpty ? _game.selectedPet.title : _game.petName,
        text: 'Кажется, новый житель уже чувствует себя здесь как дома.',
      ),
      const SizedBox(height: 14),
      const _StatusCard(
        icon: Icons.nights_stay_outlined,
        title: 'Никаких планов сегодня',
        text: 'Это первая сессия — только знакомство. Рабочая экономика начнётся следующим утром.',
        accent: Color(0xFF9B8CFF),
      ),
      const SizedBox(height: 12),
      const _DialogueCard(
        speaker: 'Ия',
        text: 'Ой… кажется, все уже зевают. Сегодня был тяжёлый день. Давайте отдохнём.',
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const Key('session.acquaintance.good_night'),
        onPressed: _finishAcquaintance,
        icon: const Icon(Icons.bedtime_rounded),
        label: const Text('Да, пожалуй. Добрых снов'),
      ),
    ]);
  }

  Widget _buildSessionClosed() {
    final isPrologueNight = _game.totalWorkSessionsCompleted == 0;
    final phdNext = _game.totalWorkSessionsCompleted > 0 &&
        _game.totalWorkSessionsCompleted % 5 == 0 &&
        _game.period >= 5;
    final image = isPrologueNight
        ? 'assets/scenes/base_prologue_night.jpg'
        : 'assets/scenes/base_night.jpg';
    return _page([
      _ScreenNumber(
        number: isPrologueNight ? '12' : 'Н',
        title: isPrologueNight ? 'Первая ночь на Базе' : 'База закрыта до утра',
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          image,
          width: double.infinity,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.nightlight_round,
        title: 'БАЗА ЗАКРЫТА',
        text: 'Сессия завершена. Остаток Дар сохраняется и станет начальным балансом следующего рабочего утра.',
        accent: Color(0xFF9B8CFF),
      ),
      if (!isPrologueNight) ...[
        const SizedBox(height: 10),
        _StatusCard(
          icon: Icons.summarize_outlined,
          title: 'Итоги сегодняшнего дня',
          text: 'Заработано: +$_lastPeriodIncome Дар · Потрачено: $_lastPeriodSpent Дар · '
              'Отложено в накопления: +$_lastPeriodSaved Дар.\n'
              'Цель «${_game.activeGoalTitle}»: ${_game.savingsDar}/${_game.activeGoalTarget} Дар.'
              '${_lastPeriodRepairUnitsBought > 0 ? '\nРемонт корабля: куплено $_lastPeriodRepairUnitsBought шт. ($_lastPeriodRepairDarSpent Дар).' : ''}',
          accent: const Color(0xFFFFC85C),
        ),
        if (_lastGrowthUpdate != null) ...[
          const SizedBox(height: 10),
          _StatusCard(
            icon: Icons.eco_rounded,
            title: _lastGrowthUpdate!.stageChanged
                ? 'Питомец вырос! ${PetGrowthCatalog.stageTitle(_lastGrowthUpdate!.next.growthStage)}'
                : 'Рост питомца',
            text: _lastGrowthUpdate!.explanation,
            accent: const Color(0xFF8DE5A1),
          ),
        ],
      ],
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Ия',
        text: 'Ночи на нашей Базе короткие. Пока приложение запущено, мы отдыхаем, а утро начинается, когда Вы снова заходите на Базу.',
      ),
      const SizedBox(height: 8),
      const _StatusCard(
        icon: Icons.music_note_rounded,
        title: 'За окном щебечут птицы',
        text: 'Тихая ночная пауза отделяет одну сессию от следующей.',
        accent: Color(0xFF70D7FF),
      ),
      const _BirdAmbience(),
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const Key('session.enter_base'),
        onPressed: _enterBaseForMorning,
        icon: const Icon(Icons.wb_sunny_rounded),
        label: Text(phdNext ? 'Зайти на БАЗУ · ПХД' : 'Зайти на БАЗУ'),
      ),
    ]);
  }

  Widget _buildGameEnd() {
    final pet = _game.selectedPet;
    final totalEarned = _game.transactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<int>(0, (sum, transaction) => sum + transaction.amount);
    // Фактически вложено в ремонт: при эвакуации корабль может быть
    // починен лишь частично.
    final repairSpent = ShipRepairCatalog.items.fold<int>(
      0,
      (sum, item) => sum + _game.shipRepairUnitsPaidFor(item.id) * item.unitCost,
    );

    return GameEndScreen(
      summary: GameEndSummary(
        playerName: _game.playerName,
        petName: _game.petName.isEmpty ? pet.title : _game.petName,
        petEmoji: pet.emoji,
        petArtAsset: PetLooks.of(pet, _game.petStyle).asset,
        petStageTitle: PetGrowthCatalog.stageTitle(_game.petState.growthStage),
        workSessions: _game.totalWorkSessionsCompleted,
        totalEarnedDar: totalEarned,
        repairSpentDar: repairSpent,
        savingsDar: _game.savingsDar,
        evacuated: _game.shipEvacuated && !_isShipRepairComplete(_game),
      ),
      onRestart: _resetProfile,
      onExitToTitle: _exitToTitle,
    );
  }

  Widget _buildPhd() {
    return _page([
      const _ScreenNumber(number: 'ПХД', title: 'Выходной после пяти рабочих сессий'),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/scenes/base_morning.jpg',
          width: double.infinity,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
      const SizedBox(height: 12),
      const _DialogueCard(
        speaker: 'Барт',
        text: 'Пять рабочих сессий завершены. Сегодня ПХД: приводим Базу и оборудование в порядок, закрываем старые заявки и готовимся к новому циклу.',
      ),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.cleaning_services_rounded,
        title: 'ПХД · уборка · обновление заявок',
        text: 'Временные заявки пятидневного цикла будут очищены. Постоянное содержание Питомца и Барри останется в каталоге.',
        accent: Color(0xFF8DE5A1),
      ),
      const SizedBox(height: 18),
      FilledButton.icon(
        key: const Key('session.phd.complete'),
        onPressed: _completePhd,
        icon: const Icon(Icons.cleaning_services_rounded),
        label: const Text('Завершить ПХД · начать новое утро'),
      ),
    ]);
  }

  Widget _buildBase() {
    final phase = _game.sessionPhase;
    final isMorning = phase == BaseSessionPhase.morning;
    final isDay = phase == BaseSessionPhase.day;
    final isEvening = phase == BaseSessionPhase.evening;
    final backgroundAsset = isEvening
        ? 'assets/scenes/base_evening.jpg'
        : 'assets/scenes/base_morning.jpg';
    final phaseTitle = isMorning
        ? 'УТРО · обход Командора'
        : isDay
            ? 'ДЕНЬ · выполнение Плана'
            : 'ВЕЧЕР · подведение итогов';

    void openTentForPhase() {
      if (isDay) {
        _showMessage('Вечернее Совещание откроется после завершения дневной работы на BAZAR.');
        return;
      }
      _openTent();
    }

    return Column(
      children: [
        _BaseTopBar(
          walletDar: _game.walletDar,
          savingsDar: _game.savingsDar,
          goalText: '${_game.savingsDar}/${_game.activeGoalTarget}',
          onReset: _confirmReset,
          onExit: _exitToTitle,
        ),
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: _TechBackground()),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SystemRibbon(),
                        if (_game.demoProfile) ...[
                          const SizedBox(height: 8),
                          const _StatusCard(
                            key: Key('base.demo_badge'),
                            icon: Icons.science_outlined,
                            title: 'ДЕМО · тестовый профиль',
                            text: 'Режим экспертной проверки. Сброс профиля — в разделе «Для взрослого».',
                            accent: Color(0xFFFF8BD1),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _ScreenNumber(
                          number: '${_game.period}',
                          title: 'База · $phaseTitle · сессия ${_game.period} из 5',
                        ),
                        const SizedBox(height: 10),
                        _BaseHubScene(
                          backgroundAsset: backgroundAsset,
                          pet: _game.selectedPet,
                          petStyle: _game.petStyle,
                          petStage: _game.petState.growthStage,
                          showBazar: isDay,
                          onTent: openTentForPhase,
                          onPet: () => _openPetDetail(),
                          onShip: () => _openShipDetail(),
                          onBazar: _openBazar,
                          onTir: _openTir,
                          onInfo: () => showSpravochnayaDialog(context),
                          onSchool: _openTasks,
                        ),
                        const SizedBox(height: 12),
                        _StatusCard(
                          icon: isMorning
                              ? Icons.wb_sunny_outlined
                              : isDay
                                  ? Icons.route_rounded
                                  : Icons.nights_stay_outlined,
                          title: phaseTitle,
                          text: isMorning
                              ? 'Сначала Командор обходит Питомца и Барри. В каждой таблице на сегодня можно выбрать одну непостоянную позицию. Затем — утреннее Совещание.'
                              : isDay
                                  ? 'Утренний План утверждён. Сейчас деньги не списываются: выполняем задания, зарабатываем Дар и работаем на BAZAR.'
                                  : 'Дневная работа завершена. Вечернее Совещание открыто: сверяем План и Факт и только теперь подтверждаем реальные расходы.',
                          accent: isMorning
                              ? const Color(0xFFFFC85C)
                              : isDay
                                  ? const Color(0xFF70D7FF)
                                  : const Color(0xFF9B8CFF),
                        ),
                        if (isMorning) ...[
                          const SizedBox(height: 10),
                          _MorningRoundStatus(
                            petDone: _game.currentPetRequestId != null,
                            barryDone: _game.currentBarryRequestId != null,
                            councilReady: _game.morningRoundComplete,
                          ),
                        ],
                        const SizedBox(height: 10),
                        _ActiveTaskCard(
                          task: FinanceTaskProgress.nextTask(_game),
                          done: FinanceTaskProgress.completed(_game).length,
                          total: FinanceContent.tasks.length,
                          onOpen: (task) => _openTasks(taskId: task?.id),
                        ),
                        const SizedBox(height: 12),
                        const Text('Меню Базы', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _QuickLinkCard(
                              icon: Icons.assessment_outlined,
                              title: 'Отчёт Командора',
                              subtitle: 'план · факт · заработал · потратил',
                              onTap: () => setState(() => _screen = AppScreen.commanderReport),
                            ),
                            _QuickLinkCard(
                              icon: Icons.auto_awesome_rounded,
                              title: 'BAZAR',
                              subtitle: isDay ? 'Лунная дорога открыта' : 'доступен после утреннего Плана',
                              onTap: _openBazar,
                            ),
                            _QuickLinkCard(
                              icon: Icons.cabin_rounded,
                              title: 'Палатка',
                              subtitle: isMorning
                                  ? 'утреннее Совещание'
                                  : isEvening
                                      ? 'вечернее Совещание'
                                      : 'закрыта до вечера',
                              onTap: openTentForPhase,
                            ),
                            _QuickLinkCard(
                              icon: Icons.school_rounded,
                              title: CommanderSchool.title,
                              subtitle: '${CommanderSchool.rankFor(FinanceTaskProgress.completed(_game).length).title} · '
                                  'пройдено ${FinanceTaskProgress.completed(_game).length} из ${FinanceContent.tasks.length}',
                              onTap: _openTasks,
                            ),
                            _QuickLinkCard(
                              icon: Icons.savings_rounded,
                              title: 'Накопления и цели',
                              subtitle: '${_game.savingsDar} из ${_game.activeGoalTarget} Дар · ${_game.activeGoalTitle}',
                              onTap: _openSavings,
                            ),
                            _QuickLinkCard(
                              icon: Icons.menu_book_rounded,
                              title: 'Справочная',
                              subtitle: 'Пчела расскажет порядок дня',
                              onTap: () => showSpravochnayaDialog(context),
                            ),
                            _QuickLinkCard(
                              icon: Icons.family_restroom_rounded,
                              title: 'Для взрослого',
                              subtitle: 'прогресс · настройки · сброс',
                              onTap: _openAdultSection,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const _BaseAdviceStrip(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTent() {
    final phase = _game.sessionPhase;
    final fact = _economyEngine.calculateFact(_game);
    final plan = _game.currentPlan;

    if (phase == BaseSessionPhase.morning) {
      final petChoice = PlanningCatalog.byId(_game.currentPetRequestId ?? '');
      final barryChoice = PlanningCatalog.byId(_game.currentBarryRequestId ?? '');
      return _page([
        _tentHeader('Утреннее Совещание'),
        const SizedBox(height: 8),
        _tentImage(),
        const SizedBox(height: 10),
        const _DialogueCard(
          speaker: 'Ия',
          text: 'Соберём результаты утреннего обхода. Сейчас мы только согласовываем План — ни один Дар утром не списывается.',
        ),
        const SizedBox(height: 10),
        _CouncilChoiceCard(
          title: 'Питомец',
          item: petChoice,
          missingText: 'Заявка ещё не выбрана. Вернитесь на Базу и зайдите к Питомцу.',
        ),
        const SizedBox(height: 8),
        _CouncilChoiceCard(
          title: 'Барри и Корабль',
          item: barryChoice,
          missingText: 'Заявка ещё не выбрана. Вернитесь на Базу и зайдите к Барри.',
        ),
        const SizedBox(height: 10),
        const _StatusCard(
          icon: Icons.push_pin_outlined,
          title: 'Постоянное содержание',
          text: 'Питомец — 3 Дар. Барри — 3 Дар. Эти постоянные позиции входят в План автоматически и не исчезают после ПХД.',
          accent: Color(0xFF8DE5A1),
        ),
        const SizedBox(height: 12),
        _buildMorningBudgetCard(),
        ..._buildShipRepairMorningSection(),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('session.morning.confirm_plan'),
          onPressed: _game.morningRoundComplete ? _confirmMorningPlan : null,
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Согласовать утренний План'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _screen = AppScreen.base),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Вернуться к обходу'),
        ),
      ]);
    }

    if (phase == BaseSessionPhase.evening) {
      final purchaseable = _eveningPurchaseables();
      final selectedCost = _eveningSelectedCost();
      final maxSave = _maxEveningSaveAmount();
      final saveAmount = _eveningSaveAmount.clamp(0, maxSave).toInt();
      final repairUnitsTotal = _game.shipRepairActiveItems.fold<int>(
        0,
        (sum, item) => sum + _eveningRepairUnitsFor(item.id),
      );

      return _page([
        _tentHeader('Вечернее Совещание'),
        const SizedBox(height: 8),
        _tentImage(),
        const SizedBox(height: 10),
        const _DialogueCard(
          speaker: 'Ия',
          text: 'Теперь можно сравнить План с тем, как прошёл день. Только здесь подтверждаем реальные покупки и списываем Дар.',
        ),
        const SizedBox(height: 12),
        const Text('План ↔ Факт', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _PlanFactRow(title: 'НАДО', plan: _game.planNeed, fact: fact.actualNeed, accent: const Color(0xFF8DE5A1)),
        const SizedBox(height: 8),
        _PlanFactRow(title: 'ХОЧУ', plan: _game.planWant, fact: fact.actualWant, accent: const Color(0xFFFFA7D1)),
        const SizedBox(height: 8),
        _PlanFactRow(
          title: 'НАКОПЛЕНИЯ',
          plan: plan?.plannedSavings ?? 0,
          fact: fact.actualSavings < 0 ? 0 : fact.actualSavings,
          accent: const Color(0xFFB68CFF),
        ),
        const SizedBox(height: 8),
        _StatusCard(
          icon: Icons.trending_up_rounded,
          title: 'Заработано сегодня: ${fact.income} Дар',
          text: 'Кошелёк перед вечерними расходами: ${_game.walletDar} Дар.',
          accent: const Color(0xFF70D7FF),
        ),
        const SizedBox(height: 12),
        const Text('Что покупаем сегодня', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        ...purchaseable.map((item) {
          final checked = item.mandatory || _game.eveningSelectedItemIds.contains(item.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: CheckboxListTile(
              value: checked,
              onChanged: item.mandatory
                  ? null
                  : (value) => _toggleEveningItem(item, value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                '${_planCategoryLabel(item.category)}${item.mandatory ? ' · ПОСТОЯННО' : ''} · ${item.plannedCost} Дар\n'
                '${_purchaseEffectText(ownerId: item.ownerId, category: item.category)}',
              ),
            ),
          );
        }),
        if (plan != null && plan.plannedItems.any((item) => item.category == PlanCategory.planned)) ...[
          const SizedBox(height: 6),
          const _StatusCard(
            icon: Icons.flag_outlined,
            title: 'ПЛАНИРУЮ не списывается',
            text: 'Большие цели остаются ориентирами. Сегодняшнее вечернее списание касается только НАДО и ХОЧУ.',
            accent: Color(0xFFFFC85C),
          ),
        ],
        const SizedBox(height: 12),
        _StatusCard(
          icon: Icons.payments_outlined,
          title: 'К списанию: $selectedCost Дар',
          text: 'После подтверждения остаток кошелька будет сохранён как основа следующего утра.',
          accent: const Color(0xFFFFC85C),
        ),
        const SizedBox(height: 16),
        const Text('Отложить в накопления', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        _StatusCard(
          icon: Icons.flag_outlined,
          title: 'Цель «${_game.activeGoalTitle}»: ${_game.savingsDar}/${_game.activeGoalTarget} Дар',
          text: maxSave > 0
              ? 'Из сегодняшних денег можно отложить до $maxSave Дар — они не тратятся и приближают к цели.'
              : 'Сегодня свободных Дар для накоплений нет — всё уходит на НАДО и ХОЧУ.',
          accent: const Color(0xFFB68CFF),
        ),
        const SizedBox(height: 8),
        _EveningSaveControl(
          amount: saveAmount,
          maxAmount: maxSave,
          onDecrease: () => _adjustEveningSave(-1),
          onIncrease: () => _adjustEveningSave(1),
        ),
        ..._buildShipRepairEveningSection(),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('session.evening.close'),
          onPressed: _settleEveningAndClose,
          icon: const Icon(Icons.nights_stay_rounded),
          label: Text(_eveningCloseButtonLabel(saveAmount, repairUnitsTotal)),
        ),
      ]);
    }

    return _page([
      _tentHeader('Палатка'),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.lock_clock_outlined,
        title: 'Совещание сейчас недоступно',
        text: 'Утреннее Совещание уже завершено. Вечернее откроется после дневной работы.',
        accent: Color(0xFF70D7FF),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => setState(() => _screen = AppScreen.base),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Вернуться на БАЗУ'),
      ),
    ]);
  }

  /// Бюджет дня по 3 направлениям: НАДО, ХОЧУ, накопления — с остатком
  /// и понятным сообщением при превышении (ТЗ 2.5.5).
  Widget _buildMorningBudgetCard() {
    final draft = _draftMorningPlan();
    final available = _morningAvailableBudget;
    final maxSave = _maxMorningSave();
    final save = _morningPlannedSave.clamp(0, maxSave).toInt();
    final total = draft.plannedNeed + draft.plannedWant + save;
    final free = available - total;
    final over = free < 0;
    final accent = over ? const Color(0xFFFF9A8E) : const Color(0xFF8DE5A1);

    return Container(
      key: const Key('session.morning.budget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Бюджет дня', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            'Доступно: $available Дар = в кошельке ${_game.walletDar} + план дохода $_plannedDayIncome '
            '(столько обычно приносит дневная работа на BAZAR).',
            style: const TextStyle(fontSize: 14, height: 1.35, color: Color(0xFFC5D0E4)),
          ),
          const SizedBox(height: 10),
          _BudgetLine(label: 'НАДО · обязательное', value: draft.plannedNeed, icon: Icons.shield_outlined),
          _BudgetLine(label: 'ХОЧУ · по желанию', value: draft.plannedWant, icon: Icons.favorite_border_rounded),
          Row(
            children: [
              const Icon(Icons.savings_outlined, size: 20, color: Color(0xFFB68CFF)),
              const SizedBox(width: 8),
              const Expanded(child: Text('Накопления · отложить', style: TextStyle(fontSize: 15))),
              IconButton(
                key: const Key('session.morning.save.minus'),
                tooltip: 'Меньше',
                onPressed: save > 0 ? () => _adjustMorningSave(-1) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text('$save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              IconButton(
                key: const Key('session.morning.save.plus'),
                tooltip: 'Больше',
                onPressed: save < maxSave ? () => _adjustMorningSave(1) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Icon(over ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  over
                      ? 'План: $total из $available Дар — больше бюджета на ${-free} Дар. '
                          'Выберите позицию подешевле у Питомца или Барри.'
                      : 'План: $total из $available Дар · свободно $free Дар',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Утренний блок Ремонта корабля: активные позиции (можно исключить) и,
  /// если есть свободный слот, позиции из бэклога (можно добавить).
  /// Добавить позицию можно только здесь — вечером в Палатке уже нельзя.
  List<Widget> _buildShipRepairMorningSection() {
    final enabled = _game.sessionPhase == BaseSessionPhase.morning;
    final active = _game.shipRepairActiveItems;
    final pending = _game.shipRepairPendingItems;
    final freeSlots = ShipRepairCatalog.activeSlotLimit - active.length;

    final widgets = <Widget>[
      const SizedBox(height: 10),
      const Text('Ремонт корабля', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
    ];

    if (active.isEmpty && pending.isEmpty) {
      widgets.add(
        const _StatusCard(
          icon: Icons.build_circle_outlined,
          title: 'Ремонт корабля завершён',
          text: 'Все запчасти закуплены — корабль в полном порядке!',
          accent: Color(0xFF8DE5A1),
        ),
      );
      return widgets;
    }

    for (final item in active) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: CheckboxListTile(
            value: true,
            onChanged: enabled ? (_) => _excludeShipRepairItem(item.id) : null,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              'В плане · куплено ${_game.shipRepairUnitsPaidFor(item.id)} из ${item.totalUnits} шт · ${item.unitCost} Дар/шт',
            ),
          ),
        ),
      );
    }

    if (freeSlots > 0) {
      if (pending.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Свободно слотов: $freeSlots из ${ShipRepairCatalog.activeSlotLimit} — можно добавить в план',
              style: const TextStyle(fontSize: 13, color: Color(0xFFB8C7E3)),
            ),
          ),
        );
        for (final item in pending) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: CheckboxListTile(
                value: false,
                onChanged: enabled ? (_) => _activateShipRepairItem(item.id) : null,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Ждёт очереди · ${item.totalUnits} шт по ${item.unitCost} Дар/шт'),
              ),
            ),
          );
        }
      } else if (active.isNotEmpty) {
        widgets.add(
          const _StatusCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Остальные позиции ремонта закрыты',
            text: 'Больше нечего добавлять в план ремонта.',
            accent: Color(0xFF8DE5A1),
          ),
        );
      }
    }

    return widgets;
  }

  /// Вечерний блок Ремонта корабля: по каждой активной позиции — степпер
  /// «купить N шт сегодня», делящий один и тот же остаток кошелька с
  /// накоплениями (см. _maxEveningRepairUnits/_maxEveningSaveAmount).
  List<Widget> _buildShipRepairEveningSection() {
    final active = _game.shipRepairActiveItems;
    if (active.isEmpty) {
      return const <Widget>[];
    }

    final widgets = <Widget>[
      const SizedBox(height: 16),
      const Text('Ремонт корабля', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
    ];

    for (final item in active) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ShipRepairEveningCard(
            title: item.title,
            unitCost: item.unitCost,
            unitsPaid: _game.shipRepairUnitsPaidFor(item.id),
            totalUnits: item.totalUnits,
            unitsToBuy: _eveningRepairUnitsFor(item.id),
            maxUnitsToBuy: _maxEveningRepairUnits(item),
            onDecrease: () => _adjustEveningRepairUnits(item, -1),
            onIncrease: () => _adjustEveningRepairUnits(item, 1),
          ),
        ),
      );
    }

    return widgets;
  }

  String _eveningCloseButtonLabel(int saveAmount, int repairUnitsTotal) {
    final parts = <String>['Подтвердить расходы'];
    if (repairUnitsTotal > 0) {
      parts.add('купить $repairUnitsTotal шт. для ремонта');
    }
    if (saveAmount > 0) {
      parts.add('отложить $saveAmount Дар');
    }
    parts.add('закрыть сессию');
    return parts.join(', ');
  }

  Widget _tentHeader(String title) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Вернуться на Базу',
          onPressed: () => setState(() => _screen = AppScreen.base),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
        _TechBadge(text: 'СЕССИЯ ${_game.period}/5'),
      ],
    );
  }

  Widget _tentImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        'assets/scenes/tent_council.png',
        width: double.infinity,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }

  Widget _buildPetDetail() {
    final pet = _game.selectedPet;
    final name = _game.petName.isEmpty ? pet.title : _game.petName;
    final items = PlanningCatalog.forOwner(PlanOwner.pet, petTypeId: pet.id);
    final mandatory = items.where((item) => item.mandatory).toList(growable: false);
    final choices = items.where((item) => !item.mandatory).toList(growable: false);
    final enabled = _game.sessionPhase == BaseSessionPhase.morning;

    return _page([
      _detailHeader(name, 'ПИТОМЕЦ'),
      const SizedBox(height: 8),
      _PetStageArt(pet: pet, style: _game.petStyle, stage: _game.petState.growthStage, height: 300),
      const SizedBox(height: 8),
      _PetLookPicker(
        pet: pet,
        selected: _game.petStyle,
        onSelected: _selectPetLook,
      ),
      const SizedBox(height: 10),
      _PetGrowthStatusCard(state: _game.petState),
      const SizedBox(height: 10),
      const _StatusCard(
        icon: Icons.inventory_2_outlined,
        title: 'Таблица Питомца',
        text: 'Постоянные позиции сохраняются всегда. Из остальных позиций Командор выбирает одну заявку на текущую рабочую сессию.',
        accent: Color(0xFF70D7FF),
      ),
      const SizedBox(height: 12),
      _PlanningChoiceTable(
        title: 'ПОСТОЯННО · 3 Дар',
        items: mandatory,
        selectedId: null,
        enabled: false,
        onSelected: (_) {},
      ),
      const SizedBox(height: 12),
      _PlanningChoiceTable(
        title: 'Выбрать одну позицию на сегодня',
        items: choices,
        selectedId: _game.currentPetRequestId,
        enabled: enabled,
        onSelected: (id) => _selectMorningRequest(ownerId: PlanOwner.pet, itemId: id),
      ),
      const SizedBox(height: 12),
      _RequestHistoryCard(
        title: 'Заявки Питомца · цикл 1–5',
        ids: _game.petRequestIdsBySession,
      ),
      const SizedBox(height: 14),
      FilledButton.icon(
        onPressed: () => setState(() => _screen = AppScreen.base),
        icon: const Icon(Icons.home_rounded),
        label: Text(_game.currentPetRequestId == null ? 'Вернуться на БАЗУ' : 'Заявка выбрана · на БАЗУ'),
      ),
    ]);
  }

  Widget _buildShipDetail() {
    final items = PlanningCatalog.forOwner(PlanOwner.barry);
    final mandatory = items.where((item) => item.mandatory).toList(growable: false);
    final choices = items.where((item) => !item.mandatory).toList(growable: false);
    final enabled = _game.sessionPhase == BaseSessionPhase.morning;

    return _page([
      _detailHeader('Барри + Корабль', 'КОРАБЛЬ'),
      const SizedBox(height: 10),
      const _DialogueCard(
        speaker: 'Барри',
        text: 'Командор, вот наш список. Постоянное содержание никуда не исчезает, а на сегодня выберите одну дополнительную позицию.',
      ),
      const SizedBox(height: 12),
      _PlanningChoiceTable(
        title: 'ПОСТОЯННО · 3 Дар',
        items: mandatory,
        selectedId: null,
        enabled: false,
        onSelected: (_) {},
      ),
      const SizedBox(height: 12),
      _PlanningChoiceTable(
        title: 'Выбрать одну позицию на сегодня',
        items: choices,
        selectedId: _game.currentBarryRequestId,
        enabled: enabled,
        onSelected: (id) => _selectMorningRequest(ownerId: PlanOwner.barry, itemId: id),
      ),
      const SizedBox(height: 12),
      _RequestHistoryCard(
        title: 'Заявки Барри · цикл 1–5',
        ids: _game.barryRequestIdsBySession,
      ),
      const SizedBox(height: 14),
      const _StatusCard(
        icon: Icons.local_shipping_outlined,
        title: 'Выезд технички',
        text: 'Если починить корабль не получается, можно вызвать техничку: она эвакуирует корабль на ремонтную станцию. Это завершит игру.',
        accent: Color(0xFFFFA65A),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('ship.evacuate'),
        onPressed: _confirmEvacuation,
        icon: const Icon(Icons.local_shipping_rounded),
        label: const Text('Вызвать техничку · эвакуация'),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: () => setState(() => _screen = AppScreen.base),
        icon: const Icon(Icons.home_rounded),
        label: Text(_game.currentBarryRequestId == null ? 'Вернуться на БАЗУ' : 'Заявка выбрана · на БАЗУ'),
      ),
    ]);
  }

  Widget _detailHeader(String title, String badge) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Вернуться на Базу',
          onPressed: () => setState(() => _screen = AppScreen.base),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
        _TechBadge(text: badge),
      ],
    );
  }

  Widget _buildCommanderReport() {
    final fact = _economyEngine.calculateFact(_game);
    final spent = fact.actualNeed + fact.actualWant;

    return _page([
      Row(
        children: [
          IconButton(
            tooltip: 'Вернуться на Базу',
            onPressed: () => setState(() => _screen = AppScreen.base),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Отчёт Командора',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
          ),
          _TechBadge(text: 'ПЕРИОД ${_game.period}/5'),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _ReportNumberCard(
              title: 'Заработал',
              value: '+${fact.income} Дар',
              icon: Icons.trending_up_rounded,
              accent: const Color(0xFF8DE5A1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ReportNumberCard(
              title: 'Потратил',
              value: '$spent Дар',
              icon: Icons.shopping_bag_outlined,
              accent: const Color(0xFFFFA7D1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ReportNumberCard(
              title: 'Запас',
              value: '${_game.savingsDar} Дар',
              icon: Icons.savings_outlined,
              accent: const Color(0xFFFFC85C),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'План ↔ Факт',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      _PlanFactRow(
        title: 'НАДО',
        plan: _game.planNeed,
        fact: fact.actualNeed,
        accent: const Color(0xFF8DE5A1),
      ),
      const SizedBox(height: 8),
      _PlanFactRow(
        title: 'ХОЧУ',
        plan: _game.planWant,
        fact: fact.actualWant,
        accent: const Color(0xFFFFA7D1),
      ),
      const SizedBox(height: 8),
      _PlanFactRow(
        title: 'ЗАПАС',
        plan: _game.planSave,
        fact: fact.actualSavings,
        accent: const Color(0xFFFFC85C),
      ),
      const SizedBox(height: 12),
      _StatusCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Кошелёк: ${_game.walletDar} Дар',
        text:
            'Заработал и Потратил здесь — фактические показатели из операций экономики. '
            'ЗАПАС не считается расходом.',
        accent: const Color(0xFF70D7FF),
      ),
    ]);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить тестовый профиль?'),
        content: const Text('Будут удалены никнейм, питомец, Дар и текущий прогресс на этом устройстве.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сбросить')),
        ],
      ),
    );

    if (confirmed == true) await _resetProfile();
  }

  /// Альтернативный финал: вызвать техничку и эвакуировать корабль.
  Future<void> _confirmEvacuation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Вызвать техничку?'),
        content: const Text(
          'Техничка эвакуирует корабль Барри на ремонтную станцию, и игра завершится. '
          'Продолжить ремонт самостоятельно уже не получится.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(
            key: const Key('ship.evacuate.confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Вызвать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _game.shipEvacuated = true;
      _screen = AppScreen.gameEnd;
    });
    await _save();
  }
}

class _BaseHubScene extends StatelessWidget {
  final String backgroundAsset;
  final PetType pet;
  final int petStyle;
  final int petStage;
  final bool showBazar;
  final VoidCallback onTent;
  final VoidCallback onPet;
  final VoidCallback onShip;
  final VoidCallback onBazar;
  final VoidCallback onTir;
  final VoidCallback onInfo;
  final VoidCallback onSchool;

  const _BaseHubScene({
    required this.backgroundAsset,
    required this.pet,
    required this.petStyle,
    required this.petStage,
    required this.showBazar,
    required this.onTent,
    required this.onPet,
    required this.onShip,
    required this.onBazar,
    required this.onTir,
    required this.onInfo,
    required this.onSchool,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 1.5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget hotspot({
              required Key key,
              required double left,
              required double top,
              required double width,
              required double height,
              required String label,
              required IconData icon,
              required VoidCallback onTap,
            }) {
              return Positioned(
                left: constraints.maxWidth * left,
                top: constraints.maxHeight * top,
                width: constraints.maxWidth * width,
                height: constraints.maxHeight * height,
                child: Semantics(
                  button: true,
                  label: label,
                  child: GestureDetector(
                    key: key,
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xD9142037),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFC85C).withValues(alpha: 0.80)),
                        ),
                        child: FittedBox(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 16, color: const Color(0xFFFFC85C)),
                              const SizedBox(width: 5),
                              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(backgroundAsset, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                Positioned(
                  left: constraints.maxWidth * 0.065,
                  top: constraints.maxHeight * 0.46,
                  width: constraints.maxWidth * 0.16,
                  height: constraints.maxHeight * 0.18,
                  child: IgnorePointer(
                    child: _PetStageArt(pet: pet, style: petStyle, stage: petStage, height: constraints.maxHeight * 0.18),
                  ),
                ),
                hotspot(
                  key: const Key('base.tir.hotspot'),
                  left: 0.02,
                  top: 0.02,
                  width: 0.24,
                  height: 0.16,
                  label: 'ТИР',
                  icon: Icons.track_changes_rounded,
                  onTap: onTir,
                ),
                hotspot(
                  key: const Key('base.pet.hotspot'),
                  left: 0.00,
                  top: 0.43,
                  width: 0.30,
                  height: 0.30,
                  label: 'Питомец',
                  icon: Icons.pets_rounded,
                  onTap: onPet,
                ),
                hotspot(
                  key: const Key('base.ship.hotspot'),
                  left: 0.46,
                  top: 0.25,
                  width: 0.22,
                  height: 0.36,
                  label: 'Барри',
                  icon: Icons.rocket_launch_rounded,
                  onTap: onShip,
                ),
                hotspot(
                  key: const Key('base.tent.hotspot'),
                  left: 0.66,
                  top: 0.24,
                  width: 0.28,
                  height: 0.40,
                  label: 'Палатка',
                  icon: Icons.cabin_rounded,
                  onTap: onTent,
                ),
                // Справочная: окно с Пчелой на стене в правом верхнем углу
                // (место плаката). Стоит после Палатки, чтобы в узкой зоне
                // перекрытия тап доставался окну.
                Positioned(
                  left: constraints.maxWidth * 0.845,
                  top: constraints.maxHeight * 0.02,
                  width: constraints.maxWidth * 0.14,
                  height: constraints.maxHeight * 0.23,
                  child: SpravochnayaWindow(onTap: onInfo),
                ),
                if (showBazar)
                  Positioned(
                    left: constraints.maxWidth * 0.31,
                    top: constraints.maxHeight * 0.48,
                    width: constraints.maxWidth * 0.15,
                    height: constraints.maxHeight * 0.22,
                    child: GestureDetector(
                      key: const Key('base.bazar.hotspot'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onBazar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0x4470D7FF),
                          border: Border.all(color: const Color(0xFF70D7FF), width: 2),
                          boxShadow: [BoxShadow(color: const Color(0x6670D7FF), blurRadius: 18)],
                        ),
                        child: const Center(
                          child: FittedBox(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC85C)),
                                  Text('BAZAR', style: TextStyle(fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Неоновая вывеска «Школа командиров» на краю стола — вход
                // в финансовые задания, отдельно от сюжета в Палатке.
                Positioned(
                  left: constraints.maxWidth * 0.33,
                  top: constraints.maxHeight * 0.71,
                  width: constraints.maxWidth * 0.34,
                  height: constraints.maxHeight * 0.22,
                  child: _SchoolNeonSign(onTap: onSchool),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Неоновая вывеска «Школа командиров» на сцене Базы.
/// Кроме свечения у неё есть значок и подпись — цвет не единственный
/// признак (ТЗ 3.6). Область нажатия шире и выше самой вывески, чтобы
/// ребёнку было удобно попасть пальцем (ТЗ 3.6, рекомендация 48 dp).
class _SchoolNeonSign extends StatelessWidget {
  final VoidCallback onTap;

  const _SchoolNeonSign({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF00E5FF);
    const neonPink = Color(0xFFFF4FD8);
    return Semantics(
      button: true,
      label: CommanderSchool.title,
      child: GestureDetector(
        key: const Key('base.school.hotspot'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: FractionallySizedBox(
            heightFactor: 0.6,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xCC0B1024),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neonPink, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FF4FD8), blurRadius: 14, spreadRadius: 1),
                  BoxShadow(color: Color(0x6600E5FF), blurRadius: 24),
                ],
              ),
              child: const FittedBox(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.school_rounded, color: neon, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'ШКОЛА КОМАНДИРОВ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFFE9FDFF),
                        shadows: [
                          Shadow(color: neon, blurRadius: 8),
                          Shadow(color: neon, blurRadius: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MorningRoundStatus extends StatelessWidget {
  final bool petDone;
  final bool barryDone;
  final bool councilReady;

  const _MorningRoundStatus({required this.petDone, required this.barryDone, required this.councilReady});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: councilReady ? const Color(0xFF8DE5A1) : const Color(0xFF41577C)),
      ),
      child: Row(
        children: [
          Icon(petDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: petDone ? const Color(0xFF8DE5A1) : const Color(0xFFB8C7E3)),
          const SizedBox(width: 6),
          const Text('Питомец'),
          const SizedBox(width: 14),
          Icon(barryDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: barryDone ? const Color(0xFF8DE5A1) : const Color(0xFFB8C7E3)),
          const SizedBox(width: 6),
          const Text('Барри'),
          const Spacer(),
          Text(councilReady ? 'Совещание готово' : 'Обход не завершён', style: TextStyle(fontWeight: FontWeight.w900, color: councilReady ? const Color(0xFF8DE5A1) : const Color(0xFFFFC85C))),
        ],
      ),
    );
  }
}

class _CouncilChoiceCard extends StatelessWidget {
  final String title;
  final PlanningItemDefinition? item;
  final String missingText;

  const _CouncilChoiceCard({required this.title, required this.item, required this.missingText});

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      icon: item == null ? Icons.pending_outlined : Icons.check_circle_outline_rounded,
      title: title,
      text: item == null ? missingText : '${item!.title} · ${item!.cost} Дар · ${_planCategoryLabel(item!.category)}',
      accent: item == null ? const Color(0xFFFFC85C) : const Color(0xFF8DE5A1),
    );
  }
}

class _PlanningChoiceTable extends StatelessWidget {
  final String title;
  final List<PlanningItemDefinition> items;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onSelected;

  const _PlanningChoiceTable({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF41577C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          const Divider(height: 1),
          ...items.map((item) {
            final selected = selectedId == item.id;
            return InkWell(
              onTap: enabled ? () => onSelected(item.id) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (enabled)
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: selected ? const Color(0xFFFFC85C) : const Color(0xFFB8C7E3),
                      )
                    else
                      Icon(item.mandatory ? Icons.push_pin_rounded : Icons.circle_outlined, size: 20, color: item.mandatory ? const Color(0xFF8DE5A1) : const Color(0xFFB8C7E3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? const Color(0xFFFFC85C) : null)),
                          const SizedBox(height: 2),
                          Text('${_planCategoryLabel(item.category)}${item.mandatory ? ' · ПОСТОЯННО' : ''}', style: const TextStyle(fontSize: 12, color: Color(0xFFB8C7E3))),
                          Text(_purchaseEffectText(ownerId: item.ownerId, category: item.category), style: const TextStyle(fontSize: 12, color: Color(0xFF8DE5A1))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.cost} Дар', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RequestHistoryCard extends StatelessWidget {
  final String title;
  final List<String> ids;

  const _RequestHistoryCard({required this.title, required this.ids});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF41577C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('День ${i + 1}: ${i < ids.length && ids[i].isNotEmpty ? (PlanningCatalog.byId(ids[i])?.title ?? ids[i]) : '—'}'),
            ),
        ],
      ),
    );
  }
}

/// Предполагаемое влияние покупки на питомца и команду — показывается
/// до покупки (ТЗ 2.5.6). Совпадает с правилами роста в pet_growth.dart:
/// обязательное → забота, выполненный План → энергия, накопления → настроение.
String _purchaseEffectText({required String ownerId, required String category}) {
  if (category == PlanCategory.planned) {
    return 'Большая цель · сегодня не списывается';
  }
  if (ownerId == PlanOwner.pet) {
    return category == PlanCategory.need
        ? 'Питомцу: забота ↑ (обязательное)'
        : 'Питомцу: радость · выполненный План даёт энергию ↑';
  }
  if (ownerId == PlanOwner.barry) {
    return category == PlanCategory.need
        ? 'Команде: Барри сыт — забота питомца ↑ (обязательное)'
        : 'Команде: радость Барри · выполненный План даёт энергию ↑';
  }
  return 'Команде: помогает Базе';
}

String _planCategoryLabel(String category) {
  return switch (category) {
    PlanCategory.need => 'НАДО',
    PlanCategory.want => 'ХОЧУ',
    PlanCategory.planned => 'ПЛАНИРУЮ',
    _ => category.toUpperCase(),
  };
}

class _BaseAdviceStrip extends StatelessWidget {
  const _BaseAdviceStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF41577C)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 52,
            height: 52,
            child: _CharacterArt(
              asset: 'assets/characters/sverchok.png',
              height: 52,
              fallback: '🦗',
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF24324E),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF9B8CFF)),
            ),
            child: const Text('✨', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Сверчок и Ия рядом. Если Командор запутается, здесь будут короткие подсказки без вмешательства в его решения.',
              style: TextStyle(fontSize: 13.5, height: 1.35, color: Color(0xFFC5D0E4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportNumberCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _ReportNumberCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.60)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(height: 7),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB8C7E3)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent),
          ),
        ],
      ),
    );
  }
}

class _PlanFactRow extends StatelessWidget {
  final String title;
  final int plan;
  final int fact;
  final Color accent;

  const _PlanFactRow({
    required this.title,
    required this.plan,
    required this.fact,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          ),
          Text('План $plan', style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: Icon(Icons.compare_arrows_rounded, size: 19, color: Color(0xFFB8C7E3)),
          ),
          Text('Факт $fact', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EveningSaveControl extends StatelessWidget {
  final int amount;
  final int maxAmount;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _EveningSaveControl({
    required this.amount,
    required this.maxAmount,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB68CFF).withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            key: const Key('session.evening.save_minus'),
            onPressed: amount > 0 ? onDecrease : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$amount Дар',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  maxAmount > 0 ? 'из $maxAmount доступных' : 'нечего откладывать',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFFAEBBD1)),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const Key('session.evening.save_plus'),
            onPressed: amount < maxAmount ? onIncrease : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _ShipRepairEveningCard extends StatelessWidget {
  final String title;
  final int unitCost;
  final int unitsPaid;
  final int totalUnits;
  final int unitsToBuy;
  final int maxUnitsToBuy;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _ShipRepairEveningCard({
    required this.title,
    required this.unitCost,
    required this.unitsPaid,
    required this.totalUnits,
    required this.unitsToBuy,
    required this.maxUnitsToBuy,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final willCloseToday = unitsToBuy > 0 && unitsPaid + unitsToBuy >= totalUnits;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Куплено $unitsPaid из $totalUnits шт · цена $unitCost Дар/шт',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB8C7E3)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: unitsToBuy > 0 ? onDecrease : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$unitsToBuy шт сегодня',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      maxUnitsToBuy > 0 ? 'максимум $maxUnitsToBuy шт сейчас' : 'сейчас не хватает Дар',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFAEBBD1)),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: unitsToBuy < maxUnitsToBuy ? onIncrease : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (willCloseToday) ...[
            const SizedBox(height: 6),
            const Text(
              'Эта позиция будет закрыта!',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF8DE5A1)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemRibbon extends StatelessWidget {
  const _SystemRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xB8142037),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.28)),
      ),
      child: const Row(
        children: [
          Icon(Icons.blur_on_rounded, size: 15, color: Color(0xFF70D7FF)),
          SizedBox(width: 7),
          Text('12 DAR // BASE NETWORK', style: TextStyle(fontSize: 10.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: Color(0xFFB8C7E3))),
          Spacer(),
          Text('LOCAL', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF8DE5A1))),
        ],
      ),
    );
  }
}

class _TechBackground extends StatelessWidget {
  const _TechBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10172A), Color(0xFF131D33), Color(0xFF0E1628)],
          ),
        ),
        child: CustomPaint(painter: _CircuitPainter()),
      ),
    );
  }
}

class _CircuitPainter extends CustomPainter {
  const _CircuitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF70D7FF).withValues(alpha: 0.055)
      ..strokeWidth = 1;
    final nodePaint = Paint()
      ..color = const Color(0xFFFFC85C).withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    const gap = 72.0;
    for (double y = 28; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    for (double x = 28; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 28; y < size.height; y += gap * 2) {
      for (double x = 28; x < size.width; x += gap * 2) {
        canvas.drawCircle(Offset(x, y), 2.2, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TechBadge extends StatelessWidget {
  final String text;

  const _TechBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC17243D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.45)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10.5, letterSpacing: 0.5, fontWeight: FontWeight.w800, color: Color(0xFFBDEEFF))),
    );
  }
}

class _CrewPresenceCard extends StatelessWidget {
  final String icon;
  final String name;
  final String place;

  const _CrewPresenceCard({required this.icon, required this.name, required this.place});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3B5074)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 27)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(place, style: const TextStyle(fontSize: 11.5, color: Color(0xFFB8C7E3))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 166,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF19243D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF3A4E70)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF70D7FF), size: 24),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFFB8C7E3))),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('✨', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Принц с Барамота', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          SizedBox(height: 16),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _ScreenNumber extends StatelessWidget {
  final String number;
  final String title;

  const _ScreenNumber({required this.number, required this.title});

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
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFFC85C), shape: BoxShape.circle),
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Text(number, style: const TextStyle(color: Color(0xFF1B2743), fontSize: 22, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Экран №$number · $title', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _CharacterArt extends StatelessWidget {
  final String? asset;
  final double height;
  final String fallback;

  const _CharacterArt({required this.asset, required this.height, required this.fallback});

  @override
  Widget build(BuildContext context) {
    if (asset == null) {
      return SizedBox(height: height, child: Center(child: Text(fallback, style: TextStyle(fontSize: height * 0.42))));
    }
    return SizedBox(
      height: height,
      child: Image.asset(
        asset!,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Center(child: Text(fallback, style: TextStyle(fontSize: height * 0.42))),
      ),
    );
  }
}

class _DialogueCard extends StatelessWidget {
  final String speaker;
  final String text;

  const _DialogueCard({required this.speaker, required this.text});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$speaker говорит: $text',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2743),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334564)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(speaker, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFFC85C))),
            const SizedBox(height: 8),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color accent;

  const _StatusCard({super.key, required this.icon, required this.title, required this.text, required this.accent});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xFFC5D0E4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetChoiceCard extends StatelessWidget {
  final PetType pet;
  final bool selected;
  final String description;
  final VoidCallback onTap;

  const _PetChoiceCard({required this.pet, required this.selected, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${pet.title}. $description',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF293A5B) : const Color(0xFF19243D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: selected ? const Color(0xFFFFC85C) : const Color(0xFF30415F), width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              SizedBox(width: 116, height: 116, child: _CharacterArt(asset: pet.assetPath, height: 116, fallback: pet.emoji)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(description, style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xFFC5D0E4))),
                  ],
                ),
              ),
              Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? const Color(0xFFFFC85C) : const Color(0xFF8190AA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseTopBar extends StatelessWidget {
  final int walletDar;
  final int savingsDar;
  final String goalText;
  final VoidCallback onReset;
  final VoidCallback onExit;

  const _BaseTopBar({required this.walletDar, required this.savingsDar, required this.goalText, required this.onReset, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(color: Color(0xFF151F35), border: Border(bottom: BorderSide(color: Color(0xFF283653)))),
      child: Row(
        children: [
          Expanded(child: _EconomyPill(icon: Icons.wallet_rounded, text: '$walletDar Дар')),
          const SizedBox(width: 6),
          Expanded(child: _EconomyPill(icon: Icons.savings_rounded, text: '$savingsDar Дар')),
          const SizedBox(width: 6),
          Expanded(child: _EconomyPill(icon: Icons.build_rounded, text: goalText)),
          IconButton(
            tooltip: 'Сбросить тестовый профиль',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFFFC85C)),
          ),
          IconButton(
            key: const Key('base.exit'),
            tooltip: 'Выход на титульный экран',
            onPressed: onExit,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF70D7FF)),
          ),
        ],
      ),
    );
  }
}

/// Арт питомца: выбранный образ ([PetLooks]) + сияние и значок стадии роста.
/// Защита от отсутствующего файла: образ → базовый арт питомца → эмодзи.
class _PetStageArt extends StatelessWidget {
  final PetType pet;
  final int style;
  final int stage;
  final double height;

  const _PetStageArt({required this.pet, required this.style, required this.stage, required this.height});

  @override
  Widget build(BuildContext context) {
    final look = PetLooks.of(pet, style);
    final clampedStage = stage.clamp(0, PetGrowthCatalog.maxStage).toInt();
    final base = _CharacterArt(asset: pet.assetPath, height: height, fallback: pet.emoji);
    final glow = clampedStage == 0
        ? null
        : clampedStage == 1
            ? const Color(0xFFBFD7FF)
            : const Color(0xFFFFD66B);

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (glow != null)
            Container(
              width: height * 0.7,
              height: height * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glow.withValues(alpha: clampedStage == 1 ? 0.35 : 0.5),
                    blurRadius: height * 0.25,
                    spreadRadius: height * 0.04,
                  ),
                ],
              ),
            ),
          Semantics(
            label: '${pet.title}, образ «${look.title}», ${PetGrowthCatalog.stageTitle(clampedStage)}',
            child: Image.asset(
              look.asset,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => base,
            ),
          ),
          if (clampedStage > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                clampedStage == 1 ? '⭐' : '🌟',
                style: TextStyle(fontSize: (height * 0.14).clamp(12.0, 34.0).toDouble()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Выбор образа питомца: 3 карточки с картинкой и названием.
class _PetLookPicker extends StatelessWidget {
  final PetType pet;
  final int selected;
  final ValueChanged<int> onSelected;

  const _PetLookPicker({required this.pet, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final looks = PetLooks.forPet(pet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Образ питомца', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < looks.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _LookCard(
                  look: looks[i],
                  selected: i == selected.clamp(0, looks.length - 1),
                  onTap: () => onSelected(i),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LookCard extends StatelessWidget {
  final PetLook look;
  final bool selected;
  final VoidCallback onTap;

  const _LookCard({required this.look, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = selected ? const Color(0xFFFFC85C) : const Color(0xFF30415F);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Образ «${look.title}»',
      child: Material(
        color: selected ? const Color(0xFF293A5B) : const Color(0xFF19243D),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('pet.look.${look.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent, width: selected ? 2 : 1),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 78,
                  child: Image.asset(
                    look.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(child: Text('🐾', style: TextStyle(fontSize: 30))),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (selected) const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFFFC85C)),
                    if (selected) const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        look.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка роста питомца: стадия, очки, короткие показатели.
class _PetGrowthStatusCard extends StatelessWidget {
  final PetState state;

  const _PetGrowthStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final toNext = PetGrowthCatalog.pointsToNextStage(state.growthPoints);
    return Container(
      key: const Key('pet.growth.card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8DE5A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8DE5A1).withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: Color(0xFF8DE5A1), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  PetGrowthCatalog.stageTitle(state.growthStage),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            toNext == null
                ? 'Очки роста: ${state.growthPoints}. Питомец достиг высшей стадии!'
                : 'Очки роста: ${state.growthPoints}. До следующей стадии: $toNext.',
            style: const TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xFFC5D0E4)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PetMeterChip(label: 'Забота', value: state.care),
              _PetMeterChip(label: 'Настроение', value: state.mood),
              _PetMeterChip(label: 'Энергия', value: state.energy),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Растёт, когда Вы оплачиваете обязательное, выполняете утренний План и откладываете в накопления.',
            style: TextStyle(fontSize: 12.5, height: 1.3, color: Color(0xFF9FB0CC)),
          ),
        ],
      ),
    );
  }
}

class _PetMeterChip extends StatelessWidget {
  final String label;
  final int value;

  const _PetMeterChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0
        ? const Color(0xFF8DE5A1)
        : value < 0
            ? const Color(0xFFFF9A8E)
            : const Color(0xFFB8C7E3);
    final sign = value > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$label $sign$value',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _EconomyPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EconomyPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF24324E), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFFFC85C)),
          const SizedBox(width: 5),
          Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}

class _ChestCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _ChestCard({required this.title, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF292118),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.75), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_rounded, color: accent, size: 27),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
    );
  }
}

class _BirdAmbience extends StatefulWidget {
  const _BirdAmbience();

  @override
  State<_BirdAmbience> createState() => _BirdAmbienceState();
}

class _BirdAmbienceState extends State<_BirdAmbience> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    // Взрослый отключил звуки — атмосферный фон не запускаем.
    if (!AppSettings.instance.soundEnabled) return;
    try {
      final controller = VideoPlayerController.asset('assets/videos/base_birds.wav');
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.32);
      await controller.play();
    } catch (_) {
      // Атмосферный звук необязателен для игрового состояния.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PrologueVideo extends StatefulWidget {
  final String assetPath;
  final String skipLabel;
  final VoidCallback onFinished;

  const _PrologueVideo({
    required this.assetPath,
    required this.skipLabel,
    required this.onFinished,
  });

  @override
  State<_PrologueVideo> createState() => _PrologueVideoState();
}

class _PrologueVideoState extends State<_PrologueVideo> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _controller.addListener(_watchPlayback);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(AppSettings.instance.soundEnabled ? 1.0 : 0.0);
      if (!mounted) return;
      setState(() => _ready = true);
      await _controller.play();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _watchPlayback() {
    if (_finished || !_controller.value.isInitialized) return;

    final duration = _controller.value.duration;
    final position = _controller.value.position;
    if (duration == Duration.zero) return;

    if (position >= duration - const Duration(milliseconds: 180)) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_watchPlayback);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        children: [
          const _StatusCard(
            icon: Icons.error_outline_rounded,
            title: 'Видео не запустилось',
            text: 'Можно продолжить знакомство, даже если ролик не запустился.',
            accent: Color(0xFFFF8A80),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.skip_next_rounded),
            label: const Text('Продолжить'),
          ),
        ],
      );
    }

    if (!_ready) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
        const SizedBox(height: 10),
        VideoProgressIndicator(
          _controller,
          allowScrubbing: false,
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _finish,
          icon: const Icon(Icons.skip_next_rounded),
          label: Text(widget.skipLabel),
        ),
      ],
    );
  }
}

/// «Активное задание» на главном экране (ТЗ 2.5.3): видно без навигации.
class _ActiveTaskCard extends StatelessWidget {
  final FinanceTask? task;
  final int done;
  final int total;
  final ValueChanged<FinanceTask?> onOpen;

  const _ActiveTaskCard({required this.task, required this.done, required this.total, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final current = task;
    return Material(
      color: const Color(0xFF19243D),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('base.active_task'),
        onTap: () => onOpen(current),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFB68CFF).withValues(alpha: 0.75)),
          ),
          child: Row(
            children: [
              const Text('🎓', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current == null
                          ? '${CommanderSchool.title}: все задания пройдены!'
                          : '${CommanderSchool.title}: «${current.title}»',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      current == null
                          ? '${CommanderSchool.statusLine(done)}. Любое задание можно пройти ещё раз.'
                          : '${current.topic.title} · до +${FinanceContent.rewardBest} Дар · пройдено $done из $total',
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFFB8C7E3)),
                    ),
                    if (current != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        CommanderSchool.statusLine(done),
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFF7FEFFF), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF93A3BE)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _BudgetLine({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF70D7FF)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text('$value Дар', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
