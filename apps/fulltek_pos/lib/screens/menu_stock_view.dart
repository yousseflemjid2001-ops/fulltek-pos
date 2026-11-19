import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class MenuStockView extends StatefulWidget {
  final PosStore store;
  const MenuStockView({super.key, required this.store});

  @override
  State<MenuStockView> createState() => _MenuStockViewState();
}

class _MenuStockViewState extends State<MenuStockView> {
  int _subTab = 0; // 0 = Menu & Prix, 1 = Stock & Ingrédients
  String _query = '';
  bool _elevatedByPin = false;

  bool get _canEdit =>
      widget.store.canCurrent(PosPermission.voidOrComp) || _elevatedByPin;

  Future<void> _requestManagerElevation() async {
    final ctrl = TextEditingController();
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Autorisation Gérant / Propriétaire'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Code PIN Manager',
              errorText: err,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(widget.store.i18n.t('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final mgr = widget.store.verifyManagerPin(ctrl.text);
                if (mgr == null) {
                  setD(() => err = 'PIN Manager invalide.');
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: Text(widget.store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (ok == true && mounted) {
      setState(() => _elevatedByPin = true);
    }
  }

  Future<void> _openDishDialog({MenuItem? existing}) async {
    final store = widget.store;
    final frCtrl = TextEditingController(text: existing?.nameFr ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.priceMru.toStringAsFixed(0) : '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🍽');
    String catId = existing?.categoryId ??
        (store.categories.isNotEmpty ? store.categories.first.id : 'cat-1');
    String station = existing?.kitchenStation ?? 'KITCHEN';
    bool isTop = existing?.isTop ?? false;
    bool available = existing?.available ?? true;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Nouveau plat' : 'Modifier le plat'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(err!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: iconCtrl,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Icône'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('dish_name_fr_input'),
                          controller: frCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Nom (Français) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('dish_name_ar_input'),
                    controller: arCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nom (Arabe / عربي)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('dish_price_input'),
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Prix (MRU) *',
                            suffixText: 'MRU',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: station,
                          decoration:
                              const InputDecoration(labelText: 'Poste cuisine'),
                          items: const [
                            DropdownMenuItem(
                                value: 'KITCHEN', child: Text('Cuisine')),
                            DropdownMenuItem(
                                value: 'GRILL', child: Text('Grill')),
                            DropdownMenuItem(value: 'BAR', child: Text('Bar')),
                          ],
                          onChanged: (v) {
                            if (v != null) setD(() => station = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (store.categories.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue:
                          store.categories.any((c) => c.id == catId)
                              ? catId
                              : store.categories.first.id,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: store.categories
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.icon} ${c.label(store.lang)}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setD(() => catId = v);
                      },
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Plat vedette (Badge TOP)'),
                    value: isTop,
                    onChanged: (v) => setD(() => isTop = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disponible en caisse'),
                    value: available,
                    onChanged: (v) => setD(() => available = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('save_dish_btn'),
              onPressed: () async {
                final price = double.tryParse(priceCtrl.text.trim());
                if (frCtrl.text.trim().isEmpty || price == null || price < 0) {
                  setD(() => err = 'Veuillez saisir un nom et un prix valide.');
                  return;
                }
                final res = await store.saveMenuItem(
                  existingId: existing?.id,
                  nameFr: frCtrl.text.trim(),
                  nameAr: arCtrl.text.trim(),
                  categoryId: catId,
                  priceMru: price,
                  kitchenStation: station,
                  iconEmoji: iconCtrl.text.trim().isEmpty
                      ? '🍽'
                      : iconCtrl.text.trim(),
                  isTop: isTop,
                  available: available,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    frCtrl.dispose();
    arCtrl.dispose();
    priceCtrl.dispose();
    iconCtrl.dispose();
  }

  Future<void> _openNewIngredientDialog() async {
    final store = widget.store;
    final frCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'kg');
    final stockCtrl = TextEditingController(text: '10');
    final minCtrl = TextEditingController(text: '3');
    final costCtrl = TextEditingController(text: '200');
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouvel ingrédient (Stock)'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (err != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(err!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  TextField(
                    key: const Key('ing_name_input'),
                    controller: frCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nom ingrédient (ex: Poulet) *'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Unité (kg, L, pièce)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Coût achat (MRU)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Stock initial'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Seuil alerte'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(store.i18n.t('cancel')),
            ),
            ElevatedButton(
              key: const Key('save_ing_btn'),
              onPressed: () async {
                final res = await store.addIngredient(
                  nameFr: frCtrl.text.trim(),
                  unit: unitCtrl.text.trim(),
                  currentStock: double.tryParse(stockCtrl.text.trim()) ?? 0,
                  minThreshold: double.tryParse(minCtrl.text.trim()) ?? 0,
                  pmpCostMru: double.tryParse(costCtrl.text.trim()) ?? 0,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    frCtrl.dispose();
    unitCtrl.dispose();
    stockCtrl.dispose();
    minCtrl.dispose();
    costCtrl.dispose();
  }

  Future<void> _openRestockDialog(Ingredient ing, {bool adjustMode = false}) async {
    final store = widget.store;
    final qtyCtrl = TextEditingController(
      text: adjustMode ? ing.currentStock.toStringAsFixed(1) : '10',
    );
    final costCtrl = TextEditingController(
      text: ing.pmpCostMru.toStringAsFixed(0),
    );
    final minCtrl = TextEditingController(
      text: ing.minStock.toStringAsFixed(1),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(adjustMode
            ? 'Ajuster inventaire · ${ing.nameFr}'
            : 'Entrée de stock · ${ing.nameFr}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stock actuel : ${ing.currentStock.toStringAsFixed(2)} ${ing.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('restock_qty_input'),
              controller: qtyCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: adjustMode
                    ? 'Nouveau stock exact (${ing.unit})'
                    : 'Quantité ajoutée (${ing.unit})',
              ),
            ),
            if (!adjustMode) ...[
              const SizedBox(height: 10),
              TextField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Prix d\'achat unitaire (MRU)',
                  helperText: 'Recalcule automatiquement le coût PMP',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: minCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Seuil d\'alerte minimum (${ing.unit})',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(store.i18n.t('cancel')),
          ),
          ElevatedButton(
            key: const Key('confirm_restock_btn'),
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0;
              final cost = double.tryParse(costCtrl.text.trim());
              final minT = double.tryParse(minCtrl.text.trim());
              await store.restockIngredient(
                ingredientId: ing.id,
                deltaQty: adjustMode ? null : qty,
                newStock: adjustMode ? qty : null,
                unitCostMru: adjustMode ? null : cost,
                minThreshold: minT,
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(store.i18n.t('confirm')),
          ),
        ],
      ),
    );
    qtyCtrl.dispose();
    costCtrl.dispose();
    minCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);

    if (!_canEdit) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_person_rounded, size: 48, color: p.warning),
              const SizedBox(height: 12),
              Text(
                'Gestion Menu & Stock réservée au Gérant / Propriétaire',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('unlock_menu_stock_btn'),
                onPressed: _requestManagerElevation,
                icon: const Icon(Icons.key_rounded),
                label: const Text('Déverrouiller avec PIN Gérant'),
              ),
            ],
          ),
        ),
      );
    }

    final q = _query.trim().toLowerCase();
    final filteredMenu = store.menuItems.where((m) {
      if (q.isEmpty) return true;
      return m.nameFr.toLowerCase().contains(q) ||
          m.nameAr.contains(q) ||
          m.sku.toLowerCase().contains(q);
    }).toList();

    final filteredIngredients = store.ingredients.where((i) {
      if (q.isEmpty) return true;
      return i.nameFr.toLowerCase().contains(q) ||
          i.nameAr.contains(q) ||
          i.sku.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.restaurant_menu_rounded, size: 17),
                    label: Text('Menu & Prix (${store.menuItems.length})'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.inventory_2_rounded, size: 17),
                    label: Text(
                      'Stock & Achats (${store.ingredients.length})',
                    ),
                  ),
                ],
                selected: {_subTab},
                onSelectionChanged: (s) => setState(() => _subTab = s.first),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    key: Key(_subTab == 0 ? 'add_dish_btn' : 'add_ing_btn'),
                    onPressed: _subTab == 0
                        ? () => _openDishDialog()
                        : _openNewIngredientDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                        _subTab == 0 ? 'Nouveau plat' : 'Nouvel ingrédient'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _subTab == 0
                ? _buildMenuList(filteredMenu, store, p)
                : _buildIngredientsList(filteredIngredients, store, p),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(List<MenuItem> items, PosStore store, PosPalette p) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final m = items[idx];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: m.available ? p.border : p.danger),
          ),
          child: Row(
            children: [
              Text(m.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.nameFr}  ·  ${m.nameAr}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      '${m.kitchenStation} · SKU: ${m.sku}',
                      style: TextStyle(fontSize: 11.5, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '${m.priceMru.toStringAsFixed(0)} MRU',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: p.primary,
                ),
              ),
              const SizedBox(width: 10),
              Switch(
                value: m.available,
                onChanged: (v) =>
                    store.toggleItemAvailability(m.id, available: v),
              ),
              IconButton(
                key: Key('edit_dish_${m.id}'),
                tooltip: 'Modifier',
                onPressed: () => _openDishDialog(existing: m),
                icon: Icon(Icons.edit_rounded, color: p.textPrimary, size: 19),
              ),
              IconButton(
                key: Key('delete_dish_${m.id}'),
                tooltip: 'Supprimer',
                onPressed: () => store.deleteMenuItem(m.id),
                icon: Icon(Icons.delete_outline_rounded,
                    color: p.danger, size: 19),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIngredientsList(
      List<Ingredient> list, PosStore store, PosPalette p) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final ing = list[idx];
        final low = ing.isLowStock;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: low ? p.danger : p.border),
          ),
          child: Row(
            children: [
              Icon(
                low ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                color: low ? p.danger : p.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ing.nameFr}  ·  ${ing.nameAr}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'Seuil min: ${ing.minStock.toStringAsFixed(1)} ${ing.unit} · Coût PMP: ${ing.pmpCostMru.toStringAsFixed(0)} MRU/${ing.unit}',
                      style: TextStyle(fontSize: 11.5, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (low ? p.danger : p.success).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${ing.currentStock.toStringAsFixed(2)} ${ing.unit}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: low ? p.danger : p.success,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                key: Key('restock_ing_${ing.id}'),
                onPressed: () => _openRestockDialog(ing, adjustMode: false),
                icon: const Icon(Icons.add_box_rounded, size: 16),
                label: const Text('+ Entrée'),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                key: Key('adjust_ing_${ing.id}'),
                onPressed: () => _openRestockDialog(ing, adjustMode: true),
                child: const Text('Ajuster'),
              ),
            ],
          ),
        );
      },
    );
  }
}
