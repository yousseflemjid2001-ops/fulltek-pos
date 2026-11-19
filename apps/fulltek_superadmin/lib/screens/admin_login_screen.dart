import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminLoginScreen extends StatefulWidget {
  final String lang;
  final String Function(String) tr;
  final ValueChanged<String> onLangChanged;
  final void Function(String token, AdminProfile admin) onAuthenticated;
  final String? initialNotice;

  const AdminLoginScreen({
    super.key,
    required this.lang,
    required this.tr,
    required this.onLangChanged,
    required this.onAuthenticated,
    this.initialNotice,
  });

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.initialNotice;
  }

  @override
  void didUpdateWidget(covariant AdminLoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNotice != oldWidget.initialNotice &&
        widget.initialNotice != null &&
        widget.initialNotice!.isNotEmpty) {
      _error = widget.initialNotice;
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = widget.tr('auth_err_empty'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.loginSuperAdmin(username, password);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      setState(() => _loading = false);
      widget.onAuthenticated(res.data!.token, res.data!.admin);
      return;
    }

    setState(() {
      _loading = false;
      _error = (res.error != null && res.error!.trim().isNotEmpty)
          ? res.error
          : widget.tr('auth_err_bad');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FTColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Language switcher FR | AR | EN
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: ['fr', 'ar', 'en'].map((code) {
                          final active = widget.lang == code;
                          return GestureDetector(
                            onTap: () => widget.onLangChanged(code),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? FTColors.petrol
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                code.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: active ? Colors.white : FTColors.muted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    borderColor: FTColors.ochre.withValues(alpha: 0.35),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: FTColors.night2,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: FTColors.ochre.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Center(
                              child: FullTekPillsLogo(size: 38),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text.rich(
                              TextSpan(
                                text: 'Full·Tek ',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Control',
                                    style: TextStyle(color: FTColors.ochre),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: FTColors.ochre.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'SUPER-ADMIN',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: FTColors.ochre,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.tr('auth_sub'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: FTColors.muted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_error != null && _error!.trim().isNotEmpty) ...[
                          Container(
                            key: const Key('login_error_banner'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FTColors.danger.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: FTColors.danger),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: FTColors.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFCA5A5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextField(
                          key: const Key('login_username'),
                          controller: _userCtrl,
                          enabled: !_loading,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: widget.tr('auth_user_lbl'),
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('login_password'),
                          controller: _passCtrl,
                          enabled: !_loading,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: widget.tr('auth_pass_lbl'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              key: const Key('login_toggle_obscure'),
                              onPressed: _loading
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            key: const Key('login_submit'),
                            onPressed: _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: FTColors.ochre,
                              foregroundColor: const Color(0xFF101916),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _loading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Color(0xFF101916),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          widget.tr('auth_loading'),
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    widget.tr('auth_btn'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
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
