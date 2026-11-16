# Architecture de Développement & Plan d'Exécution Multi-Agents — **Full-Tek POS**

> **Projet :** Suite SaaS & Offline-First **Full-Tek** (*Resto · Market · Pharma · Boss*)  
> **Client :** M. Taha Chouaib (Mauritanie)  
> **Logo officiel :** Modèle 11 (« Pilules »)  
> **Thèmes UI intégrés (5) :** Modèles `01` (Émeraude Night), `04` (Aurora Glass), `06` (Ocean Fintech), `07` (Mauritanie Prestige), `11` (Nordic Minimal)

---

## 1. Par Quoi Commencer ? (La Stratégie Gagnante en 5 Étapes)

L'erreur classique sur un logiciel de caisse est de commencer par des détails secondaires avant d'avoir le **cœur de données et l'écran de vente**. Pour livrer vite, proprement et pouvoir **montrer une démo fonctionnelle au client dès les premiers jours**, voici l'ordre exact de démarrage :

### Étape 1 — Le Socle Commun : Design System (Logo 11 + 5 Thèmes) & Schéma de Base de Données
* Créer le monorepo avec les **variables CSS des 5 thèmes** (changement de thème en 1 clic) et le composant SVG du **Logo Modèle 11** (avec son animation `Slide` et ses variantes *Resto*, *Market*, *Pharma*, *Boss*).
* Figer le schéma de données (`schema.prisma` + tables locales `Dexie.js`) incluant dès le départ :
  * Multi-tenant (`tenant_id`), Utilisateurs & **9 rôles RBAC** (`Role`, `Permission`, `AuditLog`, `pin_code`),
  * Produits, Catégories, **Lots & Dates d'expiration (`StockBatch` pour FEFO)**,
  * Commandes (`Order`, `OrderItem`), Paiements Mauritanie (`PaymentTransaction` : Cash, Bankily, Masrivi, Sedad, Karni), Clôture Z.

### Étape 2 — Le Cœur Visible : L'Écran de Caisse Tactile + Moteur Local Offline
* Construire l'interface de caisse (Resto + Market/Pharma) branchée directement sur la base locale (`IndexedDB / SQLite`).
* **Pourquoi commencer par là ?** Parce que dès la fin de cette étape, vous pouvez ouvrir l'application devant le client, changer entre les 5 thèmes, scanner/cliquer des produits, voir le blocage d'un produit expiré (FEFO), encaisser en Cash/Bankily et imprimer un reçu 80 mm !

### Étape 3 — Le Hub Local LAN (Tablettes Serveurs + Écran Cuisine KDS sans Internet)
* Activer le mini-serveur WebSocket local pour que la Caisse Principale, les Tablettes Serveurs (plan de salle) et l'Écran Cuisine (KDS) communiquent en temps réel (< 0,1s) sur le Wi-Fi du restaurant même quand Internet est coupé.

### Étape 4 — Le Backend Cloud Multi-Tenant, RBAC & Synchronisation
* Connecter l'API Cloud (`/api/auth`, `/api/sync/push`, `/api/sync/pull`, `/api/tenants`) pour synchroniser automatiquement les ventes locales vers PostgreSQL dès qu'Internet est disponible.

### Étape 5 — Les Portails de Pilotage : App « Full-Tek Boss » & Console Super-Admin
* Tableau de bord mobile temps réel du propriétaire (CA du jour, alertes péremption J-30/J-7, validation PIN à distance) et Console Super-Admin de M. Taha Chouaib (création des boutiques clientes, gestion des abonnements MRR et licences offline 30 jours).

---

## 2. Arborescence Technique du Projet (Monorepo Propre & Modulaire)

