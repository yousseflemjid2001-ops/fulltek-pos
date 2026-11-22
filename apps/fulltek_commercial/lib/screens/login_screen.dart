import 'package:flutter/material.dart';
import '../state/commercial_store.dart';
import '../theme/commercial_theme.dart';
import '../widgets/fulltek_logo.dart';

class CommercialLoginScreen extends StatefulWidget {
  final CommercialStore store;
  const CommercialLoginScreen({super.key, required this.store});

  @override
  State<CommercialLoginScreen> createState() => _CommercialLoginScreenState();
}

class _CommercialLoginScreenState extends State<CommercialLoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await widget.store.loginAccount(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommercialColors.sidebarBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        FullTekCommercialMark(size: 46, darkBg: true),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Full·Tek Commercial',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: CommercialColors.textPrimary,
                                ),
                              ),
                              Text(
                                'COMMERCIAL · Gestion en un clic · MRU',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: CommercialColors.brandViolet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CommercialColors.dangerRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CommercialColors.dangerRed),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: CommercialColors.dangerRed, fontSize: 12.5),
                        ),
                      ),
                    TextField(
                      key: const Key('commercial_login_user'),
                      controller: _userCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant entreprise',
                        prefixIcon: Icon(Icons.business_outlined, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('commercial_login_pass'),
                      controller: _passCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      key: const Key('commercial_login_submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CommercialColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Se connecter',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('commercial_demo_btn'),
                      onPressed: _loading ? null : widget.store.enterOfflineDemo,
                      icon: const Icon(Icons.play_circle_outline_rounded,
                          size: 18),
                      label: const Text('Accès Démo Locale (sans serveur)'),
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
