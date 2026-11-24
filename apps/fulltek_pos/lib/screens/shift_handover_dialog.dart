import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/touch_numpad.dart';
import 'checkout_dialog.dart';

/// Opens the "Transfert Service (Passation Caissier / Serveur)" dialog:
/// Allows outgoing morning staff to transfer all open/waiting tables & orders
/// to incoming evening staff in 1 tap before printing their X-Report.
Future<void> showShiftHandoverDialog(
  BuildContext context,
  PosStore store,
) async {
  final p = FullTekThemes.paletteOf(context);
  final activeStaff = store.staff.where((s) => s.isActive).toList();
  if (activeStaff.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Il faut au moins 2 membres d\'équipe actifs pour effectuer un transfert de service.',
        ),
      ),
    );
    return;
  }

  int mode = 0; // 0 = Caissier -> Caissier, 1 = Serveur -> Serveur
  String fromName = store.currentStaff?.name ?? activeStaff.first.name;
  if (!activeStaff.any((s) => s.name == fromName)) {
    fromName = activeStaff.first.name;
  }
  String toName = activeStaff
      .firstWhere((s) => s.name != fromName, orElse: () => activeStaff.last)
      .name;
  final pinCtrl = TextEditingController();
  String? pinError;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final waitingForFrom = mode == 0
            ? store.waitingOrders
                .where((o) =>
                    (o.cashierName ?? o.staffName).trim().toLowerCase() ==
                    fromName.trim().toLowerCase())
                .length
            : store.waitingOrders
                .where((o) =>
                    (o.serverName ?? o.staffName).trim().toLowerCase() ==
                    fromName.trim().toLowerCase())
                .length;

        return AlertDialog(
          backgroundColor: p.surface,
          title: Row(
            children: [
              Icon(Icons.swap_horizontal_circle_rounded,
                  color: p.primary, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Transfert de Service (Passation)',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
                ),
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
                  'Transférez les tables et commandes en cours vers l\'équipe entrante avant de sortir le Rapport X.',
                  style: TextStyle(fontSize: 12.5, color: p.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('shift_mode_cashier'),
                        label: const Text('💼 Caissier → Caissier'),
                        selected: mode == 0,
                        onSelected: (_) => setD(() => mode = 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('shift_mode_server'),
                        label: const Text('🍽 Serveur → Serveur'),
                        selected: mode == 1,
                        onSelected: (_) => setD(() => mode = 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: const Key('shift_from_dropdown'),
                  initialValue: fromName,
                  decoration: InputDecoration(
                    labelText: mode == 0
                        ? 'Caissier sortant (équipe matin)'
                        : 'Serveur sortant (équipe matin)',
                    prefixIcon: const Icon(Icons.logout_rounded),
                  ),
                  items: activeStaff
                      .map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text('${s.name} (${s.role.label(store.lang)})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setD(() {
                        fromName = v;
                        if (toName == fromName) {
                          toName = activeStaff
                              .firstWhere((s) => s.name != fromName,
                                  orElse: () => activeStaff.first)
                              .name;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('shift_to_dropdown'),
                  initialValue: toName,
                  decoration: InputDecoration(
                    labelText: mode == 0
                        ? 'Caissier entrant (équipe soir)'
                        : 'Serveur entrant (équipe soir)',
                    prefixIcon: const Icon(Icons.login_rounded),
                  ),
                  items: activeStaff
                      .where((s) => s.name != fromName)
                      .map((s) => DropdownMenuItem(
                            value: s.name,
                            child: Text('${s.name} (${s.role.label(store.lang)})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => toName = v);
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    waitingForFrom > 0
                        ? '📋 $waitingForFrom table(s) / commande(s) en cours de $fromName seront transférées à $toName.'
                        : 'Aucune table en cours actuellement attribuée à $fromName.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: waitingForFrom > 0 ? p.primary : p.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('shift_receiver_pin_input'),
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  onTap: () => showTouchNumpad(
                    context: ctx,
                    controller: pinCtrl,
                    title: 'Code PIN de $toName (validation)',
                    suffix: '',
                    obscure: true,
                    onChanged: () => setD(() => pinError = null),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Code PIN de $toName (ou Gérant) *',
                    hintText: 'Validation obligatoire du destinataire',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: const Icon(Icons.dialpad_rounded, size: 20),
                    errorText: pinError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton.icon(
              key: const Key('confirm_shift_transfer_btn'),
              onPressed: waitingForFrom == 0
                  ? null
                  : () {
                      final enteredPin = pinCtrl.text.trim();
                      final receiver = activeStaff
                          .where((s) => s.name == toName)
                          .firstOrNull;
                      final validReceiverPin = receiver != null &&
                          enteredPin.isNotEmpty &&
                          receiver.pinCode == enteredPin;
                      final validManagerPin = enteredPin.isNotEmpty &&
                          store.verifyManagerPin(enteredPin) != null;
                      if (!validReceiverPin && !validManagerPin) {
                        setD(() => pinError =
                            'Code PIN invalide : saisissez le PIN de $toName ou d\'un gérant.');
                        return;
                      }
                      final moved = mode == 0
                          ? store.transferShiftCashier(fromName, toName)
                          : store.transferShiftServer(fromName, toName);
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ $moved table(s)/commande(s) transférée(s) de $fromName vers $toName (validé par PIN).',
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text('Valider & Transférer ($waitingForFrom)'),
            ),
          ],
        );
      },
    ),
  );
  pinCtrl.dispose();
}

/// Opens the "Rapport X (X Caissier / X Général)" selector & 80mm preview.
Future<void> showReportXDialog(
  BuildContext context,
  PosStore store,
) async {
  final p = FullTekThemes.paletteOf(context);
  final activeStaff = store.staff.where((s) => s.isActive).toList();
  String selectedScope = store.currentStaff?.name ?? '__ALL__';
  if (selectedScope != '__ALL__' &&
      !activeStaff.any((s) => s.name == selectedScope)) {
    selectedScope = '__ALL__';
  }

  final chosen = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        backgroundColor: p.surface,
        title: Row(
          children: [
            Icon(Icons.assessment_outlined, color: p.accent, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Rapport X (Lecture sans clôture)',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Affiche et imprime le bilan intermédiaire sans remettre les compteurs à zéro.',
                style: TextStyle(fontSize: 12.5, color: p.textMuted),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('report_x_scope_dropdown'),
                initialValue: selectedScope,
                decoration: const InputDecoration(
                  labelText: 'Périmètre du Rapport X',
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '__ALL__',
                    child: Text('📊 X Général (Toute la caisse)'),
                  ),
                  ...activeStaff.map(
                    (s) => DropdownMenuItem(
                      value: s.name,
                      child: Text('👤 X Caissier · ${s.name}'),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setD(() => selectedScope = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(store.i18n.t('cancel')),
          ),
          ElevatedButton.icon(
            key: const Key('print_report_x_btn'),
            onPressed: () => Navigator.of(ctx).pop(selectedScope),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Afficher / Imprimer X'),
          ),
        ],
      ),
    ),
  );

  if (chosen != null && context.mounted) {
    final text = store.generateReportX80mm(
      staffName: chosen == '__ALL__' ? null : chosen,
    );
    showReceiptPreviewDialog(
      context,
      title: chosen == '__ALL__'
          ? '📄 Rapport X Général'
          : '📄 Rapport X Caissier · $chosen',
      subtitle: 'Lecture intermédiaire — Compteurs non remis à zéro',
      receiptText: text,
    );
  }
}