```text
full-tek-pos/
├── docker-compose.yml              # PostgreSQL 16 + Redis + API Cloud + Web PWA + Nginx
├── packages/
│   └── shared/                     # Types TypeScript partagés (RBAC, FEFO, MRU, i18n FR/AR/EN, DTOs Sync)
│       ├── src/rbac.ts             # Matrice des 9 rôles & permissions granulaires
│       ├── src/fefo.ts             # Algorithme FEFO & validation des dates d'expiration
│       ├── src/i18n/               # Dictionnaires complets 3 langues : fr.ts, ar.ts (RTL), en.ts (English)
│       └── src/themes.ts           # Tokens des 5 thèmes (Modèles 01, 04, 06, 07, 11)
│
├── apps/
│   ├── landing-web/                # Site Vitrine & Page d'Accueil Animée (full-tek.com — style caissa.tn)
│   │   └── src/
│   │       ├── hero/               # Bienvenue animée (Logo N°11 Slide), aperçu interactif des 5 Thèmes
│   │       ├── products/           # Fiches commerciales : Full-Tek Resto, Market, Pharma & Boss
│   │       ├── features/           # Démonstration Offline-First, Bankily/Masrivi, RBAC & Dates FEFO
│   │       ├── pricing/            # Tarifs MRU, Packs Matériels & Essai Gratuit 15 jours
│   │       └── cta/                # Boutons « Connexion Caisse » (app.) & « Demande Démo WhatsApp »
│   │
│   ├── superadmin-app/             # Application dédiée Super-Admin (M. Taha Chouaib) — admin.full-tek.com
│   │   ├── public/manifest.json    # Icône dédiée « Full-Tek Control » sur le téléphone du Super-Admin
│   │   └── src/
│   │       ├── tenants/            # Création 1-clic de boutiques (Resto / Market / Pharma) & Quotas caisses
│   │       ├── subscriptions/      # Gestion Abonnements MRR, Facturation MRU, Validation Bankily/Masrivi
│   │       ├── licenses/           # Prolongation (+30j), Suspension à distance & Codes de secours Offline
│   │       ├── whatsapp-reminders/ # Relances d'échéance automatisées WhatsApp (J-5, J-2, Expiré)
│   │       └── fleet-monitoring/   # Suivi en direct des caisses connectées & Santé du VPS
│   │
│   ├── web-pos/                    # Application PWA Client (Caisse Resto/Market/Pharma + KDS + App Boss)
│   │   ├── public/manifest.json    # Configuration PWA installable hors-ligne (0 € Stores)
│   │   └── src/
│   │       ├── assets/logos/       # SVG du Logo N°11 Pilules (Clair, Sombre, Animé, Resto/Market/Pharma/Boss)
│   │       ├── db/                 # Moteur Offline-First (Dexie.js IndexedDB + File SyncQueue)
│   │       ├── modules/
│   │       │   ├── auth-rbac/      # Login, Clavier PIN hors-ligne, Gestion des 9 rôles & Journal d'Audit
│   │       │   ├── pos-resto/      # Caisse tactile Resto, Plan de salle, Division de note, VIP Khaima
│   │       │   ├── pos-market/     # Caisse Market/Pharma, Scan EAN/Balance, Blocage Périmés FEFO
│   │       │   ├── kds-kitchen/    # Écran Cuisine temps réel (tickets, chronomètre, prêt)
│   │       │   ├── stock-batches/  # Réception par lot, Dates d'expiration, Alertes J-90/J-30/J-7
│   │       │   ├── payments-mru/   # Paiement mixte (Cash + Bankily/Masrivi/Sedad) + Carnet Karni + Clôture Z
│   │       │   ├── boss-mobile/    # Vue mobile Propriétaire (KPIs live, approbations à distance)
│   │       │   └── super-admin/    # Console de M. Taha Chouaib (Clients SaaS, Licences 30j, MRR)
│   │       └── services/
│   │           ├── sync-agent.ts   # Synchronisation automatique en arrière-plan (LAN & Cloud)
│   │           └── printer-esc.ts  # Impression Ticket 80mm FR/AR + Ouverture Tiroir RJ11
│   │
│   ├── edge-hub/                   # Mini-serveur local LAN (Node/Fastify + SQLite WAL + WebSocket LAN)
│   │   └── src/                    # Relais ultra-léger entre Caisse Maître, Tablettes Serveurs, KDS & Imprimante IP
│   │
│   └── cloud-api/                  # Backend Cloud Multi-Tenant (Node/NestJS ou Fastify + Prisma + PostgreSQL)
│       ├── prisma/schema.prisma    # Schéma complet avec tenant_id, RBAC, StockBatch, Orders, AuditLog
│       └── src/                    # API REST + Webhooks Bankily/Masrivi + Sync Delta + Licences
```

---

## 3. L'Équipe de 4 Agents IA Spécialisés (Déjà Configurés & Prêts)

J'ai créé et enregistré **4 sous-agents spécialisés** dans votre environnement pour paralléliser le travail :

