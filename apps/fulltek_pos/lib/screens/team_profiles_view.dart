import 'package:flutter/material.dart';
import '../models/pos_models.dart';
import '../state/pos_store.dart';
import '../theme/fulltek_themes.dart';

class TeamProfilesView extends StatefulWidget {
  final PosStore store;
  const TeamProfilesView({super.key, required this.store});

  @override
  State<TeamProfilesView> createState() => _TeamProfilesViewState();
}

class _TeamProfilesViewState extends State<TeamProfilesView> {
  int _subTab = 0; // 0 = Profils & Droits, 1 = Utilisateurs & Badges
  String? _selectedProfileId;

  Future<void> _openNewProfileDialog() async {
    final store = widget.store;
    final nameCtrl = TextEditingController();
    PosRole baseRole = PosRole.cashier;
    final selectedPerms = Set<PosPermission>.from(
      RbacMatrix.grants[PosRole.cashier] ?? const {},
    );
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouveau profil d\'accès'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
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
                    key: const Key('new_profile_name_input'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du profil *',
                      hintText: 'Ex: Caissier Superviseur, Serveur Soir...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PosRole>(
                    initialValue: baseRole,
                    decoration: const InputDecoration(
                        labelText: 'Modèle de base (rôle)'),
                    items: PosRole.values
                        .where((r) => r != PosRole.owner)
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.fr),
                            ))
                        .toList(),
                    onChanged: (r) {
                      if (r == null) return;
                      setD(() {
                        baseRole = r;
                        selectedPerms
                          ..clear()
                          ..addAll(RbacMatrix.grants[r] ?? const {});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Droits par option :',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...PosPermission.values.map(
                    (perm) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(perm.labelFr,
                          style: const TextStyle(fontSize: 13)),
                      value: selectedPerms.contains(perm),
                      onChanged: (v) => setD(() {
                        if (v == true) {
                          selectedPerms.add(perm);
                        } else {
                          selectedPerms.remove(perm);
                        }
                      }),
                    ),
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
              key: const Key('save_profile_btn'),
              onPressed: () {
                final res = store.saveProfile(
                  name: nameCtrl.text,
                  baseRole: baseRole,
                  permissions: selectedPerms,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                setState(() => _selectedProfileId = store.profiles.last.id);
                Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _openUserDialog({StaffMember? existing}) async {
    final store = widget.store;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final pinCtrl = TextEditingController(text: existing?.pinCode ?? '');
    final badgeCtrl = TextEditingController(text: existing?.badgeUid ?? '');
    String profileId = existing?.profileId ??
        (store.profiles.isNotEmpty ? store.profiles.first.id : 'prof-cashier');
    if (!store.profiles.any((p) => p.id == profileId) &&
        store.profiles.isNotEmpty) {
      profileId = store.profiles.first.id;
    }
    bool isActive = existing?.isActive ?? true;
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? 'Nouvel utilisateur'
              : 'Modifier ${existing.name}'),
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
                  TextField(
                    key: const Key('user_name_input'),
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('user_pin_input'),
                    controller: pinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe / Code PIN (min. 4 car.) *',
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('user_badge_input'),
                    controller: badgeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Badge magnétique / RFID (optionnel)',
                      hintText: 'Passez le badge ou saisissez l\'UID',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: const Key('user_profile_dropdown'),
                    initialValue: profileId,
                    decoration: const InputDecoration(
                      labelText: 'Profil d\'accès attribué *',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: store.profiles
                        .map((prof) => DropdownMenuItem(
                              value: prof.id,
                              child: Text(prof.name),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setD(() => profileId = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compte utilisateur actif'),
                    value: isActive,
                    onChanged: (v) => setD(() => isActive = v),
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
              key: const Key('save_user_btn'),
              onPressed: () {
                final res = store.saveStaffMember(
                  existingId: existing?.id,
                  name: nameCtrl.text,
                  pinCode: pinCtrl.text,
                  profileId: profileId,
                  badgeUid: badgeCtrl.text,
                  isActive: isActive,
                );
                if (res != null) {
                  setD(() => err = res);
                  return;
                }
                Navigator.of(ctx).pop();
              },
              child: Text(store.i18n.t('confirm')),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    pinCtrl.dispose();
    badgeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final p = FullTekThemes.paletteOf(context);
    final profiles = store.profiles;
    final activeProfile = profiles.firstWhere(
      (prof) => prof.id == _selectedProfileId,
      orElse: () => profiles.first,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    key: const Key('subtab_profiles'),
                    selected: _subTab == 0,
                    onSelected: (_) => setState(() => _subTab = 0),
                    label: Text('Profils & Droits (${profiles.length})'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    key: const Key('subtab_users'),
                    selected: _subTab == 1,
                    onSelected: (_) => setState(() => _subTab = 1),
                    label: Text('Utilisateurs & Badges (${store.staff.length})'),
                  ),
                ],
              ),
              ElevatedButton.icon(
                key: Key(_subTab == 0 ? 'add_profile_btn' : 'add_user_btn'),
                onPressed: _subTab == 0
                    ? _openNewProfileDialog
                    : () => _openUserDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                    _subTab == 0 ? 'Nouveau profil' : 'Nouvel utilisateur'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _subTab == 0
                ? _buildProfilesMatrix(profiles, activeProfile, store, p)
                : _buildUsersList(store, p),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesMatrix(
    List<PosProfile> profiles,
    PosProfile activeProfile,
    PosStore store,
    PosPalette p,
  ) {
    final wide = MediaQuery.of(context).size.width >= 820;

    final profileSelector = ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final prof = profiles[idx];
        final selected = prof.id == activeProfile.id;
        final usersCount =
            store.staff.where((s) => s.profileId == prof.id).length;
        return InkWell(
          key: Key('profile_card_${prof.id}'),
          onTap: () => setState(() => _selectedProfileId = prof.id),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? p.primary.withValues(alpha: 0.14) : p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? p.primary : p.border),
            ),
            child: Row(
              children: [
                Icon(
                  prof.isMaster
                      ? Icons.verified_user_rounded
                      : Icons.tune_rounded,
                  color: selected ? p.primary : p.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prof.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        '${prof.permissions.length}/${PosPermission.values.length} options · $usersCount utilisateur(s)',
                        style: TextStyle(fontSize: 11.5, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                if (!prof.isMaster && usersCount == 0)
                  IconButton(
                    tooltip: 'Supprimer ce profil',
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: p.danger),
                    onPressed: () {
                      final err = store.deleteProfile(prof.id);
                      if (err != null && mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );

    final optionsEditor = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Droits du profil : ${activeProfile.name}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (activeProfile.isMaster)
                Chip(
                  label: const Text('Compte Master (accès total)'),
                  backgroundColor: p.vipGold.withValues(alpha: 0.2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: PosPermission.values.map((perm) {
                final enabled = activeProfile.can(perm);
                return SwitchListTile(
                  key: Key('perm_toggle_${activeProfile.id}_${perm.name}'),
                  dense: true,
                  title: Text(
                    perm.labelFr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  value: enabled,
                  onChanged: activeProfile.isMaster
                      ? null
                      : (v) {
                          final next =
                              Set<PosPermission>.from(activeProfile.permissions);
                          if (v) {
                            next.add(perm);
                          } else {
                            next.remove(perm);
                          }
                          store.saveProfile(
                            existingId: activeProfile.id,
                            name: activeProfile.name,
                            baseRole: activeProfile.baseRole,
                            permissions: next,
                          );
                        },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 310, child: profileSelector),
          const SizedBox(width: 14),
          Expanded(child: optionsEditor),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(height: 180, child: profileSelector),
        const SizedBox(height: 12),
        Expanded(child: optionsEditor),
      ],
    );
  }

  Widget _buildUsersList(PosStore store, PosPalette p) {
    return ListView.separated(
      itemCount: store.staff.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final u = store.staff[idx];
        final prof = store.profileForStaff(u);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: u.isActive ? p.border : p.danger),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: p.primary.withValues(alpha: 0.15),
                child: Icon(Icons.person_rounded, color: p.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'Profil: ${prof?.name ?? u.role.fr}  ·  Badge: ${u.badgeUid.isNotEmpty ? u.badgeUid : 'Non assigné'}',
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: u.isActive,
                onChanged: u.role == PosRole.owner
                    ? null
                    : (v) => store.toggleStaffActive(u.id, v),
              ),
              IconButton(
                key: Key('edit_user_${u.id}'),
                tooltip: 'Modifier utilisateur / badge / profil',
                onPressed: () => _openUserDialog(existing: u),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        );
      },
    );
  }
}
