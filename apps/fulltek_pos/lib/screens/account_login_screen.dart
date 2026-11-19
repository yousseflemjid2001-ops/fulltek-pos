import 'package:flutter/material.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';

/// Step 1 — Restaurant SaaS account login (reached from the landing page
/// « Se connecter » → Full·Tek Resto). Step 2 is the staff PIN pad.
class AccountLoginScreen extends StatefulWidget {
  final PosStore store;
  const AccountLoginScreen({super.key, required this.store});

  @override
  State<AccountLoginScreen> createState() => _AccountLoginScreenState();
}

class _AccountLoginScreenState extends State<AccountLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.store.loginAccount(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  void _fillDemo() {
    _userCtrl.text = 'darelkram41';
    _passCtrl.text = 'FullTek@2026';
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);

    return Scaffold(
      body: Container(
        decoration: _bgDecoration(store, p),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: const FullTekLogo(size: 52, variant: 'Resto')),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(p.radius + 6),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.t('account_title'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            i18n.t('account_hint'),
                            style: TextStyle(fontSize: 13, color: p.textMuted),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            key: const Key('account_user_input'),
                            controller: _userCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: i18n.t('account_user'),
                              prefixIcon: const Icon(Icons.storefront_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('account_pass_input'),
                            controller: _passCtrl,
                            obscureText: _obscure,
                            onSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: i18n.t('account_pass'),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: p.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: p.danger.withValues(alpha: 0.45)),
                              ),
                              child: Text(
                                _error!,
                                key: const Key('account_error'),
                                style: TextStyle(
                                    color: p.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            key: const Key('account_login_btn'),
                            onPressed: _busy ? null : _submit,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(i18n.t('account_login')),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('account_demo_btn'),
                            onPressed: _fillDemo,
                            icon: const Icon(Icons.auto_fix_high_rounded,
                                size: 18),
                            label: Text(i18n.t('account_demo')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: ['fr', 'ar', 'en'].map((code) {
                        final selected = store.lang == code;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            key: Key('account_lang_$code'),
                            label: Text(code.toUpperCase()),
                            selected: selected,
                            onSelected: (_) => store.setLanguage(code),
                          ),
                        );
                      }).toList(),
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

BoxDecoration _bgDecoration(PosStore store, PosPalette p) {
  final g = store.themeSpec.bgGradient;
  if (g != null) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: g,
      ),
    );
  }
  return BoxDecoration(color: p.bg);
}
