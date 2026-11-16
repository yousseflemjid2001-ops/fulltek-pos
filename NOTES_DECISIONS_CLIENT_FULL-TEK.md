# Notes & Décisions Validées par le Client — Projet Full-Tek POS

> **Client / Investisseur :** M. Taha Chouaib (Mauritanie)  
> **Date d'enregistrement :** 14 Novembre 2026  
> **Objectif :** Référence technique et visuelle officielle pour la phase de développement.

---

## 1. Identité de Marque & Gamme Produit

* **Nom officiel de la plateforme :** **Full-Tek** *(Full-Tek POS)*
* **Déclinaisons métiers (4 modules) :**
  1. **Full-Tek Resto** — Couleur d'accent : `#E4572E` *(Orange)* — Restaurants, Fast-Foods, Cafés, Salons Khaima VIP
  2. **Full-Tek Market** — Couleur d'accent : `#2E9E5B` *(Vert)* — Supermarchés, Supérettes, Épiceries, Balances
  3. **Full-Tek Pharma** — Couleur d'accent : `#1B8FD9` *(Bleu)* — Pharmacies, Lots & Péremption FEFO, Ordonnances
  4. **Full-Tek Boss** — Couleur d'accent : `#C99A2E` *(Or)* — Application Mobile Propriétaire & Console Super-Admin

---

## 2. Logo Retenu : **Modèle 11 — « Pilules »**

* **Concept :** Trois lignes de ticket de longueurs décroissantes formant un **F** épuré, lisible en toutes tailles (de l'icône 16 px / ticket 80 mm à l'enseigne).
* **Palette du logo principal :**
  * **Encre (Base) :** `#264653` *(Bleu-vert pétrole)*
  * **Accent :** `#E9A23B` *(Ocre chaleureux)*
  * **Nuit (Fond sombre) :** `#0F1B20`
