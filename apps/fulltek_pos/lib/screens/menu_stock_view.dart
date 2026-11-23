import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';
import '../widgets/dish_image.dart';

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

  Future<void> _openCategoryDialog({MenuCategory? existing}) async {
    final store = widget.store;
    final frCtrl = TextEditingController(text: existing?.nameFr ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🍽');
    final imgCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    const presetImages = <String, String>{
      'Plats': 'assets/images/menu/resto_thieboudienne.jpg',
      'Grillades': 'assets/images/menu/resto_mechoui.jpg',
      'Burger/Sandwich': 'assets/images/menu/burger_chameau.jpg',
      'Poulet': 'assets/images/menu/poulet_braise.jpg',
      'Pizza/Snack': 'assets/images/menu/chawarma_royal.jpg',
      'Salades': 'assets/images/menu/salade_fattouch.jpg',
      'Boissons': 'assets/images/menu/jus_bissap.jpg',
      'Thé/Café': 'assets/images/menu/resto_atay.jpg',
      'Desserts': 'assets/images/menu/resto_dattes.jpg',
    };
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? 'Nouvelle famille / catégorie'
              : 'Modifier la famille & son image'),
          content: SizedBox(
            width: 410,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        width: 68,
                        child: TextField(
                          controller: iconCtrl,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Icône'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('category_name_fr_input'),
                          controller: frCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                              labelText: 'Nom (Français) *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('category_name_ar_input'),
                    controller: arCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nom (Arabe / عربي)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('category_image_input'),
                    controller: imgCtrl,
                    onChanged: (_) => setD(() {}),
                    decoration: InputDecoration(
                      labelText: 'Image de la catégorie (URL ou Galerie)',
                      prefixIcon: const Icon(Icons.image_outlined, size: 18),
                      suffixIcon: imgCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setD(() => imgCtrl.clear()),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Galerie d\'images rapides :',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presetImages.entries.map((e) {
                      final selected = imgCtrl.text.trim() == e.value;
                      return ChoiceChip(
                        label:
                            Text(e.key, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => setD(() => imgCtrl.text = e.value),
                      );
                    }).toList(),
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
              key: const Key('save_category_btn'),
              onPressed: () async {
                if (frCtrl.text.trim().isEmpty) {
                  setD(() => err = 'Veuillez saisir un nom de famille.');
                  return;
                }
                final res = await store.saveCategory(
                  existingId: existing?.id,
                  nameFr: frCtrl.text.trim(),
                  nameAr: arCtrl.text.trim(),
                  icon: iconCtrl.text.trim().isEmpty
                      ? '🍽'
                      : iconCtrl.text.trim(),
                  imageUrl: imgCtrl.text.trim(),
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
    iconCtrl.dispose();
    imgCtrl.dispose();
  }

  Future<void> _openFamiliesManagerDialog() async {
    final store = widget.store;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Familles / Catégories'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: ListView.separated(
              itemCount: store.categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, idx) {
                final c = store.categories[idx];
                final isDefault = c.id == 'sans-famille';
                final count = store.menuItems
                    .where((m) => m.categoryId == c.id)
                    .length;
                return ListTile(
                  dense: true,
                  leading: Text(c.icon, style: const TextStyle(fontSize: 20)),
                  title: Text(c.label(store.lang)),
                  subtitle: Text('$count article(s)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Renommer',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          await _openCategoryDialog(existing: c);
                          setD(() {});
                        },
                      ),
                      if (!isDefault)
                        IconButton(
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          onPressed: () async {
                            await store.deleteCategory(c.id);
                            setD(() {});
                          },
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await _openCategoryDialog();
                setD(() {});
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouvelle famille'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDishDialog({MenuItem? existing}) async {
    final store = widget.store;
    final frCtrl = TextEditingController(text: existing?.nameFr ?? '');
    final arCtrl = TextEditingController(text: existing?.nameAr ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.priceMru.toStringAsFixed(0) : '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🍽');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    const presetPhotos = <String, String>{
      'Thiéboudienne': 'assets/images/menu/resto_thieb.jpg',
      'Méchoui': 'assets/images/menu/resto_mechoui.jpg',
      'Mix Grill': 'assets/images/menu/mix_grill.jpg',
      'Brochettes': 'assets/images/menu/resto_brochettes.jpg',
      'Chawarma': 'assets/images/menu/chawarma.jpg',
      'Poisson': 'assets/images/menu/poisson_braise.jpg',
      'Salade': 'assets/images/menu/salade_fattouch.jpg',
      'Atay': 'assets/images/menu/resto_atay.jpg',
      'Jus Bissap': 'assets/images/menu/jus_bissap.jpg',
      'Dattes': 'assets/images/menu/resto_dattes.jpg',
    };
    String catId = existing?.categoryId ??
        (store.categories.isNotEmpty
            ? store.categories.first.id
            : 'sans-famille');
    const stationItems = <DropdownMenuItem<String>>[
      DropdownMenuItem(value: 'KITCHEN', child: Text('Cuisine')),
      DropdownMenuItem(value: 'GRILL', child: Text('Grill')),
      DropdownMenuItem(value: 'BAR', child: Text('Bar')),
      DropdownMenuItem(value: 'POULET', child: Text('Poulet')),
      DropdownMenuItem(value: 'PIZZA', child: Text('Pizza')),
      DropdownMenuItem(value: 'SNACK', child: Text('Snack')),
      DropdownMenuItem(value: 'TRADITIONAL', child: Text('Traditionnel')),
    ];
    String station = existing?.kitchenStation ?? 'KITCHEN';
    if (!stationItems.any((e) => e.value == station)) {
      station = 'KITCHEN';
    }
    bool isTop = existing?.isTop ?? false;
    bool available = existing?.available ?? true;
    bool manualPrice = existing?.manualPrice ?? false;
    final modGroups = List<ModifierGroup>.from(existing?.modifiers ?? const []);
    final modNameCtrl = TextEditingController();
    final modPriceCtrl = TextEditingController(text: '0');
    String modGroupLabel = 'Suppléments';
    bool modRequired = false;
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
                          key: const Key('dish_station_dropdown'),
                          initialValue: station,
                          decoration: const InputDecoration(
                              labelText: 'Département préparation'),
                          items: stationItems,
                          onChanged: (v) {
                            if (v != null) setD(() => station = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (store.categories.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const Key('dish_category_dropdown'),
                            initialValue:
                                store.categories.any((c) => c.id == catId)
                                    ? catId
                                    : store.categories.first.id,
                            decoration: const InputDecoration(
                                labelText: 'Famille / Catégorie'),
                            items: store.categories
                                .map((c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(
                                          '${c.icon} ${c.label(store.lang)}'),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setD(() => catId = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Ajouter / Renommer des familles',
                          child: OutlinedButton(
                            key: const Key('manage_families_inline_btn'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(44, 48),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () async {
                              await _openFamiliesManagerDialog();
                              setD(() {
                                if (!store.categories
                                        .any((c) => c.id == catId) &&
                                    store.categories.isNotEmpty) {
                                  catId = store.categories.first.id;
                                }
                              });
                            },
                            child: const Text('...'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: DishImage(
                          imageUrl: imageCtrl.text.trim(),
                          fallbackIcon: iconCtrl.text.trim(),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: imageCtrl,
                          onChanged: (_) => setD(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Photo du plat (URL ou asset)',
                            hintText: 'https://... ou assets/images/menu/...',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: presetPhotos.entries.map((e) {
                        final selected = imageCtrl.text.trim() == e.value;
                        return ChoiceChip(
                          label: Text(e.key, style: const TextStyle(fontSize: 11)),
                          selected: selected,
                          onSelected: (_) =>
                              setD(() => imageCtrl.text = e.value),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('dish_manual_price_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Saisie prix manuel en caisse (MRU)'),
                    subtitle: const Text(
                        'Demande le montant au caissier à chaque ajout'),
                    value: manualPrice,
                    onChanged: (v) => setD(() => manualPrice = v),
                  ),
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
                  const Divider(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Suppléments & Options (ex: +Fromage, Taille, Sauce)',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: modGroupLabel,
                          isDense: true,
                          decoration:
                              const InputDecoration(labelText: 'Groupe'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Suppléments',
                                child: Text('Suppléments (Multiple)')),
                            DropdownMenuItem(
                                value: 'Taille',
                                child: Text('Taille (Choix unique)')),
                            DropdownMenuItem(
                                value: 'Sauces',
                                child: Text('Sauces (Multiple)')),
                            DropdownMenuItem(
                                value: 'Cuisson',
                                child: Text('Cuisson (Choix unique)')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setD(() {
                              modGroupLabel = v;
                              modRequired =
                                  (v == 'Taille' || v == 'Cuisson');
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          key: const Key('dish_mod_name_input'),
                          controller: modNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Option (ex: +Mozzarella)',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          key: const Key('dish_mod_price_input'),
                          controller: modPriceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '+ MRU',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        key: const Key('dish_mod_add_btn'),
                        tooltip: 'Ajouter le supplément',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () {
                          final optName = modNameCtrl.text.trim();
                          if (optName.isEmpty) return;
                          final extra =
                              double.tryParse(modPriceCtrl.text.trim()) ?? 0;
                          final isMulti = modGroupLabel == 'Suppléments' ||
                              modGroupLabel == 'Sauces';
                          final groupId =
                              'grp-${modGroupLabel.toLowerCase().replaceAll(' ', '-')}';
                          final newOpt = ModifierOption(
                            id: 'opt-${DateTime.now().millisecondsSinceEpoch % 100000}',
                            nameFr: optName,
                            nameAr: optName,
                            nameEn: optName,
                            extraPriceMru: extra < 0 ? 0 : extra,
                          );
                          setD(() {
                            final gIdx =
                                modGroups.indexWhere((g) => g.id == groupId);
                            if (gIdx != -1) {
                              final g = modGroups[gIdx];
                              modGroups[gIdx] = ModifierGroup(
                                id: g.id,
                                nameFr: g.nameFr,
                                nameAr: g.nameAr,
                                nameEn: g.nameEn,
                                required: g.required,
                                multiSelect: g.multiSelect,
                                options: [...g.options, newOpt],
                              );
                            } else {
                              modGroups.add(
                                ModifierGroup(
                                  id: groupId,
                                  nameFr: modGroupLabel,
                                  nameAr: modGroupLabel,
                                  nameEn: modGroupLabel,
                                  required: modRequired,
                                  multiSelect: isMulti,
                                  options: [newOpt],
                                ),
                              );
                            }
                            modNameCtrl.clear();
                            modPriceCtrl.text = '0';
                          });
                        },
                      ),
                    ],
                  ),
                  if (modGroups.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (int gi = 0; gi < modGroups.length; gi++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${modGroups[gi].nameFr} (${modGroups[gi].multiSelect ? 'multiple' : 'unique'})',
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: modGroups[gi].options.map((opt) {
                                final pStr = opt.extraPriceMru > 0
                                    ? ' (+${opt.extraPriceMru.toStringAsFixed(0)} MRU)'
                                    : '';
                                return InputChip(
                                  label: Text('${opt.nameFr}$pStr',
                                      style: const TextStyle(fontSize: 11.5)),
                                  onDeleted: () {
                                    setD(() {
                                      final g = modGroups[gi];
                                      final nextOpts = g.options
                                          .where((o) => o.id != opt.id)
                                          .toList();
                                      if (nextOpts.isEmpty) {
                                        modGroups.removeAt(gi);
                                      } else {
                                        modGroups[gi] = ModifierGroup(
                                          id: g.id,
                                          nameFr: g.nameFr,
                                          nameAr: g.nameAr,
                                          nameEn: g.nameEn,
                                          required: g.required,
                                          multiSelect: g.multiSelect,
                                          options: nextOpts,
                                        );
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
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
                  imageUrl: imageCtrl.text.trim(),
                  isTop: isTop,
                  available: available,
                  manualPrice: manualPrice,
                  modifiers: modGroups,
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
    imageCtrl.dispose();
    modNameCtrl.dispose();
    modPriceCtrl.dispose();
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
                  ButtonSegment(
                    value: 2,
                    icon: const Icon(Icons.category_rounded, size: 17),
                    label: Text('Familles (${store.categories.length})'),
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
                    key: Key(_subTab == 0
                        ? 'add_dish_btn'
                        : _subTab == 1
                            ? 'add_ing_btn'
                            : 'add_family_btn'),
                    onPressed: _subTab == 0
                        ? () => _openDishDialog()
                        : _subTab == 1
                            ? _openNewIngredientDialog
                            : () => _openCategoryDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(_subTab == 0
                        ? 'Nouveau plat'
                        : _subTab == 1
                            ? 'Nouvel ingrédient'
                            : 'Nouvelle famille'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _subTab == 0
                ? _buildMenuList(filteredMenu, store, p)
                : _subTab == 1
                    ? _buildIngredientsList(filteredIngredients, store, p)
                    : _buildCategoriesList(store, p),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(PosStore store, PosPalette p) {
    final q = _query.trim().toLowerCase();
    final cats = store.categories.where((c) {
      if (q.isEmpty) return true;
      return c.nameFr.toLowerCase().contains(q) || c.nameAr.contains(q);
    }).toList();
    return ListView.separated(
      itemCount: cats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final c = cats[idx];
        final isDefault = c.id == 'sans-famille';
        final count = store.menuItems.where((m) => m.categoryId == c.id).length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Text(c.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.label(store.lang),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      '$count article(s)${isDefault ? ' • Famille par défaut' : ''}',
                      style: TextStyle(color: p.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('edit_family_${c.id}'),
                tooltip: 'Renommer',
                onPressed: () => _openCategoryDialog(existing: c),
                icon: const Icon(Icons.edit_outlined),
              ),
              if (!isDefault)
                IconButton(
                  key: Key('delete_family_${c.id}'),
                  tooltip: 'Supprimer',
                  onPressed: () => store.deleteCategory(c.id),
                  icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                ),
            ],
          ),
        );
      },
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
              SizedBox(
                width: 48,
                height: 48,
                child: DishImage(
                  imageUrl: m.imageUrl,
                  fallbackIcon: m.icon,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: p.surfaceAlt,
                  fallbackFontSize: 22,
                ),
              ),
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
