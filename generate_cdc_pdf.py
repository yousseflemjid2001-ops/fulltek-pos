import os
import subprocess

html_content = """<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Cahier des Charges Stratégique & Technique - SaaS POS Restauration & Retail Mauritanie - Taha Chouaib</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap');

  :root {
    --primary: #0A2540;
    --primary-light: #133B63;
    --accent: #00A86B;
    --accent-dark: #007A4D;
    --gold: #D97706;
    --gold-light: #FEF3C7;
    --blue-tech: #2563EB;
    --blue-light: #EFF6FF;
    --emerald-light: #ECFDF5;
    --purple: #7C3AED;
    --purple-light: #F5F3FF;
    --slate-900: #0F172A;
    --slate-800: #1E293B;
    --slate-700: #334155;
    --slate-600: #475569;
    --slate-500: #64748B;
    --slate-300: #CBD5E1;
    --slate-200: #E2E8F0;
    --slate-100: #F1F5F9;
    --slate-50: #F8FAFC;
    --danger: #DC2626;
    --danger-light: #FEF2F2;
  }

  @page {
    size: A4 portrait;
    margin: 0mm;
  }

  * {
    box-sizing: border-box;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
  }

  body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    color: var(--slate-800);
    background: #FFFFFF;
    margin: 0;
    padding: 0;
    font-size: 8.6pt;
    line-height: 1.42;
  }

  h1, h2, h3, h4, .heading-font {
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
  }

  code, .mono {
    font-family: 'JetBrains Mono', Consolas, monospace;
    font-size: 7.8pt;
    background: rgba(15, 23, 42, 0.06);
    padding: 1px 4px;
    border-radius: 3px;
  }

  /* FIXED A4 PAGE CONTAINER */
  .page {
    width: 210mm;
    height: 297mm;
    padding: 9.5mm 13mm 8.5mm 13mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    page-break-after: always;
    overflow: hidden;
    position: relative;
    background: #FFFFFF;
  }

  .page:last-child {
    page-break-after: auto;
  }

  .page-body {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
  }

  /* COVER PAGE */
  .cover-page {
    width: 210mm;
    height: 297mm;
    background: linear-gradient(145deg, #061527 0%, #0A2540 50%, #0D3832 100%);
    color: #FFFFFF;
    padding: 20mm 18mm 16mm 18mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    position: relative;
    overflow: hidden;
    page-break-after: always;
  }

  .cover-bg-pattern {
    position: absolute;
    top: -60px;
    right: -60px;
    width: 520px;
    height: 520px;
    border-radius: 50%;
    background: radial-gradient(circle, rgba(0,168,107,0.22) 0%, rgba(217,119,6,0.08) 45%, transparent 70%);
    pointer-events: none;
  }

  .cover-bg-grid {
    position: absolute;
    inset: 0;
    background-image: 
      linear-gradient(to right, rgba(255,255,255,0.03) 1px, transparent 1px),
      linear-gradient(to bottom, rgba(255,255,255,0.03) 1px, transparent 1px);
    background-size: 28px 28px;
    pointer-events: none;
  }

  .cover-top-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(255,255,255,0.15);
    padding-bottom: 14px;
    position: relative;
    z-index: 2;
  }

  .brand-badge {
    display: inline-flex;
    align-items: center;
    gap: 10px;
    font-weight: 800;
    font-size: 11.5pt;
    letter-spacing: 0.5px;
    color: #FFFFFF;
  }

  .brand-dot {
    width: 12px;
    height: 12px;
    border-radius: 3px;
    background: linear-gradient(135deg, #00E699, #F59E0B);
    display: inline-block;
  }

  .doc-ref {
    font-size: 8pt;
    color: #94A3B8;
    background: rgba(255,255,255,0.07);
    padding: 5px 12px;
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,0.12);
  }

  .cover-hero {
    position: relative;
    z-index: 2;
  }

  .cover-tag {
    display: inline-block;
    background: rgba(0, 168, 107, 0.2);
    border: 1px solid #00D68F;
    color: #34D399;
    font-weight: 700;
    font-size: 8.5pt;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    padding: 6px 14px;
    border-radius: 6px;
    margin-bottom: 16px;
  }

  .cover-title {
    font-size: 26pt;
    font-weight: 800;
    line-height: 1.15;
    margin: 0 0 14px 0;
    letter-spacing: -0.5px;
    color: #FFFFFF;
  }

  .cover-title span.highlight { color: #34D399; }
  .cover-title span.gold { color: #FBBF24; }

  .cover-subtitle {
    font-size: 10.8pt;
    line-height: 1.52;
    color: #CBD5E1;
    max-width: 96%;
    font-weight: 400;
    margin-bottom: 20px;
  }

  .cover-pillars {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 11px;
  }

  .cover-pillar-card {
    background: rgba(255, 255, 255, 0.055);
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-left: 3px solid #34D399;
    border-radius: 8px;
    padding: 10px 13px;
  }

  .cover-pillar-card.gold-border { border-left-color: #FBBF24; }

  .cover-pillar-title {
    font-weight: 700;
    font-size: 9.2pt;
    color: #FFFFFF;
    margin-bottom: 3px;
  }

  .cover-pillar-desc {
    font-size: 8pt;
    color: #94A3B8;
    line-height: 1.35;
  }

  .cover-client-box {
    position: relative;
    z-index: 2;
    background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.04) 100%);
    border: 1px solid rgba(255,255,255,0.2);
    border-radius: 12px;
    padding: 16px 20px;
    display: grid;
    grid-template-columns: 1.2fr 1fr 1fr 0.9fr;
    gap: 12px;
  }

  .client-meta-label {
    font-size: 7pt;
    text-transform: uppercase;
    letter-spacing: 1.1px;
    color: #94A3B8;
    margin-bottom: 4px;
    font-weight: 600;
  }

  .client-meta-value {
    font-size: 11.2pt;
    font-weight: 800;
    color: #FBBF24;
  }

  .client-meta-sub {
    font-size: 7.8pt;
    color: #E2E8F0;
    margin-top: 2px;
  }

  .cover-footer {
    position: relative;
    z-index: 2;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1px solid rgba(255,255,255,0.14);
    padding-top: 10px;
    font-size: 7.8pt;
    color: #94A3B8;
  }

  /* HEADERS & FOOTERS */
  .doc-topbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1.5px solid var(--slate-200);
    padding-bottom: 5px;
    margin-bottom: 9px;
    font-size: 7.3pt;
    color: var(--slate-500);
    font-weight: 600;
  }

  .doc-topbar .client-tag {
    color: var(--primary);
    background: var(--slate-100);
    border: 1px solid var(--slate-200);
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 700;
  }

  .doc-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-top: 1.5px solid var(--slate-200);
    padding-top: 5px;
    margin-top: 6px;
    font-size: 7.2pt;
    color: var(--slate-500);
    font-weight: 500;
  }

  .page-num-pill {
    background: var(--primary);
    color: #34D399;
    font-weight: 700;
    padding: 1.5px 8px;
    border-radius: 10px;
    font-size: 7.2pt;
  }

  .section-header {
    margin-bottom: 9px;
    background: linear-gradient(135deg, var(--primary) 0%, #10365C 100%);
    color: #FFFFFF;
    padding: 9px 14px;
    border-radius: 7px;
    border-left: 4px solid var(--accent);
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .section-num {
    font-size: 7.2pt;
    text-transform: uppercase;
    letter-spacing: 1.3px;
    color: #34D399;
    font-weight: 700;
    display: block;
    margin-bottom: 1px;
  }

  .section-title {
    font-size: 12.2pt;
    font-weight: 800;
    margin: 0;
    color: #FFFFFF;
  }

  .section-badge {
    font-size: 7.2pt;
    background: rgba(255,255,255,0.12);
    color: #E2E8F0;
    padding: 3px 9px;
    border-radius: 20px;
    font-weight: 600;
    white-space: nowrap;
  }

  h3 {
    font-size: 9.8pt;
    font-weight: 700;
    color: var(--primary);
    margin: 8px 0 5px 0;
    padding-bottom: 3px;
    border-bottom: 1.5px solid var(--slate-200);
    display: flex;
    align-items: center;
    gap: 6px;
  }

  h3 .h3-dot {
    width: 7px;
    height: 7px;
    border-radius: 2px;
    background: var(--accent);
    display: inline-block;
  }

  p {
    margin: 0 0 6px 0;
    text-align: justify;
  }

  ul, ol {
    margin: 3px 0 6px 0;
    padding-left: 15px;
  }

  li {
    margin-bottom: 2.5px;
  }

  li strong {
    color: var(--primary);
  }

  /* GRIDS & CARDS */
  .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 7px; }
  .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; margin-bottom: 7px; }
  .grid-4 { display: grid; grid-template-columns: repeat(4, 1fr); gap: 7px; margin-bottom: 7px; }

  .card {
    background: var(--slate-50);
    border: 1px solid var(--slate-200);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-white {
    background: #FFFFFF;
    border: 1px solid var(--slate-200);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-accent {
    background: var(--emerald-light);
    border: 1px solid #A7F3D0;
    border-left: 3.5px solid var(--accent);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-gold {
    background: var(--gold-light);
    border: 1px solid #FDE68A;
    border-left: 3.5px solid var(--gold);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-blue {
    background: var(--blue-light);
    border: 1px solid #BFDBFE;
    border-left: 3.5px solid var(--blue-tech);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-purple {
    background: var(--purple-light);
    border: 1px solid #DDD6FE;
    border-left: 3.5px solid var(--purple);
    border-radius: 6px;
    padding: 7px 10px;
  }

  .card-title {
    font-weight: 700;
    font-size: 8.8pt;
    color: var(--primary);
    margin-bottom: 4px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .badge {
    display: inline-block;
    padding: 1px 6px;
    font-size: 6.8pt;
    font-weight: 700;
    border-radius: 8px;
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }

  .badge-green { background: #D1FAE5; color: #065F46; }
  .badge-blue { background: #DBEAFE; color: #1E40AF; }
  .badge-amber { background: #FEF3C7; color: #92400E; }
  .badge-purple { background: #EDE9FE; color: #5B21B6; }
  .badge-red { background: #FEE2E2; color: #991B1B; }

  /* TABLES */
  table {
    width: 100%;
    border-collapse: collapse;
    margin: 5px 0 7px 0;
    font-size: 7.9pt;
  }

  th {
    background: var(--primary);
    color: #FFFFFF;
    font-weight: 700;
    text-align: left;
    padding: 5px 7px;
    border: 1px solid var(--primary);
    font-size: 7.8pt;
  }

  td {
    padding: 4.5px 7px;
    border: 1px solid var(--slate-200);
    vertical-align: top;
  }

  tr:nth-child(even) td {
    background: var(--slate-50);
  }

  /* TOC STYLING */
  .toc-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 5.5px;
    margin-top: 4px;
  }

  .toc-item {
    display: flex;
    gap: 8px;
    align-items: flex-start;
    padding: 5.5px 9px;
    border: 1px solid var(--slate-200);
    border-radius: 6px;
    background: var(--slate-50);
  }

  .toc-num {
    background: var(--primary);
    color: #34D399;
    font-weight: 800;
    font-size: 8pt;
    min-width: 24px;
    height: 24px;
    border-radius: 5px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .toc-text strong {
    display: block;
    font-size: 8.1pt;
    color: var(--primary);
    margin-bottom: 1px;
  }

  .toc-text span {
    font-size: 7.2pt;
    color: var(--slate-600);
    line-height: 1.22;
    display: block;
  }

  /* KPI STAT BOX */
  .kpi-box {
    text-align: center;
    padding: 7px 6px;
    background: #FFFFFF;
    border: 1px solid var(--slate-200);
    border-top: 3px solid var(--accent);
    border-radius: 6px;
  }

  .kpi-val {
    font-size: 12.5pt;
    font-weight: 800;
    color: var(--primary);
    line-height: 1.1;
  }

  .kpi-lbl {
    font-size: 7pt;
    color: var(--slate-600);
    margin-top: 2px;
    font-weight: 600;
  }

  .mockup-window {
    border: 1.5px solid var(--slate-800);
    border-radius: 7px;
    overflow: hidden;
    background: #0F172A;
    color: #FFFFFF;
    margin: 5px 0 7px 0;
  }

  .mockup-bar {
    background: #1E293B;
    padding: 4px 9px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 7pt;
    border-bottom: 1px solid #334155;
  }

  .mockup-dots span {
    display: inline-block;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    margin-right: 3px;
  }

  .diagram-box {
    border: 1px solid var(--slate-300);
    background: #FFFFFF;
    border-radius: 7px;
    padding: 7px;
    margin: 5px 0 7px 0;
    text-align: center;
  }
</style>
</head>
<body>

<!-- ==================== PAGE 1 : COVER PAGE ==================== -->
<div class="cover-page">
  <div class="cover-bg-pattern"></div>
  <div class="cover-bg-grid"></div>

  <div class="cover-top-bar">
    <div class="brand-badge">
      <span class="brand-dot"></span>
      <span>FULL-TEK CLOUD &amp; EDGE SaaS &bull; Resto &bull; Market &bull; Pharma</span>
    </div>
    <div class="doc-ref">Réf : CDC-SAAS-MR-2026-V3.0 &bull; Édition Enrichie &bull; Délai : 1 à 2 Mois</div>
  </div>

  <div class="cover-hero">
    <div class="cover-tag">Cahier des Charges Exhaustif &amp; Architecture Système</div>
    <h1 class="cover-title">
      Plateforme <span class="highlight">SaaS Cloud</span> &amp; Système Multi-Caisses <span class="gold">Offline-First</span>
    </h1>
    <div class="cover-subtitle">
      Solution de gestion intégrale nouvelle génération dédiée au secteur de la <strong>Restauration</strong> (Restaurants, Fast-Foods, Cafés, Boulangeries-Pâtisseries, Salons VIP, Traiteurs) et extensible aux <strong>Supermarchés &amp; Retail</strong>, conçue sur-mesure pour les réalités opérationnelles, monétaires et technologiques de la <strong>Mauritanie</strong>.
    </div>

    <div class="cover-pillars">
      <div class="cover-pillar-card">
        <div class="cover-pillar-title">1. Hybride Offline-First &amp; Multi-Caisses LAN</div>
        <div class="cover-pillar-desc">Continuité de service 100 % garantie sans Internet : synchronisation locale entre caisses, tablettes serveurs et écrans cuisine (KDS) + sauvegarde miroir sur clé USB/SD locale.</div>
      </div>
      <div class="cover-pillar-card gold-border">
        <div class="cover-pillar-title">2. Écosystème FinTech Mauritanien Natif</div>
        <div class="cover-pillar-desc">Gestion en Ouguiya (MRU), paiements mixtes (Cash + Bankily, Masrivi, Sedad, Bimbank, Click), afficheur client QR dynamique et gestion du carnet de crédit (« Karni »).</div>
      </div>
      <div class="cover-pillar-card">
        <div class="cover-pillar-title">3. Excellence Métier Restauration 360°</div>
        <div class="cover-pillar-desc">Plan de salle, réservations Salons VIP/Khaima, KDS cuisine, fiches techniques &amp; Food Cost, gestion des retours/offerts/repas staff, multi-tarifs et flotte de livreurs.</div>
      </div>
      <div class="cover-pillar-card gold-border">
        <div class="cover-pillar-title">4. IA Embarquée &amp; Moteur SaaS Multi-Tenant</div>
        <div class="cover-pillar-desc">Détection anti-fraude en caisse par IA, scan OCR des factures fournisseurs, bilingue Arabe (RTL) / Français, mode Formation et console Super-Admin avec licences hors-ligne.</div>
      </div>
    </div>
  </div>

  <div class="cover-client-box">
    <div>
      <div class="client-meta-label">Client &amp; Porteur du Projet</div>
      <div class="client-meta-value">M. Taha Chouaib</div>
      <div class="client-meta-sub">Investisseur &amp; Propriétaire SaaS</div>
    </div>
    <div>
      <div class="client-meta-label">Marché Cible</div>
      <div class="client-meta-value" style="color:#34D399;">Mauritanie (MRU)</div>
      <div class="client-meta-sub">Nouakchott, Nouadhibou &amp; National</div>
    </div>
    <div>
      <div class="client-meta-label">Architecture</div>
      <div class="client-meta-value" style="color:#FFFFFF;">Cloud + Edge POS</div>
      <div class="client-meta-sub">Restauration + Market/Retail</div>
    </div>
    <div>
      <div class="client-meta-label">Délai de Réalisation</div>
      <div class="client-meta-value" style="color:#38BDF8;">1 à 2 Mois</div>
      <div class="client-meta-sub">4 à 8 Semaines (Agile)</div>
    </div>
  </div>

  <div class="cover-footer">
    <div>CONFIDENTIEL &mdash; Propriété intellectuelle réservée à M. Taha Chouaib</div>
    <div>Architecture SaaS Moderne &bull; IA &bull; Mobile &bull; POS Hardware &bull; 13 Pages</div>
  </div>
</div>

<!-- ==================== PAGE 2 : SECTION 01 - VISION STRATEGIQUE & SOMMAIRE ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 01</span>
        <h2 class="section-title">Sommaire Exécutif &amp; Vision Stratégique du Projet</h2>
      </div>
      <span class="section-badge">Vision &amp; Opportunité Marché</span>
    </div>

    <p>
      Ce cahier des charges définit l'architecture fonctionnelle, technique, sécuritaire et commerciale d'une plateforme <strong>SaaS (Software as a Service) de Point de Vente (POS) et de Gestion Intégrée</strong> financée et portée par <strong>M. Taha Chouaib</strong>. L'objectif est de déployer en <strong>1 à 2 mois (4 à 8 semaines)</strong> le leader technologique de l'encaissement et du pilotage en <strong>Mauritanie</strong>, avec une spécialisation d'excellence sur le secteur de la <strong>Restauration</strong> (restaurants assis, fast-foods, cafés, boulangeries-pâtisseries, salons VIP, traiteurs) tout en intégrant un socle modulaire pour les <strong>Markets, Supérettes et Commerces multi-caisses</strong>.
    </p>

    <div class="grid-4">
      <div class="kpi-box">
        <div class="kpi-val">100%</div>
        <div class="kpi-lbl">Autonomie Offline-First (0 perte de vente sans Internet)</div>
      </div>
      <div class="kpi-box" style="border-top-color: var(--gold);">
        <div class="kpi-val">&lt; 50 ms</div>
        <div class="kpi-lbl">Synchronisation Multi-Caisses &amp; Cuisine sur réseau LAN</div>
      </div>
      <div class="kpi-box" style="border-top-color: var(--blue-tech);">
        <div class="kpi-val">4 &ndash; 8 Sem.</div>
        <div class="kpi-lbl">Livraison Agile Rapide : MVP en 1 mois, Complet en 2 mois</div>
      </div>
      <div class="kpi-box" style="border-top-color: var(--purple);">
        <div class="kpi-val">FR / AR</div>
        <div class="kpi-lbl">Interface Bilingue native Français (LTR) &amp; Arabe (RTL)</div>
      </div>
    </div>

    <h3><span class="h3-dot"></span>1.1 Pourquoi les solutions étrangères échouent en Mauritanie (Le constat terrain)</h3>
    <div class="grid-2">
      <div class="card">
        <div class="card-title">Problèmes des logiciels Cloud ou PC classiques <span class="badge badge-red">Limites actuelles</span></div>
        <ul>
          <li><strong>Dépendance à Internet :</strong> La moindre coupure ADSL/4G bloque l'encaissement aux heures de pointe (déjeuner, dîner, Iftar).</li>
          <li><strong>Inadaptation aux paiements locaux :</strong> Aucune gestion structurée des wallets mauritaniens (<em>Bankily, Masrivi, Sedad, Bimbank, Click</em>) ni des paiements mixtes.</li>
          <li><strong>Coulage et fraude interne :</strong> En restauration, jusqu'à 15 % à 25 % du chiffre d'affaires est perdu à cause des annulations non contrôlées, des plats refaits non tracés, du vol de stock en cuisine et des fausses captures mobiles.</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">La Réponse du SaaS de M. Taha Chouaib <span class="badge badge-green">Avantage Décisif</span></div>
        <ul>
          <li><strong>Architecture Hybride Cloud + Local Edge :</strong> Les caisses fonctionnent en autonomie totale hors-ligne et communiquent entre elles sur le Wi-Fi local (Caisse 1 &harr; Caisse 2 &harr; Tablettes Serveurs &harr; Cuisine).</li>
          <li><strong>Contrôle total du Cash &amp; Wallets (MRU) :</strong> Réconciliation exacte par portefeuille mobile et contrôle anti-fraude assisté par Intelligence Artificielle.</li>
          <li><strong>Rentabilité immédiate pour le restaurateur :</strong> Fiches recettes au gramme près, alertes WhatsApp en temps réel et application mobile dédiée au propriétaire.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>1.2 Structure Complète du Dossier (11 Sections Stratégiques, Métiers &amp; Techniques)</h3>
    <div class="toc-grid">
      <div class="toc-item">
        <div class="toc-num">01</div>
        <div class="toc-text">
          <strong>Vision Stratégique &amp; Contexte Mauritanien (p. 2)</strong>
          <span>Positionnement marché, enjeux locaux (MRU, coupures, wallets) et proposition de valeur.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">02</div>
        <div class="toc-text">
          <strong>Architecture Hybride : Cloud SaaS + Offline LAN (p. 3)</strong>
          <span>Fonctionnement LAN Master/Peer multi-caisses, moteur de sync CRDT et sauvegarde USB locale.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">03</div>
        <div class="toc-text">
          <strong>Module Restauration 360° : Caisse &amp; Salle (p. 4)</strong>
          <span>Caisse tactile rapide FR/AR, plan de salle interactif, tablettes serveurs (PAD), division de note.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">04</div>
        <div class="toc-text">
          <strong>Fonctions Avancées : VIP/Khaima, Retours &amp; Multi-Prix (p. 5)</strong>
          <span>Réservations Salons VIP, Traiteur, gestion des retours/remakes, repas staff, Happy Hour &amp; Mode Formation.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">05</div>
        <div class="toc-text">
          <strong>Parcours Client Digital : QR Table, Kiosk &amp; Livraison (p. 6)</strong>
          <span>Menu QR Code à table, borne tactile, double écran client et flotte de livreurs Nouakchott.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">06</div>
        <div class="toc-text">
          <strong>Cuisine (KDS), Fiches Recettes, HACCP &amp; Food Cost (p. 7)</strong>
          <span>Écrans cuisine multi-postes, déstockage au gramme, DLC interne, contrôle des écarts et cuisine centrale.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">07</div>
        <div class="toc-text">
          <strong>Spécificités Mauritaniennes, Market/Retail, Droits d'Accès (RBAC) &amp; Stock avec Péremption (p. 8-10)</strong>
          <span>Bankily/Masrivi/Sedad, paiement mixte, clôture aveugle, carnet de crédit (Karni), rôles/permissions, lots, FEFO &amp; dates d'expiration (Supermarché/Pharmacie).</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">08</div>
        <div class="toc-text">
          <strong>IA Embarquée &amp; Automatisation WhatsApp (p. 11)</strong>
          <span>IA Anti-fraude caissiers, OCR factures fournisseurs, prévisions Ramadan, rapports WhatsApp.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">09</div>
        <div class="toc-text">
          <strong>Portail Super-Admin SaaS &amp; Modèle Financier (p. 12)</strong>
          <span>Console de M. Taha Chouaib, licences hors-ligne, import Excel 1-clic, mises à jour OTA et MRR.</span>
        </div>
      </div>
      <div class="toc-item">
        <div class="toc-num">10</div>
        <div class="toc-text">
          <strong>Back-Office, App « Boss », Stack, Hardware &amp; Roadmap 1-2 Mois (p. 13-16)</strong>
          <span>Pilotage mobile, RH, architecture BDD, câblage matériel et planning d'exécution en 8 semaines.</span>
        </div>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 02 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 3 : SECTION 02 - ARCHITECTURE HYBRIDE OFFLINE-FIRST ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 02</span>
        <h2 class="section-title">Architecture Hybride : Cloud SaaS &amp; Multi-Caisses Offline-First</h2>
      </div>
      <span class="section-badge">Cœur Technologique</span>
    </div>

    <p>
      La plus grande force technique du projet de <strong>M. Taha Chouaib</strong> réside dans son moteur <strong>« Dual-Engine (Cloud + Local Edge Mesh) »</strong>. Contrairement aux caisses web classiques qui s'arrêtent dès que la fibre ou la 4G coupe, et contrairement aux anciens logiciels installés sur un seul PC qui ne permettent aucune gestion à distance, notre architecture combine les deux mondes sans compromis.
    </p>

    <div class="diagram-box">
      <div style="font-weight:800; color:var(--primary); font-size:8.6pt; margin-bottom:4px;">
        SCHÉMA D'ARCHITECTURE : SYNCHRONISATION MULTI-CAISSES LOCALE (LAN) &amp; CLOUD SAAS
      </div>
      <svg viewBox="0 0 820 250" width="100%" height="205" xmlns="http://www.w3.org/2000/svg" style="font-family: 'Inter', sans-serif;">
        <rect x="10" y="6" width="800" height="80" rx="8" fill="#EFF6FF" stroke="#93C5FD" stroke-width="1.5" stroke-dasharray="5,3"/>
        <text x="24" y="22" fill="#1E40AF" font-size="9.5" font-weight="700">ZONE CLOUD SAAS (EN LIGNE - HAUTE DISPONIBILITÉ MULTI-TENANT)</text>

        <rect x="25" y="30" width="175" height="46" rx="6" fill="#0A2540"/>
        <text x="112" y="50" fill="#34D399" font-size="9" font-weight="700" text-anchor="middle">Portail Super-Admin SaaS</text>
        <text x="112" y="64" fill="#CBD5E1" font-size="7.8" text-anchor="middle">Gestion Clients, Licences &amp; MRU</text>

        <rect x="220" y="30" width="195" height="46" rx="6" fill="#1E3A8A"/>
        <text x="317" y="50" fill="#FFFFFF" font-size="9" font-weight="700" text-anchor="middle">Serveur Central &amp; Moteur Sync</text>
        <text x="317" y="64" fill="#93C5FD" font-size="7.8" text-anchor="middle">PostgreSQL Multi-Tenant + Redis</text>

        <rect x="435" y="30" width="175" height="46" rx="6" fill="#065F46"/>
        <text x="522" y="50" fill="#FFFFFF" font-size="9" font-weight="700" text-anchor="middle">App Mobile Propriétaire</text>
        <text x="522" y="64" fill="#A7F3D0" font-size="7.8" text-anchor="middle">Dashboard Live, Alertes &amp; IA</text>

        <rect x="628" y="30" width="168" height="46" rx="6" fill="#047857"/>
        <text x="712" y="50" fill="#FFFFFF" font-size="9" font-weight="700" text-anchor="middle">Passerelle WhatsApp &amp; QR</text>
        <text x="712" y="64" fill="#A7F3D0" font-size="7.8" text-anchor="middle">Rapports Z, Commandes en ligne</text>

        <line x1="317" y1="76" x2="317" y2="116" stroke="#00A86B" stroke-width="2.5" stroke-dasharray="4,3"/>
        <polygon points="317,76 312,84 322,84" fill="#00A86B"/>
        <polygon points="317,116 312,108 322,108" fill="#00A86B"/>
        <rect x="328" y="87" width="320" height="20" rx="4" fill="#FEF3C7" stroke="#F59E0B"/>
        <text x="488" y="100" fill="#92400E" font-size="8" font-weight="700" text-anchor="middle">Sync Delta Automatique dès qu'Internet est disponible (4G / Fibre)</text>

        <rect x="10" y="116" width="800" height="128" rx="8" fill="#ECFDF5" stroke="#10B981" stroke-width="2"/>
        <text x="24" y="133" fill="#065F46" font-size="9.5" font-weight="700">ZONE LOCALE RESTAURANT / MARKET (100% FONCTIONNELLE MÊME SANS INTERNET VIA WIFI/LAN LOCAL)</text>

        <rect x="25" y="144" width="190" height="88" rx="6" fill="#0A2540" stroke="#34D399" stroke-width="2"/>
        <text x="120" y="162" fill="#FBBF24" font-size="9" font-weight="700" text-anchor="middle">CAISSE PRINCIPALE (Master Edge)</text>
        <text x="120" y="177" fill="#FFFFFF" font-size="7.8" text-anchor="middle">&bull; Base SQLite Locale Chiffrée</text>
        <text x="120" y="190" fill="#FFFFFF" font-size="7.8" text-anchor="middle">&bull; Miroir Auto sur Clé USB / SD</text>
        <text x="120" y="203" fill="#FFFFFF" font-size="7.8" text-anchor="middle">&bull; Tiroir-Caisse RJ11 + Imprimante</text>
        <text x="120" y="219" fill="#34D399" font-size="7.4" font-weight="700" text-anchor="middle">Élection auto d'un nouveau Master si panne</text>

        <line x1="215" y1="188" x2="265" y2="188" stroke="#0A2540" stroke-width="2.5"/>

        <rect x="265" y="144" width="160" height="88" rx="6" fill="#FFFFFF" stroke="#0A2540" stroke-width="1.5"/>
        <text x="345" y="162" fill="#0A2540" font-size="8.6" font-weight="700" text-anchor="middle">CAISSES SECONDAIRES (2..N)</text>
        <text x="345" y="179" fill="#334155" font-size="7.8" text-anchor="middle">Caisse Terrasse / Drive / Market</text>
        <text x="345" y="194" fill="#334155" font-size="7.8" text-anchor="middle">Base locale synchronisée en</text>
        <text x="345" y="209" fill="#00A86B" font-size="7.8" font-weight="700" text-anchor="middle">temps réel (&lt; 50ms sur LAN)</text>

        <line x1="425" y1="188" x2="455" y2="188" stroke="#0A2540" stroke-width="2.5"/>

        <rect x="455" y="144" width="160" height="88" rx="6" fill="#FFFFFF" stroke="#0A2540" stroke-width="1.5"/>
        <text x="535" y="162" fill="#0A2540" font-size="8.6" font-weight="700" text-anchor="middle">TABLETTES SERVEURS / PAD</text>
        <text x="535" y="179" fill="#334155" font-size="7.8" text-anchor="middle">Prise de commande à table</text>
        <text x="535" y="194" fill="#334155" font-size="7.8" text-anchor="middle">Plan de salle partagé en direct</text>
        <text x="535" y="209" fill="#2563EB" font-size="7.8" font-weight="700" text-anchor="middle">Android / iOS / Terminaux Sunmi</text>

        <line x1="615" y1="188" x2="645" y2="188" stroke="#0A2540" stroke-width="2.5"/>

        <rect x="645" y="144" width="150" height="88" rx="6" fill="#FFFFFF" stroke="#0A2540" stroke-width="1.5"/>
        <text x="720" y="162" fill="#0A2540" font-size="8.6" font-weight="700" text-anchor="middle">CUISINE (KDS &amp; Bons)</text>
        <text x="720" y="179" fill="#334155" font-size="7.8" text-anchor="middle">Écrans Tactiles Cuisine</text>
        <text x="720" y="194" fill="#334155" font-size="7.8" text-anchor="middle">Imprimantes Thermiques IP</text>
        <text x="720" y="209" fill="#D97706" font-size="7.8" font-weight="700" text-anchor="middle">Postes : Chaud, Grill, Pizza, Bar</text>
      </svg>
    </div>

    <h3><span class="h3-dot"></span>2.1 Mode Multi-Caisses Hors-Ligne (LAN Mesh), Auto-Failover &amp; Backup Clé USB</h3>
    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">1. Communication inter-caisses sans Internet</div>
        <ul>
          <li>Dans un établissement disposant de <strong>plusieurs caisses</strong> et tablettes serveurs connectées au routeur Wi-Fi/Ethernet local, tout fonctionne à 100 % même si l'opérateur Internet (Mattel, Mauritel, Chinguitel) est coupé.</li>
          <li>Un serveur ouvre la <strong>Table 12</strong> sur sa tablette : la Caisse Principale et la Caisse Terrasse voient immédiatement la Table 12 passer en statut « Occupée ».</li>
          <li>Le bon de fabrication part instantanément sur l'écran cuisine (KDS) et sur l'imprimante thermique via l'adresse IP locale (port TCP 9100).</li>
        </ul>
      </div>
      <div class="card-white">
        <div class="card-title">2. Auto-Failover &amp; Sauvegarde Miroir sur Clé USB</div>
        <ul>
          <li><strong>Bascule Automatique (Auto-Failover) :</strong> Si la Caisse N°1 tombe en panne en plein service, la Caisse N°2 (qui possède un réplica temps réel) prend automatiquement le relais comme Master Local sans aucune perte.</li>
          <li><strong>Protection contre le crash disque hors-ligne (Cold Backup USB) :</strong> Et si le disque dur d'une caisse mono-poste grille alors qu'Internet était coupé depuis 3 jours ? Le logiciel écrit une <strong>copie chiffrée en temps réel sur une mini clé USB/SD</strong> branchée sur la caisse !</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>2.2 Moteur de Synchronisation Cloud &amp; Résolution Automatique des Conflits</h3>
    <table>
      <thead>
        <tr>
          <th style="width:22%;">Scénario Opérationnel</th>
          <th style="width:39%;">Comportement en Mode Hors-Ligne (Offline)</th>
          <th style="width:39%;">Comportement au Retour d'Internet (Sync Cloud)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Ventes &amp; Encaissements</strong></td>
          <td>Stockage local dans un journal d'événements immuable (<em>Append-Only Event Log</em>) signé cryptographiquement.</td>
          <td>Envoi par lots compressés (Delta Sync). Le Cloud reconstitue le CA, met à jour l'App Boss et envoie les alertes WhatsApp.</td>
        </tr>
        <tr>
          <td><strong>Déstockage &amp; Inventaire</strong></td>
          <td>Les ventes décrémentent le stock local sous forme d'opérations relatives (<code>-2 Burgers</code>, <code>-1 Coca</code>).</td>
          <td>Compteurs <strong>CRDT (Conflict-free Replicated Data Types)</strong> : toutes les opérations de toutes les caisses s'additionnent sans conflit.</td>
        </tr>
        <tr>
          <td><strong>Modification Prix / Menu</strong></td>
          <td>Le gérant peut modifier un prix ou désactiver un plat en rupture (« 86 ») directement sur le réseau local.</td>
          <td>Propagation par horloge logique hybride (HLC) et journal d'audit complet traçant l'auteur de la modification.</td>
        </tr>
        <tr>
          <td><strong>Contrôle Licence SaaS</strong></td>
          <td>La caisse vérifie un <strong>Jeton de Licence Cryptographique (Lease Token)</strong> local valable durant la période de grâce (ex: 7 jours).</td>
          <td>Renouvellement transparent du jeton si l'abonnement auprès de <strong>M. Taha Chouaib</strong> est à jour.</td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 03 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 4 : SECTION 03 - MODULE RESTAURATION 360 (CAISSE & SALLE) ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 03</span>
        <h2 class="section-title">Cœur Métier : Module Restauration 360° (Caisse, Salle &amp; Serveurs)</h2>
      </div>
      <span class="section-badge">Priorité Secteur Restauration</span>
    </div>

    <p>
      Le module Restauration est conçu pour offrir une <strong>rapidité d'encaissement extrême aux heures de rush</strong> (3 clics maximum par commande) tout en s'adaptant à tous les formats mauritaniens : restaurants assis, fast-foods (burgers, chawarmas, tacos, pizzerias), cafés/salons de thé, boulangeries-pâtisseries et lounges.
    </p>

    <div class="mockup-window">
      <div class="mockup-bar">
        <div class="mockup-dots">
          <span style="background:#EF4444;"></span>
          <span style="background:#F59E0B;"></span>
          <span style="background:#10B981;"></span>
          <strong style="margin-left:5px; color:#E2E8F0;">APERÇU MAQUETTE : ÉCRAN CAISSE TACTILE RESTAURATION (BILINGUE FR / AR)</strong>
        </div>
        <div style="color:#34D399; font-weight:700;">● LAN ACTIF (3 Caisses + 2 KDS) | ● CLOUD SYNC OK | Caissier : Ahmed</div>
      </div>
      <div style="display:grid; grid-template-columns: 1.15fr 1.85fr; gap:7px; padding:7px; background:#0F172A; font-size:7.4pt;">
        <div style="background:#1E293B; border-radius:5px; padding:7px; display:flex; flex-direction:column; justify-content:space-between;">
          <div>
            <div style="display:flex; justify-content:space-between; border-bottom:1px solid #334155; padding-bottom:4px; margin-bottom:5px;">
              <span><strong style="color:#FBBF24;">TABLE T-08 (Terrasse)</strong> &bull; 4 Couverts</span>
              <span style="background:#065F46; color:#A7F3D0; padding:1px 5px; border-radius:4px;">Sur Place</span>
            </div>
            <div style="display:flex; justify-content:space-between; padding:2.5px 0; border-bottom:1px dashed #334155;">
              <span><strong>2x</strong> Méchoui Royal Individuel <br><em style="color:#94A3B8; font-size:6.6pt;">+ Sans oignon, + Sauce algérienne</em></span>
              <span style="font-weight:700;">900 MRU</span>
            </div>
            <div style="display:flex; justify-content:space-between; padding:2.5px 0; border-bottom:1px dashed #334155;">
              <span><strong>1x</strong> Pizza Reine (Grande) <br><em style="color:#94A3B8; font-size:6.6pt;">+ Supplément Mozzarella (+60 MRU)</em></span>
              <span style="font-weight:700;">410 MRU</span>
            </div>
            <div style="display:flex; justify-content:space-between; padding:2.5px 0; border-bottom:1px dashed #334155;">
              <span><strong>3x</strong> Jus Naturel Bouye / Bissap</span>
              <span style="font-weight:700;">300 MRU</span>
            </div>
          </div>
          <div style="margin-top:6px; border-top:1.5px solid #475569; padding-top:5px;">
            <div style="display:flex; justify-content:space-between; font-size:9.2pt; font-weight:800; color:#34D399; margin-bottom:5px;">
              <span>TOTAL À PAYER (TTC)</span>
              <span>1 610,00 MRU</span>
            </div>
            <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:4px; text-align:center; font-weight:700; font-size:6.6pt;">
              <div style="background:#059669; padding:4px 2px; border-radius:4px;">CASH MRU</div>
              <div style="background:#D97706; padding:4px 2px; border-radius:4px;">BANKILY</div>
              <div style="background:#2563EB; padding:4px 2px; border-radius:4px;">MASRIVI / SEDAD</div>
              <div style="background:#7C3AED; padding:4px 2px; border-radius:4px;">MIXTE / KARNI</div>
            </div>
          </div>
        </div>
        <div style="background:#1E293B; border-radius:5px; padding:7px;">
          <div style="display:flex; gap:4px; margin-bottom:6px; font-weight:700; font-size:6.8pt;">
            <span style="background:#00A86B; color:#FFF; padding:3px 7px; border-radius:4px;">🔥 Grillades &amp; Plats</span>
            <span style="background:#334155; color:#CBD5E1; padding:3px 7px; border-radius:4px;">🍕 Pizzas &amp; Tacos</span>
            <span style="background:#334155; color:#CBD5E1; padding:3px 7px; border-radius:4px;">🍔 Burgers &amp; Menus</span>
            <span style="background:#334155; color:#CBD5E1; padding:3px 7px; border-radius:4px;">🥤 Boissons &amp; Thé</span>
            <span style="background:#334155; color:#FBBF24; padding:3px 7px; border-radius:4px; margin-left:auto;">عربي / FR</span>
          </div>
          <div style="display:grid; grid-template-columns: repeat(3, 1fr); gap:5px;">
            <div style="background:#0F172A; border:1px solid #334155; border-left:3px solid #10B981; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FFF;">Méchoui Royal</div>
              <div style="color:#94A3B8; font-size:6.5pt;">مشوي ملكي</div>
              <div style="color:#34D399; font-weight:800; margin-top:2px;">450 MRU</div>
            </div>
            <div style="background:#0F172A; border:1px solid #334155; border-left:3px solid #10B981; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FFF;">Menu Tacos XL</div>
              <div style="color:#94A3B8; font-size:6.5pt;">تاكوس كبير + بطاطس</div>
              <div style="color:#34D399; font-weight:800; margin-top:2px;">280 MRU</div>
            </div>
            <div style="background:#0F172A; border:1px solid #334155; border-left:3px solid #F59E0B; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FFF;">Chawarma Arabe</div>
              <div style="color:#94A3B8; font-size:6.5pt;">شاورما عربي</div>
              <div style="color:#34D399; font-weight:800; margin-top:2px;">220 MRU</div>
            </div>
            <div style="background:#0F172A; border:1px solid #334155; border-left:3px solid #3B82F6; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FFF;">Pizza 4 Saisons</div>
              <div style="color:#94A3B8; font-size:6.5pt;">بيتزا 4 فصول</div>
              <div style="color:#34D399; font-weight:800; margin-top:2px;">380 MRU</div>
            </div>
            <div style="background:#0F172A; border:1px solid #334155; border-left:3px solid #EC4899; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FFF;">Burger Double Smash</div>
              <div style="color:#94A3B8; font-size:6.5pt;">برغر دبل سماش</div>
              <div style="color:#34D399; font-weight:800; margin-top:2px;">260 MRU</div>
            </div>
            <div style="background:#311010; border:1px solid #991B1B; border-left:3px solid #EF4444; padding:5px; border-radius:4px;">
              <div style="font-weight:700; color:#FCA5A5;">Poisson Braisé (ÉPUISÉ)</div>
              <div style="color:#F87171; font-size:6.5pt;">Rupture cuisine (86)</div>
              <div style="color:#FCA5A5; font-weight:800; margin-top:2px;">550 MRU</div>
            </div>
          </div>
          <div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:4px; margin-top:6px; font-size:6.8pt; font-weight:700; text-align:center;">
            <div style="background:#334155; padding:4px; border-radius:4px;">🗺️ Plan de Salle</div>
            <div style="background:#334155; padding:4px; border-radius:4px;">👨‍🍳 Envoyer Cuisine</div>
            <div style="background:#334155; padding:4px; border-radius:4px;">✂️ Diviser Note</div>
            <div style="background:#334155; padding:4px; border-radius:4px;">🛵 Assigner Livreur</div>
          </div>
        </div>
      </div>
    </div>

    <h3><span class="h3-dot"></span>3.1 Gestion de la Salle, des Tables &amp; Prise de Commande Serveurs (PAD)</h3>
    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">Plan de Salle Interactif &amp; Zones Multiples</div>
        <ul>
          <li><strong>Éditeur visuel Drag &amp; Drop :</strong> Création de plusieurs salles/zones (<em>Salle Climatisée, Terrasse, Étage, Salon VIP / Khaima privée</em>) avec formes de tables personnalisables.</li>
          <li><strong>Statuts temps réel :</strong> <span class="badge badge-green">Libre</span> <span class="badge badge-blue">Occupée</span> <span class="badge badge-amber">Attente &gt;20 min</span> <span class="badge badge-purple">Addition imprimée</span> avec chronomètre d'occupation et montant en cours sur chaque table.</li>
          <li><strong>Opérations en 2 clics :</strong> Transfert de table (ex: client passant de la terrasse à la salle climatisée), fusion de tables pour les familles, changement de serveur lors de la relève d'équipe.</li>
        </ul>
      </div>
      <div class="card-white">
        <div class="card-title">Application Serveur Mobile (PAD) &amp; Division de Note</div>
        <ul>
          <li><strong>Prise de commande au pied de la table :</strong> Application mobile sur smartphone Android ou terminal portable <em>Sunmi</em> connectée en Wi-Fi local. La commande part en cuisine sans que le serveur n'ait à se déplacer vers la caisse.</li>
          <li><strong>Ordre d'envoi (« Suite / Réclamer ») :</strong> Envoi immédiat des boissons/entrées, mise en attente des plats chauds, puis bouton <em>« Réclamer Suite Table 8 »</em> en un clic.</li>
          <li><strong>Division d'addition (Split Bill) :</strong> Par article (chacun paie ce qu'il a consommé), à parts égales, ou par montant libre.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>3.2 Mode Fast-Food, Pizzeria, Café &amp; Boulangerie-Pâtisserie</h3>
    <div class="grid-3">
      <div class="card">
        <div class="card-title">Menus, Combos &amp; Options</div>
        <p style="margin:0;">
          Gestion intelligente des formules (<em>Burger + Frite + Boisson au choix</em>). Pop-up automatique pour les <strong>modificateurs obligatoires</strong> (cuisson, sauce) et <strong>suppléments payants</strong> (fromage +40 MRU, double viande +120 MRU) déstockés en temps réel.
        </p>
      </div>
      <div class="card">
        <div class="card-title">File d'Attente &amp; Écran TV</div>
        <p style="margin:0;">
          Chaque ticket génère un <strong>Numéro d'Appel</strong> (ex: <code>N° 42</code>). Un écran TV affiche les colonnes <em>« En préparation »</em> et <em>« Prêt à retirer »</em> avec annonce vocale bilingue (Arabe / Français) dès validation sur l'écran cuisine KDS.
        </p>
      </div>
      <div class="card">
        <div class="card-title">Hybride Pâtisserie / Poids</div>
        <p style="margin:0;">
          Pour les boulangeries-pâtisseries et salons de thé : combinaison sur le même écran de la vente au comptoir par <strong>code-barres / balance électronique</strong> (gâteaux au kilo, viennoiseries) et du service à table.
        </p>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 04 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 5 : SECTION 04 - FONCTIONS METIERS AVANCEES (VIP/KHAIMA, RETOURS, MULTI-TARIFS, FORMATION) ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 04</span>
        <h2 class="section-title">Fonctions Métiers Avancées : Salons VIP, Traiteur, Retours &amp; Multi-Tarifs</h2>
      </div>
      <span class="section-badge">Gestion Fine des Cas Réels</span>
    </div>

    <p>
      Pour couvrir 100 % des situations réelles vécues quotidiennement dans les restaurants, cafés, pâtisseries et commerces en Mauritanie, le cahier des charges intègre ces modules opérationnels critiques souvent oubliés dans les logiciels standards :
    </p>

    <h3><span class="h3-dot"></span>4.1 Réservations de Tables, Salons Privés (VIP / Khaima) &amp; Commandes Traiteur</h3>
    <div class="grid-2">
      <div class="card-gold">
        <div class="card-title">Agenda des Réservations &amp; Salons Privés (Khaima)</div>
        <ul>
          <li><strong>Planning visuel des réservations :</strong> Prise de réservation par téléphone ou WhatsApp avec heure d'arrivée, nombre de convives et préférences (table calme, terrasse, salon familial).</li>
          <li><strong>Forfait Salon VIP / Khaima :</strong> Possibilité d'appliquer automatiquement un <em>minimum de consommation</em> (ex: 3 000 MRU min.) ou un forfait horaire sur les salons privés.</li>
          <li><strong>Gestion des Acomptes (Arboun) :</strong> Encaissement d'un acompte à la réservation (par Bankily ou Cash). Lors du paiement final à la caisse, l'acompte est automatiquement déduit de l'addition !</li>
        </ul>
      </div>
      <div class="card-blue">
        <div class="card-title">Module Événements, Banquets &amp; Service Traiteur</div>
        <ul>
          <li><strong>Devis &amp; Commandes Spéciales :</strong> Pour les mariages, baptêmes (<em>Aqîqah</em>), réceptions d'entreprises ou grands plateaux pâtisserie/méchoui.</li>
          <li><strong>Bon de Production Anticipé :</strong> Génère automatiquement la liste d'achats des matières premières nécessaires pour l'événement 48h à l'avance et le bon de fabrication pour la cuisine.</li>
          <li><strong>Suivi du Solde Client :</strong> Gestion du paiement en plusieurs tranches (ex: 50 % à la commande, 50 % à la livraison).</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>4.2 Gestion Rigoureuse des Retours, Plats Refaits (« Remake »), Offerts &amp; Repas Staff</h3>
    <table>
      <thead>
        <tr>
          <th style="width:24%;">Cas Opérationnel</th>
          <th style="width:42%;">Traitement Logique &amp; Comptable dans le SaaS</th>
          <th style="width:34%;">Impact sur le Stock &amp; Anti-Fraude</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Plat Renvoyé &amp; Refait (« Remake »)</strong><br><em>Ex: Plat froid ou erreur cuisson</em></td>
          <td>Le client ne paie qu'une seule fois son plat, mais la cuisine doit en préparer un deuxième. Un bon spécial <code>** REFAIRE PRIORITAIRE **</code> est envoyé au KDS.</td>
          <td><strong>Double déstockage tracé :</strong> Le premier plat est comptabilisé en « Perte Cuisine » (avec motif obligatoire) et le second en vente normale.</td>
        </tr>
        <tr>
          <td><strong>Retour Produit Intact / Échange</strong><br><em>Ex: Boisson non ouverte, article Market</em></td>
          <td>Génération d'un ticket d'avoir (remboursement Cash/Bankily ou bon d'achat valable sur une prochaine commande) soumis au code PIN Manager.</td>
          <td><strong>Remise en stock automatique :</strong> L'article non entamé réintègre immédiatement le stock disponible du point de vente.</td>
        </tr>
        <tr>
          <td><strong>Offert Maison (Complimentary) &amp; Compte Patron</strong></td>
          <td>Lorsque le propriétaire consomme ou offre un thé/dessert/plat à un invité VIP, la vente est validée sur le bouton <strong>« Offert / Compte Patron »</strong>.</td>
          <td><strong>Distinction Vol vs Générosité :</strong> La matière première est déstockée proprement et valorisée au coût d'achat dans un rapport dédié.</td>
        </tr>
        <tr>
          <td><strong>Repas du Personnel (Staff Meals)</strong></td>
          <td>Enregistrement quotidien des repas pris par l'équipe (cuisiniers, serveurs, livreurs) avec plafond journalier par employé.</td>
          <td>Déduit les ingrédients du stock sans gonfler artificiellement le chiffre d'affaires ni créer de faux écarts d'inventaire.</td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>4.3 Grilles Multi-Tarifs Automatiques, Happy Hour &amp; Mode Formation (« Bac à Sable »)</h3>
    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">Multi-Tarifs par Zone &amp; Horaires (Happy Hour)</div>
        <ul>
          <li><strong>Prix automatique selon le canal :</strong> Un même plat ou boisson peut avoir un prix différent appliqué automatiquement : <em>Prix Comptoir / À Emporter (200 MRU)</em>, <em>Prix Salle (230 MRU)</em>, <em>Prix Salon VIP (280 MRU)</em>, <em>Prix Tarif Nuit</em>.</li>
          <li><strong>Promotions programmées :</strong> Offres automatiques selon l'heure ou le jour (ex: « 2 Pizzas achetées = 1 offerte le Mardi » ou remise automatique de 15 % entre 16h et 18h).</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">Mode « Formation / Training » Intégré sur Caisse</div>
        <ul>
          <li>Pour former un nouveau caissier ou serveur en 30 minutes sans risquer de fausser la comptabilité du restaurant :</li>
          <li>Activation du <strong>« Mode Formation »</strong> (bandeau orange clignotant). Toutes les ventes et impressions fonctionnent normalement (avec mention <code>*** TICKET DE FORMATION - NON VALIDE ***</code>), mais <strong>aucun impact n'est enregistré dans le CA réel ni dans le stock</strong> !</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 05 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 6 : SECTION 05 - PARCOURS CLIENT DIGITAL : QR, KIOSK, DOUBLE ECRAN & LIVRAISON ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 05</span>
        <h2 class="section-title">Parcours Client Digital : Menu QR, Borne, Double Écran &amp; Livraison</h2>
      </div>
      <span class="section-badge">Expérience Client &amp; Omnicanal</span>
    </div>

    <p>
      Pour augmenter le chiffre d'affaires des restaurants abonnés au SaaS de <strong>M. Taha Chouaib</strong> et fluidifier le passage en caisse aux heures de pointe, la plateforme intègre quatre canaux digitaux directement reliés à la caisse et à la cuisine.
    </p>

    <div class="diagram-box">
      <div style="font-weight:800; color:var(--primary); font-size:8.4pt; margin-bottom:3px;">
        FLUX OMNICANAL DES COMMANDES (SUR PLACE, QR TABLE, BORNE KIOSK, LIVRAISON &amp; DOUBLE ÉCRAN CLIENT)
      </div>
      <svg viewBox="0 0 820 135" width="100%" height="112" xmlns="http://www.w3.org/2000/svg" style="font-family: 'Inter', sans-serif;">
        <rect x="12" y="10" width="175" height="50" rx="6" fill="#EFF6FF" stroke="#3B82F6" stroke-width="1.5"/>
        <text x="100" y="30" fill="#1E40AF" font-size="8.8" font-weight="700" text-anchor="middle">📱 QR Code sur Table</text>
        <text x="100" y="45" fill="#475569" font-size="7.4" text-anchor="middle">Client scanne, commande &amp; appelle</text>

        <rect x="12" y="72" width="175" height="50" rx="6" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
        <text x="100" y="92" fill="#92400E" font-size="8.8" font-weight="700" text-anchor="middle">🖥️ Borne Tactile (Kiosk)</text>
        <text x="100" y="107" fill="#475569" font-size="7.4" text-anchor="middle">Self-Ordering Fast-Food (FR / AR)</text>

        <line x1="187" y1="35" x2="295" y2="56" stroke="#2563EB" stroke-width="2"/>
        <line x1="187" y1="97" x2="295" y2="76" stroke="#D97706" stroke-width="2"/>

        <rect x="295" y="28" width="230" height="76" rx="8" fill="#0A2540" stroke="#00A86B" stroke-width="2"/>
        <text x="410" y="50" fill="#34D399" font-size="9.5" font-weight="800" text-anchor="middle">HUB CENTRAL CAISSE &amp; KDS</text>
        <text x="410" y="67" fill="#FFFFFF" font-size="7.8" text-anchor="middle">+ Second Écran Client (QR Bankily Live)</text>
        <text x="410" y="83" fill="#FBBF24" font-size="7.8" font-weight="700" text-anchor="middle">Impression Cuisine &amp; Déstockage</text>

        <line x1="525" y1="56" x2="633" y2="35" stroke="#00A86B" stroke-width="2"/>
        <line x1="525" y1="76" x2="633" y2="97" stroke="#7C3AED" stroke-width="2"/>

        <rect x="633" y="10" width="175" height="50" rx="6" fill="#ECFDF5" stroke="#10B981" stroke-width="1.5"/>
        <text x="720" y="30" fill="#065F46" font-size="8.8" font-weight="700" text-anchor="middle">🛵 Flotte Livreurs Internes</text>
        <text x="720" y="45" fill="#475569" font-size="7.4" text-anchor="middle">Suivi Cash/Bankily &amp; Zones Nouakchott</text>

        <rect x="633" y="72" width="175" height="50" rx="6" fill="#F5F3FF" stroke="#8B5CF6" stroke-width="1.5"/>
        <text x="720" y="92" fill="#5B21B6" font-size="8.8" font-weight="700" text-anchor="middle">💬 Click &amp; Collect / Web</text>
        <text x="720" y="107" fill="#475569" font-size="7.4" text-anchor="middle">Lien commande WhatsApp &amp; Instagram</text>
      </svg>
    </div>

    <h3><span class="h3-dot"></span>5.1 Menu Digital QR Code &amp; Affichage Client Double Écran (Customer Display)</h3>
    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">Menu QR Code Interactif <span class="badge badge-blue">+18 % de Panier Moyen</span></div>
        <ul>
          <li><strong>QR Code unique par table :</strong> Le client scanne le QR Code avec son téléphone (sans télécharger d'application), consulte le menu photo HD en Arabe ou Français, et commande directement.</li>
          <li><strong>Contrôle Serveur &amp; Boutons d'Appel :</strong> Validation en 1 clic sur la caisse avant impression cuisine, plus boutons <em>« Appeler le serveur »</em> ou <em>« Demander l'addition »</em>.</li>
        </ul>
      </div>
      <div class="card-white">
        <div class="card-title">Second Écran Client (Customer Facing Display)</div>
        <ul>
          <li>Sur les terminaux POS équipés d'un <strong>deuxième écran tourné vers le client</strong> (en fast-food, boulangerie ou supermarché) :</li>
          <li>Affichage en direct des lignes d'articles, du total en MRU, d'un carrousel publicitaire des plats phares, puis affichage du <strong>QR Code Bankily / Masrivi</strong> exact à scanner et vote de satisfaction (😍/😐/😡).</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>5.2 Mode Borne de Commande Autonome (Self-Ordering Kiosk)</h3>
    <div class="card-gold" style="margin-bottom:6px;">
      <div class="card-title">Idéal pour les Fast-Foods, Tacos, Burgers &amp; Grands Cafés à Nouakchott</div>
      <p style="margin:0;">
        L'application peut être lancée en <strong>« Mode Kiosque Client »</strong> sur n'importe quel écran tactile vertical 15"/21" à l'entrée du restaurant. Le client choisit sa langue (Arabe ou Français), compose son menu (avec suggestion automatique de suppléments : double fromage, frites XL), choisit <em>« Sur Place »</em> ou <em>« À Emporter »</em>, et récupère un ticket avec son <strong>Numéro d'Appel</strong> pour payer au comptoir ou par Bankily.
      </p>
    </div>

    <h3><span class="h3-dot"></span>5.3 Hub de Livraison (Delivery Management) &amp; Gestion de la Flotte de Livreurs</h3>
    <table>
      <thead>
        <tr>
          <th style="width:24%;">Fonctionnalité Livraison</th>
          <th style="width:76%;">Fonctionnement Détaillé &amp; Adaptation au Terrain Mauritanien</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Identification Client &amp; Carnet d'Adresses</strong></td>
          <td>Dès que le client appelle ou écrit sur WhatsApp, la saisie de son numéro (<code>+222 ...</code>) affiche automatiquement son nom, son quartier (<em>Tevragh Zeina, Ksar, Socogim, Arafat, Dar Naim, Nouadhibou...</em>), son point de repère (ex: <em>« Près de la Mosquée / Pharmacie X »</em>) et ses plats favoris.</td>
        </tr>
        <tr>
          <td><strong>Tarification par Zone</strong></td>
          <td>Calcul automatique des frais de livraison selon la zone sélectionnée (ex: Zone A = 50 MRU, Zone B = 100 MRU, Gratuit si commande &gt; 1 500 MRU) et répartition de la part livreur vs part restaurant.</td>
        </tr>
        <tr>
          <td><strong>Portefeuille Financier par Livreur (Anti-Perte)</strong></td>
          <td>Chaque livreur possède un compte de caisse flottant dans le logiciel. Lorsqu'on lui assigne 4 commandes à livrer, le système trace exactement combien il doit encaisser en <strong>Cash</strong> et quelles commandes ont été payées par <strong>Bankily/Masrivi</strong>. En fin de service, le caissier fait la <strong>« Remise Livreur »</strong> en 1 clic.</td>
        </tr>
        <tr>
          <td><strong>Suivi des Temps &amp; Agrégateurs</strong></td>
          <td>Chronométrage du temps entre le départ cuisine et le retour du livreur + gestion des commandes issues d'applications de livraison tierces avec calcul de leur commission.</td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 06 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 7 : SECTION 06 - CUISINE KDS, FICHES TECHNIQUES, HACCP & FOOD COST ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 06</span>
        <h2 class="section-title">Cuisine (KDS), Fiches Techniques, HACCP &amp; Contrôle du Food Cost</h2>
      </div>
      <span class="section-badge">Production, Stock &amp; Rentabilité</span>
    </div>

    <h3><span class="h3-dot"></span>6.1 Système d'Affichage Cuisine (KDS) &amp; Routage Multi-Postes</h3>
    <p>
      Pour éliminer les erreurs de préparation, les bons papier perdus et les cris en cuisine, la plateforme intègre un module <strong>KDS (Kitchen Display System)</strong> sur écran tactile ou TV (commandé par pavé numérique), tout en restant 100 % compatible avec les imprimantes thermiques réseau ESC/POS.
    </p>

    <div class="grid-2">
      <div class="card-blue">
        <div class="card-title">Routage Intelligent par Poste de Préparation</div>
        <ul>
          <li>Lorsqu'une commande comporte <em>1 Chawarma + 1 Pizza + 2 Jus + 1 Chicha</em>, le système éclate automatiquement le bon sur le réseau local :</li>
          <li>Le <strong>Poste Four/Pizza</strong> reçoit uniquement la Pizza ; le <strong>Poste Grill</strong> reçoit le Chawarma ; le <strong>Bar</strong> reçoit les 2 Jus ; le <strong>Poste Lounge</strong> reçoit la Chicha.</li>
          <li>L'écran du <strong>Chef Passe / Expédition</strong> consolide tous les postes pour garantir que tous les plats d'une même table partent chauds en même temps.</li>
        </ul>
      </div>
      <div class="card-gold">
        <div class="card-title">Chronomètre SLA, Alertes &amp; Rupture Instantanée (« 86 »)</div>
        <ul>
          <li><strong>Code Couleur Temps d'Attente :</strong> Le bon s'affiche en <strong>Vert</strong> (0 à 10 min), passe à l'<strong>Orange</strong> (10 à 18 min), puis clignote en <strong>Rouge</strong> (&gt; 18 min) avec signal sonore.</li>
          <li><strong>Déclaration de Rupture en 1 clic :</strong> Si le chef n'a plus de poisson frais, il touche « Rupture » sur son KDS : en moins d'une seconde, le plat est grisé et bloqué sur toutes les caisses, tablettes serveurs et menus QR Code !</li>
          <li><strong>Affichage Bilingue :</strong> Le cuisinier peut lire son écran KDS en <strong>Arabe</strong> même si la commande a été saisie en Français en salle.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>6.2 Fiches Techniques (Recettes), Déstockage au Gramme &amp; Calcul du Food Cost</h3>
    <p>
      C'est le module qui rentabilise immédiatement l'abonnement SaaS pour les clients de <strong>M. Taha Chouaib</strong> : chaque plat vendu déduit automatiquement ses ingrédients exacts (au gramme, millilitre ou unité) du stock théorique.
    </p>

    <table>
      <thead>
        <tr>
          <th>Composant / Ingrédient (Ex: Burger Classic)</th>
          <th>Unité d'Achat</th>
          <th>Quantité Déstockée par Vente</th>
          <th>Coût Matière (PMP)</th>
          <th>Impact Automatique en Temps Réel</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Viande hachée bœuf locale</td>
          <td>Kilogramme (kg)</td>
          <td><code>0,150 kg</code> (150 g)</td>
          <td>37,50 MRU</td>
          <td>Déduit 150 g du stock chambre froide à chaque validation caisse.</td>
        </tr>
        <tr>
          <td>Pain Burger Artisanal (Bun)</td>
          <td>Pièce (Unité)</td>
          <td><code>1,00 unité</code></td>
          <td>12,00 MRU</td>
          <td>Déduit 1 pain du stock boulangerie du jour.</td>
        </tr>
        <tr>
          <td>Fromage Cheddar + Sauce + Crudités</td>
          <td>Gramme / Litre</td>
          <td><code>2 tranches + 25 ml</code></td>
          <td>18,50 MRU</td>
          <td>Si le client demande « Sans fromage », la caisse ne déstocke pas le fromage !</td>
        </tr>
        <tr>
          <td>Boîte Emballage + Sac Kraft (Si À Emporter)</td>
          <td>Carton de 500</td>
          <td><code>1 boîte + 1 sac</code></td>
          <td>7,00 MRU</td>
          <td><strong>Déstocké uniquement</strong> si le mode de commande est « À Emporter » ou « Livraison ».</td>
        </tr>
        <tr style="background:#ECFDF5; font-weight:700;">
          <td colspan="3">COÛT DE REVIENT THÉORIQUE TOTAL (FOOD + PACKAGING COST)</td>
          <td>75,00 MRU</td>
          <td>Prix de vente : <strong>250 MRU</strong> &rarr; Marge Brute : <strong>175 MRU (70 %)</strong></td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>6.3 Contrôle des Écarts de Stock, Cuisine Centrale &amp; Traçabilité Hygiène (HACCP)</h3>
    <div class="grid-2">
      <div class="card-accent">
        <div class="card-title">Détection du Vol et du Gaspillage en Cuisine</div>
        <p style="margin:0;">
          En fin de journée ou de semaine, le gérant saisit sur son téléphone l'inventaire physique rapide des produits sensibles (viande, poulet, huile, fromage, canettes). Le système compare : <code>Stock Initial + Achats &minus; Ventes Théoriques = Stock Attendu</code>. S'il manque <strong>8,5 kg de viande</strong> (soit 56 burgers non encaissés), un <strong>Rapport d'Écart valorisé en MRU</strong> est envoyé au propriétaire sur WhatsApp.
        </p>
      </div>
      <div class="card-purple">
        <div class="card-title">Cuisine Centrale, Sous-Recettes &amp; DLC Secondaire</div>
        <p style="margin:0;">
          Gestion des <strong>préparations intermédiaires</strong> (ex: transformer 50 kg de poulet brut en « Broche Chawarma » ou produire en laboratoire central avec <strong>Bons de Transfert Inter-Dépôts</strong>) + impression d'étiquettes de <strong>DLC secondaire (Hygiène HACCP)</strong> indiquant l'heure de préparation et l'heure limite d'utilisation.
        </p>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 07 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 8 : SECTION 07 - SPECIFICITES MAURITANIENNES & MODULE MARKET ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 07</span>
        <h2 class="section-title">Spécificités Mauritaniennes &amp; Extension Modulaire Market / Retail</h2>
      </div>
      <span class="section-badge">Adaptation Locale 100 % Mauritanie</span>
    </div>

    <p>
      Pour s'imposer durablement en Mauritanie, la plateforme de <strong>M. Taha Chouaib</strong> intègre au cœur de son code les usages financiers, fiscaux et commerciaux locaux qu'aucun logiciel étranger ne maîtrise.
    </p>

    <h3><span class="h3-dot"></span>7.1 Écosystème des Paiements Mobiles Mauritaniens &amp; Anti-Fraude Wallets</h3>
    <div class="grid-2">
      <div class="card-gold">
        <div class="card-title">Portefeuilles Mobiles &amp; Paiement Mixte (Split Payment)</div>
        <ul>
          <li><strong>Boutons d'encaissement natifs dédiés :</strong>
            <span class="badge badge-amber">Bankily (BPM)</span>
            <span class="badge badge-blue">Masrivi (BMCI)</span>
            <span class="badge badge-green">Sedad (BCI)</span>
            <span class="badge badge-purple">Bimbank</span>
            <span class="badge badge-red">Click / Amanty</span>
            ainsi que <strong>Cash (MRU)</strong> et Cartes GIMTEL/Visa.
          </li>
          <li><strong>Encaissement Mixte sur un seul ticket :</strong> Un client dont l'addition est de <code>1 800 MRU</code> peut payer <code>1 000 MRU</code> via <strong>Bankily</strong> + <code>500 MRU</code> en <strong>Espèces</strong> + <code>300 MRU</code> via <strong>Masrivi</strong>. Le système ventile chaque montant dans le bon journal de trésorerie.</li>
          <li><strong>Affichage QR Marchand :</strong> Affichage à l'écran client du code marchand / QR Code Bankily ou Masrivi avec le montant exact à régler.</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">Sécurisation contre les Fausses Captures &amp; Clôture Z</div>
        <ul>
          <li><strong>Vérification de Référence :</strong> Lors d'un encaissement Bankily/Masrivi/Sedad, le caissier doit saisir les 4 derniers chiffres de la référence de transaction ou le numéro de téléphone client (avec option de validation automatique par lecture du SMS/notification reçu sur le téléphone marchand du restaurant).</li>
          <li><strong>Clôture de Caisse « Z » en Aveugle (Blind Close) :</strong> En fin de service, le caissier ne voit pas le montant théorique attendu. Il compte ses billets/pièces MRU (coupures de 1000, 500, 200, 100, 50, 20 MRU) et saisit ses totaux. Le système révèle immédiatement tout écart au propriétaire.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>7.2 Gestion du Carnet de Crédit (« Karni / Dettes Clients ») &amp; Comptes Entreprises</h3>
    <div class="card-white" style="margin-bottom:7px;">
      <ul>
        <li><strong>Plafond de Crédit Automatisé :</strong> Chaque client autorisé (habitué, famille ou cadre) dispose d'un plafond maximal en MRU (ex: <code>15 000 MRU</code>). Si le plafond est atteint, la caisse bloque la mise en crédit sauf autorisation PIN du gérant ou validation à distance sur l'application mobile du patron.</li>
        <li><strong>Remboursements Partiels &amp; Reçus WhatsApp :</strong> Le client peut verser un acompte à n'importe quelle caisse (en Cash ou Bankily). Un ticket de versement est imprimé et le nouveau solde restant dû lui est envoyé automatiquement par WhatsApp.</li>
        <li><strong>Conventions B2B / Repas Entreprises :</strong> Gestion des sociétés/administrations clientes dont les employés consomment via des bons ou badges, avec génération en 1 clic de la facture récapitulative mensuelle conforme DGI (avec NIF et TVA 16 %).</li>
      </ul>
    </div>

    <h3><span class="h3-dot"></span>7.3 Architecture Multi-Secteurs : Extension Native aux Markets, Supérettes &amp; Épiceries</h3>
    <p>
      Grâce à son architecture modulaire, <strong>M. Taha Chouaib</strong> peut commercialiser la même plateforme aux <strong>Supermarchés, Supérettes, Épiceries et Commerces</strong> en activant simplement le profil « Market / Retail » dans le Super-Admin :
    </p>
    <table>
      <thead>
        <tr>
          <th style="width:23%;">Fonctionnalité</th>
          <th style="width:38.5%;">Mode Restauration / Fast-Food / Café</th>
          <th style="width:38.5%;">Mode Market / Supérette / Boulangerie</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Ergonomie Caisse</strong></td>
          <td>Pavé tactile visuel par catégories, plan de salle, modificateurs de cuisson, envoi cuisine KDS.</td>
          <td>Scan code-barres ultra-rapide (douchette USB/2D), mise en attente de panier (« Client suivant »), raccourcis clavier.</td>
        </tr>
        <tr>
          <td><strong>Gestion des Unités</strong></td>
          <td>Portions, recettes composées, ingrédients au gramme/litre, menus combos.</td>
          <td>Conditionnements multiples (<strong>Unité, Pack de 6, Carton de 24</strong>) avec déstockage lié et tarifs dégressifs Demi-Gros/Gros.</td>
        </tr>
        <tr>
          <td><strong>Balances &amp; Poids</strong></td>
          <td>Plats au poids (ex: Méchoui ou poisson vendu au kilo, pâtisseries orientales).</td>
          <td>Décodage natif des étiquettes balances électroniques (codes EAN-13 préfixe <code>20</code> à <code>29</code> intégrant le poids ou le prix).</td>
        </tr>
        <tr>
          <td><strong>Traçabilité &amp; Consignes</strong></td>
          <td>Fiches techniques, calcul Food Cost, pertes cuisine &amp; casse.</td>
          <td>Gestion des dates de péremption (<strong>FEFO</strong>), suivi des <strong>emballages consignés</strong> (bouteilles/casiers) et étiquetage rayon.</td>
        </tr>
      </tbody>
    </table>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 08 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 9 : SECTION 07-A - DROITS D'ACCES & ROLES (RBAC) ==================== -->
<div class="page">
  <div class="page-body" style="zoom:0.86;">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 07-A &bull; Sécurité &amp; Habilitations</span>
        <h2 class="section-title">Gestion des Utilisateurs, Rôles &amp; Droits d'Accès (RBAC)</h2>
      </div>
      <span class="section-badge">Contrôle d'Accès Granulaire</span>
    </div>

    <p>
      Chaque établissement dispose de son <strong>propre espace isolé</strong> et de ses <strong>propres utilisateurs</strong>. Les droits sont attribués par <strong>rôle</strong> (profils prédéfinis) et peuvent être <strong>personnalisés permission par permission</strong> par le propriétaire. Aucun employé ne voit ni ne modifie plus que ce que son rôle autorise.
    </p>

    <h3><span class="h3-dot"></span>7-A.1 Profils Utilisateurs Prédéfinis</h3>
    <table>
      <thead>
        <tr>
          <th style="width:19%;">Rôle</th>
          <th style="width:30%;">Périmètre</th>
          <th style="width:51%;">Accès &amp; Interdictions Clés</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Super-Admin SaaS</strong></td>
          <td>Toute la plateforme (M. Taha Chouaib)</td>
          <td>Crée/suspend les abonnés, gère licences, plans et facturation. <strong>Ne voit pas</strong> les données de vente détaillées sans autorisation du client (support à accès tracé).</td>
        </tr>
        <tr>
          <td><strong>Propriétaire</strong></td>
          <td>Tous ses sites / établissements</td>
          <td>Accès total à son compte : rapports, marges, prix, utilisateurs, droits, paramètres, abonnement.</td>
        </tr>
        <tr>
          <td><strong>Gérant de Site</strong></td>
          <td>Un seul établissement</td>
          <td>Prix, stock, annulations, remises illimitées, clôture Z, validation des écarts. Pas d'accès à l'abonnement ni aux autres sites.</td>
        </tr>
        <tr>
          <td><strong>Caissier</strong></td>
          <td>Sa caisse / son poste</td>
          <td>Vente, encaissement, impression. <strong>Interdit :</strong> modifier un prix, voir marges, supprimer un ticket payé, rapport global (remise &amp; annulation = PIN gérant).</td>
        </tr>
        <tr>
          <td><strong>Serveur</strong></td>
          <td>Tablette salle / ses tables</td>
          <td>Prise de commande, envoi cuisine, addition. Ne voit que <strong>ses propres tables</strong> et son chiffre.</td>
        </tr>
        <tr>
          <td><strong>Cuisinier / Barman</strong></td>
          <td>Écran KDS</td>
          <td>Voit uniquement les tickets de son poste, marque « prêt ». Aucun prix, aucun montant.</td>
        </tr>
        <tr>
          <td><strong>Magasinier / Stock</strong></td>
          <td>Inventaire &amp; réceptions</td>
          <td>Réceptions, lots, péremptions, inventaire, transferts. Pas d'accès à la caisse ni à la trésorerie.</td>
        </tr>
        <tr>
          <td><strong>Pharmacien Responsable</strong></td>
          <td>Profil Pharmacie</td>
          <td>Dispensation des médicaments contrôlés, registre ordonnances, validation substitutions, retraits de lots.</td>
        </tr>
        <tr>
          <td><strong>Comptable (lecture seule)</strong></td>
          <td>Finance &amp; exports</td>
          <td>Consulte et exporte journaux, TVA, clôtures. <strong>Aucune modification</strong> possible.</td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>7-A.2 Matrice des Permissions (Extrait des Actions Sensibles)</h3>
    <table>
      <thead>
        <tr>
          <th style="width:31%;">Action</th>
          <th style="width:11%;">Proprio</th>
          <th style="width:11%;">Gérant</th>
          <th style="width:11%;">Caissier</th>
          <th style="width:11%;">Serveur</th>
          <th style="width:12%;">Magasinier</th>
          <th style="width:13%;">Comptable</th>
        </tr>
      </thead>
      <tbody>
        <tr><td>Encaisser une vente</td><td>&#10004;</td><td>&#10004;</td><td>&#10004;</td><td>Addition</td><td>&#10006;</td><td>&#10006;</td></tr>
        <tr><td>Modifier un prix / appliquer remise &gt; seuil</td><td>&#10004;</td><td>&#10004;</td><td>PIN gérant</td><td>&#10006;</td><td>&#10006;</td><td>&#10006;</td></tr>
        <tr><td>Annuler / rembourser un ticket payé</td><td>&#10004;</td><td>&#10004;</td><td>PIN gérant</td><td>&#10006;</td><td>&#10006;</td><td>&#10006;</td></tr>
        <tr><td>Voir marges &amp; prix d'achat</td><td>&#10004;</td><td>&#10004;</td><td>&#10006;</td><td>&#10006;</td><td>Achat seul</td><td>&#10004;</td></tr>
        <tr><td>Réception, lots &amp; dates de péremption</td><td>&#10004;</td><td>&#10004;</td><td>&#10006;</td><td>&#10006;</td><td>&#10004;</td><td>Lecture</td></tr>
        <tr><td>Ajustement / casse / inventaire</td><td>&#10004;</td><td>&#10004;</td><td>&#10006;</td><td>&#10006;</td><td>&#10004;</td><td>Lecture</td></tr>
        <tr><td>Clôture Z &amp; validation des écarts</td><td>&#10004;</td><td>&#10004;</td><td>Saisie aveugle</td><td>&#10006;</td><td>&#10006;</td><td>Lecture</td></tr>
        <tr><td>Créer utilisateurs &amp; modifier droits</td><td>&#10004;</td><td>Limité</td><td>&#10006;</td><td>&#10006;</td><td>&#10006;</td><td>&#10006;</td></tr>
        <tr><td>Exporter rapports / données</td><td>&#10004;</td><td>&#10004;</td><td>&#10006;</td><td>&#10006;</td><td>&#10006;</td><td>&#10004;</td></tr>
      </tbody>
    </table>

    <div class="grid-2">
      <div class="card-accent">
        <div class="card-title">Mécanismes de Sécurité d'Accès</div>
        <ul>
          <li><strong>Connexion :</strong> e-mail/téléphone + mot de passe, <strong>code PIN 4-6 chiffres</strong> par poste de caisse (fonctionne hors-ligne).</li>
          <li><strong>2FA optionnelle</strong> (code WhatsApp) pour Propriétaire et Gérant.</li>
          <li><strong>Verrouillage auto</strong> après inactivité et après 5 PIN erronés.</li>
          <li><strong>Restriction par site, appareil et plage horaire</strong> (ex : caissier uniquement sur sa caisse pendant son service).</li>
        </ul>
      </div>
      <div class="card-gold">
        <div class="card-title">Traçabilité &amp; Journal d'Audit</div>
        <ul>
          <li><strong>Journal d'audit inaltérable :</strong> qui, quand, quel appareil, avant/après pour chaque annulation, remise, changement de prix ou de droit.</li>
          <li><strong>Autorisation à distance :</strong> le patron approuve une exception depuis son mobile.</li>
          <li><strong>Rôles personnalisés :</strong> création de rôles sur mesure (ex : « Chef de rayon ») avec cases à cocher.</li>
          <li><strong>Départ d'un employé :</strong> désactivation immédiate, y compris sur caisses hors-ligne à la prochaine synchronisation.</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 09 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 10 : SECTION 07-B - STOCK, LOTS & DATES D'EXPIRATION (SUPERMARCHE & PHARMACIE) ==================== -->
<div class="page">
  <div class="page-body" style="zoom:0.86;">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 07-B &bull; Stock Avancé</span>
        <h2 class="section-title">Gestion de Stock, Lots &amp; Dates d'Expiration (Supermarché &amp; Pharmacie)</h2>
      </div>
      <span class="section-badge">Traçabilité par Lot &bull; FEFO</span>
    </div>

    <p>
      Pour les produits périssables ou réglementés, le stock n'est plus géré par simple quantité mais <strong>par lot</strong> : chaque réception enregistre un <strong>numéro de lot</strong>, une <strong>date d'expiration</strong> et une quantité. Le système garantit qu'<strong>aucun produit périmé n'est vendu</strong>.
    </p>

    <h3><span class="h3-dot"></span>7-B.1 Cycle de Vie d'un Lot et Règles Automatiques</h3>
    <table>
      <thead>
        <tr>
          <th style="width:24%;">Étape</th>
          <th style="width:76%;">Fonctionnement</th>
        </tr>
      </thead>
      <tbody>
        <tr><td><strong>1. Réception</strong></td><td>Saisie ou scan à la réception : fournisseur, n° de lot, <strong>date d'expiration obligatoire</strong> pour les articles marqués « périssable », prix d'achat, quantité.</td></tr>
        <tr><td><strong>2. Vente FEFO</strong></td><td>La caisse décrémente automatiquement le lot qui <strong>expire en premier</strong> (First Expired, First Out), sans action du caissier.</td></tr>
        <tr><td><strong>3. Alertes progressives</strong></td><td>Notifications configurables par catégorie : <span class="badge badge-blue">J-90</span> <span class="badge badge-amber">J-30</span> <span class="badge badge-red">J-7</span> via tableau de bord, application mobile et WhatsApp du gérant.</td></tr>
        <tr><td><strong>4. Remise anti-gaspillage</strong></td><td>Promotion automatique proposée (ex : -30 % à J-15) pour écouler le stock proche de la date, avec accord du gérant.</td></tr>
        <tr><td><strong>5. Blocage à la vente</strong></td><td><strong>Un lot expiré est bloqué en caisse</strong> (scan refusé avec alerte sonore et rouge). Seul le gérant peut débloquer, avec justification tracée.</td></tr>
        <tr><td><strong>6. Retrait &amp; démarque</strong></td><td>Sortie des lots périmés ou rappelés vers « Démarque / Perte » avec motif, valorisation de la perte et photo optionnelle.</td></tr>
      </tbody>
    </table>

    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">Module Supermarché / Market</div>
        <ul>
          <li>DLC (date limite de consommation) et DLUO/DDM selon le type de produit.</li>
          <li>Contrôle des dates <strong>par rayon</strong> et tableau « À retirer cette semaine ».</li>
          <li>Seuils d'alerte différents par catégorie (frais 3 j, laitiers 15 j, conserves 90 j).</li>
          <li>Rapport de <strong>valeur du stock à risque</strong> en MRU.</li>
          <li>Inventaire tournant par scan code-barres, écarts valorisés.</li>
          <li>Consignes, emballages et étiquetage de prix rayon.</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">Module Pharmacie</div>
        <ul>
          <li>Fiche médicament : <strong>DCI, nom commercial, forme, dosage</strong>, laboratoire, code-barres.</li>
          <li><strong>Substitution générique</strong> proposée en caisse (même DCI).</li>
          <li>Médicaments <strong>sur ordonnance / contrôlés</strong> : dispensation réservée au pharmacien, saisie ordonnance, registre dédié.</li>
          <li><strong>Rappel de lot sanitaire :</strong> blocage immédiat d'un lot par n° et liste des ventes concernées.</li>
          <li>Suivi de la <strong>chaîne du froid</strong> (produits réfrigérés) et conditions de stockage.</li>
          <li>Ventes à crédit / assurance (Karni) et ordonnancier exportable.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>7-B.2 Rapports &amp; Droits Associés</h3>
    <table>
      <thead>
        <tr>
          <th style="width:30%;">Rapport / Fonction</th>
          <th style="width:46%;">Contenu</th>
          <th style="width:24%;">Accès (rôle)</th>
        </tr>
      </thead>
      <tbody>
        <tr><td><strong>Produits proche expiration</strong></td><td>Liste triée par échéance (30/60/90 j), lot, quantité, valeur.</td><td>Gérant, Magasinier, Pharmacien</td></tr>
        <tr><td><strong>Pertes &amp; démarque</strong></td><td>Périmés, casse, vols par période, motif et responsable.</td><td>Propriétaire, Gérant</td></tr>
        <tr><td><strong>Traçabilité d'un lot</strong></td><td>Fournisseur &rarr; réception &rarr; ventes &rarr; clients concernés (rappel).</td><td>Gérant, Pharmacien</td></tr>
        <tr><td><strong>Registre médicaments contrôlés</strong></td><td>Ordonnance, patient, quantité, pharmacien, date (export PDF).</td><td>Pharmacien responsable</td></tr>
        <tr><td><strong>Déblocage d'un lot expiré</strong></td><td>Exception exceptionnelle justifiée, inscrite dans le journal d'audit.</td><td>Gérant / Propriétaire</td></tr>
      </tbody>
    </table>

    <div class="card-gold">
      <div class="card-title">Fonctionnement Hors-Ligne</div>
      <p style="margin:0; font-size:7.8pt;">
        Les lots, dates d'expiration et le blocage des produits périmés sont <strong>stockés localement sur chaque caisse</strong> : le contrôle FEFO et le refus d'un article expiré fonctionnent <strong>même sans Internet</strong>, puis se synchronisent avec le Cloud au retour de la connexion.
      </p>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 10 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 9 : SECTION 08 - IA EMBARQUEE & AUTOMATISATION WHATSAPP ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 08</span>
        <h2 class="section-title">Nouvelles Technologies, Intelligence Artificielle &amp; Automatisation WhatsApp</h2>
      </div>
      <span class="section-badge">Innovation &amp; Différenciation SaaS</span>
    </div>

    <p>
      Pour donner au SaaS de <strong>M. Taha Chouaib</strong> plusieurs années d'avance sur toute concurrence locale ou internationale, la plateforme embarque des modules d'<strong>Intelligence Artificielle pragmatiques</strong> et une intégration profonde avec <strong>WhatsApp Business</strong>.
    </p>

    <div class="grid-2">
      <div class="card-white" style="border-top:3px solid #2563EB;">
        <div class="card-title">1. IA Anti-Fraude &amp; Audit Comportemental Caissiers <span class="badge badge-blue">IA Sécurité</span></div>
        <p>
          La fraude classique en restaurant consiste à imprimer la note provisoire pour le client, encaisser le cash, puis supprimer des lignes ou annuler la table. Notre moteur d'audit IA surveille :
        </p>
        <ul>
          <li><strong>Verrouillage après impression d'addition :</strong> Toute suppression d'article après impression d'une note provisoire exige un motif, un code Manager et génère une alerte rouge instantanée.</li>
          <li><strong>Détection des ouvertures de tiroir sans vente (« No-Sale »)</strong>, des remises suspectes et des réimpressions multiples de tickets.</li>
          <li><strong>Score de Fiabilité par Caissier :</strong> Analyse statistique comparant le taux d'annulation d'un employé par rapport à la moyenne de ses collègues.</li>
        </ul>
      </div>

      <div class="card-white" style="border-top:3px solid #00A86B;">
        <div class="card-title">2. Scan IA (OCR) des Factures Fournisseurs <span class="badge badge-green">Vision IA</span></div>
        <p>
          Saisir manuellement les bons de livraison fournisseurs (boucherie, légumes, boissons) prend du temps. Grâce au module OCR IA :
        </p>
        <ul>
          <li>Le gérant prend simplement en <strong>photo la facture papier du fournisseur</strong> avec son smartphone.</li>
          <li>L'IA extrait automatiquement les articles, les quantités livrées et les prix d'achat unitaires en MRU pour alimenter le stock.</li>
          <li><strong>Détecteur de Hausse des Prix :</strong> Si le prix d'achat du kilo de viande ou du bidon d'huile augmente de +10 %, l'IA alerte le propriétaire et lui montre quels plats du menu perdent en marge !</li>
        </ul>
      </div>
    </div>

    <div class="grid-2">
      <div class="card-white" style="border-top:3px solid #D97706;">
        <div class="card-title">3. IA Prédictive &amp; Mode Spécial « Ramadan / Iftar » <span class="badge badge-amber">Smart Prep</span></div>
        <ul>
          <li><strong>Prévision des quantités à préparer :</strong> Chaque matin, l'IA analyse l'historique des ventes selon le jour (ex: Jeudi/Vendredi soir), la période du mois (semaine des salaires) et les événements pour recommander au chef la mise en place idéale.</li>
          <li><strong>Mode Spécial Ramadan (Iftar &amp; Suhoor) :</strong> Gestion des pré-commandes et réservations d'Iftar avec compte à rebours synchronisé en cuisine pour que toutes les tables et livraisons soient prêtes exactement à l'heure de la rupture du jeûne.</li>
        </ul>
      </div>

      <div class="card-accent" style="background:#064E3B; color:#FFFFFF; border-color:#059669;">
        <div class="card-title" style="color:#34D399;">4. Aperçu du Rapport Z Automatique envoyé sur WhatsApp <span class="badge badge-green">Temps Réel</span></div>
        <div style="background:#0F172A; border-radius:6px; padding:7px 9px; font-family:'JetBrains Mono', monospace; font-size:7pt; color:#E2E8F0; line-height:1.38;">
          <div style="color:#34D399; font-weight:700;">📊 RAPPORT CLÔTURE Z — RESTO LE SULTAN (10/11/2026)</div>
          <div>💰 <strong>CA Total TTC :</strong> 148 500 MRU (+14% vs Mardi dernier)</div>
          <div>💵 Cash : 62 000 MRU | 📱 Bankily : 54 200 MRU</div>
          <div>📲 Masrivi : 19 800 MRU | 💳 Sedad/Click : 8 500 MRU</div>
          <div>📒 Crédit (Karni) : 4 000 MRU (Client: Soc. MauriLog)</div>
          <div>🍽️ Commandes : 214 (Panier moyen : 694 MRU)</div>
          <div style="color:#FBBF24;">⚠️ Alertes : 2 annulations après addition (Caissier #2 - 850 MRU)</div>
          <div style="color:#34D399;">📈 Marge Brute Théorique du jour : 96 525 MRU (65%)</div>
        </div>
      </div>
    </div>

    <h3><span class="h3-dot"></span>8.1 Matrice d'Ingénierie de Menu (Menu Engineering Automatisé)</h3>
    <p>
      Le système croise automatiquement le <strong>volume de ventes</strong> et la <strong>marge nette en MRU</strong> de chaque plat pour conseiller le restaurateur :
    </p>
    <div class="grid-4">
      <div class="card-accent">
        <div class="card-title">⭐ Les « Stars »</div>
        <div style="font-size:7.6pt;"><strong>Forte marge + Forte vente.</strong> Plats phares à mettre en tête du menu QR et à protéger.</div>
      </div>
      <div class="card-blue">
        <div class="card-title">🐄 « Vaches à lait »</div>
        <div style="font-size:7.6pt;"><strong>Faible marge + Forte vente.</strong> L'IA suggère d'ajuster le prix (+15 MRU) ou d'y lier un supplément.</div>
      </div>
      <div class="card-gold">
        <div class="card-title">❓ Les « Énigmes »</div>
        <div style="font-size:7.6pt;"><strong>Forte marge + Faible vente.</strong> Plats très rentables mais peu visibles : les intégrer en formule.</div>
      </div>
      <div class="card" style="border-left:3.5px solid var(--danger); background:var(--danger-light);">
        <div class="card-title" style="color:var(--danger);">⚠️ « Poids Morts »</div>
        <div style="font-size:7.6pt;"><strong>Faible marge + Faible vente.</strong> Immobilisent du stock et créent des pertes : à retirer du menu.</div>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 11 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 10 : SECTION 09 - PORTAIL SUPER-ADMIN SAAS & MODELE ECONOMIQUE (TAHA CHOUAIB) ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 09</span>
        <h2 class="section-title">Console Super-Admin SaaS, Licences Offline &amp; Modèle Financier</h2>
      </div>
      <span class="section-badge">Business SaaS de M. Taha Chouaib</span>
    </div>

    <p>
      En tant que propriétaire et investisseur du SaaS, <strong>M. Taha Chouaib</strong> dispose d'une <strong>Console Super-Admin Centrale</strong> qui lui permet de créer de nouveaux clients en quelques clics, d'importer leur catalogue existant, de déployer des mises à jour à distance et de sécuriser l'encaissement des abonnements.
    </p>

    <h3><span class="h3-dot"></span>9.1 Console Super-Admin, Importation Express &amp; Licence Hors-Ligne Inviolable</h3>
    <div class="grid-2">
      <div class="card-white">
        <div class="card-title">Onboarding en 15 min, Import Excel &amp; Mises à jour OTA</div>
        <ul>
          <li><strong>Templates Métiers + Import Excel/CSV en 1 clic :</strong> Pour migrer un restaurant ou un supermarché qui utilisait déjà un ancien logiciel ou Excel, un assistant importe instantanément ses 2 000 articles, codes-barres, prix et soldes clients (« Karni »).</li>
          <li><strong>Mises à jour silencieuses à distance (OTA - Over The Air) :</strong> Lorsqu'une nouvelle fonctionnalité est publiée, toutes les caisses de Mauritanie se mettent à jour automatiquement dès qu'elles détectent Internet.</li>
          <li><strong>Monitoring Technique du Parc :</strong> Carte temps réel des établissements actifs, état de synchronisation et alertes d'abonnement à J-7.</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">Protection Anti-Impayés en Mode Offline (Cryptographic Lease)</div>
        <p style="margin-bottom:4px;">
          <em>Comment empêcher un client qui ne paie plus son abonnement de couper Internet sur sa caisse pour l'utiliser gratuitement ?</em>
        </p>
        <ul>
          <li>Chaque caisse stocke un <strong>Jeton de Licence Signé (Ed25519)</strong> contenant la date de fin d'abonnement et une période de grâce hors-ligne (ex: 7 jours max sans Internet).</li>
          <li>Si l'abonnement expire : avertissement à J-5, puis <strong>verrouillage de l'ouverture de caisse</strong> à J+0 (les données restent consultables mais aucune nouvelle vente ne peut être encaissée).</li>
          <li><strong>Déblocage par Code SMS / Air-Gap :</strong> Dès que le client règle son abonnement par Bankily, la console de M. Taha Chouaib génère un <strong>Code de Déblocage à 12 chiffres</strong> que le client saisit sur son écran (même sans Internet) pour prolonger sa caisse de 30 jours !</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>9.2 Grille des Offres d'Abonnement SaaS (Packaging Commercial)</h3>
    <table>
      <thead>
        <tr>
          <th style="width:20%;">Forfait SaaS</th>
          <th style="width:24%;">Cible Clientèle</th>
          <th style="width:24%;">Périmètre Inclus</th>
          <th style="width:32%;">Fonctionnalités Clés Activées</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>PACK STARTER</strong><br><span class="badge badge-green">Entrée de gamme</span></td>
          <td>Snacks, petits fast-foods, cafés mono-caisse, épiceries</td>
          <td>1 Caisse (Offline/Online) + 1 Accès Propriétaire</td>
          <td>Encaissement rapide FR/AR, Paiements Cash/Bankily/Masrivi/Sedad, Clôture Z, Stock simple, Cloud Sync.</td>
        </tr>
        <tr>
          <td><strong>PACK PRO RESTO</strong><br><span class="badge badge-blue">Cœur de marché</span></td>
          <td>Restaurants assis, pizzerias, boulangeries-pâtisseries, salons de thé</td>
          <td>Jusqu'à 3 Caisses + Tablettes Serveurs + KDS Cuisine (LAN)</td>
          <td>Tout Starter + <strong>Sync Multi-Caisses LAN</strong>, Plan de salle, Salons VIP, Fiches techniques &amp; Food Cost, Livreurs, Crédit (Karni), Menu QR, Rapport WhatsApp.</td>
        </tr>
        <tr>
          <td><strong>PACK ENTERPRISE</strong><br><span class="badge badge-amber">Grands Comptes</span></td>
          <td>Chaînes de restaurants, grands supermarchés, franchises</td>
          <td>Caisses illimitées + Multi-Sites + Cuisine Centrale</td>
          <td>Tout Pro + <strong>Consolidation Multi-Établissements</strong>, Centrale d'achat &amp; transferts, IA Anti-fraude, Scan OCR Factures, API.</td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>9.3 Modèle de Revenus Récurrents (MRR / ARR) pour M. Taha Chouaib</h3>
    <div class="grid-3">
      <div class="card-gold">
        <div class="card-title">1. Revenus d'Installation (Setup)</div>
        <p style="margin:0; font-size:7.8pt;">
          <strong>Frais de mise en service initiaux</strong> (configuration du menu, formation du personnel sur place à Nouakchott/Nouadhibou) + marge commerciale sur la vente ou location du pack matériel (Caisse tactile + Imprimante + Tiroir).
        </p>
      </div>
      <div class="card-blue">
        <div class="card-title">2. Abonnement Récurrent (MRR)</div>
        <p style="margin:0; font-size:7.8pt;">
          <strong>Revenu mensuel ou annuel récurrent en MRU</strong> par établissement et par caisse active. Avec un coût serveur Cloud marginal très faible, la marge brute récurrente du logiciel dépasse <strong>85 %</strong> dès le palier de 30 clients.
        </p>
      </div>
      <div class="card-purple">
        <div class="card-title">3. Services à Valeur Ajoutée</div>
        <p style="margin:0; font-size:7.8pt;">
          Options additionnelles facturables : Pack Crédits notifications WhatsApp automatiques, module Menu QR Code personnalisé aux couleurs du restaurant, et support VIP 24/7.
        </p>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 12 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 11 : SECTION 10 (PARTIE A) - BACK-OFFICE RESTAURATEUR, APP MOBILE BOSS, RH & COMPTA ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 10 &bull; Partie A</span>
        <h2 class="section-title">Back-Office Restaurateur, App Mobile « Boss », Achats, RH &amp; Trésorerie</h2>
      </div>
      <span class="section-badge">Gestion 360° de l'Établissement</span>
    </div>

    <p>
      En Mauritanie, les propriétaires de restaurants ou de commerces ont souvent plusieurs activités et ne peuvent pas rester assis derrière la caisse toute la journée. L'<strong>Application Mobile « Owner Cockpit » (iOS &amp; Android)</strong> et le Back-Office Web leur donnent un contrôle absolu à distance.
    </p>

    <h3><span class="h3-dot"></span>10.1 Application Mobile « Owner Cockpit » (Pilotage Temps Réel sur Smartphone)</h3>
    <div class="grid-3">
      <div class="card-white" style="border-top:3px solid var(--accent);">
        <div class="card-title">Tableau de Bord Live</div>
        <ul>
          <li>Chiffre d'affaires en direct (minute par minute) et comparatif avec la semaine précédente.</li>
          <li>Répartition instantanée : <strong>Cash vs Bankily vs Masrivi vs Sedad vs Crédit</strong>.</li>
          <li>Nombre de tables occupées en ce moment et panier moyen.</li>
        </ul>
      </div>
      <div class="card-white" style="border-top:3px solid var(--gold);">
        <div class="card-title">Contrôle &amp; Approbation Mobile</div>
        <ul>
          <li>Notification push immédiate en cas d'annulation d'un ticket déjà envoyé en cuisine.</li>
          <li><strong>Validation à distance :</strong> Le caissier demande une remise exceptionnelle de 15 % ; le patron clique sur « Accepter » depuis son téléphone !</li>
        </ul>
      </div>
      <div class="card-white" style="border-top:3px solid var(--blue-tech);">
        <div class="card-title">Vue Multi-Établissements</div>
        <ul>
          <li>Si un propriétaire possède 3 restaurants ou boulangeries à Nouakchott, il bascule de l'un à l'autre ou consulte le <strong>CA consolidé du groupe</strong> en un seul écran.</li>
          <li>Comparaison des performances et du Food Cost entre ses points de vente.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>10.2 Gestion des Achats, Fournisseurs, Dépenses de Caisse &amp; Trésorerie</h3>
    <div class="grid-2">
      <div class="card">
        <div class="card-title">Cycle d'Achat &amp; Dettes Fournisseurs</div>
        <ul>
          <li><strong>Bons de Commande &amp; Réception :</strong> Création des commandes fournisseurs (viandes, boissons, emballages), contrôle des quantités reçues et mise à jour automatique du <strong>PMP (Prix Moyen Pondéré)</strong>.</li>
          <li><strong>Compte Fournisseur :</strong> Suivi des factures réglées au comptant ou à crédit, échéancier des paiements fournisseurs et historique des prix d'achat par fournisseur au marché de Nouakchott.</li>
        </ul>
      </div>
      <div class="card">
        <div class="card-title">Sorties de Caisse (Petty Cash) &amp; Compte d'Exploitation</div>
        <ul>
          <li><strong>Décaissements justifiés :</strong> Toute sortie d'espèces du tiroir-caisse en cours de journée (achat urgent de menthe, glace, bouteille de gaz, transport, acompte employé) doit être enregistrée par catégorie avec justificatif.</li>
          <li><strong>Calcul du Bénéfice Net Réel :</strong> Le Back-Office calcule automatiquement : <code>CA Encaissé &minus; Coût Matière (Food Cost) &minus; Dépenses &amp; Charges Fixes (Loyer, Électricité Somelec, Salaires) = Résultat Net en MRU</code>.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>10.3 Ressources Humaines (RH), Pointage du Personnel &amp; Matrice de Sécurité</h3>
    <table>
      <thead>
        <tr>
          <th style="width:22%;">Profil Utilisateur</th>
          <th style="width:43%;">Droits Autorisés par Défaut</th>
          <th style="width:35%;">Actions Interdites / Soumises à Code Manager</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Serveur (Salle / PAD)</strong></td>
          <td>Ouvrir une table, saisir une commande, envoyer en cuisine, imprimer l'addition provisoire.</td>
          <td>Encaisser, supprimer un plat déjà envoyé en cuisine, accorder une remise, ouvrir le tiroir-caisse.</td>
        </tr>
        <tr>
          <td><strong>Caissier</strong></td>
          <td>Prendre les commandes comptoir/livraison, encaisser (Cash/Bankily/Mixte), saisir une dépense autorisée, faire sa clôture Z en aveugle.</td>
          <td>Voir le montant théorique avant clôture, annuler un ticket encaissé, modifier les prix ou consulter le Food Cost.</td>
        </tr>
        <tr>
          <td><strong>Chef Cuisine (KDS)</strong></td>
          <td>Valider la préparation des plats sur l'écran KDS, déclarer un plat en rupture (« 86 »), saisir les pertes/casse cuisine.</td>
          <td>Accéder aux données financières, modifier les fiches recettes ou les prix d'achat fournisseurs.</td>
        </tr>
        <tr>
          <td><strong>Gérant / Manager</strong></td>
          <td>Autoriser une annulation ou remise par code PIN/Badge, saisir les achats fournisseurs et inventaires, gérer le planning.</td>
          <td>Effacer l'historique d'audit (aucun profil, même Manager, ne peut effacer la trace d'une opération dans la boîte noire).</td>
        </tr>
      </tbody>
    </table>

    <div class="card-accent" style="margin-top:4px;">
      <div class="card-title">Pointage Horaire, Commissions &amp; Avances sur Salaire (« Tasbiq »)</div>
      <p style="margin:0;">
        Chaque employé pointe son arrivée et son départ sur la caisse (par code PIN, carte magnétique RFID ou lecteur d'empreinte USB). Le système calcule les heures travaillées, les retards, les commissions éventuelles (par vente ou par course livreur) et déduit automatiquement les avances sur salaire (« <em>Tasbiq</em> ») prises en caisse au cours du mois.
      </p>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 13 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 12 : SECTION 10 (PARTIE B) - ARCHITECTURE TECHNIQUE, BDD & HARDWARE ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 10 &bull; Partie B</span>
        <h2 class="section-title">Stack Technique, Modèle de Données (MCD) &amp; Matériel POS</h2>
      </div>
      <span class="section-badge">Ingénierie Logicielle &amp; Hardware</span>
    </div>

    <h3><span class="h3-dot"></span>10.4 Stack Technologique Recommandée (Haute Performance &amp; Maintenabilité)</h3>
    <table>
      <thead>
        <tr>
          <th style="width:23%;">Couche Système</th>
          <th style="width:34%;">Technologies Sélectionnées</th>
          <th style="width:43%;">Justification &amp; Bénéfices pour le SaaS</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>Caisse Desktop &amp; Local Edge Hub</strong></td>
          <td><strong>Tauri (Rust) ou Electron + React 19 / TypeScript + TailwindCSS</strong></td>
          <td>Exécutable natif ultra-rapide sur Windows/Linux. Accès direct bas-niveau aux imprimantes USB/Série/IP (ESC/POS), tiroirs RJ11, second écran client et balances.</td>
        </tr>
        <tr>
          <td><strong>App Mobile (PAD Serveur, Sunmi, App Boss)</strong></td>
          <td><strong>Flutter (Dart) ou React Native</strong> (iOS &amp; Android + Terminaux Sunmi POS)</td>
          <td>Un seul code source pour les tablettes serveurs, les terminaux portables Sunmi (avec imprimante intégrée) et l'application mobile du propriétaire.</td>
        </tr>
        <tr>
          <td><strong>Base Locale Offline &amp; Protocole LAN</strong></td>
          <td><strong>SQLite 3 (Mode WAL + Chiffrement SQLCipher)</strong> + <strong>WebSockets / mDNS Local</strong></td>
          <td>Découverte automatique des autres caisses et écrans KDS sur le Wi-Fi local (Zero-Config mDNS), réplication &lt; 50 ms et backup miroir auto sur clé USB/SD.</td>
        </tr>
        <tr>
          <td><strong>Backend Cloud SaaS &amp; Base Centrale</strong></td>
          <td><strong>NestJS (Node.js/TypeScript)</strong> + <strong>PostgreSQL 16 (Row-Level Security)</strong> + <strong>Redis</strong></td>
          <td>Architecture Multi-Tenant stricte (chaque client est isolé par <code>tenant_id</code>), files d'attente BullMQ/Redis pour absorber les synchronisations et envoyer les WhatsApp.</td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>10.5 Architecture du Modèle de Base de Données (Entités Cœurs Multi-Tenant)</h3>
    <div class="grid-3">
      <div class="card-white">
        <div class="card-title">1. Noyau SaaS &amp; Licences</div>
        <div style="font-size:7.5pt; line-height:1.38;">
          &bull; <code>tenants</code> (Entreprises clientes, NIF)<br>
          &bull; <code>branches</code> (Points de vente / Sites)<br>
          &bull; <code>subscriptions</code> (Forfaits, Dates, MRU)<br>
          &bull; <code>pos_registers</code> (Caisses, Clés Ed25519)<br>
          &bull; <code>offline_lease_tokens</code> (Jetons &amp; Codes)<br>
          &bull; <code>users_roles</code> (Employés, PIN, Droits)
        </div>
      </div>
      <div class="card-white">
        <div class="card-title">2. Catalogue, Salle &amp; Stock</div>
        <div style="font-size:7.5pt; line-height:1.38;">
          &bull; <code>categories</code> &amp; <code>products</code> (FR / AR)<br>
          &bull; <code>price_tiers</code> (Salle, Emporter, VIP)<br>
          &bull; <code>ingredients</code> &amp; <code>recipes_bom</code> (Grammage)<br>
          &bull; <code>stock_movements_crdt</code> (Achats, Pertes)<br>
          &bull; <code>dining_zones</code> &amp; <code>reservations_vip</code><br>
          &bull; <code>kds_stations</code> (Postes Cuisine/Bar)
        </div>
      </div>
      <div class="card-white">
        <div class="card-title">3. Ventes, Wallets &amp; Audit</div>
        <div style="font-size:7.5pt; line-height:1.38;">
          &bull; <code>orders</code> &amp; <code>order_items</code> (HLC Sync)<br>
          &bull; <code>returns_remakes_comps</code> (Retours/Offerts)<br>
          &bull; <code>payments_splits</code> (Cash, Bankily, Masrivi...)<br>
          &bull; <code>customer_credits_karni</code> (Dettes &amp; Acomptes)<br>
          &bull; <code>cash_shifts_z</code> (Clôtures aveugles &amp; Écarts)<br>
          &bull; <code>audit_blackbox_logs</code> (Journal immuable)
        </div>
      </div>
    </div>

    <h3><span class="h3-dot"></span>10.6 Topologie Matérielle (Hardware POS) Recommandée en Restaurant / Market</h3>
    <div class="diagram-box">
      <svg viewBox="0 0 820 130" width="100%" height="110" xmlns="http://www.w3.org/2000/svg" style="font-family: 'Inter', sans-serif;">
        <rect x="15" y="15" width="185" height="100" rx="6" fill="#0A2540"/>
        <text x="107" y="36" fill="#34D399" font-size="9" font-weight="700" text-anchor="middle">Terminal Caisse Tactile 15"</text>
        <text x="107" y="51" fill="#FFFFFF" font-size="7.6" text-anchor="middle">Double Écran Client + Clé USB Backup</text>
        <text x="107" y="68" fill="#CBD5E1" font-size="7.4" text-anchor="middle">&bull; Port USB : Douchette 1D/2D</text>
        <text x="107" y="82" fill="#CBD5E1" font-size="7.4" text-anchor="middle">&bull; Port USB/LAN : Imprimante Ticket</text>
        <text x="107" y="96" fill="#FBBF24" font-size="7.4" font-weight="700" text-anchor="middle">&bull; Port RJ11 : Ouverture Tiroir-Caisse</text>

        <line x1="200" y1="65" x2="275" y2="65" stroke="#00A86B" stroke-width="2.5"/>
        <text x="237" y="57" fill="#065F46" font-size="7.5" font-weight="700" text-anchor="middle">Ethernet / Wi-Fi</text>

        <rect x="275" y="25" width="150" height="80" rx="6" fill="#ECFDF5" stroke="#00A86B" stroke-width="2"/>
        <text x="350" y="52" fill="#065F46" font-size="9" font-weight="800" text-anchor="middle">Routeur Local LAN</text>
        <text x="350" y="68" fill="#334155" font-size="7.6" text-anchor="middle">Fonctionne sur Onduleur (UPS)</text>
        <text x="350" y="84" fill="#047857" font-size="7.6" font-weight="700" text-anchor="middle">+ Backup 4G SIM Automatique</text>

        <line x1="425" y1="45" x2="485" y2="32" stroke="#0A2540" stroke-width="2"/>
        <line x1="425" y1="65" x2="485" y2="65" stroke="#0A2540" stroke-width="2"/>
        <line x1="425" y1="85" x2="485" y2="98" stroke="#0A2540" stroke-width="2"/>

        <rect x="485" y="10" width="320" height="32" rx="5" fill="#EFF6FF" stroke="#3B82F6"/>
        <text x="645" y="30" fill="#1E40AF" font-size="8.2" font-weight="700" text-anchor="middle">🖨️ Imprimantes Cuisine/Bar IP (Port 9100) &amp; Écrans KDS</text>

        <rect x="485" y="49" width="320" height="32" rx="5" fill="#FEF3C7" stroke="#F59E0B"/>
        <text x="645" y="69" fill="#92400E" font-size="8.2" font-weight="700" text-anchor="middle">📱 Caisses Secondaires (2..N) &amp; Tablettes Serveurs Wi-Fi</text>

        <rect x="485" y="88" width="320" height="32" rx="5" fill="#F5F3FF" stroke="#8B5CF6"/>
        <text x="645" y="108" fill="#5B21B6" font-size="8.2" font-weight="700" text-anchor="middle">⚖️ Balances Poids-Prix (Market/Pâtisserie) &amp; Écran TV File d'Attente</text>
      </svg>
    </div>

    <div class="card-gold">
      <div class="card-title">Recommandation Énergie &amp; Continuité Électrique (Spécial Mauritanie)</div>
      <p style="margin:0;">
        Pour garantir une continuité totale lors des coupures électriques (Somelec), le cahier des charges préconise de brancher le <strong>Routeur Wi-Fi Local</strong> et la <strong>Caisse Principale</strong> sur un mini-onduleur (UPS DC 12V pour le routeur offrant 6h d'autonomie + UPS caisse), permettant aux tablettes serveurs sur batterie de continuer à opérer sans interruption.
      </p>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 14 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 13 : SECTION 11 - BUSINESS MODEL SAAS, SIMULATION MRR INVESTISSEUR & ANTI-PIRATAGE OFFLINE ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 11 &bull; Volet Investisseur</span>
        <h2 class="section-title">Business Model SaaS, Grille Tarifaire MRU, Simulation MRR &amp; Sécurité des Licences</h2>
      </div>
      <span class="section-badge">Rentabilité &amp; Protection Investisseur</span>
    </div>

    <p>
      En tant qu'investisseur et propriétaire exclusif de la plateforme SaaS, <strong>M. Taha Chouaib</strong> dispose d'un modèle économique à revenus récurrents (<strong>MRR — Monthly Recurring Revenue</strong>) conçu pour le marché mauritanien (Nouakchott, Nouadhibou, Atar, Rosso, Kiffa) avec verrouillage cryptographique anti-impayés même en mode Offline.
    </p>

    <h3><span class="h3-dot"></span>11.1 Grille d'Abonnements Recommandée pour la Commercialisation en Mauritanie</h3>
    <table>
      <thead>
        <tr>
          <th style="width:20%;">Offre Commerciale</th>
          <th style="width:24%;">Cible Clientèle</th>
          <th style="width:18%;">Tarif Mensuel / Établissement</th>
          <th style="width:38%;">Modules &amp; Matériels Inclus dans la Licence</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>PACK STARTER</strong><br><span class="badge badge-green">Snack &amp; Épicerie</span></td>
          <td>Snacks, Cafés, Boulangeries, Supérettes de quartier (1 caisse)</td>
          <td><strong>3 500 à 4 500 MRU / mois</strong><br><em>+ Frais setup initial</em></td>
          <td>1 Caisse Offline/Cloud, Paiements MRU &amp; Wallets (Bankily, Masrivi, Sedad), Impression thermique FR/AR, Clôture Z, App Mobile Boss basique.</td>
        </tr>
        <tr>
          <td><strong>PACK PRO</strong><br><span class="badge badge-blue">Restaurant &amp; Market</span></td>
          <td>Restaurants avec salle, Fast-Foods, Boucheries, Supermarchés (2 à 3 caisses)</td>
          <td><strong>6 500 à 8 500 MRU / mois</strong><br><em>+ Frais setup initial</em></td>
          <td>Synchronisation LAN Multi-Caisses, Plan de Salle 2D, Écran Cuisine KDS, App Serveur, Balance Poids-Prix, Fiches Techniques Food Cost, Rapports WhatsApp.</td>
        </tr>
        <tr>
          <td><strong>PACK ENTERPRISE</strong><br><span class="badge badge-purple">VIP, Kiosk &amp; Chaînes</span></td>
          <td>Grands Restaurants, Lounges VIP, Multi-Sites, Hypermarchés (4+ postes)</td>
          <td><strong>11 000 à 15 000 MRU / mois</strong><br><em>Sur mesure multi-sites</em></td>
          <td>Borne Tactile Kiosk 27", Écran TV File d'attente, Centrale Livraison GPS, IA Anti-Fraude &amp; Scan Factures OCR, Gestion Centrale Multi-Magasins.</td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>11.2 Simulation de Rentabilité Récurrente (MRR &amp; ARR) pour M. Taha Chouaib</h3>
    <div class="grid-3">
      <div class="card-white">
        <div class="card-title">Phase 1 &mdash; Lancement (25 Clients)</div>
        <ul>
          <li><strong>Parc :</strong> 15 Packs Starter + 8 Packs Pro + 2 Packs Enterprise à Nouakchott.</li>
          <li><strong>Revenu Mensuel (MRR) :</strong> <strong>~145 000 MRU / mois</strong>.</li>
          <li><strong>Revenu Annuel (ARR) :</strong> <strong>~1 740 000 MRU / an</strong> (+ marges sur vente du matériel caisses/imprimantes).</li>
        </ul>
      </div>
      <div class="card-accent">
        <div class="card-title">Phase 2 &mdash; Croissance (60 Clients)</div>
        <ul>
          <li><strong>Parc :</strong> 30 Packs Starter + 22 Packs Pro + 8 Packs Enterprise (Nouakchott &amp; Nouadhibou).</li>
          <li><strong>Revenu Mensuel (MRR) :</strong> <strong>~390 000 MRU / mois</strong>.</li>
          <li><strong>Revenu Annuel (ARR) :</strong> <strong>~4 680 000 MRU / an</strong> de revenus récurrents à forte marge (&gt;85 %).</li>
        </ul>
      </div>
      <div class="card-gold">
        <div class="card-title">Phase 3 &mdash; Leader National (150 Clients)</div>
        <ul>
          <li><strong>Parc :</strong> 70 Starter + 55 Pro + 25 Enterprise (Restaurants + Markets).</li>
          <li><strong>Revenu Mensuel (MRR) :</strong> <strong>~980 000 MRU / mois</strong>.</li>
          <li><strong>Revenu Annuel (ARR) :</strong> <strong>~11 760 000 MRU / an</strong> + commissions sur options WhatsApp/SMS.</li>
        </ul>
      </div>
    </div>

    <h3><span class="h3-dot"></span>11.3 Protection Anti-Piratage &amp; Verrouillage des Licences en Mode Offline</h3>
    <div class="grid-2">
      <div class="card-blue">
        <div class="card-title">Jeton Cryptographique « Offline Lease 30 Jours » &amp; Hardware Lock</div>
        <ul>
          <li><strong>Empreinte Matérielle (Hardware Fingerprint) :</strong> Chaque installation locale est liée cryptographiquement à l'identifiant unique de la machine (CPU/Disque/MAC). Impossible pour un client de copier le logiciel sur un autre PC sans autorisation de M. Taha Chouaib.</li>
          <li><strong>Bail Hors-Ligne Signé (RSA-2048) :</strong> La caisse locale reçoit un jeton de licence valable 30 jours. Tant que l'abonnement est payé, il se renouvelle silencieusement via Internet.</li>
          <li><strong>Protection Anti-Manipulation d'Horloge :</strong> Détection automatique si un utilisateur tente de reculer la date/heure Windows pour contourner l'expiration de son abonnement.</li>
        </ul>
      </div>
      <div class="card-white">
        <div class="card-title">Déblocage par Code SMS / WhatsApp &amp; Télémaintenance 1-Clic</div>
        <ul>
          <li><strong>Activation sans Internet :</strong> Si un restaurant en zone isolée n'a pas Internet le jour du renouvellement et paie M. Taha Chouaib par Bankily, la Console Super-Admin génère un <strong>Code de Déblocage à 12 chiffres</strong> (envoyé par WhatsApp/SMS) qui prolonge immédiatement la caisse pour 30 jours.</li>
          <li><strong>Mode Grâce 72h :</strong> Bannière d'alerte à J-5, puis mode lecture seule après expiration (aucune perte de données comptables, réactivation en 5 secondes dès paiement).</li>
          <li><strong>Bouton « Assistance Technique » intégré :</strong> Lance un canal de télémaintenance sécurisé et un autodiagnostic (test imprimante, tiroir, réseau LAN et sauvegarde Cloud/WhatsApp).</li>
        </ul>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 15 / 16</span>
  </div>
</div>

<!-- ==================== PAGE 14 : SECTION 10 (PARTIE C) - ROADMAP ACCELEREE 1 A 2 MOIS & VALIDATION ==================== -->
<div class="page">
  <div class="page-body">
    <div class="doc-topbar">
      <span>CAHIER DES CHARGES &mdash; PLATEFORME SAAS POS RESTAURATION &amp; RETAIL (MAURITANIE)</span>
      <span class="client-tag">Client : M. Taha Chouaib</span>
    </div>

    <div class="section-header">
      <div>
        <span class="section-num">Section 10 &bull; Partie C</span>
        <h2 class="section-title">Planning d'Exécution Accéléré (1 à 2 Mois / 8 Semaines) &amp; Validation</h2>
      </div>
      <span class="section-badge">Livraison Rapide : 4 à 8 Semaines</span>
    </div>

    <h3><span class="h3-dot"></span>10.7 Feuille de Route Intensive en 1 à 2 Mois (Découpage Hebdomadaire en 4 Sprints)</h3>
    <p>
      Conformément à l'objectif stratégique de <strong>M. Taha Chouaib</strong>, le projet est structuré selon une méthodologie <strong>Agile Fast-Track sur 1 à 2 mois (4 à 8 semaines)</strong> : une première version opérationnelle et commercialisable (<strong>MVP V1</strong>) est livrée dès la fin du <strong>Mois 1 (Semaine 4)</strong>, suivie des modules avancés au cours du <strong>Mois 2 (Semaines 5 à 8)</strong>.
    </p>

    <table>
      <thead>
        <tr>
          <th style="width:18%;">Sprint / Période</th>
          <th style="width:17%;">Échéance Cible</th>
          <th style="width:65%;">Livrables Clés &amp; Jalons Opérationnels</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><strong>SPRINT 1</strong><br>Architecture, Caisse Offline &amp; Paiements MRU</td>
          <td><strong>Semaines 1 &ndash; 2</strong><br><span class="badge badge-green">Mois 1 (Début)</span></td>
          <td>
            &bull; Mise en place de l'architecture Cloud Multi-Tenant (PostgreSQL) + Moteur local Offline-First (SQLite + Backup USB).<br>
            &bull; Interface Caisse Tactile Bilingue (<strong>Français / Arabe RTL</strong>), Catalogue, Menus Combos, Modificateurs &amp; Multi-tarifs.<br>
            &bull; Encaissement <strong>MRU</strong> (Cash, <strong>Bankily, Masrivi, Sedad, Bimbank, Click</strong>, Paiement Mixte), Tiroir RJ11 &amp; Imprimantes ESC/POS.
          </td>
        </tr>
        <tr>
          <td><strong>SPRINT 2</strong><br>Salle, Cuisine KDS, Super-Admin &amp; <strong>Livraison MVP</strong></td>
          <td><strong>Semaines 3 &ndash; 4</strong><br><span class="badge badge-blue">Fin Mois 1 (MVP)</span></td>
          <td>
            &bull; <strong>Synchronisation Multi-Caisses LAN (sans Internet)</strong> avec Auto-Failover + Plan de salle 2D, division de note &amp; Salons VIP.<br>
            &bull; <strong>Écran Cuisine KDS</strong> multi-postes, Application Serveur (PAD), Fiches techniques au gramme &amp; calcul du <strong>Food Cost</strong>.<br>
            &bull; Gestion des Retours/Remakes, Offerts, Carnet de Crédit (<strong>« Karni »</strong>), Clôture Z en aveugle et Mode Formation.<br>
            &bull; <strong>Console Super-Admin de M. Taha Chouaib</strong> (Licences hors-ligne + Code de déblocage 12 chiffres + Import Excel).<br>
            <strong style="color:var(--accent-dark);">&rArr; JALON FIN MOIS 1 : Système 100 % prêt à être installé dans les premiers restaurants !</strong>
          </td>
        </tr>
        <tr>
          <td><strong>SPRINT 3</strong><br>Livraison, App Mobile Boss, QR &amp; Market</td>
          <td><strong>Semaines 5 &ndash; 6</strong><br><span class="badge badge-amber">Mois 2 (Partie 1)</span></td>
          <td>
            &bull; <strong>Hub de Livraison</strong> (Flotte de livreurs internes, zones Nouakchott, portefeuille Cash/Bankily par livreur).<br>
            &bull; <strong>Application Mobile « Owner Cockpit »</strong> (iOS &amp; Android) pour les propriétaires + Rapports Z automatiques sur <strong>WhatsApp</strong>.<br>
            &bull; <strong>Menu Digital QR Code à table</strong>, mode Borne Tactile (Kiosk), Second Écran Client et activation du mode <strong>Market / Supérette</strong>.
          </td>
        </tr>
        <tr>
          <td><strong>SPRINT 4</strong><br>Modules IA, Multi-Sites &amp; Clôture Projet</td>
          <td><strong>Semaines 7 &ndash; 8</strong><br><span class="badge badge-purple">Fin Mois 2 (Complet)</span></td>
          <td>
            &bull; <strong>IA Anti-Fraude</strong> (Détection comportementale des annulations suspectes après impression d'addition) &amp; Matrice Menu Engineering.<br>
            &bull; <strong>Scan OCR par IA</strong> des factures fournisseurs par photo smartphone + Prévisions de ventes (Spécial <strong>Ramadan / Iftar</strong>).<br>
            &bull; Consolidation Multi-Établissements / Cuisine Centrale, tests de charge et formation de l'équipe de M. Taha Chouaib.
          </td>
        </tr>
      </tbody>
    </table>

    <h3><span class="h3-dot"></span>10.8 Garanties, Propriété Intellectuelle Exclusive &amp; Accompagnement</h3>
    <div class="grid-3">
      <div class="card">
        <div class="card-title">Propriété 100 % Client</div>
        <p style="margin:0; font-size:7.6pt;">
          L'intégralité des codes sources (Web, Caisse Offline, Mobile, Backend), schémas et droits commerciaux appartient exclusivement à <strong>M. Taha Chouaib</strong>.
        </p>
      </div>
      <div class="card">
        <div class="card-title">Démonstrations Hebdomadaires</div>
        <p style="margin:0; font-size:7.6pt;">
          À la fin de chaque semaine (chaque vendredi), une démonstration en direct est présentée à M. Taha Chouaib pour valider l'avancement concret.
        </p>
      </div>
      <div class="card">
        <div class="card-title">Garantie &amp; Support</div>
        <p style="margin:0; font-size:7.6pt;">
          Garantie de correction de bugs post-lancement, documentation technique complète et accompagnement lors du déploiement des premiers clients.
        </p>
      </div>
    </div>

    <div style="margin-top:8px; border:2px solid var(--primary); border-radius:8px; padding:10px 14px; background:linear-gradient(135deg, #F8FAFC 0%, #ECFDF5 100%);">
      <div style="display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--slate-300); padding-bottom:6px; margin-bottom:8px;">
        <div>
          <span style="font-size:7.5pt; text-transform:uppercase; letter-spacing:1px; color:var(--accent-dark); font-weight:800;">Validation Officielle du Cahier des Charges (Délai : 1 à 2 Mois)</span>
          <div style="font-size:10.2pt; font-weight:800; color:var(--primary);">Bon pour Accord Stratégique &amp; Démarrage Immédiat du Sprint 1</div>
        </div>
        <span class="badge badge-green" style="font-size:7.5pt; padding:3px 10px;">Prêt pour Exécution</span>
      </div>
      <div class="grid-2" style="margin-bottom:0;">
        <div style="background:#FFFFFF; border:1px dashed var(--slate-400); border-radius:6px; padding:8px 12px; height:58px;">
          <div style="font-size:7.5pt; font-weight:700; color:var(--primary);">LE CLIENT &amp; INVESTISSEUR DU PROJET SAAS :</div>
          <div style="font-size:9pt; font-weight:800; color:var(--gold); margin-top:2px;">M. Taha Chouaib</div>
          <div style="font-size:7pt; color:var(--slate-500); margin-top:6px;">Date &amp; Signature : ........................................................................</div>
        </div>
        <div style="background:#FFFFFF; border:1px dashed var(--slate-400); border-radius:6px; padding:8px 12px; height:58px;">
          <div style="font-size:7.5pt; font-weight:700; color:var(--primary);">DIRECTION TECHNIQUE &amp; ÉQUIPE PROJET :</div>
          <div style="font-size:8.5pt; font-weight:700; color:var(--slate-700); margin-top:2px;">Équipe Ingénierie &mdash; Livraison 1 à 2 Mois</div>
          <div style="font-size:7pt; color:var(--slate-500); margin-top:6px;">Date &amp; Signature : ........................................................................</div>
        </div>
      </div>
    </div>
  </div>

  <div class="doc-footer">
    <span>CONFIDENTIEL &mdash; Cahier des Charges SaaS Restauration &amp; Retail Mauritanie (M. Taha Chouaib)</span>
    <span class="page-num-pill">Page 16 / 16</span>
  </div>
</div>

</body>
</html>
"""

output_dir = r"d:\_Documents\Bureau\caissamrr"
html_path = os.path.join(output_dir, "Cahier_des_Charges_SaaS_POS_Mauritanie_Taha_Chouaib.html")
pdf_path = os.path.join(output_dir, "Cahier_des_Charges_SaaS_POS_Mauritanie_Taha_Chouaib.pdf")

with open(html_path, "w", encoding="utf-8") as f:
    f.write(html_content)

print(f"HTML written to: {html_path}")

chrome_path = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
browser = chrome_path if os.path.exists(chrome_path) else edge_path

cmd = [
    browser,
    "--headless=new",
    "--disable-gpu",
    "--no-pdf-header-footer",
    "--print-to-pdf-no-header",
    f"--print-to-pdf={pdf_path}",
    html_path
]

subprocess.run(cmd, check=True)
print(f"PDF successfully generated at: {pdf_path}")