* **Typographie :** `'Segoe UI', Arial, sans-serif` (Graisse 800, séparateur `·` entre `Full` et `Tek`)
* **Animation prévue (Splash / Ouverture app) :** `Slide` — Les trois lignes s'impriment l'une après l'autre.
* **Fichiers sources SVG prêts à intégrer :** [Logos_Full-Tek/Modele_11_Pilules/](file:///d:/_Documents/Bureau/caissamrr/Logos_Full-Tek/Modele_11_Pilules)
  * `logo_principal_clair.svg`
  * `logo_principal_sombre.svg`
  * `logo_anime.svg`
  * `icone_application.svg`
  * `Full-Tek_Resto.svg`, `Full-Tek_Market.svg`, `Full-Tek_Pharma.svg`, `Full-Tek_Boss.svg`

---

## 3. Thèmes d'Interface POS Retenus (Sélecteur de Thèmes)

Le client a sélectionné les thèmes suivants issus du [Catalogue des Maquettes](file:///d:/_Documents/Bureau/caissamrr/Maquettes_Interfaces_POS_Taha_Chouaib.pdf) pour intégration dans le système :

> [!NOTE]
> Le client a mentionné « 5 modes de thème : modèles 1, 6, 7, 11 ». Quatre modèles précis sont listés ci-dessous ; vérifier avec lui si un **5ᵉ thème** (ex. thème spécifique Market ou mode Clair/Sombre dérivé) doit être ajouté lors du développement.

### Thème 1 — **Modèle 01 : Émeraude Night** *(Mode Sombre Pro)*
* **Usage idéal :** Services de nuit, lounges, restaurants peu éclairés, usage intensif 12h/jour.
* **Disposition :** Ticket à droite · Catégories en onglets (`tabs`).
* **Palette CSS :**
  * Fond (`--bg`) : `#0B1220`
  * Surface (`--sf`) : `#131C2E` / `--sf2` : `#1B2742`
  * Accent (`--ac`) : `#10B981` (Secondaire : `#34D399`)
  * Texte (`--tx`) : `#E8EEFC` (Atténué : `#8B9BB8`)
  * Bordures : `rgba(255,255,255,.08)` · Rayons : `12px`

### Thème 2 — **Modèle 06 : Ocean Fintech** *(Mode Clair SaaS Moderne)*
* **Usage idéal :** Toutes activités, chaînes multi-sites, cohérence avec l'App Boss et le Back-Office.
* **Disposition :** Ticket à droite · Catégories en barre latérale (`rail`).
* **Palette CSS :**
  * Fond (`--bg`) : `#F4F7FB`
  * Surface (`--sf`) : `#FFFFFF` / `--sf2` : `#EAF0F9`
  * Accent (`--ac`) : `#2563EB` (Secondaire : `#06B6D4`)
  * Texte (`--tx`) : `#0F1B33` (Atténué : `#6B7A99`)
  * Bordures : `#E1E8F4` · Rayons : `14px`

### Thème 3 — **Modèle 07 : Mauritanie Prestige** *(Identité Nationale & Khaima VIP)*
* **Usage idéal :** Restaurants traditionnels mauritaniens, méchouis, salons Khaima VIP, affichage bilingue AR/FR.
* **Disposition :** Ticket à gauche · Catégories en onglets (`tabs`).
* **Palette CSS :**
  * Fond (`--bg`) : `#06281E` *(Vert Mauritanie)*
  * Surface (`--sf`) : `#0C3B2E` / `--sf2` : `#134E3E`
  * Accent (`--ac`) : `#F59E0B` *(Or Sable)* (Secondaire : `#10B981`)
  * Texte (`--tx`) : `#F7FEE7` (Atténué : `#A7F3D0`)
  * Typo titres : `'Playfair Display', Georgia, serif` · Rayons : `14px`

### Thème 4 — **Modèle 11 : Nordic Minimal (Apple Style)** *(Minimalisme iPadOS)*
* **Usage idéal :** Bistros modernes, tablettes iPad/Android, franchises, bornes & caisses épurées.
* **Disposition :** Ticket à droite · Catégories en barre latérale (`rail`).
* **Palette CSS :**
  * Fond (`--bg`) : `#F5F5F7`
  * Surface (`--sf`) : `#FFFFFF` / `--sf2` : `#EEF0F4`
  * Accent (`--ac`) : `#0071E3` (Secondaire : `#34C759`)
  * Texte (`--tx`) : `#1D1D1F` (Atténué : `#86868B`)
  * Bordures : `#E5E5EA` · Rayons : `18px`

*(Emplacement réservé : **Thème 5** à confirmer avec le client si souhaité — ex. Modèle 08 Supermarché / Market Express).*

---

## 4. Nouveaux Ajouts Validés (Multilingue FR/AR/EN & Application Super-Admin)

### 4.1 Système Trilingue Complet : **Français (FR) · Arabe (AR - RTL) · English (EN)**
* **Commutateur de langue instantané (`FR | AR | EN`)** accessible en 1 clic dans la barre supérieure de tous les écrans (Caisse POS, KDS Cuisine, Back-Office, App Boss et App Super-Admin).
* **Basculement automatique RTL/LTR :** Passage fluide de gauche à droite (`FR` / `EN`) vers droite à gauche (`AR`).
* **Catalogues & Tickets :** Support des libellés produits et impressions de reçus 80 mm en Français, Arabe et Anglais (idéal pour les hôtels, restaurants internationaux, ONG, ambassades et supermarchés expatriés à Nouakchott).

### 4.2 Application Dédiée pour le Super-Admin (M. Taha Chouaib) — **« Full-Tek Control »**
Une application dédiée (Web + Mobile PWA installable sur le smartphone et le PC de M. Taha Chouaib) lui permettant de piloter l'ensemble de son business SaaS où qu'il soit :
1. **Création & Provisioning de Boutiques en 1 clic :**
   * Choix du module métier (*Full-Tek Resto*, *Full-Tek Market* ou *Full-Tek Pharma*), nombre de caisses autorisées, thèmes activés (`01`, `06`, `07`, `11`) et création automatique des identifiants du propriétaire client.
2. **Gestion des Abonnements & Facturation Récurrente (MRR) :**
   * Suivi en temps réel du MRR/ARR en MRU, liste des abonnés actifs, en période d'essai, proches de l'échéance (`J-5`, `J-2`) ou expirés.
   * Enregistrement et validation des paiements d'abonnements reçus via **Bankily, Masrivi, Sedad ou Espèces** avec génération automatique de la facture d'abonnement PDF.
3. **Contrôle à Distance des Licences Offline (Lease 30 jours) :**
   * Bouton d'extension de licence en 1 clic (+30 jours / +1 an) dès qu'un client règle son abonnement.
   * Bouton de suspension / verrouillage à distance en cas de non-paiement, ou génération d'un code de déblocage hors-ligne à 8 chiffres si la caisse du client n'a pas Internet.
4. **Relances Automatiques WhatsApp :**
   * Envoi en 1 clic (ou automatique) d'un rappel d'échéance courtois sur le WhatsApp du gérant avec le montant en MRU et le code marchand Bankily/Masrivi de M. Taha Chouaib.
5. **Monitoring du Parc & Support Sécurisé :**
   * État de connexion/synchronisation des caisses déployées à Nouakchott, Nouadhibou, Atar, etc., et mode « Prise en main Support » tracé dans le journal d'audit.

### 4.3 Page d'Accueil Publique & Site Vitrine Animé (Modèle `caissa.tn` — `full-tek.com`)
Avant même la page de connexion, le domaine principal (`full-tek.com` / `full-tek.mr`) affiche un **site vitrine commercial moderne et animé** (en **FR | AR | EN**) destiné à séduire les commerçants et restaurateurs :
* **Section Hero Animée :** Animation du **Logo Modèle 11 (« Pilules »)**, accroche claire (*« La caisse intelligente qui ne s'arrête jamais, même sans Internet »*), aperçu interactif des **4 Thèmes (01, 06, 07, 11)** et boutons d'action (**« Essai Gratuit 15 jours »**, **« Se Connecter à ma Caisse »**, **« Démo WhatsApp »**).
* **Présentation des 4 Produits Commercialisables :**
  1. **Full-Tek Resto** (Salles, KDS Cuisine, Tablettes Serveurs, Salons Khaima VIP)
  2. **Full-Tek Market** (Code-barres ultra-rapide, Balances poids/prix, Lots & Consignes)
  3. **Full-Tek Pharma** (Dates d'expiration FEFO, Blocage périmés, Ordonnances, Chaîne du froid)
  4. **Full-Tek Boss** (Suivi chiffre d'affaires sur smartphone, Alertes stock & péremption)
* **Atouts Spécifiques Mauritanie :** Zéro coupure (Offline-First), Cash MRU + **Bankily / Masrivi / Sedad** + Carnet **Karni**, Clôture Z aveugle anti-fraude, Compatibilité imprimantes 80mm/douchettes/balances.
* **Grille Tarifaire Transparente (MRU/mois)** + Packs Matériels + Formulaire de demande de démo directement relié au **WhatsApp commercial** de M. Taha Chouaib et à la console Super-Admin.

---

## 5. Rappels Critiques du Périmètre (Pour le Développement)

1. **Architecture Hybride Offline-First :** Cloud SaaS Multi-Tenant (PostgreSQL RLS) + Moteur Edge Local LAN (synchronisation entre caisse maître, tablettes serveurs, KDS cuisine et imprimantes ESC/POS 80mm même sans Internet).
2. **Droits d'Accès (RBAC) :** 9 profils prédéfinis + permissions personnalisables + code PIN hors-ligne + journal d'audit inaltérable (Section 07-A du CDC).
3. **Stock Avancé (Market & Pharmacie) :** Gestion par **lots**, méthode **FEFO** (First Expired, First Out), alertes J-90/J-30/J-7, **blocage automatique en caisse des produits périmés** (Section 07-B du CDC).
4. **Trilingue Natif (`FR` / `AR` / `EN`)** & **Application Mobile/Web Super-Admin dédiée** pour la gestion des abonnements et licences.
5. **Coûts Infrastructure Minimaux :** VPS Hetzner CX22 (~4,50 €/mois) + Domaine `.com` Cloudflare (~12 €/an) + Backups Backblaze B2 (~0,30 €/mois) + **0 € de frais Apple Store / Google Play** (distribution directe PWA + APK).

---

## 6. Documents de Référence du Projet

* **Cahier des Charges (16 pages) :** [Cahier_des_Charges_SaaS_POS_Mauritanie_Taha_Chouaib.pdf](file:///d:/_Documents/Bureau/caissamrr/Cahier_des_Charges_SaaS_POS_Mauritanie_Taha_Chouaib.pdf)
* **Maquettes Interfaces (30 pages) :** [Maquettes_Interfaces_POS_Taha_Chouaib.pdf](file:///d:/_Documents/Bureau/caissamrr/Maquettes_Interfaces_POS_Taha_Chouaib.pdf)
* **Architecture & Coûts Serveurs (12 pages) :** [Architecture_et_Couts_Serveurs_SaaS_POS_Taha_Chouaib.pdf](file:///d:/_Documents/Bureau/caissamrr/Architecture_et_Couts_Serveurs_SaaS_POS_Taha_Chouaib.pdf)
* **Catalogue Logos (12 Modèles / 27 pages) :** [Logos_Full-Tek_12_Modeles.pdf](file:///d:/_Documents/Bureau/caissamrr/Logos_Full-Tek_12_Modeles.pdf)
