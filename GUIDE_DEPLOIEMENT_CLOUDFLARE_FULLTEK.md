# 🚀 Guide Complet de Déploiement : full-tek.com sur Cloudflare

Ce guide vous explique pas à pas comment héberger et mettre en ligne l'ensemble de votre solution Full-Tek POS sous votre nom de domaine **`full-tek.com`** géré sur **Cloudflare**.

---

## 🗺️ 1. Architecture des 4 Espaces

Votre solution est découpée en 4 sous-domaines professionnels, sécurisés en HTTPS avec le réseau mondial Cloudflare :

| Sous-domaine | Rôle | Technologie | Hébergement Recommandé |
| :--- | :--- | :--- | :--- |
| **`full-tek.com`** & **`www`** | Site vitrine commercial & Démo | HTML5 / CSS3 / Vanilla JS (`index.html`) | **Cloudflare Pages** (Gratuit, Illimité, CDN mondial) |
| **`app.full-tek.com`** | Application Caisse POS Resto Web | Flutter Web (`apps/fulltek_pos/build/web`) | **Cloudflare Pages** (Gratuit, PWA offline, CDN) |
| **`admin.full-tek.com`** | Portail Super-Admin SaaS | Flutter Web (`apps/fulltek_superadmin/build/web`) | **Cloudflare Pages** (Gratuit, sécurisé) |
| **`api.full-tek.com`** | Backend Cloud API & Base SQLite/Postgres | Node.js v22 (`apps/cloud-api`) | **VPS Hetzner / Docker** ou **Render** + Proxy Cloudflare |

---

## 📦 Étape 1 : Sauvegarder et Pousser le Code sur GitHub

Toutes les applications frontend se déploient automatiquement à chaque mise à jour via votre dépôt GitHub.

Dans votre terminal PowerShell :
```powershell
git add .
git commit -m "feat(resto): POS resto v2, Docker production et configuration multi-domaines"
git push origin main
```

---

## ⚡ Étape 2 : Déployer les 3 Sites Web sur Cloudflare Pages (100% Gratuit)

