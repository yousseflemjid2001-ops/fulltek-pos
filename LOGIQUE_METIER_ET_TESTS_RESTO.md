# Full·Tek Resto — Logique métier & Guide de test

Parcours complet (conforme à l'architecture : site vitrine → compte restaurant → caisse) :

```
full-tek.com (index.html)  →  « Se connecter » → Full·Tek Resto
        →  app.full-tek.com : ÉTAPE 1 compte restaurant (identifiant + mot de passe, cloud-api /api/auth/login)
        →  ÉTAPE 2 code PIN du personnel (hors-ligne, RBAC 9 rôles)
        →  ÉTAPE 3 Caisse / Plan de salle / Karni / Clôture Z & Sync
```

## 0. URLs locales
| Service | URL |
|---|---|
| Site vitrine | ouvrir `index.html` (bouton **Se connecter → Full·Tek Resto** ouvre la caisse) |
| Caisse Resto (Web) | http://localhost:8090 |
| API Cloud | http://localhost:4000/health |
| Super-Admin (compte Taha) | `taha` / `FullTekAdmin@2026` (API `/api/admin/login`) |

## 1. Comptes de test
**Compte restaurant (étape 1)** — créé par le Super-Admin : `darelkram41` / `FullTek@2026` (Dar El-Karam Resto, FT-1041).
Autre compte resto : `khaimandb90` / `FullTek@2026` (Café Khaima Nouadhibou). Un compte *market/pharma* est refusé dans Full·Tek Resto ; `elwiam12` (statut *expiré*) est refusé.

**PIN du personnel (étape 2)**
| PIN | Profil | Droits |
|---|---|---|
| `7410` | Propriétaire (PIN du compte) | tout |
| `9999` | Manager | tout sauf rien de bloqué : remises, offerts, retours |
| `1234` | Caissier | commandes, encaissement, Karni, Clôture Z — **pas** remise/offert/retour sans PIN Manager |
| `2222` | Serveur | commandes, division de note, réservations — **pas** d'encaissement |

## 2. Règles métier & scénarios de test
1. **Accès** : sans compte valide → pas de PIN pad. Mauvais mot de passe → « Identifiant ou mot de passe incorrect ». Mauvais PIN → refus + saisie remise à zéro.
2. **Thèmes (5)** — sélecteur palette en haut ; les thèmes proposés = ceux activés par le Super-Admin pour ce restaurant (`enabledThemes`).
   - 01 Émeraude Night : sombre, ticket à **droite**, catégories en **onglets**
   - 04 Aurora Glass : dégradé violet/cyan, ticket à **gauche**
   - 06 Ocean Fintech : **clair** bleu, ticket à droite, catégories en **rail** latéral
   - 07 Mauritanie Prestige : vert #06281E + or, ticket à **gauche**, onglets
   - 11 Nordic Minimal : **clair** Apple #F5F5F7 / #0071E3, rail
3. **Langues** FR / AR (bascule RTL complète) / EN, en 1 clic.
4. **Vente comptoir** : toucher un plat → ligne ajoutée ; toucher encore → quantité +1 ; ± pour ajuster ; note cuisine (✎).
5. **Plan de salle** : Libre (vert) / Occupée (orange) / Réservée (or) ; toucher une table ouvre sa commande ; zones Salle, Terrasse, Salon Khaima VIP 👑.
6. **Khaima VIP + Arboun** : réservation VIP → « Installer » : l'**Arboun** (acompte) est **déduit du total à payer**. Ex : Méchoui ×2 (2×1400) + Ataya ×2 (2×150) = 3100 − Arboun 2000 = **1100 MRU**.
7. **Envoyer cuisine** : génère le bon KDS (station GRILL / KITCHEN / BAR) ; les lignes passent « envoyées 🔥 ».
8. **Division de note** : par articles (sélection → sous-ticket) ou parts égales.
9. **Retour / Remake / Offert** : motif **obligatoire** ; réservé Manager/Propriétaire ou **PIN Manager** (9999/7410) ; tracé dans la file de sync (audit).
10. **Encaissement MRU** : Espèces (billets 100…2000), Bankily/Masrivi/Sedad (référence), Crédit Karni (plafond client), **paiement mixte** (ajouter plusieurs règlements) ; monnaie rendue calculée ; la table est libérée.
11. **Reçu 80 mm FR/AR** : aperçu après paiement (Arboun, référence mobile money, monnaie).
12. **Carnet Karni** : une vente en Karni augmente le solde dû ; « Encaisser acompte » le diminue.
13. **Clôture Z aveugle** : saisir les montants comptés (le théorique reste caché) → rapport avec écart de caisse. Théorique espèces = espèces encaissées − monnaie rendue.
14. **Offline-First** : chaque vente/Z/Karni/retour entre dans la `SyncQueue` ; « Synchroniser Cloud » envoie à `POST /api/pos/sync` (JWT du compte) ; si le serveur est coupé, les éléments restent en attente (aucune perte).
15. **Verrouiller** : bouton cadenas → retour au PIN pad (le compte reste connecté). « Changer de compte » → retour à l'étape 1.

## 3. Lancer les tests automatiques
```
cd apps/fulltek_pos   && flutter analyze && flutter test
cd apps/cloud-api     && node --test test/*.test.js
cd .                  && node --test tests/e2e/*.test.js
```
