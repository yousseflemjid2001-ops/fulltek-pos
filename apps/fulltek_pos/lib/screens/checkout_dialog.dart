import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/receipt_formatter.dart';
import '../services/web_printer.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';

class CheckoutDialog extends StatefulWidget {
  final PosStore store;
  const CheckoutDialog({super.key, required this.store});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  String? _selectedWalletLabel;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  String? _selectedKarniId;
  final List<PaymentEntry> _entries = [];
  String? _error;

  double get _orderTotal => widget.store.activeOrder?.netTotal ?? 0;
  double get _paidSoFar => _entries.fold(0.0, (s, e) => s + e.amountMru);
  double get _remaining =>
      (_orderTotal - _paidSoFar) > 0 ? (_orderTotal - _paidSoFar) : 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _orderTotal.toStringAsFixed(0);
    if (widget.store.karniCustomers.isNotEmpty) {
      _selectedKarniId = widget.store.karniCustomers.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  void _addPayment() {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Montant invalide');
      return;
    }
    if (_method == PaymentMethod.karni && _selectedKarniId == null) {
      setState(() => _error = 'Sélectionnez un client Karni');
      return;
    }
    final candidate = PaymentEntry(
      method: _method,
      walletLabel: _selectedWalletLabel,
      amountMru: amount,
      reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
      karniCustomerId:
          _method == PaymentMethod.karni ? _selectedKarniId : null,
    );
    final karniErr = widget.store.validateKarniLimits(
      [..._entries, candidate],
      isTraining: widget.store.activeOrder?.isTraining ?? false,
    );
    if (karniErr != null) {
      setState(() => _error = karniErr);
      return;
    }
    setState(() {
      _error = null;
      _entries.add(candidate);
      _refCtrl.clear();
      _amountCtrl.text = _remaining.toStringAsFixed(0);
    });
  }

