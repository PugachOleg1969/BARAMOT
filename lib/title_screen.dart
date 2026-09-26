import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legal_texts.dart';

/// Хранит отметку «взрослый ознакомился с документами». Лежит отдельно от
/// игрового прогресса, поэтому «Начать заново» её не стирает: повторно
/// подтверждать нужно только при смене [LegalInfo.documentsVersion].
class LegalConsentStore {
  static const String _key = 'baramot.legal.accepted_version';

  final SharedPreferencesAsync _prefs;

  LegalConsentStore({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  Future<bool> isAccepted() async {
    try {
      final version = await _prefs.getInt(_key);
      return version != null && version >= LegalInfo.documentsVersion;
    } catch (_) {
      return false;
    }
  }

  Future<void> accept() async {
    try {
      await _prefs.setInt(_key, LegalInfo.documentsVersion);
    } catch (_) {
      // Не удалось сохранить — при следующем запуске просто спросим снова.
    }
  }
}

/// Титульный экран: название, описание, возрастная маркировка, документы
/// и согласие взрослого при первом запуске.
class TitleScreen extends StatefulWidget {
  final bool hasProgress;
  final String playerName;
  final VoidCallback onPlay;
  final VoidCallback onNewGame;
  final LegalConsentStore? consentStore;

  const TitleScreen({
    super.key,
    required this.hasProgress,
    required this.playerName,
    required this.onPlay,
    required this.onNewGame,
    this.consentStore,
  });

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  late final LegalConsentStore _store;
  bool _checking = true;
  bool _alreadyAccepted = false;
  bool _checkboxValue = false;

  @override
  void initState() {
    super.initState();
    _store = widget.consentStore ?? LegalConsentStore();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final accepted = await _store.isAccepted();
    if (!mounted) return;
    setState(() {
      _alreadyAccepted = accepted;
      _checkboxValue = accepted;
      _checking = false;
    });
  }

  bool get _canPlay => _alreadyAccepted || _checkboxValue;

  Future<void> _handle(VoidCallback action) async {
    if (!_canPlay) return;
    if (!_alreadyAccepted) {
      await _store.accept();
      if (!mounted) return;
      setState(() => _alreadyAccepted = true);
    }
    action();
  }

  void _openDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.playerName.trim();
    final continueLabel = name.isEmpty ? 'Продолжить' : 'Продолжить, $name';

    return Stack(
      children: [
        const Positioned.fill(child: _TitleBackground()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Hero(),
                    const SizedBox(height: 18),
                    const _FeatureRow(),
                    const SizedBox(height: 14),
                    _GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Командор, команде нужна Ваша помощь!',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Корабль Барри сломался у Базы. Составляйте План, '
                            'зарабатывайте Дар на BAZAR, заботьтесь о Питомце, '
                            'копите — и помогите друзьям вернуться домой.',
                            style: TextStyle(fontSize: 15, height: 1.4, color: Color(0xFFC5D0E4)),
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            key: const Key('title.about'),
                            onPressed: () => _openDocument(LegalTexts.about),
                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                            label: const Text('Подробнее об игре'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_checking)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      if (!_alreadyAccepted)
                        _ConsentCard(
                          value: _checkboxValue,
                          onChanged: (value) => setState(() => _checkboxValue = value),
                          onOpenTerms: () => _openDocument(LegalTexts.terms),
                          onOpenPrivacy: () => _openDocument(LegalTexts.privacy),
                        ),
                      if (!_alreadyAccepted) const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('title.play'),
                        onPressed: _canPlay ? () => _handle(widget.onPlay) : null,
                        icon: Icon(widget.hasProgress
                            ? Icons.play_arrow_rounded
                            : Icons.rocket_launch_rounded),
                        label: Text(
                          widget.hasProgress ? continueLabel : 'Начать игру',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.hasProgress) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('title.new_game'),
                          onPressed: _canPlay ? () => _handle(widget.onNewGame) : null,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Новая игра'),
                        ),
                      ],
                      if (!_canPlay) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Чтобы начать, взрослому нужно отметить согласие выше.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFFFFC85C)),
                        ),
                      ],
                    ],
                    const SizedBox(height: 22),
                    _Footer(onOpen: _openDocument),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TitleBackground extends StatelessWidget {
  const _TitleBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/scenes/base_morning.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x9910172A), Color(0xE610172A), Color(0xFF10172A)],
              stops: [0.0, 0.45, 0.8],
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              label: 'Возрастная категория ${LegalInfo.ageRating}',
              child: Container(
                key: const Key('title.age_rating'),
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xCC10172A),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Text(
                  LegalInfo.ageRating,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text('✨ 🚀 ✨', style: TextStyle(fontSize: 30)),
        const SizedBox(height: 10),
        const Text(
          'ПРИНЦ С БАРАМОТА',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Color(0xFFFFC85C),
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 16)],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Игра о планировании и финансовой грамотности',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE6EEFF),
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _FeatureChip(icon: Icons.block_rounded, text: 'Без рекламы'),
        _FeatureChip(icon: Icons.money_off_rounded, text: 'Без покупок'),
        _FeatureChip(icon: Icons.wifi_off_rounded, text: 'Без интернета'),
        _FeatureChip(icon: Icons.phone_android_rounded, text: 'Данные только на устройстве'),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC17243D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF70D7FF).withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF8DE5A1)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xE61B2743),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334564)),
      ),
      child: child,
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  const _ConsentCard({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0x1AFFC85C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC85C).withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 4),
            child: Row(
              children: [
                Icon(Icons.family_restroom_rounded, color: Color(0xFFFFC85C), size: 20),
                SizedBox(width: 8),
                Text(
                  'Для взрослого · первый запуск',
                  style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFFC85C)),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: const Key('title.consent'),
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(!value),
                  child: const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Я — родитель (законный представитель) ребёнка. Я ознакомился '
                      'с Пользовательским соглашением и Политикой конфиденциальности '
                      'и принимаю их.',
                      style: TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: onOpenTerms,
                  child: const Text('Соглашение'),
                ),
                TextButton(
                  onPressed: onOpenPrivacy,
                  child: const Text('Политика конфиденциальности'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final ValueChanged<LegalDocument> onOpen;

  const _Footer({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(fontSize: 12.5, decoration: TextDecoration.underline);
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              key: const Key('title.doc.privacy'),
              onPressed: () => onOpen(LegalTexts.privacy),
              child: const Text('Политика конфиденциальности', style: linkStyle),
            ),
            TextButton(
              key: const Key('title.doc.terms'),
              onPressed: () => onOpen(LegalTexts.terms),
              child: const Text('Пользовательское соглашение', style: linkStyle),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '${LegalInfo.appName} · версия ${LegalInfo.appVersion} · ${LegalInfo.ageRating}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF8C9BB8)),
        ),
        const SizedBox(height: 2),
        const Text(
          '© ${LegalInfo.rightsHolder}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF8C9BB8)),
        ),
      ],
    );
  }
}

/// Экран чтения документа.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        backgroundColor: const Color(0xFF151F35),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          children: [
            for (final section in document.sections) ...[
              Text(
                section.heading,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFFC85C)),
              ),
              const SizedBox(height: 6),
              Text(
                section.body,
                style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFFD3DDF0)),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
    );
  }
}
