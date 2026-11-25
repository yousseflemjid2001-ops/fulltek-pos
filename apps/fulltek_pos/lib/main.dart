import 'package:flutter/material.dart';
import 'screens/account_login_screen.dart';
import 'screens/pin_login_screen.dart';
import 'screens/pos_shell_screen.dart';
import 'state/pos_store.dart';
import 'widgets/touch_keyboard.dart';

void main() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF0B1220),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Erreur d\'affichage Full·Tek Resto',
                    style: TextStyle(
                      color: Color(0xFFF87171),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${details.exception}',
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };
  runApp(const FullTekPosApp());
}

class FullTekPosApp extends StatefulWidget {
  final PosStore? store;
  const FullTekPosApp({super.key, this.store});

  @override
  State<FullTekPosApp> createState() => _FullTekPosAppState();
}

class _FullTekPosAppState extends State<FullTekPosApp> {
  late final PosStore _store;
  late final bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store = widget.store ?? PosStore();
  }

  @override
  void dispose() {
    if (_ownsStore) {
      _store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final i18n = _store.i18n;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: i18n.t('app_title'),
          theme: _store.themeSpec.toThemeData(),
          builder: (context, child) {
            final g = _store.themeSpec.bgGradient;
            Widget content = child ?? const SizedBox.shrink();
            if (g != null) {
              content = DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: g,
                  ),
                ),
                child: content,
              );
            }
            final mq = MediaQuery.of(context);
            final z = _store.uiZoom.clamp(0.80, 1.30);
            final hasFiniteSize = mq.size.width.isFinite &&
                mq.size.height.isFinite &&
                mq.size.width > 0 &&
                mq.size.height > 0;
            final scaledSize = hasFiniteSize
                ? Size(mq.size.width / z, mq.size.height / z)
                : mq.size;

            return MediaQuery(
              data: mq.copyWith(
                size: scaledSize,
                devicePixelRatio: mq.devicePixelRatio * z,
              ),
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: scaledSize.width,
                  height: scaledSize.height,
                  child: Directionality(
                    textDirection: i18n.direction,
                    child: TouchKeyboardHost(child: content),
                  ),
                ),
              ),
            );
          },
          home: !_store.accountLoggedIn
              ? AccountLoginScreen(store: _store)
              : (_store.currentStaff == null
                  ? PinLoginScreen(store: _store)
                  : PosShellScreen(store: _store)),
        );
      },
    );
  }
}
