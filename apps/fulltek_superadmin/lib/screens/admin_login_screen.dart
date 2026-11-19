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

  Widget _featurePill(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FTColors.ochre.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: FTColors.ochre, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: FTColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWebDesktop = constraints.maxWidth >= 900;
        return _buildLoginScaffold(context, isWebDesktop);
      },
    );
  }

  Widget _buildLoginScaffold(BuildContext context, bool isWebDesktop) {

    final langSwitcher = Container(
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
                color: active ? FTColors.petrol : Colors.transparent,
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
    );

    final loginCard = GlassCard(
      borderColor: FTColors.ochre.withValues(alpha: 0.35),
      padding: EdgeInsets.all(isWebDesktop ? 28 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWebDesktop) ...[
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
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: FTColors.ochre.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'SUPER-ADMIN',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: FTColors.ochre,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                langSwitcher,
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (!isWebDesktop)
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
            textAlign: isWebDesktop ? TextAlign.start : TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: FTColors.muted,
            ),
          ),
          const SizedBox(height: 22),
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
          const SizedBox(height: 14),
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
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
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
    );

    if (isWebDesktop) {
      return Scaffold(
        backgroundColor: FTColors.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 44),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: FTColors.night2,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: FTColors.ochre.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: const Center(
                                  child: FullTekPillsLogo(size: 32),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text.rich(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        TextSpan(
                                          text: 'Full·Tek ',
                                          style: TextStyle(
                                            fontSize: 28,
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FTColors.ochre.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        widget.tr('web_console_badge'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                          color: FTColors.ochre,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            widget.tr('login_hero_title'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _featurePill(
                            Icons.verified_user_rounded,
                            widget.tr('login_f1_t'),
                            widget.tr('login_f1_s'),
                          ),
                          const SizedBox(height: 10),
                          _featurePill(
                            Icons.storefront_rounded,
                            widget.tr('login_f2_t'),
                            widget.tr('login_f2_s'),
                          ),
                          const SizedBox(height: 10),
                          _featurePill(
                            Icons.upload_file_rounded,
                            widget.tr('login_f3_t'),
                            widget.tr('login_f3_s'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: loginCard,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: FTColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: langSwitcher,
                  ),
                  const SizedBox(height: 12),
                  loginCard,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
