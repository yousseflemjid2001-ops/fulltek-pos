import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';

class KarniView extends StatelessWidget {
  final PosStore store;
  const KarniView({super.key, required this.store});

  Future<void> _settleDialog(BuildContext context, KarniCustomer c) async {
    final ctrl = TextEditingController(text: c.balanceDueMru.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${store.i18n.t('karni_settle')} · ${c.name}'),
        content: TextField(
          key: const Key('karni_settle_amount_input'),
          controller: ctrl,
          keyboardType: TextInputType.number,
          onTap: () => showTouchNumpad(
            context: ctx,
            controller: ctrl,
            title: 'Montant encaissé (MRU)',
            showQuickBills: true,
          ),
          decoration: const InputDecoration(
            labelText: 'Montant encaissé (MRU)',
            suffixText: 'MRU',
            suffixIcon: Icon(Icons.dialpad_rounded, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(store.i18n.t('cancel')),
          ),
          ElevatedButton(
            key: const Key('karni_settle_confirm_btn'),
            onPressed: () {
              final amt = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amt > 0) {
                store.settleKarniBalance(c.id, amt);
                Navigator.of(ctx).pop(true);
              }
            },
            child: Text(store.i18n.t('confirm')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Règlement Karni enregistré & mis en file SyncQueue.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final totalDue =
        store.karniCustomers.fold(0.0, (s, c) => s + c.balanceDueMru);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.t('karni_title'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: p.textPrimary),
                    ),
                    Text(
                      '${store.karniCustomers.length} comptes actifs',
                      style: TextStyle(fontSize: 12.5, color: p.textMuted),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(i18n.t('karni_total_due'),
                        style: TextStyle(fontSize: 12, color: p.textMuted)),
                    Text(
                      '${totalDue.toStringAsFixed(0)} ${i18n.t('mru')}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: p.warning),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              itemCount: store.karniCustomers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final c = store.karniCustomers[idx];
                final ratio = c.creditLimitMru > 0
                    ? (c.balanceDueMru / c.creditLimitMru).clamp(0.0, 1.0)
                    : 0.0;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: p.textPrimary)),
                                Text(c.phone,
                                    style: TextStyle(
                                        fontSize: 12, color: p.textMuted)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${c.balanceDueMru.toStringAsFixed(0)} ${i18n.t('mru')}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: c.balanceDueMru > 0
                                      ? p.warning
                                      : p.success,
                                ),
                              ),
                              Text(
                                '${i18n.t('karni_limit')}: ${c.creditLimitMru.toStringAsFixed(0)} MRU',
                                style: TextStyle(
                                    fontSize: 11, color: p.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            key: Key('karni_settle_btn_${c.id}'),
                            onPressed: c.balanceDueMru > 0
                                ? () => _settleDialog(context, c)
                                : null,
                            child: Text(i18n.t('karni_settle')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: p.surfaceAlt,
                          color: ratio > 0.8 ? p.danger : p.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
