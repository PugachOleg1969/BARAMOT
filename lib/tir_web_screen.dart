import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_settings.dart';

/// Экран мини-игры «Весёлый тир».
///
/// Сама игра — самодостаточная HTML5-страница (Canvas + Web Audio) в
/// assets/tir/vesely-tir.html. Здесь она показывается во встроенном WebView.
///
/// Безопасность для детского приложения:
/// - страница грузится только из ассетов приложения, интернет не нужен;
/// - любые переходы на внешние адреса блокируются [NavigationDelegate];
/// - экономика игры (Дар) не затрагивается: тир — чисто развлекательный режим.
///
/// Ориентация: игра рассчитана на холст 3:2, поэтому на время тира экран
/// поворачивается в альбомную ориентацию, а при выходе возвращается в
/// портретную — остальная игра свёрстана вертикально.
class TirWebScreen extends StatefulWidget {
  final VoidCallback onExit;

  const TirWebScreen({super.key, required this.onExit});

  static const String assetPath = 'assets/tir/vesely-tir.html';

  @override
  State<TirWebScreen> createState() => _TirWebScreenState();
}

class _TirWebScreenState extends State<TirWebScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  static const List<DeviceOrientation> _landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static const List<DeviceOrientation> _portrait = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(_landscape);
    // Полноэкранный режим: прячем строку состояния и навигацию, чтобы
    // игре досталась вся высота. Свайп от края временно их показывает.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1B2C57))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // Взрослый отключил звуки — глушим звуки игры до первого выстрела.
            if (!AppSettings.instance.soundEnabled) {
              _controller.runJavaScript('window.BARAMOT_MUTED = true;');
            }
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Ошибка вспомогательного ресурса не должна ломать игру —
            // показываем сообщение только если не загрузилась сама страница.
            if (error.isForMainFrame != true) return;
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
          onNavigationRequest: (request) {
            final url = request.url;
            final isLocal = url.startsWith('file://') ||
                url.startsWith('about:') ||
                url.startsWith('data:');
            return isLocal
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset(TirWebScreen.assetPath);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(_portrait);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onExit();
      },
      child: ColoredBox(
        color: const Color(0xFF1B2C57),
        child: Stack(
          children: [
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),
            // Кнопка «назад» поверх игры — в альбомной ориентации каждая
            // точка высоты на счету, поэтому отдельной шапки нет.
            Positioned(
              left: 6,
              top: 6,
              child: Material(
                color: const Color(0xAA0B1424),
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('tir.back'),
                  tooltip: 'Вернуться на Базу',
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xFF1B2C57),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: _TirErrorView(
                  details: _error!,
                  onExit: widget.onExit,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TirErrorView extends StatelessWidget {
  final String details;
  final VoidCallback onExit;

  const _TirErrorView({required this.details, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1B2C57),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 10),
              const Text(
                'Тир сейчас не открылся',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                details,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA9B6E6)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('На Базу'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
