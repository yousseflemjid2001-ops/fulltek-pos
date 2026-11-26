import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';
import 'checkout_dialog.dart';
import 'shift_handover_dialog.dart';

class ClosingZView extends StatefulWidget {
  final PosStore store;
  const ClosingZView({super.key, required this.store});

  @override
  State<ClosingZView> createState() => _ClosingZViewState();
}

class _ClosingZViewState extends State<ClosingZView> {
  final _cashCtrl = TextEditingController(text: '0');
  final _bankilyCtrl = TextEditingController(text: '0');
  final _masriviCtrl = TextEditingController(text: '0');
  final _sedadCtrl = TextEditingController(text: '0');
  final _bimbankCtrl = TextEditingController(text: '0');
  final _clickCtrl = TextEditingController(text: '0');
  final Map<String, TextEditingController> _otherWalletCtrls = {};

  TextEditingController _ctrlForOtherWallet(String wallet) {
    return _otherWalletCtrls.putIfAbsent(
      wallet,
      () => TextEditingController(text: '0'),
    );
  }

  Widget _zNumericField({
    Key? fieldKey,
    required TextEditingController ctrl,
    required String label,
    IconData? prefixIcon,
  }) {
    return TextField(
      key: fieldKey,
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: IconButton(
          tooltip: 'Pavé numérique tactile',
          icon: const Icon(Icons.dialpad_rounded, size: 20),
          onPressed: () => showTouchNumpad(
            context: context,
            controller: ctrl,
            title: label,
            showQuickBills: true,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _bankilyCtrl.dispose();
    _masriviCtrl.dispose();
    _sedadCtrl.dispose();
    _bimbankCtrl.dispose();
    _clickCtrl.dispose();
    for (final c in _otherWalletCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submitZ() {
    final otherCounted = <String, double>{};
    for (final w in widget.store.activeAdditionalWalletsForZ) {
      final v = double.tryParse(_ctrlForOtherWallet(w).text.trim()) ?? 0;
      if (v > 0) otherCounted[w] = v;
    }
    final z = widget.store.submitBlindClosingZ(
      countedCashMru: double.tryParse(_cashCtrl.text.trim()) ?? 0,
      countedBankilyMru: double.tryParse(_bankilyCtrl.text.trim()) ?? 0,
      countedMasriviMru: double.tryParse(_masriviCtrl.text.trim()) ?? 0,
      countedSedadMru: double.tryParse(_sedadCtrl.text.trim()) ?? 0,
      countedBimbankMru: double.tryParse(_bimbankCtrl.text.trim()) ?? 0,
      countedClickMru: double.tryParse(_clickCtrl.text.trim()) ?? 0,
      countedOtherWallets: otherCounted,
    );
    _cashCtrl.text = '0';
    _bankilyCtrl.text = '0';
    _masriviCtrl.text = '0';
    _sedadCtrl.text = '0';
    _bimbankCtrl.text = '0';
    _clickCtrl.text = '0';
    for (final c in _otherWalletCtrls.values) {
      c.text = '0';
    }
    showReceiptPreviewDialog(
      context,
      title: widget.store.i18n.t('closing_z_report'),
      receiptText: widget.store.formatClosingZ80mm(z),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final i18n = store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final canCloseZ = store.canCurrent(PosPermission.closeCashZ);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          final zCard = _buildBlindZCard(store, i18n, p, canCloseZ);
          final syncCard = _buildSyncQueueCard(store, i18n, p);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 52, child: zCard),
                const SizedBox(width: 16),
                Expanded(flex: 48, child: syncCard),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                zCard,
                const SizedBox(height: 16),
                SizedBox(height: 360, child: syncCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBlindZCard(
      PosStore store, dynamic i18n, PosPalette p, bool canCloseZ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.visibility_off_rounded, color: p.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i18n.t('closing_z_title'),
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: p.textPrimary),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('closing_z_settings_btn'),
                  onPressed: () => showXzReportSettingsDialog(context, store),
                  icon: Icon(Icons.tune_rounded, size: 16, color: p.primary),
                  label: const Text('Détails X / Z',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              i18n.t('closing_z_hint'),
              style: TextStyle(fontSize: 12.5, color: p.textMuted),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 17, color: p.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tickets encaissés sur cette période : ${store.unclosedOrdersCount}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary),
                    ),
                  ),
                  if (store.waitingOrders.isNotEmpty)
                    Text(
                      '⚠️ ${store.waitingOrders.length} en attente',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: p.warning),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('open_report_x_btn'),
                    onPressed: () => showReportXDialog(context, store),
                    icon: Icon(Icons.assessment_outlined,
                        size: 18, color: p.accent),
                    label: const Text(
                      'Rapport X Caissier',
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('open_shift_transfer_z_btn'),
                    onPressed: () => showShiftHandoverDialog(context, store),
                    icon: Icon(Icons.swap_horizontal_circle_outlined,
                        size: 18, color: p.primary),
                    label: const Text(
                      'Transfert Service',
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _zNumericField(
              fieldKey: const Key('z_counted_cash_input'),
              ctrl: _cashCtrl,
              label: i18n.t('counted_cash'),
              prefixIcon: Icons.money_rounded,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _zNumericField(
                    fieldKey: const Key('z_counted_bankily_input'),
                    ctrl: _bankilyCtrl,
                    label: i18n.t('counted_bankily'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _zNumericField(
                    ctrl: _masriviCtrl,
                    label: i18n.t('counted_masrivi'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _zNumericField(
              ctrl: _sedadCtrl,
              label: i18n.t('counted_sedad'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _zNumericField(
                    fieldKey: const Key('z_counted_bimbank_input'),
                    ctrl: _bimbankCtrl,
                    label: i18n.t('counted_bimbank'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _zNumericField(
                    fieldKey: const Key('z_counted_click_input'),
                    ctrl: _clickCtrl,
                    label: i18n.t('counted_click'),
                  ),
                ),
              ],
            ),
            if (store.activeAdditionalWalletsForZ.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const Key('z_more_wallets_tile'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: const EdgeInsets.only(top: 6, bottom: 4),
                  leading: Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: p.accent),
                  title: Text(
                    'Autres portefeuilles (${store.activeAdditionalWalletsForZ.length} actifs : BCI-Pay, Amanty, GazaPay...)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: store.activeAdditionalWalletsForZ.map((w) {
                        return SizedBox(
                          width: 210,
                          child: _zNumericField(
                            fieldKey: Key('z_counted_wallet_$w'),
                            ctrl: _ctrlForOtherWallet(w),
                            label: '$w compté (MRU)',
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('submit_closing_z_btn'),
              onPressed: canCloseZ ? _submitZ : null,
              icon: const Icon(Icons.lock_clock_rounded),
              label: Text(canCloseZ
                  ? i18n.t('submit_closing_z')
                  : i18n.t('rbac_denied')),
            ),
            if (store.closingsZ.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: p.border),
              const SizedBox(height: 8),
              ...store.closingsZ.take(3).map((z) {
                final varianceColor = z.cashVarianceMru == 0
                    ? p.success
                    : (z.cashVarianceMru > 0 ? p.primary : p.danger);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${z.id} · ${z.cashierName} (${z.ordersCount} tickets)',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: p.textPrimary),
                  ),
                  subtitle: Text(
                    '${i18n.t('expected_cash')}: ${z.expectedCashMru.toStringAsFixed(0)} MRU · '
                    '${i18n.t('variance')}: ${z.cashVarianceMru >= 0 ? '+' : ''}${z.cashVarianceMru.toStringAsFixed(0)} MRU',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: varianceColor),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.receipt_outlined, size: 18),
                    onPressed: () => showReceiptPreviewDialog(
                      context,
                      title: i18n.t('closing_z_report'),
                      receiptText: store.formatClosingZ80mm(z),
                    ),
                  ),
                );
              }),
            ],
            if (store.remakeRecords.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(color: p.border),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 17, color: p.danger),
                      const SizedBox(width: 6),
                      Text(
                        'Offerts, Retours & Annulations (${store.remakeRecords.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (store.unclosedCompCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.success.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: p.success.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '🎁 Offerts : ${store.unclosedCompCount} art. · ${store.unclosedCompTotalMru.toStringAsFixed(0)} MRU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: p.success,
                        ),
                      ),
                    ),
                  if (store.unclosedReturnCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.danger.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: p.danger.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '↩️ Retours/Annul. : ${store.unclosedReturnCount} art. · ${store.unclosedReturnTotalMru.toStringAsFixed(0)} MRU',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: p.danger,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ...store.remakeRecords.take(8).map((r) {
                final typeLabel = switch (r.type) {
                  'void_kitchen' => 'ANNULATION CUISINE',
                  'return' => 'RETOUR',
                  'comp' => 'OFFERT',
                  _ => 'REMAKE',
                };
                final badgeColor = r.type == 'comp' ? p.success : p.danger;
                final hm =
                    '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: r.type == 'void_kitchen'
                          ? p.danger.withValues(alpha: 0.4)
                          : (r.type == 'comp'
                              ? p.success.withValues(alpha: 0.4)
                              : p.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${r.quantity}x ${r.itemName} · ${r.orderTicket}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '-${r.amountMru.toStringAsFixed(0)} MRU',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: p.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Motif : ${r.reason} · 🕒 $hm · Demandé : ${r.staffName} · Validé : ${r.approvedBy}',
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncQueueCard(PosStore store, dynamic i18n, PosPalette p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, color: p.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${i18n.t('sync_queue')} (${store.pendingSyncCount})',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: p.textPrimary),
                ),
              ),
              ElevatedButton.icon(
                key: const Key('sync_now_btn'),
                onPressed: store.isSyncing ? null : store.syncPendingToCloud,
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: Text(i18n.t('sync_now')),
              ),
            ],
          ),
          if (store.lastSyncMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              store.lastSyncMessage!,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: p.accent),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: store.syncQueue.isEmpty
                ? Center(
                    child: Text(
                      'Aucune opération en file — passez une vente ou une Clôture Z.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: store.syncQueue.length,
                    separatorBuilder: (_, _) => Divider(color: p.border),
                    itemBuilder: (context, idx) {
                      final q = store.syncQueue[idx];
                      final isSynced = q.status == 'synced';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isSynced
                              ? Icons.cloud_done_rounded
                              : Icons.schedule_rounded,
                          color: isSynced ? p.success : p.warning,
                        ),
                        title: Text(q.summary,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p.textPrimary)),
                        subtitle: Text(
                          '${q.id} · ${q.entityType.toUpperCase()}',
                          style: TextStyle(fontSize: 11, color: p.textMuted),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isSynced ? p.success : p.warning)
                                .withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isSynced ? i18n.t('synced') : i18n.t('pending'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isSynced ? p.success : p.warning,
                            ),
                          ),
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

Future<void> showXzReportSettingsDialog(
    BuildContext context, PosStore store) async {
  final p = FullTekThemes.paletteOf(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: p.surface,
        title: Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: p.primary, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Paramétrage Rapports X & Clôture Z',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choisissez les sections détaillées à imprimer sur vos tickets X et Z 80 mm :',
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Détail des règlements',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Espèces, Bankily, Masrvi, Sedad, Karni... (toujours inclus)',
                    style: TextStyle(fontSize: 11.5)),
                value: true,
                onChanged: null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                key: const Key('xz_by_family_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ventes par Famille / Catégorie',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Quantité & total MRU par famille (Plats, Boissons, Sandwich...)',
                    style: TextStyle(fontSize: 11.5)),
                value: store.xzShowByFamily,
                onChanged: (v) {
                  setD(() => store.setXzReportSettings(byFamily: v));
                },
              ),
              SwitchListTile(
                key: const Key('xz_by_article_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ventes par Article / Produit',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Quantité & total MRU de chaque plat/boisson vendu',
                    style: TextStyle(fontSize: 11.5)),
                value: store.xzShowByArticle,
                onChanged: (v) {
                  setD(() => store.setXzReportSettings(byArticle: v));
                },
              ),
              SwitchListTile(
                key: const Key('xz_by_customer_switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Ventes par Client',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text(
                    'Nombre de tickets & total MRU par client / table / passage',
                    style: TextStyle(fontSize: 11.5)),
                value: store.xzShowByCustomer,
                onChanged: (v) {
                  setD(() => store.setXzReportSettings(byCustomer: v));
                },
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    ),
  );
}