Connectez-vous à votre tableau de bord **[Cloudflare Dashboard](https://dash.cloudflare.com/)** :

### A. Déployer le Site Vitrine (`full-tek.com`)
1. Dans le menu de gauche, allez dans **Workers & Pages** > **Create application** > onglet **Pages** > **Connect to Git**.
2. Sélectionnez votre dépôt GitHub : `yousseflemjid2001-ops/fulltek-pos`.
3. Configurez les options de build :
   - **Project name** : `fulltek-landing`
   - **Production branch** : `main`
   - **Framework preset** : `None`
   - **Build command** : *(Laissez vide)*
   - **Build output directory** : `.` (ou `/` pour servir la racine contenant `index.html`)
4. Cliquez sur **Save and Deploy**.
5. Une fois déployé, allez dans l'onglet **Custom domains** de votre projet Pages :
   - Cliquez sur **Set up a custom domain**.
   - Entrez `full-tek.com`, Cloudflare créera l'enregistrement DNS automatiquement !
   - Répétez pour `www.full-tek.com`.

---

### B. Déployer l'Application Caisse (`app.full-tek.com`)
1. Dans **Workers & Pages** > **Create application** > **Pages** > **Connect to Git**.
2. Sélectionnez le même dépôt GitHub.
3. Configurez :
   - **Project name** : `fulltek-pos-app`
   - **Production branch** : `main`
   - **Framework preset** : `None`
   - **Build command** :
     ```bash
     cd apps/fulltek_pos && flutter build web --no-web-resources-cdn --dart-define=API_BASE_URL=https://api.full-tek.com
     ```
     *(Note : Si vous préférez compiler en local sur votre PC et envoyer le build prêt, vous pouvez utiliser la commande CLI `npx wrangler pages deploy apps/fulltek_pos/build/web --project-name=fulltek-pos-app`).*
   - **Build output directory** : `apps/fulltek_pos/build/web`
4. Cliquez sur **Save and Deploy**.
5. Dans l'onglet **Custom domains** de ce projet :
   - Ajoutez `app.full-tek.com`.

---

### C. Déployer le Super-Admin (`admin.full-tek.com`)
1. Dans **Workers & Pages** > **Create application** > **Pages** > **Connect to Git**.
2. Configurez :
   - **Project name** : `fulltek-superadmin`
   - **Build output directory** : `apps/fulltek_superadmin/build/web`
3. Dans l'onglet **Custom domains** :
   - Ajoutez `admin.full-tek.com`.

---

## 🗄️ Étape 3 : Déployer le Backend Cloud API (`api.full-tek.com`)

L'API Node.js a besoin d'exécuter un processus continu et de sauvegarder la base de données (`fulltek.db`). Vous avez deux options simples :

### Option A : Déploiement VPS Hetzner / Ubuntu (Recommandé ~4,50 €/mois)
C'est la solution la plus économique et robuste préconisée dans le cahier des charges :
1. Commandez un petit VPS Ubuntu (ex: Hetzner CX22 ou Contabo ~4€/mois).
2. Connectez-vous en SSH à votre serveur :
   ```bash
   ssh root@<IP_DE_VOTRE_SERVEUR>
   ```
3. Installez Docker & Docker Compose :
   ```bash
   apt update && apt install -y docker.io docker-compose-plugin git
   ```
4. Clonez votre projet :
   ```bash
   git clone https://github.com/yousseflemjid2001-ops/fulltek-pos.git /opt/fulltek
   cd /opt/fulltek
   ```
5. Lancez l'API en production :
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build
   ```
   *L'API tourne désormais en arrière-plan sur le port 4000, avec redémarrage automatique.*

---

### Option B : Déploiement PaaS Clé en Main (Render.com / Railway - Sans Linux)
Si vous ne souhaitez pas gérer de serveur Linux :
1. Créez un compte sur **[Render.com](https://render.com)**.
2. Créez un **Web Service** connecté à votre dépôt GitHub.
3. Paramètres :
   - **Root Directory** : `apps/cloud-api`
   - **Runtime** : `Node`
   - **Build Command** : `npm install`
   - **Start Command** : `npm start`
4. Ajoutez un **Persistent Disk** (Disque persistant) monté sur `/app/data` (pour conserver les comptes, licences et ventes).
5. Dans les paramètres Render, ajoutez le domaine personnalisé : `api.full-tek.com`.

---

## 🌐 Étape 4 : Configuration des Enregistrements DNS sur Cloudflare

Allez dans votre compte **Cloudflare** > Sélectionnez votre domaine **`full-tek.com`** > **DNS** > **Records** :

| Type | Nom (Name) | Cible (Target / Content) | Proxy status (Nuage) | Utilisation |
| :--- | :--- | :--- | :--- | :--- |
| **CNAME** | `@` *(ou full-tek.com)* | `fulltek-landing.pages.dev` | 🟠 **Proxied** (Orange) | Site Vitrine Landing Page |
| **CNAME** | `www` | `fulltek-landing.pages.dev` | 🟠 **Proxied** (Orange) | Redirection www |
| **CNAME** | `app` | `fulltek-pos-app.pages.dev` | 🟠 **Proxied** (Orange) | Application Caisse Resto |
| **CNAME** | `admin` | `fulltek-superadmin.pages.dev` | 🟠 **Proxied** (Orange) | Portail Super-Admin |
| **A** *(si VPS)* | `api` | `<IP_DE_VOTRE_VPS>` | 🟠 **Proxied** (Orange) | API Backend sécurisée SSL |
| *ou* **CNAME** *(si Render)* | `api` | `fulltek-api.onrender.com` | 🟠 **Proxied** (Orange) | API Backend sur Render |

> [!IMPORTANT]
> Laissez toujours le **nuage orange (Proxied)** activé sur Cloudflare pour bénéficier du chiffrement SSL/TLS gratuit, de la protection anti-DDoS et de la mise en cache CDN.

---

## 🔒 Étape 5 : Paramètres SSL/TLS dans Cloudflare

Dans votre tableau de bord Cloudflare :
1. Allez dans **SSL/TLS** > **Overview** :
   - Choisissez le mode de chiffrement : **Full** (ou **Full Strict** si vous avez configuré un certificat origin sur votre serveur).
2. Allez dans **SSL/TLS** > **Edge Certificates** :
   - Activez **Always Use HTTPS** (Redirection automatique HTTP vers HTTPS).
   - Activez **Automatic HTTPS Rewrites**.
   - Activez **Minimum TLS Version** : `TLS 1.2`.

---

## ✅ Résultat Final

Une fois ces étapes effectuées :
- 🌍 **`https://full-tek.com`** : Votre site web vitrine est accessible mondialement en moins de 100ms.
- 📱 **`https://app.full-tek.com`** : Vos serveurs et caissiers se connectent à l'interface de caisse.
- 👑 **`https://admin.full-tek.com`** : Vous pilotez les licences Ed25519, les établissements et les imports de menus.
- ⚙️ **`https://api.full-tek.com`** : Votre backend synchronise les commandes, les tables et les stocks en toute sécurité.
