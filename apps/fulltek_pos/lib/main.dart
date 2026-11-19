import 'package:flutter/material.dart';
import 'screens/pin_login_screen.dart';
import 'screens/pos_shell_screen.dart';
import 'state/pos_store.dart';

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
            return Directionality(
              textDirection: i18n.direction,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _store.currentStaff == null
              ? PinLoginScreen(store: _store)
              : PosShellScreen(store: _store),
        );
      },
    );
  }
}