| Agent configuré | Rôle & Responsabilité | Fichiers & Modules pris en charge |
| :--- | :--- | :--- |
| **`backend-architect`** | **Architecte Backend & BDD Multi-Tenant** | `schema.prisma`, API Auth/JWT/PIN, Matrice RBAC (9 rôles), Logique stock par lots & FEFO, Endpoints de synchronisation `/api/sync`, Licences SaaS. |
| **`frontend-pos-ui`** | **Lead Frontend UI/UX, Thèmes & Écrans** | Intégration du **Logo N°11 (Pilules)**, Moteur des **5 Thèmes (1, 4, 6, 7, 11)**, Écrans Caisse Resto, Market, Pharma, KDS, Gestion Utilisateurs/RBAC, Alertes Péremption, App Boss & Super-Admin. |
| **`offline-edge-hardware`** | **Ingénieur Offline, Réseau LAN & Matériel** | Base locale `Dexie/SQLite`, File d'attente `SyncQueue`, Serveur WebSocket LAN (Tablettes ↔ Caisse ↔ KDS sans Internet), Ticket thermique 80mm FR/AR, Décodage balances poids/prix. |
| **`qa-devops`** | **Ingénieur QA, Tests Métier & Docker VPS** | `docker-compose.yml`, Nginx SSL, Scripts Backup S3, Tests de sécurité RBAC, Tests de blocage d'articles expirés en caisse et Clôture Z aveugle. |

---

## 4. Plan de Tâches Prêt à Exécuter (Par Vagues Parallèles)

### 🚀 Vague 1 (Fondations — Exécution immédiate en parallèle)
* **Task 1.1 (`backend-architect`) :** Initialiser le monorepo, les types partagés (`packages/shared`) incluant la matrice complète des **9 rôles RBAC** et le schéma Prisma multi-tenant (`schema.prisma`) avec gestion des **Lots & Dates d'expiration (`StockBatch`)**.
* **Task 1.2 (`frontend-pos-ui`) :** Initialiser le site vitrine animé `apps/landing-web` (`full-tek.com`), l'application client `apps/web-pos` (`app.full-tek.com`) et la base de `apps/superadmin-app` (`admin.full-tek.com`) avec le **Logo N°11 (Pilules)** animé, le sélecteur instantané des **5 Thèmes (`01`, `04`, `06`, `07`, `11`)** et le commutateur **Trilingue `FR | AR (RTL) | EN (English)`**.
* **Task 1.3 (`offline-edge-hardware`) :** Créer la base locale Offline-First (`IndexedDB / Dexie`) pré-remplie avec un jeu de données de démonstration réaliste (Restaurant + Supermarché + Pharmacie avec lots proches d'expiration et lots expirés) + moteur d'impression ticket 80mm.

### ⚡ Vague 2 (Modules Caisse, RBAC & Stock FEFO)
* **Task 2.1 (`frontend-pos-ui`) :** Coder les écrans **Caisse Resto** (plan de salle, tablettes, KDS) et **Caisse Market / Pharmacie** (scan code-barres, sélection automatique du lot FEFO, alerte rouge bloquante si produit périmé, substitution générique DCI).
* **Task 2.2 (`frontend-pos-ui`) :** Coder l'écran **Gestion des Utilisateurs & Droits d'Accès (RBAC)** (les 9 profils, cases à cocher des permissions, code PIN, journal d'audit) et l'écran **Gestion des Lots & Dates d'Expiration** (filtres J-90 / J-30 / J-7, démarque).
* **Task 2.3 (`offline-edge-hardware`) :** Coder l'encaissement Mauritanie (Cash MRU, Bankily, Masrivi, Sedad, paiement mixte, carnet de crédit **Karni** et **Clôture Z aveugle**).

### 🌐 Vague 3 (Hub LAN, Cloud API, App Boss & Super-Admin)
* **Task 3.1 (`backend-architect` + `offline-edge-hardware`) :** Coder le Hub LAN WebSocket et l'API Cloud de synchronisation delta (`/api/sync`).
* **Task 3.2 (`superadmin-app-dev` + `frontend-pos-ui`) :** Finaliser la **Page d'Accueil / Site Vitrine Animé (`apps/landing-web` — style `caissa.tn`)** présentant les 4 produits (*Resto, Market, Pharma, Boss*), les tarifs MRU et les boutons *Connexion / Essai gratuit WhatsApp* ; et finaliser l'**Application Dédiée Super-Admin (`apps/superadmin-app` — Full-Tek Control)** pour M. Taha Chouaib ainsi que la vue mobile **Full-Tek Boss**.
* **Task 3.3 (`qa-devops`) :** Préparer le `docker-compose.yml` de production pour le VPS Hetzner et vérifier tous les parcours critiques.
