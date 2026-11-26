import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';

class RemakeCompDialog extends StatefulWidget {
  final PosStore store;
  const RemakeCompDialog({super.key, required this.store});

  @override
  State<RemakeCompDialog> createState() => _RemakeCompDialogState();
}

class _RemakeCompDialogState extends State<RemakeCompDialog> {
  String _type = 'comp'; // comp | return | remake
  bool _wholeOrder = false; // false = Article(s) au choix, true = Tout le ticket
  bool _autoCloseCompOrder = true;
  final Set<String> _selectedLineIds = {};
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  String? _error;

  static const _quickReasons = [
    'Geste VIP',
    'Offert Direction',
    'Erreur commande',
    'Plat froid / Défaut',
    'Client fidèle',
  ];

  @override
  void initState() {
    super.initState();
    final items = widget.store.activeOrder?.items ?? const [];
    if (items.isNotEmpty) {
      final firstEligible = items.where((l) => !l.isComp).firstOrNull ?? items.first;
      _selectedLineIds.add(firstEligible.lineId);
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final items = widget.store.activeOrder?.items ?? const [];
    if (items.isEmpty) return;
    if (!_wholeOrder && _selectedLineIds.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins un article.');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = widget.store.i18n.t('reason_required'));
      return;
    }
    final ok = widget.store.recordOrderCompOrReturn(
      type: _type,
      reason: _reasonCtrl.text.trim(),
      lineIds: _wholeOrder ? null : _selectedLineIds.toList(),
      wholeOrder: _wholeOrder,
      autoCloseCompOrder: _wholeOrder && _type == 'comp' && _autoCloseCompOrder,
      managerPin: _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
    );
    if (!ok) {
      setState(() => _error = widget.store.i18n.t('manager_pin_required'));
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final items = widget.store.activeOrder?.items ?? const [];
    final needsPin = !widget.store.canCurrent(PosPermission.voidOrComp);

    final affectedItems = _wholeOrder
        ? items.where((l) => _type != 'comp' || !l.isComp).toList()
        : items
            .where((l) =>
                _selectedLineIds.contains(l.lineId) &&
                (_type != 'comp' || !l.isComp))
            .toList();
    final affectedAmount = affectedItems.fold<double>(
        0.0, (s, l) => s + (l.unitPriceWithModifiers * l.quantity));

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: p.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i18n.t('remake_title'),
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: p.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${affectedAmount.toStringAsFixed(0)} MRU',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: p.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Action Type
                Text(
                  '1. Type d\'opération',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      key: const Key('remake_type_comp'),
                      label: Text('🎁 ${i18n.t('type_comp')}'),
                      selected: _type == 'comp',
                      onSelected: (_) => setState(() {
                        _type = 'comp';
                        _error = null;
                      }),
                    ),
                    ChoiceChip(
                      key: const Key('remake_type_return'),
                      label: Text('↩️ ${i18n.t('type_return')}'),
                      selected: _type == 'return',
                      onSelected: (_) => setState(() {
                        _type = 'return';
                        _error = null;
                      }),
                    ),
                    ChoiceChip(
                      key: const Key('remake_type_remake'),
                      label: Text('🔥 ${i18n.t('type_remake')}'),
                      selected: _type == 'remake',
                      onSelected: (_) => setState(() {
                        _type = 'remake';
                        _error = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Scope: Article(s) au choix vs Tout le ticket
                Text(
                  '2. Portée (Article(s) ou Ticket entier)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: p.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('remake_scope_items'),
                        selected: !_wholeOrder,
                        onSelected: (_) => setState(() {
                          _wholeOrder = false;
                          _error = null;
                        }),
                        label: const Text('Article(s) au choix'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('remake_scope_whole'),
                        selected: _wholeOrder,
                        onSelected: (_) => setState(() {
                          _wholeOrder = true;
                          _error = null;
                        }),
                        label: const Text('Tout le ticket'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_wholeOrder)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: p.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _type == 'comp'
                              ? '🎁 Tout le ticket (${affectedItems.length} ligne(s) · ${affectedAmount.toStringAsFixed(0)} MRU) sera marqué OFFERT et comptabilisé dans les rapports X et Z.'
                              : 'Sera appliqué à l\'ensemble des ${affectedItems.length} ligne(s) du ticket (${affectedAmount.toStringAsFixed(0)} MRU).',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        if (_type == 'comp') ...[
                          const SizedBox(height: 6),
                          SwitchListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _autoCloseCompOrder,
                            onChanged: (v) =>
                                setState(() => _autoCloseCompOrder = v),
                            title: const Text(
                              'Clôturer immédiatement le ticket Offert (0 MRU)',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 175),
                    decoration: BoxDecoration(
                      color: p.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: p.border),
                      itemBuilder: (ctx, i) {
                        final l = items[i];
                        final disabledComp = _type == 'comp' && l.isComp;
                        final checked =
                            !disabledComp && _selectedLineIds.contains(l.lineId);
                        final lineVal = l.unitPriceWithModifiers * l.quantity;
                        return CheckboxListTile(
                          key: Key('remake_item_check_${l.lineId}'),
                          dense: true,
                          value: checked,
                          onChanged: disabledComp
                              ? null
                              : (v) => setState(() {
                                    if (v == true) {
                                      _selectedLineIds.add(l.lineId);
                                    } else {
                                      _selectedLineIds.remove(l.lineId);
                                    }
                                    _error = null;
                                  }),
                          title: Text(
                            '${l.quantity}x ${l.item.label(widget.store.lang)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color:
                                  disabledComp ? p.textMuted : p.textPrimary,
                              decoration: l.isComp
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          secondary: Text(
                            l.isComp
                                ? 'DÉJÀ OFFERT'
                                : '${lineVal.toStringAsFixed(0)} MRU',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: l.isComp ? p.success : p.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 12),

                // 3. Quick Reasons + Text Input
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReasons
                      .map((r) => ActionChip(
                            label: Text(r, style: const TextStyle(fontSize: 11)),
                            onPressed: () => setState(() {
                              _reasonCtrl.text = r;
                              _error = null;
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('remake_reason_input'),
                  controller: _reasonCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('reason_required'),
                    hintText: 'Ex: Plat froid / Erreur commande / Geste VIP',
                  ),
                ),
                if (needsPin) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('remake_manager_pin_input'),
                    controller: _pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    onTap: () => showTouchNumpad(
                      context: context,
                      controller: _pinCtrl,
                      title: i18n.t('manager_pin_required'),
                      suffix: '',
                      obscure: true,
                    ),
                    decoration: InputDecoration(
                      labelText: i18n.t('manager_pin_required'),
                      hintText: '0000 / 9999',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: TextStyle(
                          color: p.danger, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(i18n.t('cancel')),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      key: const Key('confirm_remake_btn'),
                      onPressed: _submit,
                      child: Text(i18n.t('confirm')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
