import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/receipt_formatter.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import 'checkout_dialog.dart';

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

  @override
  void dispose() {
    _cashCtrl.dispose();
    _bankilyCtrl.dispose();
    _masriviCtrl.dispose();
    _sedadCtrl.dispose();
    _bimbankCtrl.dispose();
    _clickCtrl.dispose();
    super.dispose();
  }

  void _submitZ() {
    final z = widget.store.submitBlindClosingZ(
      countedCashMru: double.tryParse(_cashCtrl.text.trim()) ?? 0,
      countedBankilyMru: double.tryParse(_bankilyCtrl.text.trim()) ?? 0,
      countedMasriviMru: double.tryParse(_masriviCtrl.text.trim()) ?? 0,
      countedSedadMru: double.tryParse(_sedadCtrl.text.trim()) ?? 0,
      countedBimbankMru: double.tryParse(_bimbankCtrl.text.trim()) ?? 0,
      countedClickMru: double.tryParse(_clickCtrl.text.trim()) ?? 0,
    );
    _cashCtrl.text = '0';
    _bankilyCtrl.text = '0';
    _masriviCtrl.text = '0';
    _sedadCtrl.text = '0';
    _bimbankCtrl.text = '0';
    _clickCtrl.text = '0';
    showReceiptPreviewDialog(
      context,
      title: widget.store.i18n.t('closing_z_report'),
      receiptText: ReceiptFormatter.formatClosingZReport(z),
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
            const SizedBox(height: 14),
            TextField(
              key: const Key('z_counted_cash_input'),
              controller: _cashCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: i18n.t('counted_cash'),
                prefixIcon: const Icon(Icons.money_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('z_counted_bankily_input'),
                    controller: _bankilyCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: i18n.t('counted_bankily')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _masriviCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: i18n.t('counted_masrivi')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sedadCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: i18n.t('counted_sedad')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('z_counted_bimbank_input'),
                    controller: _bimbankCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: i18n.t('counted_bimbank')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    key: const Key('z_counted_click_input'),
                    controller: _clickCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: i18n.t('counted_click')),
                  ),
                ),
              ],
            ),
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
                      receiptText: ReceiptFormatter.formatClosingZReport(z),
                    ),
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