  Future<void> _finalize() async {
    final List<PaymentEntry> finalPayments = List.from(_entries);
    if (finalPayments.isEmpty) {
      final typed = double.tryParse(_amountCtrl.text.trim()) ?? _orderTotal;
      finalPayments.add(
        PaymentEntry(
          method: _method,
          walletLabel: _selectedWalletLabel,
          amountMru: typed,
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          karniCustomerId:
              _method == PaymentMethod.karni ? _selectedKarniId : null,
        ),
      );
    }

    final closed = widget.store.completeCheckout(finalPayments);
    if (closed == null) {
      setState(() => _error = widget.store.lastCheckoutError ??
          'Montant insuffisant pour clôturer le ticket.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(closed);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final typedAmt =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    final liveTotalPaid = _entries.isNotEmpty ? _paidSoFar : typedAmt;
    final liveRemaining =
        (_orderTotal - liveTotalPaid).clamp(0.0, double.infinity);
    final liveChange =
        (liveTotalPaid - _orderTotal).clamp(0.0, double.infinity);
    final canComplete =
        _entries.isNotEmpty ? _paidSoFar + 0.01 >= _orderTotal : true;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_rounded, color: p.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      i18n.t('payment_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: p.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Summary banner + TVA 16 % + Delivery Fee
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metric(i18n.t('total_to_pay'),
                            '${_orderTotal.toStringAsFixed(0)} ${i18n.t('mru')}', p.textPrimary, p),
                        _metric(i18n.t('remaining'),
                            '${liveRemaining.toStringAsFixed(0)} ${i18n.t('mru')}', liveRemaining > 0 ? p.warning : p.success, p),
                        _metric(i18n.t('change_due'),
                            '${liveChange.toStringAsFixed(0)} ${i18n.t('mru')}', liveChange > 0 ? p.success : p.primary, p),
                      ],
                    ),
                    if (liveChange > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('live_change_due_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: p.success.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.success, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.currency_exchange_rounded,
                                color: p.success, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'MONNAIE À RENDRE : ${liveChange.toStringAsFixed(0)} ${i18n.t('mru')}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: p.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (widget.store.tvaEnabled ||
                        (widget.store.activeOrder?.deliveryFeeMru ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.store.tvaEnabled)
                            Text(
                              'Dont TVA ${widget.store.tvaRatePercent.toStringAsFixed(0)} %: ${((widget.store.activeOrder?.grossTotal ?? 0) * widget.store.tvaRatePercent / (100.0 + widget.store.tvaRatePercent)).round()} MRU',
                              style:
                                  TextStyle(fontSize: 11.5, color: p.textMuted),
                            )
                          else
                            const SizedBox.shrink(),
                          if ((widget.store.activeOrder?.deliveryFeeMru ?? 0) >
                              0)
                            Text(
                              '${i18n.t('delivery_fee')}: ${widget.store.activeOrder!.deliveryFeeMru.toStringAsFixed(0)} MRU',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: p.accent),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment method chips (Cash + Active Mauritanian/Custom Wallets + Karni)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mode d\'encaissement (${widget.store.activeWallets.length} portefeuilles actifs)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.textMuted,
                      ),
                    ),
                  ),
                  if (widget.store.canCurrent(PosPermission.voidOrComp) ||
                      widget.store.canCurrent(PosPermission.manageMenuStock))
                    TextButton.icon(
                      key: const Key('checkout_config_wallets_btn'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        await showWalletsConfigDialog(context, widget.store);
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.tune_rounded, size: 15),
                      label: const Text(
                        'Paramétrer',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _methodChip(
                    key: const Key('pay_method_cash'),
                    m: PaymentMethod.cash,
                    walletLabel: null,
                    label: i18n.t('payment_cash'),
                    icon: Icons.money_rounded,
                    p: p,
                  ),
                  ...widget.store.activeWallets.map((w) {
                    final pm = MauritanianWallets.methodForWallet(w);
                    final chipKey = switch (pm) {
                      PaymentMethod.bankily => const Key('pay_method_bankily'),
                      PaymentMethod.masrivi => const Key('pay_method_masrivi'),
                      PaymentMethod.sedad => const Key('pay_method_sedad'),
                      PaymentMethod.bimbank => const Key('pay_method_bimbank'),
                      PaymentMethod.click => const Key('pay_method_click'),
                      _ => Key('pay_wallet_$w'),
                    };
                    final chipIcon = switch (pm) {
                      PaymentMethod.bankily => Icons.phone_android_rounded,
                      PaymentMethod.masrivi =>
                        Icons.account_balance_wallet_rounded,
                      PaymentMethod.sedad => Icons.qr_code_2_rounded,
                      PaymentMethod.bimbank => Icons.account_balance_rounded,
                      PaymentMethod.click => Icons.bolt_rounded,
                      _ => Icons.contactless_rounded,
                    };
                    return _methodChip(
                      key: chipKey,
                      m: pm,
                      walletLabel: w,
                      label: w,
                      icon: chipIcon,
                      p: p,
                    );
                  }),
                  _methodChip(
                    key: const Key('pay_method_karni'),
                    m: PaymentMethod.karni,
                    walletLabel: null,
                    label: i18n.t('payment_karni'),
                    icon: Icons.menu_book_rounded,
                    p: p,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Quick MRU banknotes for Cash
              if (_method == PaymentMethod.cash) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [100, 200, 500, 1000, 2000].map((bill) {
                    return ActionChip(
                      label: Text('$bill MRU',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      backgroundColor: p.surfaceAlt,
                      side: BorderSide(color: p.border),
                      onPressed: () {
                        setState(() {
                          _amountCtrl.text = bill.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Mobile money / Electronic wallet reference
              if (_method != PaymentMethod.cash &&
                  _method != PaymentMethod.karni) ...[
                TextField(
                  key: const Key('payment_ref_input'),
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    labelText:
                        '${i18n.t('reference_tx')}${_selectedWalletLabel != null ? ' ($_selectedWalletLabel)' : ''}',
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Karni customer dropdown
              if (_method == PaymentMethod.karni) ...[
                DropdownButtonFormField<String>(
                  key: const Key('karni_customer_dropdown'),
                  initialValue: _selectedKarniId,
                  decoration: InputDecoration(
                    labelText: i18n.t('select_karni_customer'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  items: widget.store.karniCustomers.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} (${c.balanceDueMru.toStringAsFixed(0)} / ${c.creditLimitMru.toStringAsFixed(0)} MRU)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedKarniId = v),
                ),
                const SizedBox(height: 12),
              ],

              // Amount + Add split payment button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('payment_amount_input'),
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      onTap: () => showTouchNumpad(
                        context: context,
                        controller: _amountCtrl,
                        title: i18n.t('amount_received'),
                        showQuickBills: true,
                        onChanged: () => setState(() {}),
                      ),
                      decoration: InputDecoration(
                        labelText: i18n.t('amount_received'),
                        suffixText: i18n.t('mru'),
                        suffixIcon: IconButton(
                          tooltip: 'Pavé numérique tactile',
                          icon: const Icon(Icons.dialpad_rounded, size: 20),
                          onPressed: () => showTouchNumpad(
                            context: context,
                            controller: _amountCtrl,
                            title: i18n.t('amount_received'),
                            showQuickBills: true,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    key: const Key('add_payment_entry_btn'),
                    onPressed: _addPayment,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(i18n.t('add_payment')),
                  ),
                ],
              ),

              if (_entries.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final pe = e.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.check_circle_outline,
                        color: p.success, size: 18),
                    title: Text(
                      '${pe.displayLabel}${pe.reference != null ? ' · ${pe.reference}' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${pe.amountMru.toStringAsFixed(0)} MRU',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: p.primary),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 18, color: p.danger),
                          onPressed: () {
                            setState(() {
                              _entries.removeAt(idx);
                              _amountCtrl.text = _remaining.toStringAsFixed(0);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: TextStyle(
                        color: p.danger, fontWeight: FontWeight.w700)),
              ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(i18n.t('cancel')),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    key: const Key('confirm_checkout_btn'),
                    onPressed: canComplete ? _finalize : null,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(i18n.t('validate_print')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodChip({
    required Key key,
    required PaymentMethod m,
    required String? walletLabel,
    required String label,
    required IconData icon,
    required PosPalette p,
  }) {
    final active = walletLabel != null
        ? (_selectedWalletLabel == walletLabel && _method == m)
        : (_selectedWalletLabel == null && _method == m);
    return ChoiceChip(
      key: key,
      selected: active,
      onSelected: (_) => setState(() {
        _method = m;
        _selectedWalletLabel = walletLabel;
      }),
      avatar: Icon(icon, size: 16, color: active ? p.bg : p.primary),
      label: Text(label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? p.bg : p.textPrimary,
          )),
      selectedColor: p.primary,
      backgroundColor: p.surfaceAlt,
      side: BorderSide(color: active ? p.primary : p.border),
    );
  }

  Widget _metric(String label, String value, Color valColor, PosPalette p) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: p.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900, color: valColor)),
      ],
    );
  }
}

void showReceiptPreviewDialog(
  BuildContext context, {
  required String title,
  required String receiptText,
  String? subtitle,
}) {
  final p = FullTekThemes.paletteOf(context);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: p.border),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary)),
          if (subtitle != null)
            Text(subtitle, style: TextStyle(fontSize: 12, color: p.success)),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD6D3D1)),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            receiptText,
            key: const Key('receipt_80mm_text'),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF1C1917),
            ),
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          key: const Key('print_80mm_btn'),
          onPressed: () => printThermal80mm(title, receiptText),
          icon: const Icon(Icons.print_rounded, size: 17),
          label: const Text('Imprimer 80mm'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String buildReceiptForClosedOrder(PosOrder order, {PosStore? store}) {
  if (store == null) {
    return ReceiptFormatter.formatOrderReceipt80mm(order: order);
  }
  return ReceiptFormatter.formatOrderReceipt80mm(
    order: order,
    storeName: store.tenantName,
    storeNameAr: store.storeNameAr,
    address: store.storeAddress,
    phone: store.storePhone,
    nif: store.storeNif,
    rc: store.storeRc,
    footer: store.receiptFooter,
    showTva: store.tvaEnabled,
    tvaRatePercent: store.tvaRatePercent,
  );
}

Future<void> showWalletsConfigDialog(
    BuildContext context, PosStore store) async {
  final p = FullTekThemes.paletteOf(context);
  final newWalletCtrl = TextEditingController();
  String? err;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final wallets = store.allAvailableWallets;
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: p.border),
          ),
          title: Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: p.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Portefeuilles Électroniques (Mauritanie)',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Activez uniquement les portefeuilles acceptés dans votre établissement ou ajoutez un nouveau portefeuille :',
                    style: TextStyle(fontSize: 12.5, color: p.textMuted),
                  ),
                  const SizedBox(height: 10),
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(err!,
                          style: TextStyle(
                              color: p.danger,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('add_custom_wallet_input'),
                          controller: newWalletCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Nouveau portefeuille personnalisé',
                            hintText: 'Ex: MauriPay, SaharaPay...',
                            prefixIcon: Icon(Icons.add_card_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        key: const Key('add_custom_wallet_btn'),
                        onPressed: () async {
                          final res =
                              await store.addCustomWallet(newWalletCtrl.text);
                          if (res != null) {
                            setD(() => err = res);
                            return;
                          }
                          newWalletCtrl.clear();
                          setD(() => err = null);
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        key: const Key('enable_all_wallets_btn'),
                        onPressed: () async {
                          await store.setAllWalletsEnabled(true);
                          if (ctx.mounted) setD(() => err = null);
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: Text('Tout activer (${wallets.length})'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await store.setAllWalletsEnabled(false);
                          if (ctx.mounted) setD(() => err = null);
                        },
                        icon: const Icon(Icons.filter_1_rounded, size: 16),
                        label: const Text('Bankily seul'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: wallets.map((w) {
                      final active = store.isWalletEnabled(w);
                      final isOfficial = MauritanianWallets.official16
                          .any((o) => o.toLowerCase() == w.toLowerCase());
                      final ar = MauritanianWallets.arabicNames[w];
                      return Container(
                        width: 255,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: active
                              ? p.primary.withValues(alpha: 0.12)
                              : p.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? p.primary : p.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                  if (ar != null)
                                    Text(
                                      ar,
                                      style: TextStyle(
                                          fontSize: 11, color: p.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            if (!isOfficial)
                              IconButton(
                                tooltip: 'Supprimer ce portefeuille',
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final r = await store.removeCustomWallet(w);
                                  if (ctx.mounted) setD(() => err = r);
                                },
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: p.danger),
                              ),
                            Switch(
                              key: Key('toggle_wallet_$w'),
                              value: active,
                              onChanged: (v) async {
                                await store.toggleWalletEnabled(w, v);
                                if (ctx.mounted) setD(() => err = null);
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Terminé'),
            ),
          ],
        );
      },
    ),
  );
  newWalletCtrl.dispose();
}
