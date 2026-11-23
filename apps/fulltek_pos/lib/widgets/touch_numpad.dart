import 'package:flutter/material.dart';
import '../theme/fulltek_themes.dart';

/// Opens a large, touch-friendly Numeric Keypad modal for any numeric field
/// (amounts in MRU, quantities, prices, discounts, PIN codes, etc.).
Future<void> showTouchNumpad({
  required BuildContext context,
  required TextEditingController controller,
  required String title,
  String suffix = 'MRU',
  bool allowDecimal = false,
  bool obscure = false,
  bool showQuickBills = false,
  VoidCallback? onChanged,
}) async {
  final p = FullTekThemes.paletteOf(context);
  String value = controller.text.trim();
  if (value == '0' && !obscure) value = '';

  final confirmed = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        void pressDigit(String d) {
          setD(() {
            if (d == '.' && (!allowDecimal || value.contains('.'))) return;
            if (d == '.' && value.isEmpty) {
              value = '0.';
              return;
            }
            if (value == '0' && d != '.' && !obscure) {
              value = d;
            } else {
              value += d;
            }
          });
        }

        void addQuick(int delta) {
          setD(() {
            final cur = double.tryParse(value.replaceAll(',', '.')) ?? 0;
            final next = cur + delta;
            value = next == next.roundToDouble()
                ? next.toInt().toString()
                : next.toStringAsFixed(2);
          });
        }

        void backspace() {
          setD(() {
            if (value.isNotEmpty) {
              value = value.substring(0, value.length - 1);
            }
          });
        }

        void clear() => setD(() => value = '');

        final display = obscure
            ? '•' * value.length
            : (value.isEmpty ? '0' : value);

        return Dialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: p.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.dialpad_rounded, color: p.primary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Large LCD-style numeric display
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: p.primary.withValues(alpha: 0.45), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            display,
                            key: const Key('touch_numpad_display'),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: p.textPrimary,
                              letterSpacing: obscure ? 6 : 0.5,
                            ),
                          ),
                        ),
                        if (suffix.isNotEmpty && !obscure) ...[
                          const SizedBox(width: 8),
                          Text(
                            suffix,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: p.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showQuickBills && !obscure) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (final amt in const [50, 100, 200, 500, 1000])
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.5),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => addQuick(amt),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: p.primary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                            p.primary.withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    '+$amt',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: p.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TouchNumpadGrid(
                    allowDecimal: allowDecimal,
                    onDigit: pressDigit,
                    onBackspace: backspace,
                    onClear: clear,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('touch_numpad_confirm_btn'),
                      onPressed: () =>
                          Navigator.of(ctx).pop(value.isEmpty ? '0' : value),
                      icon: const Icon(Icons.check_rounded, size: 22),
                      label: const Text(
                        'Valider',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  if (confirmed != null) {
    controller.text = obscure && confirmed == '0' && value.isEmpty
        ? ''
        : confirmed;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    onChanged?.call();
  }
}

/// Reusable 3x4 Touch Numeric Keypad grid (can be embedded inline or in modals).
class TouchNumpadGrid extends StatelessWidget {
  final bool allowDecimal;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final double keyHeight;

  const TouchNumpadGrid({
    super.key,
    this.allowDecimal = false,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    this.keyHeight = 52,
  });

  @override
  Widget build(BuildContext context) {
    final p = FullTekThemes.paletteOf(context);
    final rows = [
      ['7', '8', '9'],
      ['4', '5', '6'],
      ['1', '2', '3'],
      [allowDecimal ? '.' : 'C', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final k in r)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        height: keyHeight,
                        child: Material(
                          color: k == 'C'
                              ? p.danger.withValues(alpha: 0.14)
                              : (k == '⌫'
                                  ? p.warning.withValues(alpha: 0.14)
                                  : p.surfaceAlt),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            key: Key('numpad_key_$k'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (k == '⌫') {
                                onBackspace();
                              } else if (k == 'C') {
                                onClear();
                              } else {
                                onDigit(k);
                              }
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: k == 'C'
                                      ? p.danger.withValues(alpha: 0.4)
                                      : (k == '⌫'
                                          ? p.warning.withValues(alpha: 0.4)
                                          : p.border),
                                ),
                              ),
                              child: k == '⌫'
                                  ? Icon(Icons.backspace_outlined,
                                      size: 20, color: p.warning)
                                  : Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: k == 'C'
                                            ? p.danger
                                            : p.textPrimary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (allowDecimal)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.clear_all_rounded, size: 18, color: p.danger),
              label: Text(
                'Effacer (C)',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: p.danger),
              ),
            ),
          ),
      ],
    );
  }
}
