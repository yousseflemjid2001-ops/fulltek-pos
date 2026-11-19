import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../services/receipt_formatter.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class CheckoutDialog extends StatefulWidget {
  final PosStore store;
  const CheckoutDialog({super.key, required this.store});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  PaymentMethod _method = PaymentMethod.cash;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  String? _selectedKarniId;
  final List<PaymentEntry> _entries = [];
  String? _error;

  double get _orderTotal => widget.store.activeOrder?.netTotal ?? 0;
  double get _paidSoFar => _entries.fold(0.0, (s, e) => s + e.amountMru);
  double get _remaining =>
      (_orderTotal - _paidSoFar) > 0 ? (_orderTotal - _paidSoFar) : 0;
  double get _changeDue =>
      _paidSoFar > _orderTotal ? (_paidSoFar - _orderTotal) : 0;

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
    setState(() {
      _error = null;
      _entries.add(
        PaymentEntry(
          method: _method,
          amountMru: amount,
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          karniCustomerId:
              _method == PaymentMethod.karni ? _selectedKarniId : null,
        ),
      );
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
          amountMru: typed,
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          karniCustomerId:
              _method == PaymentMethod.karni ? _selectedKarniId : null,
        ),
      );
    }

    final closed = widget.store.completeCheckout(finalPayments);
    if (closed == null) {
      setState(() => _error = 'Montant insuffisant pour clôturer le ticket.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(closed);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final canComplete =
        _entries.isNotEmpty ? _paidSoFar + 0.01 >= _orderTotal : true;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
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
              const SizedBox(height: 14),

              // Summary banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric(i18n.t('total_to_pay'),
                        '${_orderTotal.toStringAsFixed(0)} ${i18n.t('mru')}', p.textPrimary, p),
                    _metric(i18n.t('remaining'),
                        '${_remaining.toStringAsFixed(0)} ${i18n.t('mru')}', _remaining > 0 ? p.warning : p.success, p),
                    _metric(i18n.t('change_due'),
                        '${_changeDue.toStringAsFixed(0)} ${i18n.t('mru')}', p.primary, p),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment method chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _methodChip(PaymentMethod.cash, i18n.t('payment_cash'), Icons.money_rounded, p),
                  _methodChip(PaymentMethod.bankily, i18n.t('payment_bankily'), Icons.phone_android_rounded, p),
                  _methodChip(PaymentMethod.masrivi, i18n.t('payment_masrivi'), Icons.account_balance_wallet_rounded, p),
                  _methodChip(PaymentMethod.sedad, i18n.t('payment_sedad'), Icons.qr_code_2_rounded, p),
                  _methodChip(PaymentMethod.karni, i18n.t('payment_karni'), Icons.menu_book_rounded, p),
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
                        _amountCtrl.text = bill.toString();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Mobile money reference
              if (_method == PaymentMethod.bankily ||
                  _method == PaymentMethod.masrivi ||
                  _method == PaymentMethod.sedad) ...[
                TextField(
                  key: const Key('payment_ref_input'),
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('reference_tx'),
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
                      decoration: InputDecoration(
                        labelText: i18n.t('amount_received'),
                        suffixText: i18n.t('mru'),
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
                      '${pe.method.name.toUpperCase()}${pe.reference != null ? ' · ${pe.reference}' : ''}',
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

              const SizedBox(height: 18),
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

  Widget _methodChip(
      PaymentMethod m, String label, IconData icon, PosPalette p) {
    final active = _method == m;
    return ChoiceChip(
      key: Key('pay_method_${m.name}'),
      selected: active,
      onSelected: (_) => setState(() => _method = m),
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
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String buildReceiptForClosedOrder(PosOrder order) {
  return ReceiptFormatter.formatOrderReceipt80mm(order: order);
}
