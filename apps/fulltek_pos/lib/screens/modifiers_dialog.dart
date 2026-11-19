import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../theme/fulltek_themes.dart';

class ModifiersDialog extends StatefulWidget {
  final MenuItem item;
  final String lang;
  const ModifiersDialog({super.key, required this.item, required this.lang});

  @override
  State<ModifiersDialog> createState() => _ModifiersDialogState();
}

class _ModifiersDialogState extends State<ModifiersDialog> {
  final Map<String, Set<String>> _selected = {};
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final g in widget.item.modifiers) {
      if (g.required && g.options.isNotEmpty) {
        _selected[g.id] = {g.options.first.id};
      } else {
        _selected[g.id] = {};
      }
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<SelectedModifier> _buildSelectedList() {
    final result = <SelectedModifier>[];
    for (final g in widget.item.modifiers) {
      final chosen = _selected[g.id] ?? {};
      for (final opt in g.options) {
        if (chosen.contains(opt.id)) {
          result.add(SelectedModifier.fromOption(group: g, option: opt));
        }
      }
    }
    return result;
  }

  double get _extraTotal =>
      _buildSelectedList().fold(0.0, (s, m) => s + m.extraPriceMru);

  bool get _allRequiredSatisfied => widget.item.modifiers.every(
        (g) => !g.required || (_selected[g.id]?.isNotEmpty ?? false),
      );

  @override
  Widget build(BuildContext context) {
    final p = FullTekThemes.paletteOf(context);
    final total = widget.item.priceMru + _extraTotal;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(p.radius + 4),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(widget.item.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.label(widget.lang),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: p.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.item.priceMru.toStringAsFixed(0)} MRU',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: p.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: p.border),
              const SizedBox(height: 8),
              ...widget.item.modifiers.map((g) {
                final chosen = _selected[g.id] ?? {};
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            g.label(widget.lang),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (g.required)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: p.warning.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Requis',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: p.warning,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: g.options.map((opt) {
                          final sel = chosen.contains(opt.id);
                          final extra = opt.extraPriceMru > 0
                              ? ' (+${opt.extraPriceMru.toStringAsFixed(0)} MRU)'
                              : '';
                          return FilterChip(
                            key: Key('mod_opt_${g.id}_${opt.id}'),
                            selected: sel,
                            label: Text('${opt.label(widget.lang)}$extra'),
                            onSelected: (val) {
                              setState(() {
                                final next = Set<String>.from(chosen);
                                if (g.multiSelect) {
                                  if (val) {
                                    next.add(opt.id);
                                  } else {
                                    next.remove(opt.id);
                                  }
                                } else {
                                  next
                                    ..clear()
                                    ..add(opt.id);
                                }
                                _selected[g.id] = next;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
              TextField(
                key: const Key('modifier_note_input'),
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note cuisine (optionnel)',
                  hintText: 'Ex: Sans piment, sauce à part...',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('confirm_modifiers_btn'),
                onPressed: _allRequiredSatisfied
                    ? () => Navigator.of(context).pop({
                          'modifiers': _buildSelectedList(),
                          'note': _noteCtrl.text.trim(),
                        })
                    : null,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text('Ajouter · ${total.toStringAsFixed(0)} MRU'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
