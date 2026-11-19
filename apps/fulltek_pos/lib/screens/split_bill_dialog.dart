import 'package:flutter/material.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class SplitBillDialog extends StatefulWidget {
  final PosStore store;
  const SplitBillDialog({super.key, required this.store});

  @override
  State<SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<SplitBillDialog> {
  bool _byItems = true;
  int _guestsCount = 2;
  final Set<String> _selectedLineIds = {};

  @override
  Widget build(BuildContext context) {
    final i18n = widget.store.i18n;
    final p = FullTekThemes.paletteOf(context);
    final order = widget.store.activeOrder;
    if (order == null || order.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final perGuest = order.netTotal / _guestsCount;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                i18n.t('split_bill'),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Text(i18n.t('split_by_items')),
                      selected: _byItems,
                      onSelected: (_) => setState(() => _byItems = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: Text(i18n.t('split_equal')),
                      selected: !_byItems,
                      onSelected: (_) => setState(() => _byItems = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_byItems) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: order.items.map((line) {
                      final checked = _selectedLineIds.contains(line.lineId);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedLineIds.add(line.lineId);
                            } else {
                              _selectedLineIds.remove(line.lineId);
                            }
                          });
                        },
                        title: Text(
                            '${line.quantity}x ${line.item.label(widget.store.lang)}'),
                        subtitle:
                            Text('${line.lineTotal.toStringAsFixed(0)} MRU'),
                      );
                    }).toList(),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _guestsCount > 2
                          ? () => setState(() => _guestsCount--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '$_guestsCount ${i18n.t('guests')}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _guestsCount++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${perGuest.toStringAsFixed(0)} ${i18n.t('mru')} / pers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: p.primary),
                  ),
                ),
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
                    key: const Key('confirm_split_btn'),
                    onPressed: _byItems
                        ? (_selectedLineIds.isNotEmpty &&
                                _selectedLineIds.length < order.items.length
                            ? () {
                                final sub = widget.store
                                    .splitSelectedLines(_selectedLineIds);
                                Navigator.of(context).pop(sub != null);
                              }
                            : null)
                        : () => Navigator.of(context).pop(false),
                    child: Text(i18n.t('confirm')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
