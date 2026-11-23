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
  String _type = 'remake';
  String? _lineId;
  final TextEditingController _reasonCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final items = widget.store.activeOrder?.items ?? const [];
    if (items.isNotEmpty) {
      _lineId = items.first.lineId;
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_lineId == null) return;
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = widget.store.i18n.t('reason_required'));
      return;
    }
    final ok = widget.store.recordReturnRemakeComp(
      lineId: _lineId!,
      type: _type,
      reason: _reasonCtrl.text.trim(),
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

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                i18n.t('remake_title'),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(i18n.t('type_remake')),
                    selected: _type == 'remake',
                    onSelected: (_) => setState(() => _type = 'remake'),
                  ),
                  ChoiceChip(
                    label: Text(i18n.t('type_return')),
                    selected: _type == 'return',
                    onSelected: (_) => setState(() => _type = 'return'),
                  ),
                  ChoiceChip(
                    label: Text(i18n.t('type_comp')),
                    selected: _type == 'comp',
                    onSelected: (_) => setState(() => _type = 'comp'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _lineId,
                items: items
                    .map((l) => DropdownMenuItem(
                          value: l.lineId,
                          child: Text(
                              '${l.quantity}x ${l.item.label(widget.store.lang)}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _lineId = v),
              ),
              const SizedBox(height: 12),
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
    );
  }
}
