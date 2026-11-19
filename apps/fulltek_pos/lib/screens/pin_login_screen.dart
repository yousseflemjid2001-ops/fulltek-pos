import 'package:flutter/material.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/fulltek_logo.dart';

class PinLoginScreen extends StatefulWidget {
  final PosStore store;
  const PinLoginScreen({super.key, required this.store});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  String? _error;

  void _appendDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _clear() {
    setState(() {
      _pin = '';
      _error = null;
    });
  }

  void _submit() {
    final ok = widget.store.loginWithPin(_pin);
    if (!ok) {
      setState(() {
        _error = widget.store.i18n.t('pin_invalid');
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      const FullTekLogo(size: 42, variant: 'Resto'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: ['fr', 'ar', 'en'].map((code) {
                                final selected = store.lang == code;
                                return InkWell(
                                  key: Key('lang_btn_$code'),
                                  onTap: () => store.setLanguage(code),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? p.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      code.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: selected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                            : p.textMuted,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<FullTekThemeId>(
                                key: const Key('theme_dropdown_login'),
                                value: store.themeId,
                                dropdownColor: p.surface,
                                icon: Icon(Icons.palette_outlined,
                                    size: 18, color: p.primary),
                                items: store.availableThemes.map((spec) {
                                  return DropdownMenuItem(
                                    value: spec.id,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: spec.palette.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          spec.label(store.lang),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: p.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) store.setTheme(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 700;
                      final leftPanel = _buildInfoPanel(context, store, p);
                      final rightPanel = _buildPinPad(context, store, p);
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: leftPanel),
                            const SizedBox(width: 20),
                            Expanded(flex: 6, child: rightPanel),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          rightPanel,
                          const SizedBox(height: 16),
                          leftPanel,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, PosStore store, PosPalette p) {
    final i18n = store.i18n;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            store.tenantName,
            key: const Key('tenant_name_label'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.t('subtitle_demo'),
            style: TextStyle(fontSize: 12.5, color: p.textMuted),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('change_account_btn'),
              onPressed: store.logoutAccount,
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: Text(i18n.t('change_account')),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                Icons.cloud_off_rounded,
                i18n.t('offline_ready'),
                p.primary,
              ),
              _statusChip(
                Icons.verified_user_rounded,
                '${i18n.t('license_ok')} · ${store.license.daysRemaining} ${i18n.t('days_left')}',
                p.success,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            i18n.t('quick_profiles'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...store.staff.map((member) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                key: Key('quick_pin_${member.pinCode}'),
                onTap: () => store.loginWithPin(member.pinCode),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: p.primary.withValues(alpha: 0.18),
                        child: Text(
                          member.name.substring(0, 1),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: p.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary,
                              ),
                            ),
                            Text(
                              member.role.label(store.lang),
                              style: TextStyle(fontSize: 12, color: p.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: p.border),
                        ),
                        child: Text(
                          'PIN ${member.pinCode}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: p.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPinPad(BuildContext context, PosStore store, PosPalette p) {
    final i18n = store.i18n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Text(
            i18n.t('pin_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            i18n.t('pin_hint'),
            style: TextStyle(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? p.primary : p.surfaceAlt,
                  border: Border.all(
                    color: filled ? p.primary : p.border,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: p.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(
                  (d) => _keyBtn(d, p, () => _appendDigit(d)),
                ),
                _keyBtn('C', p, _clear, isMuted: true),
                _keyBtn('0', p, () => _appendDigit('0')),
                _keyBtn('⌫', p, _backspace, isMuted: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyBtn(String label, PosPalette p, VoidCallback onTap,
      {bool isMuted = false}) {
    return Material(
      color: isMuted ? p.bg : p.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('pin_key_$label'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isMuted ? p.textMuted : p.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
