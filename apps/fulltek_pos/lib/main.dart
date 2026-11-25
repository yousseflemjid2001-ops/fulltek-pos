import 'package:flutter/material.dart';
import 'screens/account_login_screen.dart';
import 'screens/pin_login_screen.dart';
import 'screens/pos_shell_screen.dart';
import 'state/pos_store.dart';
import 'widgets/touch_keyboard.dart';

void main() {
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
            Widget root = Directionality(
              textDirection: i18n.direction,
              child: TouchKeyboardHost(child: content),
            );
            final z = _store.uiZoom;
            if ((z - 1.0).abs() > 0.001) {
              root = LayoutBuilder(
                builder: (ctx, constraints) => OverflowBox(
                  minWidth: constraints.maxWidth / z,
                  maxWidth: constraints.maxWidth / z,
                  minHeight: constraints.maxHeight / z,
                  maxHeight: constraints.maxHeight / z,
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: z,
                    alignment: Alignment.center,
                    child: root,
                  ),
                ),
              );
            }
            return root;
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
