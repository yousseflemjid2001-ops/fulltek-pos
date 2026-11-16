#!/usr/bin/env python3
"""
Full-Tek POS — Page d'Accueil Client & Portail Solutions (Mauritanie).
- Numéro officiel M. Taha Chouaib : +222 42 74 42 42 (Appel & WhatsApp direct)
- 4 Logos Sombres Modèle 11 intégrés sans fond blanc + Animation 3 pilules
- 4 Démos Interactives Réelles adaptées au marché mauritanien :
  1. Full-Tek Resto : Caisse tactile + Plan de salle Khaima VIP + Cuisine KDS + Bankily/Masrivi/Sedad
  2. Full-Tek Market : Balance COM1, Bascule Détail/Demi-Gros, Carnet Karni (crédit client)
  3. Full-Tek Pharma : Règle FEFO, Blocage automatique lot expiré, Mutuelle CNAM Mauritanie
  4. Full-Tek Boss : App Mobile iOS/Android interactive multi-boutiques & Clôture Z à distance
- Standards UI/UX Pro Max respectés (WCAG 2.2 AA, zéro emoji, cibles tactiles, RTL Arabe).
"""
import base64
import mimetypes
import re
from pathlib import Path

ROOT = Path(r"d:\_Documents\Bureau\caissamrr")
L = "Logos_Full-Tek/Modele_11_Pilules/"

ICONS = {
    "resto": '<g fill="none" stroke="#E4572E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3v6a2 2 0 0 0 4 0V3M9 3v18M17 21V3c-2.5 1.8-3.5 4.5-3.5 8H17"/></g>',
    "market": '<g fill="none" stroke="#2E9E5B" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 4h3l2.4 11h9.6l2-8H7"/><circle cx="10" cy="19.5" r="1.6"/><circle cx="17" cy="19.5" r="1.6"/></g>',
    "pharma": '<path fill="#1B8FD9" d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>',
    "boss": '<g fill="#C99A2E"><rect x="3" y="12" width="5" height="9" rx="1"/><rect x="10" y="4" width="5" height="17" rx="1"/><rect x="17" y="8" width="5" height="13" rx="1"/></g>',
}

COLORS = {
    "resto": "#E4572E",
    "market": "#2E9E5B",
    "pharma": "#1B8FD9",
    "boss": "#C99A2E",
}


def dark_logo_svg(key: str, label: str, cls: str = "ft-logo-svg") -> str:
    c = COLORS[key]
    ic = ICONS[key]
    return (
        f'<svg class="{cls}" viewBox="0 0 400 100" fill="none" xmlns="http://www.w3.org/2000/svg" '
        f'role="img" aria-label="Full-Tek {label.title()}" dir="ltr">'
        f'<g>'
        f'<rect class="p p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>'
        f'<rect class="p p2" x="10" y="43" width="52" height="16" rx="8" fill="{c}"/>'
        f'<rect class="p p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>'
        f'</g>'
        f'<text class="w" x="120" y="56" font-family="\'Plus Jakarta Sans\',\'Segoe UI\',Arial,sans-serif" font-size="44" font-weight="800" text-anchor="start" fill="#FFFFFF">Full·Tek</text>'
        f'<g class="w" transform="translate(120,67) scale(.95)">{ic}</g>'
        f'<text class="w" x="147" y="87" font-family="\'Plus Jakarta Sans\',\'Segoe UI\',Arial,sans-serif" font-size="17" font-weight="700" letter-spacing="4" fill="{c}">{label}</text>'
        f'</svg>'
    )


def mini_emblem_svg(key: str) -> str:
    c = COLORS[key]
    return (
        f'<svg class="ft-mini-pill" width="28" height="28" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">'
        f'<rect class="p p1" x="11" y="20" width="78" height="16" rx="8" fill="#FFFFFF"/>'
        f'<rect class="p p2" x="11" y="42" width="54" height="16" rx="8" fill="{c}"/>'
        f'<rect class="p p3" x="11" y="64" width="32" height="16" rx="8" fill="#FFFFFF"/>'
        f'</svg>'
    )


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="fr" dir="ltr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Full·Tek : la caisse qui ne s'arrête jamais — Mauritanie (Resto, Market, Pharma, Boss)</title>
<meta name="description" content="Suite de caisse tactile pour la Mauritanie : Restaurants Khaima VIP, Supermarchés Balance & Carnet Karni, Pharmacies FEFO & CNAM, App Mobile Boss. Contact direct M. Taha : +222 42 74 42 42.">
<link rel="icon" type="image/svg+xml" href="__L__icone_application.svg">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@500;600;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
<style>
/* ==========================================================================
   DESIGN TOKENS (UI/UX PRO MAX + CHARTE OFFICIELLE MODÈLE 11 « PILULES »)
   ========================================================================== */
:root {
  --petrol: #264653;
  --petrol-2: #315869;
  --ochre: #E9A23B;
  --night: #0F1B20;
  --night-2: #14262D;
  --night-3: #1B323B;

  --resto: #E4572E;
  --market: #2E9E5B;
  --pharma: #1B8FD9;
  --boss: #C99A2E;

  --ink: #F4F7F8;
  --ink-secondary: #D2DEE2;
  --muted: #A9B8BE;
  --line: rgba(255, 255, 255, 0.08);
  --line-strong: rgba(255, 255, 255, 0.16);

  --f-sans: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  --f-head: 'Plus Jakarta Sans', system-ui, sans-serif;
  --f-ar: 'Cairo', 'Segoe UI', system-ui, sans-serif;
  --f-mono: 'JetBrains Mono', 'Courier New', monospace;

  --sp-1: 4px; --sp-2: 8px; --sp-3: 12px; --sp-4: 16px;
  --sp-5: 20px; --sp-6: 24px; --sp-8: 32px; --sp-12: 48px;
  --r-sm: 8px; --r-md: 14px; --r-lg: 20px; --r-xl: 26px; --r-full: 9999px;
  --wrap: 1340px;
  --ease: cubic-bezier(0.16, 1, 0.3, 1);
}

*, *::before, *::after { box-sizing: border-box; }
html { scroll-behavior: smooth; scroll-padding-top: 88px; }
body {
  margin: 0; background: var(--night); color: var(--ink);
  font: 400 16px/1.6 var(--f-sans);
  -webkit-font-smoothing: antialiased; -moz-osx-font-smoothing: grayscale;
  overflow-x: hidden;
}
html[dir=rtl] { --f-head: var(--f-ar); --f-sans: var(--f-ar); }
html[dir=rtl] body { font-family: var(--f-ar); line-height: 1.7; }
html[dir=rtl] :is(body, h1, h2, h3, h4, p, span, a, button, small, strong, b, li, label, input, select, option, div) { letter-spacing: 0; }
html[dir=rtl] h1 { line-height: 1.24; }
html[dir=rtl] h1 em { display: inline-block; padding-block: 0.06em; }
html[dir=rtl] .sol h2, html[dir=rtl] .offline-sec h2, html[dir=rtl] .cta-sec h2, html[dir=rtl] .pricing-header h2 { line-height: 1.28; }
html[dir=rtl] .eyebrow, html[dir=rtl] .sol__tag, html[dir=rtl] .pos-card-badge, html[dir=rtl] .pos-hw-bar, html[dir=rtl] .pre-pos-st, html[dir=rtl] .pre-status-row, html[dir=rtl] .boss-top-items small, html[dir=rtl] .pos-live-pill, html[dir=rtl] .pr-tag, html[dir=rtl] .tk-row b, html[dir=rtl] .tk-total span, html[dir=rtl] .price-val, html[dir=rtl] #b-ca, html[dir=rtl] .boss-st-line span, html[dir=rtl] .boss-z-row b, html[dir=rtl] .boss-top-row b, html[dir=rtl] .boss-notch-bar { font-family: var(--f-ar); }
html[dir=rtl] span[dir=ltr], html[dir=rtl] b[dir=ltr], html[dir=rtl] .price-val, html[dir=rtl] #b-delta { direction: ltr; unicode-bidi: isolate; display: inline-block; }
a { color: inherit; text-decoration: none; }
button { font: inherit; color: inherit; cursor: pointer; border: 0; background: none; }
img { max-width: 100%; display: block; }
.wrap { width: min(100% - 40px, var(--wrap)); margin-inline: auto; }
:focus-visible { outline: 2px solid var(--ochre) !important; outline-offset: 3px !important; border-radius: var(--r-sm); }

/* Animation Signature 3 Pilules */
.ft-logo-svg { height: 56px; width: auto; max-width: 100%; display: block; direction: ltr; }
.ft-logo-svg .p { transition: transform 0.35s var(--ease), filter 0.35s; }
.gate:hover .ft-logo-svg .p1, .sol__logo-glass:hover .ft-logo-svg .p1 { transform: translateX(4px); }
.gate:hover .ft-logo-svg .p2, .sol__logo-glass:hover .ft-logo-svg .p2 { transform: translateX(9px); filter: drop-shadow(0 0 8px var(--c)); }
.gate:hover .ft-logo-svg .p3, .sol__logo-glass:hover .ft-logo-svg .p3 { transform: translateX(6px); }

/* Boutons */
.btn {
  display: inline-flex; align-items: center; justify-content: center; gap: var(--sp-2);
  min-height: 48px; padding: 0 var(--sp-6); border-radius: var(--r-md); border: 1px solid transparent;
  font: 700 15px/1 var(--f-sans); cursor: pointer; white-space: nowrap;
  transition: transform 0.2s var(--ease), box-shadow 0.2s, background 0.2s, border-color 0.2s; user-select: none;
}
.btn:hover { transform: translateY(-2px); }
.btn:active { transform: scale(0.98) translateY(1px); }
.btn--ochre { background: linear-gradient(135deg, #F3B556 0%, var(--ochre) 55%, #D4841A 100%); color: #121A15; font-weight: 800; box-shadow: 0 14px 34px -10px rgba(233, 162, 59, 0.65); }
.btn--ochre:hover { box-shadow: 0 20px 40px -10px rgba(233, 162, 59, 0.85); }
.btn--ghost { background: rgba(255, 255, 255, 0.05); border-color: var(--line-strong); color: #FFFFFF; }
.btn--ghost:hover { background: rgba(255, 255, 255, 0.09); border-color: var(--ochre); color: var(--ochre); }
.btn--sm { min-height: 44px; padding: 0 var(--sp-4); font-size: 14px; border-radius: 12px; }
.btn svg { width: 16px; height: 16px; flex: none; transition: transform 0.2s var(--ease); }
.btn:hover svg { transform: translateX(3px); }
html[dir=rtl] .btn svg, html[dir=rtl] .gate__go span svg, html[dir=rtl] .pre-skip-btn svg { transform: scaleX(-1); }
html[dir=rtl] .btn:hover svg { transform: scaleX(-1) translateX(3px); }

/* Navigation */
.nav {
  position: fixed; inset: 0 0 auto 0; z-index: 100; height: 86px; display: flex; align-items: center;
  background: rgba(15, 27, 32, 0.82); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
  border-bottom: 1px solid transparent; transition: border-color 0.3s, background 0.3s;
}
.nav.scrolled { border-color: var(--line); background: rgba(15, 27, 32, 0.95); box-shadow: 0 12px 30px -10px rgba(0, 0, 0, 0.5); }
.nav__in { display: flex; align-items: center; gap: var(--sp-6); }
.nav__logo { display: flex; align-items: center; min-height: 44px; flex: none; }
.nav__logo img { height: 58px; width: auto; display: block; }
.nav__links { display: flex; align-items: center; gap: var(--sp-1); margin-inline: auto; }
.nav__links > * { position: relative; }
.nav__links a, .nav__links button.dd {
  min-height: 44px; padding: 10px 14px; border-radius: var(--r-sm); font-weight: 600; font-size: 14.5px;
  color: var(--ink-secondary); display: inline-flex; align-items: center; gap: 6px; transition: background 0.2s, color 0.2s;
}
.nav__links a:hover, .nav__links button.dd:hover, .nav__links button.dd:focus-visible { background: rgba(255, 255, 255, 0.08); color: #FFFFFF; }
.dd-menu {
  position: absolute; top: 100%; inset-inline-start: 0; min-width: 360px; padding: var(--sp-2); margin-top: var(--sp-2);
  background: var(--night-2); border: 1px solid var(--line-strong); border-radius: var(--r-lg);
  box-shadow: 0 32px 64px -18px rgba(0, 0, 0, 0.75); opacity: 0; visibility: hidden; transform: translateY(8px);
  transition: opacity 0.2s var(--ease), transform 0.2s var(--ease), visibility 0.2s;
}
.has-dd:hover .dd-menu, .has-dd:focus-within .dd-menu { opacity: 1; visibility: visible; transform: translateY(0); }
.dd-menu a { display: flex; gap: 14px; align-items: center; padding: 10px 12px; border-radius: var(--r-md); color: #FFFFFF; transition: background 0.2s; }
.dd-menu a:hover { background: color-mix(in srgb, var(--c) 14%, rgba(255,255,255,0.04)); }
.emblem-badge {
  width: 42px; height: 42px; border-radius: 12px;
  background: color-mix(in srgb, var(--c) 15%, rgba(255, 255, 255, 0.04));
  border: 1px solid color-mix(in srgb, var(--c) 38%, transparent); display: grid; place-items: center; flex: none;
}
.dd-menu a b { display: block; font-size: 15px; }
.dd-menu a span { display: block; font-size: 13px; color: var(--muted); font-weight: 400; }

.nav__act { display: flex; align-items: center; gap: var(--sp-2); }
.nav-wa-chip {
  display: inline-flex; align-items: center; gap: 8px; min-height: 44px; padding: 0 14px;
  border-radius: var(--r-full); background: rgba(37, 211, 102, 0.12); border: 1px solid rgba(37, 211, 102, 0.35);
  color: #4ADE80; font-weight: 700; font-size: 13px; transition: all 0.2s;
}
.nav-wa-chip:hover { background: rgba(37, 211, 102, 0.22); color: #FFFFFF; }
.lang { display: inline-flex; padding: 3px; border-radius: var(--r-full); border: 1px solid var(--line); background: rgba(255, 255, 255, 0.04); }
.lang button { min-height: 38px; min-width: 42px; padding: 6px 12px; border-radius: var(--r-full); font-weight: 700; font-size: 12.5px; color: var(--muted); transition: all 0.2s; }
.lang button:hover { color: #FFFFFF; }
.lang button[aria-pressed=true] { background: var(--petrol); color: #FFFFFF; }
.burger { display: none; min-width: 44px; min-height: 44px; border-radius: var(--r-sm); border: 1px solid var(--line-strong); background: rgba(255, 255, 255, 0.04); align-items: center; justify-content: center; }
@media (max-width: 1120px) {
  .nav__links, .nav__act .btn--ghost, .nav-wa-chip { display: none; }
  .burger { display: inline-flex; margin-inline-start: auto; }
  .nav__act { margin-inline-start: 0; }
  .nav.open .nav__links { display: flex; flex-direction: column; position: fixed; inset: 76px 0 0 0; background: var(--night); padding: var(--sp-5); gap: var(--sp-1); overflow-y: auto; }
  .nav.open .dd-menu { position: static; opacity: 1; visibility: visible; transform: none; box-shadow: none; border: 0; padding: 0 0 0 12px; min-width: 0; background: transparent; }
}

/* Hero */
.hero { position: relative; min-height: 100svh; padding: 130px 0 80px; display: flex; align-items: center; overflow: hidden; background: var(--night); }
.orb { position: absolute; border-radius: 50%; filter: blur(100px); opacity: 0.5; pointer-events: none; animation: float 14s ease-in-out infinite alternate; }
.orb--1 { width: 560px; height: 560px; background: var(--petrol); inset: -100px auto auto -140px; }
.orb--2 { width: 440px; height: 440px; background: rgba(233, 162, 59, 0.35); inset: 15% -100px auto auto; animation-delay: -5s; }
.orb--3 { width: 380px; height: 380px; background: rgba(46, 158, 91, 0.22); inset: auto auto -160px 35%; animation-delay: -9s; }
@keyframes float { 50% { transform: translate(35px, -30px) scale(1.06); } }
.grid-bg {
  position: absolute; inset: 0;
  background-image: linear-gradient(rgba(255, 255, 255, 0.035) 1px, transparent 1px), linear-gradient(90deg, rgba(255, 255, 255, 0.035) 1px, transparent 1px);
  background-size: 56px 56px; -webkit-mask-image: radial-gradient(ellipse 70% 60% at 50% 40%, #000 30%, transparent 80%); mask-image: radial-gradient(ellipse 70% 60% at 50% 40%, #000 30%, transparent 80%);
}
.hero__in { position: relative; display: grid; grid-template-columns: 1.05fr 0.95fr; gap: var(--sp-12); align-items: center; }
.badge-hero {
  display: inline-flex; align-items: center; gap: var(--sp-2); padding: 8px 16px; border-radius: var(--r-full);
  background: rgba(38, 70, 83, 0.65); border: 1px solid rgba(233, 162, 59, 0.45); color: var(--ochre); font-weight: 700; font-size: 13px; margin-bottom: var(--sp-5);
}
.badge-hero i { width: 8px; height: 8px; border-radius: 50%; background: var(--ochre); box-shadow: 0 0 10px var(--ochre); animation: pulseDot 2s infinite; }
@keyframes pulseDot { 0% { box-shadow: 0 0 0 0 rgba(233, 162, 59, 0.6); } 100% { box-shadow: 0 0 0 10px transparent; } }
h1 { font: 800 clamp(36px, 4.8vw, 66px)/1.06 var(--f-head); letter-spacing: -0.035em; margin: 0 0 var(--sp-5); }
h1 em {
  font-style: normal; background: linear-gradient(90deg, var(--ochre) 0%, #FDE3A7 50%, var(--ochre) 100%);
  background-size: 200% 100%; -webkit-background-clip: text; background-clip: text; color: transparent; animation: textShine 6s linear infinite;
}
@keyframes textShine { to { background-position: 200% 0; } }
.lead { font-size: 18.5px; color: var(--ink-secondary); max-width: 54ch; margin: 0 0 var(--sp-8); line-height: 1.6; }
.hero__cta { display: flex; flex-wrap: wrap; gap: var(--sp-4); margin-bottom: var(--sp-8); }
.hero__facts { display: flex; flex-wrap: wrap; gap: var(--sp-6); color: var(--muted); font-size: 14px; border-top: 1px solid var(--line); padding-top: var(--sp-6); }
.hero__facts b { display: block; font: 800 28px/1.1 var(--f-head); color: #FFFFFF; margin-bottom: 2px; }

.stage { position: relative; height: 530px; }
.card-fx { position: absolute; border-radius: var(--r-xl); background: linear-gradient(160deg, #1C3540 0%, #13242B 100%); border: 1px solid rgba(255, 255, 255, 0.12); box-shadow: 0 35px 70px -25px rgba(0, 0, 0, 0.85); padding: var(--sp-5); }
.pos-box { inset: 20px 0 auto 30px; width: 82%; animation: floatCard 7s ease-in-out infinite; }
.pos-box h4 { margin: 0 0 14px; display: flex; justify-content: space-between; align-items: center; font-size: 13.5px; color: var(--muted); font-weight: 600; }
.pos-box h4 span.tag-live { display: inline-flex; align-items: center; gap: 5px; color: #4ADE80; font-size: 12px; font-weight: 700; }
.pos-box h4 span.tag-live i { width: 6px; height: 6px; border-radius: 50%; background: #4ADE80; }
.item-line { display: flex; justify-content: space-between; padding: 10px 12px; border-radius: var(--r-sm); background: rgba(255, 255, 255, 0.05); margin-bottom: 8px; font-size: 14px; opacity: 0; animation: fadeInLine 0.6s var(--ease) forwards; }
.item-line:nth-of-type(1) { animation-delay: 0.4s; } .item-line:nth-of-type(2) { animation-delay: 0.9s; } .item-line:nth-of-type(3) { animation-delay: 1.4s; }
@keyframes fadeInLine { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: none; } }
.tot-line { display: flex; justify-content: space-between; align-items: baseline; margin: 16px 0; font: 800 28px/1 var(--f-head); }
.tot-line small { font: 600 13px var(--f-sans); color: var(--muted); }
.pay-btn-fake { height: 46px; border-radius: var(--r-md); background: var(--market); display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 700; font-size: 14.5px; color: #FFFFFF; }
.bank-card { inset: auto auto 15px 0; width: 260px; animation: floatCard 6s ease-in-out -2s infinite; display: flex; gap: 14px; align-items: center; border-color: rgba(46, 158, 91, 0.6); }
.bank-card .ok-icon { width: 44px; height: 44px; border-radius: 50%; background: var(--market); display: grid; place-items: center; flex: none; box-shadow: 0 0 16px rgba(46, 158, 91, 0.6); }
.phone-card { inset: auto 0 -10px auto; width: 195px; padding: 16px; border-radius: 28px; border: 2px solid rgba(255, 255, 255, 0.2); animation: floatCard 8s ease-in-out -4s infinite; }
.phone-card small { color: var(--muted); font-size: 11px; font-weight: 600; display: block; }
.phone-card b { display: block; font: 800 22px var(--f-head); color: var(--boss); margin: 4px 0 10px; }
.phone-bars { display: flex; align-items: flex-end; gap: 5px; height: 60px; }
.phone-bars i { flex: 1; border-radius: 4px 4px 0 0; background: linear-gradient(var(--boss), #8D6A1B); animation: barPulse 3s ease-in-out infinite; transform-origin: bottom; }
.phone-bars i:nth-child(1){height:40%}.phone-bars i:nth-child(2){height:65%;animation-delay:.2s}
.phone-bars i:nth-child(3){height:50%;animation-delay:.4s}.phone-bars i:nth-child(4){height:85%;animation-delay:.6s}.phone-bars i:nth-child(5){height:70%;animation-delay:.8s}
@keyframes barPulse { 50% { transform: scaleY(0.75); } }
.offline-pill-top { inset: 0 0 auto auto; padding: 8px 14px; border-radius: var(--r-full); font-size: 12.5px; font-weight: 700; display: flex; gap: 8px; align-items: center; animation: floatCard 5s ease-in-out -1s infinite; border-color: rgba(233, 162, 59, 0.55); background: rgba(15, 27, 32, 0.9); }
.offline-pill-top i { width: 8px; height: 8px; border-radius: 50%; background: var(--ochre); box-shadow: 0 0 8px var(--ochre); }
@keyframes floatCard { 50% { transform: translateY(-12px); } }
@media (max-width: 980px) { .hero__in { grid-template-columns: 1fr; } .stage { height: 460px; max-width: 520px; margin: 0 auto; } }

/* Portail des 4 Solutions */
.portal { margin-top: -50px; position: relative; z-index: 10; padding-bottom: var(--sp-6); }
.portal__grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: var(--sp-4); }
.gate {
  position: relative; display: flex; flex-direction: column; gap: var(--sp-4); padding: 22px 20px 22px;
  border-radius: var(--r-xl); background: linear-gradient(170deg, var(--night-3) 0%, var(--night-2) 100%);
  border: 1px solid var(--line-strong); overflow: hidden; transition: transform 0.35s var(--ease), border-color 0.3s, box-shadow 0.35s; cursor: pointer;
}
.gate::before { content: ""; position: absolute; inset: 0 0 auto 0; height: 4px; background: var(--c); }
.gate::after { content: ""; position: absolute; width: 240px; height: 240px; border-radius: 50%; background: var(--c); filter: blur(80px); opacity: 0; inset: auto -60px -100px auto; transition: opacity 0.35s; pointer-events: none; }
.gate:hover { transform: translateY(-8px); border-color: var(--c); box-shadow: 0 30px 60px -20px var(--c); }
.gate:hover::after { opacity: 0.32; }
.gate__logo {
  background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgba(255, 255, 255, 0.04)), rgba(15, 27, 32, 0.45));
  border: 1px solid color-mix(in srgb, var(--c) 30%, rgba(255, 255, 255, 0.08)); border-radius: var(--r-md); padding: 12px 14px;
  position: relative; z-index: 1; display: flex; align-items: center; justify-content: center; min-height: 76px;
}
.gate__logo .ft-logo-svg { height: 54px; width: auto; }
.gate h3 { margin: 0; font: 800 20px/1.2 var(--f-head); position: relative; z-index: 1; }
.gate p { margin: 0; color: var(--muted); font-size: 14px; line-height: 1.5; position: relative; z-index: 1; flex: 1; }
.gate__go { display: flex; justify-content: space-between; align-items: center; font-weight: 700; font-size: 14.5px; color: var(--c); position: relative; z-index: 1; padding-top: var(--sp-2); }
.gate__go span { display: grid; place-items: center; width: 40px; height: 40px; border-radius: 50%; background: var(--c); color: #FFFFFF; transition: transform 0.25s var(--ease); }
.gate:hover .gate__go span { transform: translateX(5px); }
html[dir=rtl] .gate:hover .gate__go span { transform: translateX(-5px); }
@media (max-width: 1040px) { .portal__grid { grid-template-columns: repeat(2, 1fr); } }
@media (max-width: 580px) { .portal__grid { grid-template-columns: 1fr; } }

/* Bandeau Confiance */
.strip { padding: var(--sp-6) 0; border-block: 1px solid var(--line); background: var(--night-2); overflow: hidden; }
.marq-wrap { display: flex; overflow: hidden; user-select: none; }
.marq { display: flex; gap: 50px; width: max-content; animation: marqSlide 32s linear infinite; }
.strip:hover .marq, .strip:focus-within .marq { animation-play-state: paused; }
html[dir=rtl] .marq-wrap { direction: ltr; }
html[dir=rtl] .marq { animation-direction: reverse; }
html[dir=rtl] .marq span { direction: rtl; }
.marq span { display: inline-flex; align-items: center; gap: 12px; font: 700 18px var(--f-head); color: #94A8B0; white-space: nowrap; }
.marq span svg { width: 22px; height: 22px; color: var(--ochre); flex: none; }
@keyframes marqSlide { to { transform: translateX(-50%); } }

/* ==========================================================================
   SECTIONS VITRINES + TERMINAUX POS PRO AVEC PHOTOS RÉELLES D'ARTICLES
   ========================================================================== */
.sol { padding: 105px 0; border-bottom: 1px solid var(--line); position: relative; overflow: hidden; }
.sol:nth-of-type(even) { background: linear-gradient(180deg, var(--night-2) 0%, var(--night) 100%); }
.sol__in { display: grid; grid-template-columns: 0.78fr 1.22fr; gap: 44px; align-items: center; }
.sol.flip .sol__in { grid-template-columns: 1.22fr 0.78fr; }
.sol.flip .sol__txt { order: 2; }
.sol.flip .pos-screen, .sol.flip .boss-stage { order: 1; }
.sol__txt, .pos-screen, .boss-stage { min-width: 0; width: 100%; }
.sol__txt { display: flex; flex-direction: column; align-items: flex-start; }
.sol__logo-glass {
  display: inline-flex; align-items: center; padding: 12px 20px; border-radius: var(--r-lg);
  background: linear-gradient(135deg, color-mix(in srgb, var(--c) 12%, rgba(255, 255, 255, 0.04)), rgba(15, 27, 32, 0.55));
  border: 1px solid color-mix(in srgb, var(--c) 35%, rgba(255, 255, 255, 0.08));
  box-shadow: 0 12px 30px -15px color-mix(in srgb, var(--c) 50%, transparent);
  margin-bottom: var(--sp-4); backdrop-filter: blur(10px);
}
.sol__logo-glass .ft-logo-svg { height: 60px; width: auto; }
.sol__tag {
  display: inline-flex; align-items: center; gap: 8px; padding: 6px 14px; border-radius: var(--r-full);
  font-weight: 800; font-size: 12.5px; letter-spacing: 0.04em; color: var(--c);
  background: color-mix(in srgb, var(--c) 14%, transparent); border: 1px solid color-mix(in srgb, var(--c) 38%, transparent);
  margin-bottom: var(--sp-4);
}
.sol h2 { font: 800 clamp(28px, 3vw, 40px)/1.14 var(--f-head); letter-spacing: -0.03em; margin: 0 0 var(--sp-3); }
.sub { font-size: 16.5px; color: var(--ink-secondary); line-height: 1.6; max-width: 52ch; margin: 0; }
.benefits { list-style: none; padding: 0; margin: var(--sp-5) 0 var(--sp-8); display: grid; gap: var(--sp-3); }
.benefits li { display: flex; gap: 12px; align-items: flex-start; color: #DDE7EB; font-size: 15px; }
.benefits li svg { width: 20px; height: 20px; flex: none; color: var(--c); margin-top: 2px; }
.sol__cta { display: flex; flex-wrap: wrap; gap: var(--sp-3); }
.sol .btn--c { background: var(--c); color: #FFFFFF; box-shadow: 0 14px 30px -10px var(--c); }
.sol .btn--c:hover { filter: brightness(1.1); }

/* Châssis Terminal POS Réaliste (Caisse Tactile Pro) */
.pos-screen {
  border-radius: 22px;
  background: linear-gradient(180deg, #0D1A20 0%, #081115 100%);
  border: 1.5px solid color-mix(in srgb, var(--c) 45%, rgba(255, 255, 255, 0.16));
  box-shadow: 0 42px 90px -28px rgba(0, 0, 0, 0.95), 0 0 40px -18px color-mix(in srgb, var(--c) 45%, transparent);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.pos-topbar {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  padding: 12px 16px;
  background: linear-gradient(90deg, #13242B 0%, #0F1D23 100%);
  border-bottom: 1px solid rgba(255, 255, 255, 0.09);
}
.pos-brand-mini { display: flex; align-items: center; gap: 10px; font-weight: 800; font-size: 13.5px; color: #FFFFFF; }
.pos-brand-mini small { display: block; font-size: 11px; font-weight: 600; color: var(--muted); }
.pos-tabs { display: flex; gap: 4px; background: rgba(0, 0, 0, 0.35); padding: 3px; border-radius: 10px; border: 1px solid rgba(255,255,255,0.07); }
.pos-tab-btn {
  min-height: 34px; padding: 4px 12px; border-radius: 8px; font-size: 12px; font-weight: 700;
  color: var(--muted); transition: all 0.2s; white-space: nowrap;
}
.pos-tab-btn[aria-selected=true], .pos-tab-btn[aria-pressed=true] { background: var(--c); color: #FFFFFF; box-shadow: 0 4px 12px -2px var(--c); }

.pos-live-pill {
  display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: var(--r-full);
  background: color-mix(in srgb, var(--c) 16%, transparent); border: 1px solid color-mix(in srgb, var(--c) 40%, transparent);
  color: #FFFFFF; font-size: 11px; font-weight: 700; font-family: var(--f-mono);
}
.pos-live-pill i { width: 6px; height: 6px; border-radius: 50%; background: #4ADE80; box-shadow: 0 0 8px #4ADE80; }

/* Barre Outils Recherche + Catégories */
.pos-toolbar {
  display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 8px;
  padding: 9px 12px; background: rgba(255, 255, 255, 0.025); border-bottom: 1px solid rgba(255, 255, 255, 0.07);
}
.pos-search-fake {
  display: inline-flex; align-items: center; gap: 7px; padding: 5px 10px; border-radius: 8px;
  background: rgba(0, 0, 0, 0.35); border: 1px solid rgba(255, 255, 255, 0.09);
  font-size: 11px; color: var(--muted); flex: 1; min-width: 150px;
}
.pos-search-fake svg { width: 13px; height: 13px; color: var(--c); flex: none; }
.pos-cats { display: flex; flex-wrap: wrap; gap: 5px; }
.pos-cat-pill {
  min-height: 27px; padding: 2px 9px; border-radius: 99px; font-size: 10.5px; font-weight: 700;
  background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.09); color: #CBD5E1; transition: all 0.18s;
}
.pos-cat-pill[aria-pressed=true] { background: color-mix(in srgb, var(--c) 24%, transparent); border-color: var(--c); color: #FFFFFF; }
.pos-chip {
  min-height: 32px; padding: 4px 10px; border-radius: 8px; font-size: 11px; font-weight: 700;
  background: rgba(255, 255, 255, 0.05); border: 1px solid var(--line); color: var(--muted); transition: all 0.2s;
}
.pos-chip[aria-pressed=true], .pos-chip.on {
  background: color-mix(in srgb, var(--c) 22%, transparent); border-color: var(--c); color: #FFFFFF;
}

/* Grille Caisse 2 Colonnes (Catalogue Photo + Ticket Caisse) */
.pos-split {
  display: grid;
  grid-template-columns: 1.32fr 0.88fr;
  min-height: 410px;
}
.pos-catalog {
  padding: 12px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  border-inline-end: 1px solid rgba(255, 255, 255, 0.08);
  min-width: 0;
}
.pos-ticket-col {
  padding: 12px;
  background: #0B161B;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.pos-items-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 9px;
}
.pos-item-btn {
  text-align: start; padding: 0; border-radius: 12px; overflow: hidden;
  background: #122229; border: 1px solid rgba(255, 255, 255, 0.1);
  display: flex; flex-direction: column; transition: all 0.22s var(--ease); position: relative;
  box-shadow: 0 10px 22px -12px rgba(0, 0, 0, 0.7);
}
.pos-item-btn:hover { border-color: var(--c); transform: translateY(-3px); box-shadow: 0 16px 28px -12px color-mix(in srgb, var(--c) 45%, #000); }
.pos-item-btn:active { transform: scale(0.97); }
.pos-card-media {
  position: relative; width: 100%; height: 84px; overflow: hidden; background: #1B313B;
}
.pos-card-media img {
  width: 100%; height: 100%; object-fit: cover; transition: transform 0.35s var(--ease);
}
.pos-item-btn:hover .pos-card-media img { transform: scale(1.07); }
.pos-card-media::after {
  content: ""; position: absolute; inset: 0;
  background: linear-gradient(180deg, rgba(8,17,21,0.35) 0%, transparent 45%, rgba(8,17,21,0.82) 100%);
  pointer-events: none;
}
.pos-card-badge {
  position: absolute; top: 6px; inset-inline-start: 6px; z-index: 2;
  padding: 2px 7px; border-radius: 6px; font-size: 9px; font-weight: 800; letter-spacing: 0.03em;
  background: rgba(10, 20, 24, 0.85); backdrop-filter: blur(6px); color: #F8FAFC;
  border: 1px solid rgba(255, 255, 255, 0.16);
}
.pos-card-plus {
  position: absolute; bottom: 6px; inset-inline-end: 6px; z-index: 2;
  width: 24px; height: 24px; border-radius: 50%; background: var(--c); color: #FFFFFF;
  display: grid; place-items: center; font-weight: 800; font-size: 14px; line-height: 1;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.6); transition: transform 0.2s;
}
.pos-item-btn:hover .pos-card-plus { transform: scale(1.12); }
.pos-card-body { padding: 8px 9px 9px; display: flex; flex-direction: column; gap: 2px; flex: 1; }
.pos-item-btn b { font-size: 11.8px; color: #FFFFFF; line-height: 1.22; display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pos-item-btn .ar-sub { font-family: var(--f-ar); font-size: 10.5px; color: #94A8B0; line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pos-item-btn .pr-tag { font: 800 12px var(--f-mono); color: var(--c); margin-top: 3px; display: flex; align-items: center; justify-content: space-between; }
.pos-item-btn.expired { border-color: #EF4444; background: rgba(127, 29, 29, 0.28); }
.pos-item-btn.expired .pos-card-plus { background: #EF4444; }
.pos-item-btn.expired .pr-tag { color: #FCA5A5; }

/* Ticket de caisse interactif avec miniatures photos */
.tk-head { display: flex; justify-content: space-between; align-items: flex-start; gap: 6px; padding-bottom: 8px; border-bottom: 1px dashed rgba(255, 255, 255, 0.16); }
.tk-head b { font-size: 12.5px; color: #FFFFFF; display: block; }
.tk-head small { font-size: 10.5px; color: var(--ochre); font-weight: 700; display: block; }
.tk-list { flex: 1; display: flex; flex-direction: column; gap: 6px; max-height: 175px; overflow-y: auto; padding-inline-end: 2px; }
.tk-row {
  display: flex; justify-content: space-between; align-items: center; gap: 6px;
  font-size: 11.5px; padding: 5px 7px; border-radius: 8px;
  background: rgba(255, 255, 255, 0.045); border: 1px solid rgba(255, 255, 255, 0.06);
}
.tk-row-left { display: flex; align-items: center; gap: 7px; min-width: 0; flex: 1; }
.tk-thumb { width: 28px; height: 28px; border-radius: 6px; object-fit: cover; flex: none; border: 1px solid rgba(255, 255, 255, 0.15); }
.tk-row-title { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #F1F5F9; font-weight: 600; font-size: 11.2px; }
.tk-row b { font-family: var(--f-mono); color: #FFFFFF; font-size: 11.5px; flex: none; }
.tk-qty { display: inline-grid; place-items: center; min-width: 19px; height: 19px; border-radius: 5px; background: var(--c); color: #FFFFFF; font-size: 10.5px; font-weight: 800; flex: none; }
.tk-total { display: flex; justify-content: space-between; align-items: baseline; padding-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.12); font: 800 17.5px var(--f-head); color: #FFFFFF; }
.tk-total small { font-size: 10.5px; font-weight: 700; color: var(--muted); }
.tk-pay-methods { display: grid; grid-template-columns: repeat(4, 1fr); gap: 5px; }
.tk-pm {
  min-height: 32px; border-radius: 7px; font-size: 10.5px; font-weight: 800; color: #CBD5E1;
  background: rgba(255, 255, 255, 0.06); border: 1px solid rgba(255, 255, 255, 0.1); transition: all 0.2s;
}
.tk-pm[aria-pressed=true] { background: var(--ochre); color: #121A15; border-color: var(--ochre); }
.tk-checkout-btn {
  min-height: 40px; border-radius: 10px; background: var(--c); color: #FFFFFF; font-weight: 800; font-size: 12px;
  display: flex; align-items: center; justify-content: center; gap: 6px; transition: all 0.2s;
  box-shadow: 0 10px 20px -8px var(--c);
}
.tk-checkout-btn:hover { filter: brightness(1.1); }
.tk-feedback { font-size: 11px; font-weight: 700; color: #4ADE80; text-align: center; min-height: 16px; }

/* Vues annexes Resto (Plan de Salle Khaima & KDS) */
.pos-subview { display: none; padding: 14px; }
.pos-subview.active { display: block; animation: fadeInLine 0.25s var(--ease); }
.pos-split.active { display: grid; animation: fadeInLine 0.25s var(--ease); }
.pos-split:not(.active) { display: none; }

.khaima-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; }
.khaima-card {
  padding: 14px; border-radius: 12px; border: 1px solid rgba(255, 255, 255, 0.12); background: rgba(255, 255, 255, 0.04);
  display: flex; justify-content: space-between; align-items: center; text-align: start; transition: all 0.2s;
}
.khaima-card:hover { border-color: var(--resto); background: rgba(228, 87, 46, 0.12); }
.khaima-card b { display: block; font-size: 13px; color: #FFFFFF; }
.khaima-card small { font-size: 11px; color: var(--muted); }
.khaima-st { padding: 4px 8px; border-radius: 99px; font-size: 10.5px; font-weight: 800; }

.kds-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; }
.kds-card { border-radius: 10px; overflow: hidden; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--line); display: flex; flex-direction: column; }
.kds-header { display: flex; justify-content: space-between; align-items: center; padding: 8px 10px; color: #FFFFFF; font-size: 11.5px; font-weight: 800; }
.kds-card p { margin: 0; padding: 10px; color: #D5E0E4; line-height: 1.45; font-size: 12px; flex: 1; }
.kds-ready-btn {
  margin: 0 8px 8px; min-height: 34px; border-radius: 7px; background: rgba(46, 158, 91, 0.2); border: 1px solid var(--market);
  color: #BBF7D0; font-size: 11px; font-weight: 800; transition: all 0.2s;
}
.kds-ready-btn.done { background: var(--market); color: #FFFFFF; }

/* Barre Balance Market & Alerte Pharma */
.pos-hw-bar {
  margin: 10px 12px 0; padding: 7px 12px; border-radius: 9px;
  background: rgba(46, 158, 91, 0.14); border: 1px solid rgba(46, 158, 91, 0.45);
  display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 8px;
  font-family: var(--f-mono); font-size: 11px; color: #BBF7D0; font-weight: 700;
}
.pharma-alert-bar {
  margin: 10px 12px 0; padding: 7px 12px; border-radius: 9px;
  background: rgba(27, 143, 217, 0.14); border: 1px solid rgba(27, 143, 217, 0.45);
  display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 8px;
  font-size: 11.5px; color: #BAE6FD; font-weight: 700;
}
.pharma-alert-bar.danger { background: rgba(239, 68, 68, 0.22); border-color: #EF4444; color: #FECACA; }

@media (max-width: 1120px) {
  .sol__in, .sol.flip .sol__in { grid-template-columns: 1fr; gap: var(--sp-8); }
  .sol.flip .sol__txt, .sol.flip .pos-screen, .sol.flip .boss-stage { order: 0; }
  .sol { padding: 75px 0; }
}
@media (max-width: 720px) {
  .pos-split { grid-template-columns: 1fr; }
  .pos-catalog { border-inline-end: 0; border-bottom: 1px solid rgba(255, 255, 255, 0.08); }
  .pos-items-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .kds-grid, .khaima-grid { grid-template-columns: 1fr; }
}

/* ==========================================================================
   PARTIE APP MOBILE FULL-TEK BOSS (SMARTPHONE INTERACTIF)
   ========================================================================== */
.app-badges { display: flex; flex-wrap: wrap; gap: var(--sp-2); margin: -10px 0 var(--sp-6); }
.app-badge {
  display: inline-flex; align-items: center; gap: 8px; padding: 8px 14px; border-radius: var(--r-md);
  background: rgba(255, 255, 255, 0.05); border: 1px solid var(--line-strong); font-size: 13px; font-weight: 700; color: #E2ECEF;
}
.app-badge svg { width: 17px; height: 17px; color: var(--boss); flex: none; }
.boss-stage { position: relative; display: flex; justify-content: center; align-items: center; padding: var(--sp-4) 0; min-height: 540px; }
.boss-aura { position: absolute; width: 420px; height: 420px; border-radius: 50%; background: radial-gradient(circle, rgba(201, 154, 46, 0.28) 0%, transparent 70%); filter: blur(55px); pointer-events: none; }
.boss-phone {
  position: relative; width: min(100%, 375px); border-radius: 42px; padding: 12px;
  background: linear-gradient(145deg, #2B424B 0%, #16242A 100%);
  border: 2px solid rgba(201, 154, 46, 0.5);
  box-shadow: 0 50px 90px -25px rgba(0, 0, 0, 0.95), 0 0 40px -15px rgba(201, 154, 46, 0.35); z-index: 2;
}
.boss-screen { border-radius: 32px; background: #0D181D; overflow: hidden; border: 1px solid rgba(255, 255, 255, 0.08); display: flex; flex-direction: column; }
.boss-notch-bar { display: flex; justify-content: space-between; align-items: center; padding: 10px 20px 6px; font: 700 11.5px var(--f-mono); color: #CBD5E1; }
.boss-island { width: 82px; height: 20px; border-radius: 99px; background: #05090B; display: flex; align-items: center; justify-content: flex-end; padding-inline-end: 8px; }
.boss-island i { width: 6px; height: 6px; border-radius: 50%; background: #1E3A47; }
.boss-app-top { display: flex; justify-content: space-between; align-items: center; padding: 10px 16px 10px; border-bottom: 1px solid rgba(255, 255, 255, 0.07); }
.boss-app-id { display: flex; align-items: center; gap: 8px; }
.boss-app-id strong { font-size: 14px; font-weight: 800; color: #FFFFFF; }
.boss-app-id span { font-size: 10px; font-weight: 800; color: var(--boss); letter-spacing: 0.08em; display: block; line-height: 1; }
.boss-live-chip { display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px; border-radius: var(--r-full); background: rgba(46, 158, 91, 0.16); color: #4ADE80; font-size: 11px; font-weight: 800; }
.boss-live-chip i { width: 6px; height: 6px; border-radius: 50%; background: #4ADE80; animation: pulseDot 1.8s infinite; }
.boss-shops { display: flex; gap: 6px; padding: 9px 14px; overflow-x: auto; scrollbar-width: none; }
.boss-shops::-webkit-scrollbar { display: none; }
.shop-chip { min-height: 34px; padding: 4px 12px; border-radius: var(--r-full); background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.1); color: var(--muted); font-size: 11.5px; font-weight: 700; white-space: nowrap; transition: all 0.2s; }
.shop-chip[aria-pressed=true] { background: var(--boss); border-color: var(--boss); color: #141A12; }
.boss-app-body { padding: 4px 14px 12px; min-height: 345px; }
.boss-pane { display: none; flex-direction: column; gap: 8px; animation: fadeInLine 0.25s var(--ease); }
.boss-pane.active { display: flex; }
.boss-hero-kpi { padding: 12px 14px; border-radius: var(--r-md); background: linear-gradient(135deg, rgba(201, 154, 46, 0.18), rgba(27, 50, 59, 0.8)); border: 1px solid rgba(201, 154, 46, 0.35); }
.boss-hero-kpi small { font-size: 11px; color: #D2DEE2; font-weight: 600; display: flex; justify-content: space-between; }
.boss-hero-kpi small span { color: #4ADE80; font-weight: 800; }
.boss-hero-kpi strong { display: block; font: 800 26px/1.15 var(--f-head); color: #FFFFFF; margin-top: 3px; }
.boss-split-bar { height: 6px; border-radius: 99px; background: rgba(255, 255, 255, 0.1); overflow: hidden; display: flex; margin: 8px 0 5px; }
.boss-split-bankily { background: var(--market); transition: width 0.35s var(--ease); }
.boss-split-cash { background: var(--boss); flex: 1; }
.boss-split-legend { display: flex; justify-content: space-between; font-size: 10.5px; color: var(--muted); font-weight: 600; }
.boss-mini-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; }
.boss-mini-card { padding: 8px 11px; border-radius: var(--r-sm); background: rgba(255, 255, 255, 0.04); border: 1px solid var(--line); }
.boss-mini-card small { display: block; font-size: 10.5px; color: var(--muted); }
.boss-mini-card b { display: block; font: 800 15px var(--f-head); color: #FFFFFF; margin-top: 1px; }
.boss-top-items { display: flex; flex-direction: column; gap: 5px; padding: 8px 10px; border-radius: var(--r-sm); background: rgba(255, 255, 255, 0.03); border: 1px solid var(--line); }
.boss-top-items > small { font-size: 10.5px; color: var(--muted); font-weight: 700; display: flex; justify-content: space-between; }
.boss-top-row { display: flex; align-items: center; justify-content: space-between; gap: 8px; font-size: 11px; }
.boss-top-row div { display: flex; align-items: center; gap: 7px; color: #E2E8F0; font-weight: 600; }
.boss-top-row img { width: 24px; height: 24px; border-radius: 6px; object-fit: cover; border: 1px solid rgba(255,255,255,0.15); }
.boss-top-row b { font-family: var(--f-mono); color: var(--boss); font-size: 11px; }
.boss-spark { padding: 8px 11px; border-radius: var(--r-sm); background: rgba(255, 255, 255, 0.03); border: 1px solid var(--line); }
.boss-spark small { display: block; font-size: 10.5px; color: var(--muted); margin-bottom: 6px; font-weight: 600; }
.boss-bars { display: flex; align-items: flex-end; gap: 6px; height: 38px; }
.boss-bars i { flex: 1; border-radius: 4px 4px 0 0; background: linear-gradient(var(--boss), rgba(201, 154, 46, 0.25)); transition: height 0.35s var(--ease); }
.boss-alert-item { padding: 10px 12px; border-radius: var(--r-sm); background: rgba(255, 255, 255, 0.04); border: 1px solid var(--line); display: flex; gap: 10px; align-items: flex-start; font-size: 12px; }
.boss-alert-dot { width: 8px; height: 8px; border-radius: 50%; margin-top: 5px; flex: none; }
.boss-alert-item strong { display: block; color: #FFFFFF; font-size: 12px; }
.boss-alert-item span { color: var(--muted); font-size: 11px; }
.boss-z-card { padding: 14px; border-radius: var(--r-md); background: rgba(255, 255, 255, 0.04); border: 1px solid var(--line); display: grid; gap: 8px; font-size: 12.5px; }
.boss-z-row { display: flex; justify-content: space-between; color: #D2DEE2; }
.boss-z-row b { color: #FFFFFF; }
.boss-z-btn { width: 100%; min-height: 44px; border-radius: var(--r-md); background: var(--boss); color: #121810; font-weight: 800; font-size: 13px; display: flex; align-items: center; justify-content: center; gap: 8px; margin-top: 6px; transition: all 0.2s; }
.boss-z-btn.done { background: var(--market); color: #FFFFFF; }
.boss-bottom-nav { display: grid; grid-template-columns: repeat(3, 1fr); background: #091216; border-top: 1px solid rgba(255, 255, 255, 0.08); padding: 6px 8px; }
.boss-tab { min-height: 44px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 3px; font-size: 10.5px; font-weight: 700; color: var(--muted); border-radius: 10px; transition: all 0.2s; }
.boss-tab svg { width: 17px; height: 17px; }
.boss-tab[aria-selected=true] { color: var(--boss); background: rgba(201, 154, 46, 0.12); }
.boss-push-toast {
  position: absolute; top: 24px; inset-inline-end: 0; width: 245px; padding: 11px 13px; border-radius: var(--r-md);
  background: rgba(15, 27, 32, 0.94); backdrop-filter: blur(12px); border: 1px solid rgba(201, 154, 46, 0.55);
  box-shadow: 0 25px 50px -15px rgba(0, 0, 0, 0.9); display: flex; gap: 10px; align-items: center; z-index: 4; animation: floatCard 6s ease-in-out -1s infinite;
}
.boss-stores-float {
  position: absolute; bottom: 24px; inset-inline-start: 0; width: 235px; padding: 12px 14px; border-radius: var(--r-md);
  background: rgba(15, 27, 32, 0.94); backdrop-filter: blur(12px); border: 1px solid rgba(46, 158, 91, 0.5);
  box-shadow: 0 25px 50px -15px rgba(0, 0, 0, 0.9); display: grid; gap: 6px; z-index: 4; animation: floatCard 7s ease-in-out -3s infinite;
}
.boss-stores-float small { font-size: 10px; font-weight: 800; color: #4ADE80; letter-spacing: 0.05em; }
.boss-st-line { display: flex; justify-content: space-between; align-items: center; font-size: 11.2px; color: #E2E8F0; font-weight: 600; }
.boss-st-line span { color: var(--boss); font-family: var(--f-mono); font-weight: 700; font-size: 11px; }
.boss-push-icon { width: 34px; height: 34px; border-radius: 10px; background: var(--boss); color: #121810; display: grid; place-items: center; flex: none; }
.boss-push-toast b { display: block; font-size: 12px; color: #FFFFFF; }
.boss-push-toast span { display: block; font-size: 11px; color: var(--muted); }
@media (max-width: 900px) { .boss-push-toast, .boss-stores-float { display: none; } }

/* Hors Ligne & Tarifs & Contact */
.offline-sec { background: linear-gradient(135deg, var(--petrol) 0%, #152B33 100%); padding: 100px 0; position: relative; overflow: hidden; }
.off__in { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-12); align-items: center; }
.eyebrow { color: var(--ochre); font-weight: 800; font-size: 13px; letter-spacing: 0.12em; text-transform: uppercase; margin-bottom: var(--sp-3); }
.network-switch { display: flex; gap: var(--sp-2); margin: var(--sp-6) 0; background: rgba(0, 0, 0, 0.3); padding: 4px; border-radius: var(--r-lg); border: 1px solid var(--line-strong); }
.network-switch button { flex: 1; min-height: 48px; border-radius: var(--r-md); font-weight: 700; font-size: 14.5px; display: inline-flex; align-items: center; justify-content: center; gap: 8px; transition: all 0.25s var(--ease); color: var(--muted); }
.network-switch button[aria-pressed=true] { background: var(--ochre); color: #111A15; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3); }
.net-monitor { padding: var(--sp-6); border-radius: var(--r-xl); background: rgba(15, 27, 32, 0.85); backdrop-filter: blur(12px); border: 1px solid var(--line-strong); box-shadow: 0 30px 60px -20px rgba(0, 0, 0, 0.8); }
.net-row { display: flex; justify-content: space-between; align-items: center; padding: 14px 16px; border-radius: var(--r-md); background: rgba(255, 255, 255, 0.05); margin-bottom: var(--sp-2); font-weight: 600; font-size: 14.5px; }
.net-pill { padding: 4px 12px; border-radius: var(--r-full); font-size: 12px; font-weight: 800; background: var(--market); color: #FFFFFF; transition: background 0.3s; }
.net-pill.warn { background: #D97706; } .net-pill.bad { background: #DC2626; }
.net-status-text { margin: var(--sp-4) 0 0; color: #D2DEE2; font-size: 14.5px; line-height: 1.5; min-height: 48px; }
@media (max-width: 900px) { .off__in { grid-template-columns: 1fr; gap: var(--sp-8); } }

.pricing-sec { padding: 100px 0; }
.pricing-header { text-align: center; margin-bottom: var(--sp-8); }
.pricing-header h2 { font: 800 clamp(30px, 3.6vw, 48px)/1.1 var(--f-head); margin: 0 0 14px; }
.pricing-header p { margin: 0 auto; }
.billing-toggle-wrap { display: inline-flex; align-items: center; gap: var(--sp-3); padding: 4px; background: var(--night-2); border: 1px solid var(--line-strong); border-radius: var(--r-full); margin-top: var(--sp-6); }
.billing-btn { min-height: 40px; padding: 6px 18px; border-radius: var(--r-full); font-weight: 700; font-size: 14px; color: var(--muted); transition: all 0.2s; display: inline-flex; align-items: center; gap: 8px; }
.billing-btn[aria-pressed=true] { background: var(--petrol); color: #FFFFFF; }
.discount-chip { background: var(--market); color: #FFFFFF; font-size: 11px; font-weight: 800; padding: 2px 8px; border-radius: var(--r-full); }
.plans-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: var(--sp-6); align-items: stretch; margin-top: var(--sp-8); }
.plan-card { padding: var(--sp-8) var(--sp-6); border-radius: var(--r-xl); background: var(--night-2); border: 1px solid var(--line-strong); display: flex; flex-direction: column; gap: var(--sp-5); transition: transform 0.35s var(--ease), border-color 0.3s; }
.plan-card:hover { transform: translateY(-6px); }
.plan-card.popular { background: linear-gradient(165deg, var(--petrol) 0%, #162E37 100%); border: 2px solid var(--ochre); box-shadow: 0 35px 70px -25px rgba(233, 162, 59, 0.4); position: relative; }
.plan-popular-badge { position: absolute; top: -14px; inset-inline-start: 24px; background: var(--ochre); color: #121A15; font-weight: 800; font-size: 12px; padding: 5px 14px; border-radius: var(--r-full); }
.plan-card h3 { margin: 0; font: 800 24px var(--f-head); }
.price-display { font: 800 44px/1 var(--f-head); }
.price-display small { font: 600 15px var(--f-sans); color: var(--muted); }
.plan-card ul { list-style: none; padding: 0; margin: 0; display: grid; gap: var(--sp-3); flex: 1; color: #DDE7EB; font-size: 15px; }
.plan-card li { display: flex; align-items: center; gap: 10px; }
.plan-card li svg { width: 18px; height: 18px; flex: none; color: var(--ochre); }
@media (max-width: 960px) { .plans-grid { grid-template-columns: 1fr; } }

/* Section Contact & Carte Directe M. Taha Chouaib (+222 42 74 42 42) */
.cta-sec { padding: 100px 0; background: radial-gradient(circle at 80% 20%, rgba(233, 162, 59, 0.15) 0%, transparent 60%), var(--night-2); }
.cta__in { display: grid; grid-template-columns: 1.05fr 0.95fr; gap: var(--sp-12); align-items: center; }
.taha-card {
  margin-top: var(--sp-6); padding: 20px; border-radius: var(--r-lg);
  background: rgba(15, 27, 32, 0.72); border: 1px solid rgba(233, 162, 59, 0.4);
  display: flex; flex-direction: column; gap: 12px;
}
.taha-top { display: flex; align-items: center; gap: 14px; }
.taha-avatar {
  width: 50px; height: 50px; border-radius: 50%; background: linear-gradient(135deg, var(--ochre), #C97F17);
  color: #141A12; font: 800 18px var(--f-head); display: grid; place-items: center; flex: none;
}
.taha-top b { display: block; font-size: 16px; color: #FFFFFF; }
.taha-top span { display: block; font-size: 13px; color: var(--muted); }
.taha-actions { display: flex; flex-wrap: wrap; gap: 10px; }
.taha-btn-call {
  min-height: 44px; padding: 0 16px; border-radius: var(--r-md); background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.16); color: #FFFFFF; font-weight: 700; font-size: 14px;
  display: inline-flex; align-items: center; gap: 8px; transition: all 0.2s;
}
.taha-btn-call:hover { border-color: var(--ochre); color: var(--ochre); }
.taha-btn-wa {
  min-height: 44px; padding: 0 16px; border-radius: var(--r-md); background: #25D366; color: #0B1C10;
  font-weight: 800; font-size: 14px; display: inline-flex; align-items: center; gap: 8px; transition: all 0.2s;
}
.taha-btn-wa:hover { filter: brightness(1.08); transform: translateY(-1px); }

form.f-box { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-4); padding: var(--sp-8); border-radius: var(--r-xl); background: var(--night); border: 1px solid var(--line-strong); box-shadow: 0 40px 80px -30px rgba(0, 0, 0, 0.9); }
.f-box label { display: grid; gap: 6px; font-size: 13.5px; font-weight: 600; color: #D2DEE2; }
.f-box .col-full { grid-column: 1 / -1; }
.f-box input, .f-box select { height: 52px; padding: 0 16px; border-radius: var(--r-md); border: 1px solid rgba(255, 255, 255, 0.18); background: var(--night-2); color: #FFFFFF; font: inherit; transition: border-color 0.2s, box-shadow 0.2s; }
.f-box input:focus, .f-box select:focus { outline: none; border-color: var(--ochre); box-shadow: 0 0 0 3px rgba(233, 162, 59, 0.25); }
.f-box .btn { grid-column: 1 / -1; }
.form-ok-msg { grid-column: 1 / -1; padding: 16px; border-radius: var(--r-md); background: rgba(46, 158, 91, 0.2); border: 1px solid var(--market); color: #BBF7D0; font-weight: 600; font-size: 14.5px; display: none; }
.form-ok-msg a.wa-btn { display: inline-flex; align-items: center; gap: 8px; margin-top: 10px; padding: 10px 16px; background: #25D366; color: #0B1C10; border-radius: var(--r-sm); font-weight: 800; font-size: 13.5px; }
@media (max-width: 900px) { .cta__in { grid-template-columns: 1fr; } form.f-box { grid-template-columns: 1fr; } }

/* Footer & Bouton flottant WhatsApp M. Taha */
footer { padding: 70px 0 36px; background: #091216; color: var(--muted); font-size: 14.5px; }
.foot-grid { display: grid; grid-template-columns: 1.4fr 1fr 1fr 1fr; gap: var(--sp-8); padding-bottom: var(--sp-8); border-bottom: 1px solid var(--line); }
.foot-grid h4 { margin: 0 0 14px; color: #FFFFFF; font-size: 15px; }
.foot-grid a { display: block; padding: 6px 0; transition: color 0.2s; }
.foot-grid a:hover { color: var(--ochre); }
.foot-grid img { height: 42px; width: auto; margin-bottom: 14px; }
.copy-row { padding-top: var(--sp-6); display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: var(--sp-3); font-size: 13.5px; }
.btn-replay { display: inline-flex; align-items: center; gap: 8px; min-height: 44px; padding: 6px 14px; border-radius: var(--r-sm); border: 1px solid var(--line-strong); color: var(--ochre); font-weight: 600; transition: all 0.2s; }
.btn-replay:hover { background: rgba(233, 162, 59, 0.12); border-color: var(--ochre); }
@media (max-width: 800px) { .foot-grid { grid-template-columns: 1fr 1fr; } }

.fab-wa {
  position: fixed; bottom: 22px; inset-inline-end: 22px; z-index: 95;
  display: inline-flex; align-items: center; gap: 10px; min-height: 50px; padding: 8px 18px;
  border-radius: var(--r-full); background: #25D366; color: #0B1C10; font-weight: 800; font-size: 13.5px;
  box-shadow: 0 18px 36px -10px rgba(37, 211, 102, 0.65); transition: transform 0.25s var(--ease);
}
.fab-wa:hover { transform: translateY(-3px) scale(1.02); }
@media (max-width: 580px) { .fab-wa span { display: none; } .fab-wa { width: 52px; height: 52px; padding: 0; justify-content: center; } }

/* Modale & Preloader */
.modal { position: fixed; inset: 0; z-index: 300; display: none; place-items: center; padding: var(--sp-5); background: rgba(6, 12, 15, 0.85); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); }
.modal.open { display: grid; }
.modal__card { width: min(100%, 640px); padding: var(--sp-8); border-radius: var(--r-xl); background: var(--night-2); border: 1px solid var(--ochre); box-shadow: 0 50px 100px -30px rgba(0, 0, 0, 0.95); animation: modalEnter 0.3s var(--ease); position: relative; }
@keyframes modalEnter { from { opacity: 0; transform: scale(0.96) translateY(12px); } to { opacity: 1; transform: none; } }
.modal__card h3 { margin: 0 0 6px; font: 800 26px var(--f-head); }
.modal__card > p { margin: 0 0 var(--sp-6); color: var(--muted); }
.modal-close { position: absolute; top: 20px; inset-inline-end: 20px; min-width: 44px; min-height: 44px; border-radius: 50%; background: rgba(255, 255, 255, 0.05); display: grid; place-items: center; color: #FFFFFF; transition: all 0.2s; }
.modal-close:hover { background: rgba(255, 255, 255, 0.15); color: var(--ochre); }
.acc-grid { display: grid; grid-template-columns: 1fr 1fr; gap: var(--sp-3); }
.acc-link { display: flex; align-items: center; gap: 14px; padding: 14px 16px; border-radius: var(--r-md); background: rgba(255, 255, 255, 0.05); border: 1px solid var(--line-strong); font-weight: 700; transition: all 0.25s var(--ease); }
.acc-link:hover { border-color: var(--c); background: color-mix(in srgb, var(--c) 18%, transparent); transform: translateY(-2px); }
.acc-link small { display: block; font-weight: 400; color: var(--muted); font-size: 12.5px; }
@media (max-width: 540px) { .acc-grid { grid-template-columns: 1fr; } }

.preloader { position: fixed; inset: 0; z-index: 99999; background: radial-gradient(ellipse 95% 85% at 50% 42%, #162C36 0%, #0C171B 58%, #060B0D 100%); display: flex; flex-direction: column; align-items: center; justify-content: center; overflow: hidden; transition: opacity 0.75s var(--ease), visibility 0.75s var(--ease), transform 0.75s var(--ease); }
.preloader.fade-out { opacity: 0; visibility: hidden; transform: scale(1.035); pointer-events: none; }
.pre-bg-grid { position: absolute; inset: 0; pointer-events: none; background-image: linear-gradient(rgba(255, 255, 255, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255, 255, 255, 0.03) 1px, transparent 1px); background-size: 48px 48px; -webkit-mask-image: radial-gradient(circle at 50% 46%, #000 28%, transparent 76%); mask-image: radial-gradient(circle at 50% 46%, #000 28%, transparent 76%); }
.pre-aura { position: absolute; width: 560px; height: 560px; border-radius: 50%; background: radial-gradient(circle, rgba(233, 162, 59, 0.25) 0%, rgba(38, 70, 83, 0.48) 46%, transparent 72%); filter: blur(68px); pointer-events: none; animation: preAuraPulse 3.6s ease-in-out infinite alternate; }
.pre-orbit {
  position: absolute; width: 520px; height: 520px; border-radius: 50%; pointer-events: none;
  border: 1px dashed rgba(233, 162, 59, 0.14); animation: preOrbitSpin 24s linear infinite;
  -webkit-mask-image: radial-gradient(circle, transparent 48%, #000 50%, #000 70%, transparent 100%);
  mask-image: radial-gradient(circle, transparent 48%, #000 50%, #000 70%, transparent 100%);
}
.pre-orbit::before {
  content: ""; position: absolute; top: -4px; left: 50%; width: 8px; height: 8px; border-radius: 50%;
  background: var(--ochre); box-shadow: 0 0 18px var(--ochre);
}
@keyframes preAuraPulse { 0% { transform: scale(0.86); opacity: 0.45; } 100% { transform: scale(1.2); opacity: 0.9; } }
@keyframes preOrbitSpin { to { transform: rotate(360deg); } }
.pre-content { position: relative; z-index: 2; display: flex; flex-direction: column; align-items: center; text-align: center; width: min(94vw, 840px); padding: var(--sp-4); }
.pre-logo-wrap { position: relative; margin-bottom: var(--sp-4); filter: drop-shadow(0 20px 45px rgba(0, 0, 0, 0.65)); overflow: hidden; padding: 6px 12px; }
.pre-logo-wrap::after {
  content: ""; position: absolute; inset: 0; width: 45%;
  background: linear-gradient(105deg, transparent 20%, rgba(255, 255, 255, 0.14) 50%, transparent 80%);
  transform: translateX(-160%); animation: preSweep 1.6s var(--ease) 0.55s forwards; pointer-events: none;
}
@keyframes preSweep { to { transform: translateX(340%); } }
.pre-logo-svg { width: clamp(250px, 44vw, 410px); height: auto; display: block; overflow: visible; direction: ltr; }
.pre-p1 { transform-origin: left center; animation: pillEnter1 1.1s cubic-bezier(0.16, 1, 0.3, 1) forwards; }
.pre-p2 { transform-origin: left center; animation: pillEnter2 1.2s cubic-bezier(0.16, 1, 0.3, 1) 0.14s forwards; filter: drop-shadow(0 0 16px rgba(233, 162, 59, 0.85)); }
.pre-p3 { transform-origin: left center; animation: pillEnter3 1.3s cubic-bezier(0.16, 1, 0.3, 1) 0.28s forwards; }
@keyframes pillEnter1 { 0% { opacity: 0; transform: translateX(-60px) scaleX(0.2); } 100% { opacity: 1; transform: translateX(0) scaleX(1); } }
@keyframes pillEnter2 { 0% { opacity: 0; transform: translateX(-80px) scaleX(0.15); } 100% { opacity: 1; transform: translateX(0) scaleX(1); } }
@keyframes pillEnter3 { 0% { opacity: 0; transform: translateX(-50px) scaleX(0.1); } 100% { opacity: 1; transform: translateX(0) scaleX(1); } }
.pre-word-full { opacity: 0; animation: wordFade 1s cubic-bezier(0.16, 1, 0.3, 1) 0.38s forwards; }
.pre-word-tek { opacity: 0; animation: wordFade 1s cubic-bezier(0.16, 1, 0.3, 1) 0.52s forwards; }
.pre-word-sub { opacity: 0; animation: subFade 1.1s cubic-bezier(0.16, 1, 0.3, 1) 0.68s forwards; }
@keyframes wordFade { 0% { opacity: 0; transform: translateY(16px); } 100% { opacity: 1; transform: translateY(0); } }
@keyframes subFade { 0% { opacity: 0; letter-spacing: 1px; } 100% { opacity: 1; letter-spacing: 6px; } }

/* Barre de progression + 4 Logos POS */
.pre-bar-shell { width: min(100%, 540px); height: 4px; border-radius: var(--r-full); background: rgba(255, 255, 255, 0.08); position: relative; overflow: hidden; margin: var(--sp-2) 0 var(--sp-3); }
.pre-bar-fill { position: absolute; inset-block: 0; inset-inline-start: 0; width: 0%; border-radius: var(--r-full); background: linear-gradient(90deg, var(--resto), var(--market), var(--pharma), var(--ochre)); box-shadow: 0 0 18px rgba(233, 162, 59, 0.75); transition: width 0.08s linear; }
.pre-status-row { display: flex; justify-content: space-between; align-items: center; width: min(100%, 540px); font-family: var(--f-mono); font-size: 12px; color: var(--muted); }
.pre-percent { font-weight: 700; color: var(--ochre); letter-spacing: 1px; }
.pre-msg { font-size: 12px; color: #C9D8DC; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 410px; }

.pre-pos-grid {
  display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; width: 100%; margin-top: var(--sp-5);
}
.pre-pos-card {
  position: relative; padding: 14px 12px 11px; border-radius: var(--r-md);
  background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.08);
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px;
  opacity: 0.34; transform: translateY(10px) scale(0.96);
  transition: opacity 0.45s var(--ease), transform 0.45s var(--ease), border-color 0.45s, background 0.45s, box-shadow 0.45s;
}
.pre-pos-card::before {
  content: ""; position: absolute; inset: 0 20% auto 20%; height: 2px; border-radius: 99px;
  background: var(--c); opacity: 0.25; transition: opacity 0.4s, inset 0.4s;
}
.pre-pos-card.active {
  opacity: 1; transform: translateY(-5px) scale(1.03);
  background: color-mix(in srgb, var(--c) 12%, rgba(255, 255, 255, 0.05));
  border-color: color-mix(in srgb, var(--c) 65%, transparent);
  box-shadow: 0 20px 40px -14px color-mix(in srgb, var(--c) 55%, rgba(0,0,0,0.8));
}
.pre-pos-card.active::before { opacity: 1; inset: 0 10% auto 10%; box-shadow: 0 0 12px var(--c); }
.pre-pos-card.ready {
  opacity: 0.96; transform: translateY(0) scale(1);
  background: color-mix(in srgb, var(--c) 8%, rgba(255, 255, 255, 0.035));
  border-color: color-mix(in srgb, var(--c) 45%, transparent);
}
.pre-pos-card.ready::before { opacity: 0.85; inset: 0 14% auto 14%; }
.pre-pos-svg { height: 40px; width: auto; max-width: 100%; direction: ltr; }
.pre-pos-card .p { transition: transform 0.45s var(--ease), filter 0.45s; }
.pre-pos-card.active .p1 { transform: translateX(4px); }
.pre-pos-card.active .p2 { transform: translateX(9px); filter: drop-shadow(0 0 8px var(--c)); }
.pre-pos-card.active .p3 { transform: translateX(6px); }
.pre-pos-st {
  display: inline-flex; align-items: center; gap: 6px; font-family: var(--f-mono);
  font-size: 10px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted);
  transition: color 0.35s;
}
.pre-pos-st i { width: 6px; height: 6px; border-radius: 50%; background: rgba(255,255,255,0.22); transition: background 0.35s, box-shadow 0.35s; }
.pre-pos-card.active .pre-pos-st { color: #FFFFFF; }
.pre-pos-card.active .pre-pos-st i { background: var(--c); box-shadow: 0 0 10px var(--c); }
.pre-pos-card.ready .pre-pos-st { color: #4ADE80; }
.pre-pos-card.ready .pre-pos-st i { background: #4ADE80; box-shadow: 0 0 8px #4ADE80; }
@media (max-width: 720px) {
  .pre-pos-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
  .pre-pos-svg { height: 34px; }
}
.pre-skip-btn { margin-top: var(--sp-5); min-height: 44px; padding: 8px 18px; border-radius: var(--r-full); border: 1px solid rgba(255, 255, 255, 0.16); color: rgba(255, 255, 255, 0.78); font-size: 12.5px; font-weight: 600; transition: all 0.2s; display: inline-flex; align-items: center; gap: 8px; }
.pre-skip-btn:hover { background: rgba(255, 255, 255, 0.08); color: #FFFFFF; border-color: var(--ochre); }

[data-reveal] { opacity: 0; transform: translateY(30px); transition: opacity 0.8s var(--ease), transform 0.8s var(--ease); transition-delay: var(--d, 0s); }
[data-reveal].in { opacity: 1; transform: none; }

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation-duration: 0.01ms !important; animation-iteration-count: 1 !important; transition-duration: 0.01ms !important; scroll-behavior: auto !important; }
  .preloader { display: none !important; } [data-reveal] { opacity: 1 !important; transform: none !important; } .item-line { opacity: 1 !important; }
}
</style>
</head>
<body>

<!-- PRELOADER -->
<div class="preloader" id="preloader" role="status" aria-live="polite" aria-label="Chargement de Full-Tek POS">
  <div class="pre-bg-grid" aria-hidden="true"></div>
  <div class="pre-aura" aria-hidden="true"></div>
  <div class="pre-orbit" aria-hidden="true"></div>
  <div class="pre-content">
    <div class="pre-logo-wrap" id="pre-logo-wrap">
      <svg class="pre-logo-svg" viewBox="0 0 460 110" fill="none" xmlns="http://www.w3.org/2000/svg" aria-label="Logo Full-Tek" dir="ltr">
        <defs>
          <linearGradient id="pg_p1" x1="10" y1="20" x2="88" y2="36" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="100%" stop-color="#CBD5E1"/></linearGradient>
          <linearGradient id="pg_p2" x1="10" y1="46" x2="62" y2="62" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FDE3A7"/><stop offset="60%" stop-color="#E9A23B"/><stop offset="100%" stop-color="#D97706"/></linearGradient>
          <linearGradient id="pg_p3" x1="10" y1="72" x2="40" y2="88" gradientUnits="userSpaceOnUse"><stop offset="0%" stop-color="#FFFFFF"/><stop offset="100%" stop-color="#94A3B8"/></linearGradient>
          <filter id="goldGlow" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="5" result="blur"/><feComposite in="SourceGraphic" in2="blur" operator="over"/></filter>
        </defs>
        <rect class="pre-p1" x="12" y="20" width="76" height="16" rx="8" fill="url(#pg_p1)"/>
        <rect class="pre-p2" x="12" y="46" width="50" height="16" rx="8" fill="url(#pg_p2)" filter="url(#goldGlow)"/>
        <rect class="pre-p3" x="12" y="72" width="28" height="16" rx="8" fill="url(#pg_p3)"/>
        <g class="pre-word-full"><text x="116" y="60" font-family="'Plus Jakarta Sans', sans-serif" font-size="46" font-weight="800" fill="#FFFFFF" letter-spacing="-1">Full<tspan fill="#E9A23B">·</tspan></text></g>
        <g class="pre-word-tek"><text x="216" y="60" font-family="'Plus Jakarta Sans', sans-serif" font-size="46" font-weight="800" fill="#FFFFFF" letter-spacing="-1">Tek</text></g>
        <g class="pre-word-sub"><text x="118" y="86" font-family="'Plus Jakarta Sans', sans-serif" font-size="12" font-weight="700" fill="#E9A23B" letter-spacing="6">SUITE POS · MAURITANIE</text></g>
      </svg>
    </div>
    <div class="pre-bar-shell" aria-hidden="true"><div class="pre-bar-fill" id="pre-bar-fill"></div></div>
    <div class="pre-status-row"><span class="pre-msg" id="pre-msg" data-i="pre_init">Initialisation du noyau POS...</span><span class="pre-percent" id="pre-percent" dir="ltr">0%</span></div>
    <div class="pre-pos-grid" aria-hidden="true">
      <div class="pre-pos-card" style="--c:var(--resto)" data-at="2" data-next="26">__PRE_RESTO__<span class="pre-pos-st"><i></i><span class="pre-pos-st-lbl">POS Resto</span></span></div>
      <div class="pre-pos-card" style="--c:var(--market)" data-at="26" data-next="52">__PRE_MARKET__<span class="pre-pos-st"><i></i><span class="pre-pos-st-lbl">POS Market</span></span></div>
      <div class="pre-pos-card" style="--c:var(--pharma)" data-at="52" data-next="76">__PRE_PHARMA__<span class="pre-pos-st"><i></i><span class="pre-pos-st-lbl">POS Pharma</span></span></div>
      <div class="pre-pos-card" style="--c:var(--boss)" data-at="76" data-next="96">__PRE_BOSS__<span class="pre-pos-st"><i></i><span class="pre-pos-st-lbl">Boss App</span></span></div>
    </div>
    <button type="button" class="pre-skip-btn" id="pre-skip-btn" aria-label="Passer l'animation de démarrage"><span data-i="pre_skip">Passer l'introduction</span><svg width="12" height="12" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" aria-hidden="true"><path d="M4 2.5l6 5.5-6 5.5"/></svg></button>
  </div>
</div>

<!-- BARRE DE NAVIGATION -->
<header class="nav" id="nav">
 <div class="wrap nav__in">
  <a class="nav__logo" href="#top" aria-label="Full-Tek accueil"><img src="__L__logo_principal_sombre.svg" alt="Full·Tek Suite POS"></a>
  <nav class="nav__links" aria-label="Navigation principale">
   <div class="has-dd">
    <button class="dd" type="button" aria-haspopup="true" aria-expanded="false">
      <span data-i="n_sol">Solutions</span><svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M2.5 4.5 6 8l3.5-3.5"/></svg>
    </button>
    <div class="dd-menu">
     <a href="#resto" style="--c:var(--resto)"><span class="emblem-badge">__MINI_RESTO__</span><div><b>Full·Tek Resto</b><span data-i="m_resto">Restaurants, cafés, salons Khaima VIP</span></div></a>
     <a href="#market" style="--c:var(--market)"><span class="emblem-badge">__MINI_MARKET__</span><div><b>Full·Tek Market</b><span data-i="m_market">Supermarchés, balances, carnet Karni</span></div></a>
     <a href="#pharma" style="--c:var(--pharma)"><span class="emblem-badge">__MINI_PHARMA__</span><div><b>Full·Tek Pharma</b><span data-i="m_pharma">Pharmacies, lots FEFO &amp; CNAM</span></div></a>
     <a href="#boss" style="--c:var(--boss)"><span class="emblem-badge">__MINI_BOSS__</span><div><b>Full·Tek Boss</b><span data-i="m_boss">App Mobile (iOS &amp; Android)</span></div></a>
    </div>
   </div>
   <a href="#offline" data-i="n_off">Sans Internet</a>
   <a href="#tarifs" data-i="n_price">Tarifs</a>
   <a href="#contact" data-i="n_contact">Contact</a>
  </nav>

  <div class="nav__act">
   <a class="nav-wa-chip" href="https://wa.me/22242744242" target="_blank" rel="noopener" aria-label="Contacter M. Taha sur WhatsApp au 42 74 42 42">
     <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.04 2c-5.46 0-9.91 4.45-9.91 9.91 0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.816 9.816 0 0 0 12.04 2z"/></svg>
     <span dir="ltr">42 74 42 42</span>
   </a>
   <div class="lang" role="group" aria-label="Sélecteur de langue">
     <button type="button" data-lang="fr" aria-pressed="true">FR</button><button type="button" data-lang="ar" aria-pressed="false">العربية</button><button type="button" data-lang="en" aria-pressed="false">EN</button>
   </div>
   <button class="btn btn--ghost btn--sm" type="button" data-open-access data-i="n_login">Se connecter</button>
   <a class="btn btn--ochre btn--sm" href="#contact" data-i="n_trial">Essai gratuit</a>
  </div>
  <button class="burger" id="burger" type="button" aria-label="Ouvrir le menu" aria-expanded="false"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg></button>
 </div>
</header>

<main id="top">
<!-- HERO -->
<section class="hero">
 <div class="orb orb--1" aria-hidden="true"></div><div class="orb orb--2" aria-hidden="true"></div><div class="orb orb--3" aria-hidden="true"></div><div class="grid-bg" aria-hidden="true"></div>
 <div class="wrap hero__in">
  <div>
   <div class="badge-hero"><i></i><span data-i="badge">Fonctionne même sans Internet</span></div>
   <h1 data-i="h1">La caisse qui <em>ne s'arrête jamais</em>, pour votre commerce.</h1>
   <p class="lead" data-i="lead">Restaurant, supermarché ou pharmacie en Mauritanie : encaissez en un éclair, acceptez Bankily, Masrivi, Sedad ou Karni, et pilotez vos boutiques en direct.</p>
   <div class="hero__cta">
    <a class="btn btn--ochre" href="#contact"><span data-i="cta1">Essai gratuit 15 jours</span><svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></a>
    <a class="btn btn--ghost" href="#solutions" data-i="cta2">Choisir ma solution</a>
   </div>
   <div class="hero__facts">
    <div><b data-i="f1_n">0,08 s</b><span data-i="f1">par article scanné</span></div>
    <div><b data-i="f2_n">100 %</b><span data-i="f2">ventes sans coupure</span></div>
    <div><b data-i="f3_n">15 j</b><span data-i="f3">d'essai offert</span></div>
   </div>
  </div>
  <div class="stage" aria-hidden="true">
   <div class="card-fx offline-pill-top"><i></i> <span data-i="h_lan">Réseau LAN actif · zéro coupure</span></div>
   <div class="card-fx pos-box">
    <h4><span data-i="h_tbl">Khaima VIP-02 · Nouakchott</span> <span class="tag-live"><i></i><span data-i="h_online">EN LIGNE</span></span></h4>
    <div class="item-line"><span style="display:inline-flex;align-items:center;gap:10px"><img src="assets/products/resto_mechoui.jpg" alt="" style="width:32px;height:32px;border-radius:7px;object-fit:cover"><span data-i="h_it1">1/2 Agneau Méchoui</span></span><b><span dir="ltr">2 800</span> <span data-i="cur">MRU</span></b></div>
    <div class="item-line"><span style="display:inline-flex;align-items:center;gap:10px"><img src="assets/products/resto_atay.jpg" alt="" style="width:32px;height:32px;border-radius:7px;object-fit:cover"><span data-i="h_it2">Thé Atay 3 Services</span></span><b><span dir="ltr">150</span> <span data-i="cur">MRU</span></b></div>
    <div class="item-line"><span style="display:inline-flex;align-items:center;gap:10px"><img src="assets/products/resto_dattes.jpg" alt="" style="width:32px;height:32px;border-radius:7px;object-fit:cover"><span data-i="h_it3">Plateau Dattes Atar</span></span><b><span dir="ltr">250</span> <span data-i="cur">MRU</span></b></div>
    <div class="tot-line"><small data-i="h_tot">TOTAL À PAYER</small><span class="tot-line-val"><span dir="ltr">3 200</span> <span data-i="cur">MRU</span></span></div>
    <div class="pay-btn-fake"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg><span data-i="h_pay">Encaisser · Bankily / Masrivi</span></div>
   </div>
   <div class="card-fx bank-card"><div class="ok-icon"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7"/></svg></div><div><b data-i="h_bok">Bankily confirmé</b><span style="font-size:13px;color:var(--muted)" data-i="h_bref">Réf. ••4821 · 3 200 MRU</span></div></div>
   <div class="card-fx phone-card"><small data-i="h_boss">BOSS MOBILE</small><b dir="ltr">486 900</b><div class="phone-bars"><i></i><i></i><i></i><i></i><i></i></div></div>
  </div>
 </div>
</section>

<!-- PORTAIL DES 4 SOLUTIONS -->
<section class="portal" id="solutions">
 <div class="wrap">
  <div class="portal__grid">
   <a class="gate" href="#resto" style="--c:var(--resto)" data-reveal>
    <div class="gate__logo">__LOGO_RESTO__</div>
    <h3 data-i="gt_resto">Restaurants &amp; cafés</h3>
    <p data-i="g_resto">Salons Khaima VIP, commandes sur tablette, écran cuisine KDS et addition partagée.</p>
    <div class="gate__go"><b data-i="discover">Tester Resto en direct</b><span><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></span></div>
   </a>
   <a class="gate" href="#market" style="--c:var(--market);--d:.1s" data-reveal>
    <div class="gate__logo">__LOGO_MARKET__</div>
    <h3 data-i="gt_market">Supermarchés &amp; épiceries</h3>
    <p data-i="g_market">Balances connectées, scan rapide, prix Détail / Demi-gros et Carnet de crédit Karni.</p>
    <div class="gate__go"><b data-i="discover2">Tester Market en direct</b><span><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></span></div>
   </a>
   <a class="gate" href="#pharma" style="--c:var(--pharma);--d:.2s" data-reveal>
    <div class="gate__logo">__LOGO_PHARMA__</div>
    <h3 data-i="gt_pharma">Pharmacies &amp; dépôts</h3>
    <p data-i="g_pharma">Lots FEFO, blocage automatique des produits périmés et prise en charge CNAM.</p>
    <div class="gate__go"><b data-i="discover3">Tester Pharma en direct</b><span><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></span></div>
   </a>
   <a class="gate" href="#boss" style="--c:var(--boss);--d:.3s" data-reveal>
    <div class="gate__logo">__LOGO_BOSS__</div>
    <h3 data-i="gt_boss">App Mobile Gérant</h3>
    <p data-i="g_boss">Votre commerce en poche : ventes par boutique, alertes anti-fraude et clôture Z à distance.</p>
    <div class="gate__go"><b data-i="discover4">Tester l'App Boss</b><span><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></span></div>
   </a>
  </div>
 </div>
</section>

<!-- BANDEAU CONFIANCE -->
<div class="strip" aria-label="Moyens de paiement et matériel compatibles">
 <div class="marq-wrap">
  <div class="marq">
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg><b data-i="st_bk" style="font-weight:inherit">Bankily</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg><b data-i="st_ms" style="font-weight:inherit">Masrivi</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="m10 15 5-3-5-3v6Z"/></svg><b data-i="st_sd" style="font-weight:inherit">Sedad</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/></svg><b data-i="st_kr" style="font-weight:inherit">Carnet Karni</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14" rx="1"/></svg><b data-i="st_pr" style="font-weight:inherit">Imprimante 80 mm FR/AR</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 5v14M8 5v14M12 5v14M17 5v14M21 5v14"/></svg><b data-i="st_sc" style="font-weight:inherit">Douchette EAN-13</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="M7 21h10"/><path d="M12 3v18"/><path d="M3 7h18"/></svg><b data-i="st_bl" style="font-weight:inherit">Balance COM1</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg><b data-i="st_cn" style="font-weight:inherit">CNAM Officine</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg><b data-i="st_bk" style="font-weight:inherit">Bankily</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/></svg><b data-i="st_ms" style="font-weight:inherit">Masrivi</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="m10 15 5-3-5-3v6Z"/></svg><b data-i="st_sd" style="font-weight:inherit">Sedad</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/></svg><b data-i="st_kr" style="font-weight:inherit">Carnet Karni</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9V2h12v7M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect width="12" height="8" x="6" y="14" rx="1"/></svg><b data-i="st_pr" style="font-weight:inherit">Imprimante 80 mm FR/AR</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 5v14M8 5v14M12 5v14M17 5v14M21 5v14"/></svg><b data-i="st_sc" style="font-weight:inherit">Douchette EAN-13</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m16 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="m2 16 3-8 3 8c-.87.65-1.92 1-3 1s-2.13-.35-3-1Z"/><path d="M7 21h10"/><path d="M12 3v18"/><path d="M3 7h18"/></svg><b data-i="st_bl" style="font-weight:inherit">Balance COM1</b></span>
   <span><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg><b data-i="st_cn" style="font-weight:inherit">CNAM Officine</b></span>
  </div>
 </div>
</div>

<!-- ========================================================================
     1. FULL-TEK RESTO : SIMULATEUR CAISSE TACTILE + KHAIMA VIP + KDS RÉEL
     ======================================================================== -->
<section class="sol" id="resto" style="--c:var(--resto)">
 <div class="wrap sol__in">
  <div class="sol__txt" data-reveal>
   <div class="sol__logo-glass">__LOGO_RESTO__</div>
   <div class="sol__tag"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 8h1a4 4 0 0 1 0 8h-1M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8zM6 1v3M10 1v3M14 1v3"/></svg> <span data-i="tag_resto">RESTAURANTS, MÉCHOUIS &amp; SALONS KHAIMA VIP</span></div>
   <h2 data-i="r_h">Servez plus vite, encaissez sans erreur.</h2>
   <p class="sub" data-i="r_p">Du salon Khaima VIP à la terrasse : prenez la commande bilingue FR/AR sur tablette, envoyez en cuisine KDS et encaissez via Bankily, Masrivi ou Cash.</p>
   <ul class="benefits">
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="r1">Plan de salle, Terrasses et Salons Khaima VIP (vente au plateau)</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="r2">Écran cuisine KDS avec chronomètre et alerte rupture immédiate</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="r3">Encaissement mixte Cash + Bankily / Masrivi + ticket 80 mm FR/AR</span></li>
   </ul>
   <div class="sol__cta">
    <a class="btn btn--c" href="#contact" data-pick="Full-Tek Resto" data-i="try">Essayer gratuitement</a>
    <button class="btn btn--ghost" type="button" data-open-access data-i="n_login">Se connecter</button>
   </div>
  </div>

  <!-- TERMINAL POS INTERACTIF RESTO AVEC PHOTOS RÉELLES -->
  <div class="pos-screen" data-reveal style="--d:.15s" aria-label="Démonstration interactive Full-Tek Resto">
   <div class="pos-topbar">
    <div class="pos-brand-mini">__MINI_RESTO__<div><span data-i="pr_brand">Dar El-Karam · دار الكرم</span><small data-i="pr_sub">Tevragh Zeina &middot; Serveur : Ahmed &middot; Imprimante 80mm PRÊTE</small></div></div>
    <div class="pos-tabs" role="tablist">
     <button type="button" class="pos-tab-btn" role="tab" data-rtab="r-pos" aria-selected="true" data-i="pr_t1">Caisse Tactile</button>
     <button type="button" class="pos-tab-btn" role="tab" data-rtab="r-salle" aria-selected="false" data-i="pr_t2">Khaima VIP (4)</button>
     <button type="button" class="pos-tab-btn" role="tab" data-rtab="r-kds" aria-selected="false" data-i="pr_t3">Cuisine KDS (3)</button>
    </div>
   </div>

   <div class="pos-toolbar">
    <div class="pos-search-fake"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg><span data-i="pr_srch">Rechercher un plat FR / العربية...</span></div>
    <div class="pos-cats" role="group" aria-label="Catégories Resto">
     <button type="button" class="pos-cat-pill" data-rcat="all" aria-pressed="true" data-i="pr_c0">Tous (6)</button>
     <button type="button" class="pos-cat-pill" data-rcat="plat" aria-pressed="false" data-i="pr_c1">Méchouis &amp; Plats</button>
     <button type="button" class="pos-cat-pill" data-rcat="boisson" aria-pressed="false" data-i="pr_c2">Atay &amp; Douceurs</button>
    </div>
   </div>

   <!-- Vue 1 : Caisse Tactile + Ticket Direct -->
   <div class="pos-split active" id="r-pos">
    <div class="pos-catalog">
     <div class="pos-items-grid">
      <button type="button" class="pos-item-btn" data-rcat-item="plat" data-add-resto="1/2 Agneau Méchoui" data-price="2800" data-img="assets/products/resto_mechoui.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_mechoui.jpg" alt="1/2 Agneau Méchoui" loading="lazy"><span class="pos-card-badge" data-i="rb_1">PLAT STAR</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_1">1/2 Agneau Méchoui</b><span class="ar-sub" data-i="rs_1">مشوي نصف خروف</span><span class="pr-tag" data-p="2800">2 800 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-rcat-item="plat" data-add-resto="Thiéboudienne Royal" data-price="450" data-img="assets/products/resto_thieb.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_thieb.jpg" alt="Thiéboudienne Royal" loading="lazy"><span class="pos-card-badge" data-i="rb_2">TRADITION</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_2">Thiéboudienne Royal</b><span class="ar-sub" data-i="rs_2">تيبودين ملكي</span><span class="pr-tag" data-p="450">450 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-rcat-item="plat" data-add-resto="Brochettes Chameau" data-price="520" data-img="assets/products/resto_brochettes.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_brochettes.jpg" alt="Brochettes Chameau" loading="lazy"><span class="pos-card-badge" data-i="rb_3">GRILLADE</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_3">Brochettes Chameau</b><span class="ar-sub" data-i="rs_3">مشوي لحم الإبل</span><span class="pr-tag" data-p="520">520 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-rcat-item="boisson" data-add-resto="Thé Atay 3 Services" data-price="150" data-img="assets/products/resto_atay.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_atay.jpg" alt="Thé Atay 3 Services" loading="lazy"><span class="pos-card-badge" data-i="rb_4">KHAIMA VIP</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_4">Thé Atay 3 Services</b><span class="ar-sub" data-i="rs_4">أتاي موريتاني</span><span class="pr-tag" data-p="150">150 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-rcat-item="boisson" data-add-resto="Lait Chamelle Frais" data-price="120" data-img="assets/products/resto_lait.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_lait.jpg" alt="Lait Chamelle Frais" loading="lazy"><span class="pos-card-badge" data-i="rb_5">100% FRAIS</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_5">Lait Chamelle Frais</b><span class="ar-sub" data-i="rs_5">لبن الإبل الطازج</span><span class="pr-tag" data-p="120">120 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-rcat-item="boisson" data-add-resto="Dattes Atar & Bissap" data-price="250" data-img="assets/products/resto_dattes.jpg">
        <div class="pos-card-media"><img src="assets/products/resto_dattes.jpg" alt="Dattes Atar &amp; Bissap" loading="lazy"><span class="pos-card-badge" data-i="rb_6">ATAR BIO</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="rn_6">Dattes Atar &amp; Bissap</b><span class="ar-sub" data-i="rs_6">تمر أطار و كركديه</span><span class="pr-tag" data-p="250">250 MRU</span></div>
      </button>
     </div>
    </div>

    <div class="pos-ticket-col">
     <div class="tk-head">
      <div><b id="r-tbl-name" data-i="rk_2h">Salon Khaima VIP-02</b><small data-i="pr_tk_sub">6 couverts &middot; Ticket #104 &middot; FR / العربية</small></div>
      <span class="pos-live-pill"><i></i><span data-i="pos_act">ACTIF</span></span>
     </div>
     <div class="tk-list" id="r-tk-list"></div>
     <div class="tk-total"><small data-i="pos_ttc">TOTAL TTC</small><span id="r-total"><span dir="ltr">3 200</span> <span data-i="cur">MRU</span></span></div>
     <div class="tk-pay-methods" role="group" aria-label="Mode de paiement">
      <button type="button" class="tk-pm" data-rpm="Bankily" aria-pressed="true" data-i="pm_bk">Bankily</button>
      <button type="button" class="tk-pm" data-rpm="Masrivi" aria-pressed="false" data-i="pm_ms">Masrivi</button>
      <button type="button" class="tk-pm" data-rpm="Sedad" aria-pressed="false" data-i="pm_sd">Sedad</button>
      <button type="button" class="tk-pm" data-rpm="Cash MRU" aria-pressed="false" data-i="pm_cs">Cash</button>
     </div>
     <button type="button" class="tk-checkout-btn" id="r-pay-btn" data-i="pr_pay">Encaisser &amp; Ticket 80mm</button>
     <div class="tk-feedback" id="r-fb" aria-live="polite"></div>
    </div>
   </div>

   <!-- Vue 2 : Plan de salle Khaima VIP -->
   <div class="pos-subview" id="r-salle">
    <div class="khaima-grid">
     <button type="button" class="khaima-card" data-pick-tbl="rk_1h"><div><b data-i="rk_1h">Salon Khaima VIP-01</b><small data-i="rk_1s">Libre &middot; 8 places &middot; Tapis Mauritanien</small></div><span class="khaima-st" style="background:rgba(46,158,91,.2);color:#4ADE80" data-i="rk_st1">LIBRE</span></button>
     <button type="button" class="khaima-card" data-pick-tbl="rk_2h"><div><b data-i="rk_2h">Salon Khaima VIP-02</b><small data-i="rk_2s">Occupée &middot; 3 200 MRU &middot; 6 couverts</small></div><span class="khaima-st" style="background:rgba(228,87,46,.25);color:#FCA5A5" data-i="rk_st2">OCCUPÉE</span></button>
     <button type="button" class="khaima-card" data-pick-tbl="rk_3h"><div><b data-i="rk_3h">Terrasse T-04</b><small data-i="rk_3s">Addition demandée &middot; 950 MRU</small></div><span class="khaima-st" style="background:rgba(233,162,59,.25);color:#FDE3A7" data-i="rk_st3">ADDITION</span></button>
     <button type="button" class="khaima-card" data-pick-tbl="rk_4h"><div><b data-i="rk_4h">Livraison Ksar #43</b><small data-i="rk_4s">Moto en route &middot; 1 400 MRU</small></div><span class="khaima-st" style="background:rgba(27,143,217,.25);color:#BAE6FD" data-i="rk_st4">MOTO</span></button>
    </div>
   </div>

   <!-- Vue 3 : Écran Cuisine KDS -->
   <div class="pos-subview" id="r-kds">
    <div class="kds-grid">
     <div class="kds-card"><div class="kds-header" style="background:#DC2626"><span data-i="kds_h1">#104 · VIP-02</span> <span dir="ltr">14:20</span></div><p data-i="kds_1">1× 1/2 Agneau Méchoui<br>2× Thé Atay<br><span style="color:#FBBF24;font-weight:700">Sans oignon</span></p><button type="button" class="kds-ready-btn" data-kds-btn data-i="kds_ready">Marquer Prêt</button></div>
     <div class="kds-card"><div class="kds-header" style="background:#D97706"><span data-i="kds_h2">#105 · Ksar</span> <span dir="ltr">08:45</span></div><p data-i="kds_2">2× Chawarma viande<br>2× Jus Bissap frais</p><button type="button" class="kds-ready-btn" data-kds-btn data-i="kds_ready">Marquer Prêt</button></div>
     <div class="kds-card"><div class="kds-header" style="background:#16A34A"><span data-i="kds_h3">#108 · T-04</span> <span dir="ltr">03:12</span></div><p data-i="kds_3">1× Thiéboudienne Royal<br>1× Lait Chamelle</p><button type="button" class="kds-ready-btn" data-kds-btn data-i="kds_ready">Marquer Prêt</button></div>
    </div>
   </div>
  </div>
 </div>
</section>

<!-- ========================================================================
     2. FULL-TEK MARKET : BALANCE COM1, GROS/DÉTAIL & CARNET KARNI INTERACTIF
     ======================================================================== -->
<section class="sol flip" id="market" style="--c:var(--market)">
 <div class="wrap sol__in">
  <div class="sol__txt" data-reveal>
   <div class="sol__logo-glass">__LOGO_MARKET__</div>
   <div class="sol__tag"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57l1.65-7.43H5.12"/></svg> <span data-i="tag_market">SUPERMARCHÉS, BOUCHERIES &amp; GROS</span></div>
   <h2 data-i="m_h">Une file d'attente qui avance vite.</h2>
   <p class="sub" data-i="m_p">Scannez en 0,08 s, lisez directement le poids de la balance électronique, basculez Détail / Demi-gros et gérez votre Carnet de crédit client (Karni) sans papier.</p>
   <ul class="benefits">
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="mk1">Balance Poids-Prix connectée en direct (viande, dattes, fruits)</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="mk2">Bascule instantanée Prix Détail / Prix Demi-Gros sur chaque produit</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="mk3">Carnet de crédit numérique (Karni) avec plafond client et relance</span></li>
   </ul>
   <div class="sol__cta">
    <a class="btn btn--c" href="#contact" data-pick="Full-Tek Market" data-i="try">Essayer gratuitement</a>
    <button class="btn btn--ghost" type="button" data-open-access data-i="n_login">Se connecter</button>
   </div>
  </div>

  <!-- TERMINAL POS INTERACTIF MARKET AVEC PHOTOS RÉELLES -->
  <div class="pos-screen" data-reveal style="--d:.15s" aria-label="Démonstration interactive Full-Tek Market">
   <div class="pos-topbar">
    <div class="pos-brand-mini">__MINI_MARKET__<div><span data-i="pm_brand">Al-Baraka Market</span> &middot; <span data-i="pm_pos">Caisse #01</span><small data-i="pm_sub">سوبرماركت البركة &middot; Scanner EAN-13 &amp; Balance COM1</small></div></div>
    <div class="pos-tabs" role="group" aria-label="Grille tarifaire">
     <button type="button" class="pos-tab-btn" id="m-btn-detail" aria-pressed="true" data-i="pm_t1">Tarif Détail</button>
     <button type="button" class="pos-tab-btn" id="m-btn-gros" aria-pressed="false" data-i="pm_t2">Tarif Demi-Gros</button>
    </div>
   </div>

   <div class="pos-hw-bar">
    <span data-i="pm_hw1">BALANCE COM1 : 1,450 kg &times; 380 MRU = 551 MRU</span>
    <span style="color:#4ADE80" data-i="pm_hw2">DOUCHETTE EAN-13 PRÊTE</span>
   </div>

   <div class="pos-toolbar">
    <div class="pos-search-fake"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M3 5v14M8 5v14M12 5v14M17 5v14M21 5v14"/></svg><span data-i="pm_srch">Code-barres EAN-13 ou nom d'article...</span></div>
    <div class="pos-cats" role="group" aria-label="Rayons Supermarché">
     <button type="button" class="pos-cat-pill" data-mcat="all" aria-pressed="true" data-i="pm_c0">Tous (6)</button>
     <button type="button" class="pos-cat-pill" data-mcat="frais" aria-pressed="false" data-i="pm_c1">Boucherie &amp; Lait</button>
     <button type="button" class="pos-cat-pill" data-mcat="epicerie" aria-pressed="false" data-i="pm_c2">Gros &amp; Boissons</button>
    </div>
   </div>

   <div class="pos-split active">
    <div class="pos-catalog">
     <div class="pos-items-grid">
      <button type="button" class="pos-item-btn" data-mcat-item="frais" data-madd="Viande Hachée (1,45kg)" data-d="551" data-g="510" data-img="assets/products/market_viande.jpg">
        <div class="pos-card-media"><img src="assets/products/market_viande.jpg" alt="Viande Hachée 1,45kg" loading="lazy"><span class="pos-card-badge" style="background:rgba(46,158,91,.88)" data-i="mb_1">PESÉE 1,45 KG</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_1">Viande Hachée 1,45kg</b><span class="ar-sub" data-i="ms_1">لحم مفروم (ميزان)</span><span class="pr-tag m-price">551 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-mcat-item="epicerie" data-madd="Sac Riz Basmati 25 kg" data-d="980" data-g="910" data-img="assets/products/market_riz.jpg">
        <div class="pos-card-media"><img src="assets/products/market_riz.jpg" alt="Riz Basmati 25 kg" loading="lazy"><span class="pos-card-badge" data-i="mb_2">SAC 25 KG</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_2">Riz Basmati 25 kg</b><span class="ar-sub" data-i="ms_2">أرز بسمتي ٢٥ كغ</span><span class="pr-tag m-price">980 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-mcat-item="epicerie" data-madd="Huile Végétale 5 L" data-d="440" data-g="415" data-img="assets/products/market_huile.jpg">
        <div class="pos-card-media"><img src="assets/products/market_huile.jpg" alt="Huile Végétale 5 L" loading="lazy"><span class="pos-card-badge" data-i="mb_3">BIDON 5 L</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_3">Huile Végétale 5 L</b><span class="ar-sub" data-i="ms_3">زيت نباتي ٥ لتر</span><span class="pr-tag m-price">440 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-mcat-item="frais" data-madd="Lait Nido Poudre 900g" data-d="380" data-g="355" data-img="assets/products/market_lait_poudre.jpg">
        <div class="pos-card-media"><img src="assets/products/market_lait_poudre.jpg" alt="Lait Nido 900 g" loading="lazy"><span class="pos-card-badge" data-i="mb_4">BOÎTE 900G</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_4">Lait Nido 900 g</b><span class="ar-sub" data-i="ms_4">حليب نيدو ٩٠٠غ</span><span class="pr-tag m-price">380 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-mcat-item="epicerie" data-madd="Pack Eau Benichab x6" data-d="110" data-g="95" data-img="assets/products/market_eau.jpg">
        <div class="pos-card-media"><img src="assets/products/market_eau.jpg" alt="Pack Benichab x6" loading="lazy"><span class="pos-card-badge" data-i="mb_5">PACK ×6</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_5">Pack Benichab x6</b><span class="ar-sub" data-i="ms_5">مياه بنشاب ×٦</span><span class="pr-tag m-price">110 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-mcat-item="epicerie" data-madd="Thé Achoura 500g" data-d="180" data-g="160" data-img="assets/products/market_the.jpg">
        <div class="pos-card-media"><img src="assets/products/market_the.jpg" alt="Thé Achoura 500g" loading="lazy"><span class="pos-card-badge" data-i="mb_6">TOP VENTE</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="mn_6">Thé Achoura 500g</b><span class="ar-sub" data-i="ms_6">شاي عشورة ٥٠٠غ</span><span class="pr-tag m-price">180 MRU</span></div>
      </button>
     </div>
    </div>

    <div class="pos-ticket-col">
     <div class="tk-head">
      <div><b data-i="pm_tk_h">Panier Caisse #01</b><small data-i="pm_tk_sub">Client Karni : Ould Sidi (Plafond 50 000 MRU)</small></div>
      <span class="pos-live-pill"><i></i><span data-i="pm_karni_ok">KARNI OK</span></span>
     </div>
     <div class="tk-list" id="m-tk-list"></div>
     <div class="tk-total"><small data-i="pm_net">NET À PAYER</small><span id="m-total"><span dir="ltr">1 531</span> <span data-i="cur">MRU</span></span></div>
     <div class="tk-pay-methods">
      <button type="button" class="tk-pm" data-mpm="Cash MRU" aria-pressed="true" data-i="pm_cs">Cash</button>
      <button type="button" class="tk-pm" data-mpm="Bankily" aria-pressed="false" data-i="pm_bk">Bankily</button>
      <button type="button" class="tk-pm" data-mpm="Masrivi" aria-pressed="false" data-i="pm_ms">Masrivi</button>
      <button type="button" class="tk-pm" data-mpm="Carnet Karni" aria-pressed="false" data-i="pm_kr">Karni</button>
     </div>
     <button type="button" class="tk-checkout-btn" id="m-pay-btn" data-i="pm_pay">Encaisser / Inscrire au Karni</button>
     <div class="tk-feedback" id="m-fb" aria-live="polite"></div>
    </div>
   </div>
  </div>
 </div>
</section>

<!-- ========================================================================
     3. FULL-TEK PHARMA : LOTS FEFO, BLOCAGE PÉRIMÉ & ASSURANCE CNAM
     ======================================================================== -->
<section class="sol" id="pharma" style="--c:var(--pharma)">
 <div class="wrap sol__in">
  <div class="sol__txt" data-reveal>
   <div class="sol__logo-glass">__LOGO_PHARMA__</div>
   <div class="sol__tag"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/></svg> <span data-i="tag_pharma">PHARMACIES, OFFICINES &amp; CNAM MAURITANIE</span></div>
   <h2 data-i="p_h">Aucun médicament périmé ne sort de votre officine.</h2>
   <p class="sub" data-i="p_p">Gestion par lots FEFO (premier expiré, premier sorti) : la caisse verrouille automatiquement toute boîte expirée et calcule la part prise en charge par la CNAM.</p>
   <ul class="benefits">
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="p1">Blocage instantané en caisse des lots expirés (Sécurité Patient)</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="p2">Prise en charge CNAM &amp; mutuelles avec calcul automatique de la part patient</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="p3">Alertes 90/30/7 jours, équivalents génériques et suivi chaîne du froid (+4°C)</span></li>
   </ul>
   <div class="sol__cta">
    <a class="btn btn--c" href="#contact" data-pick="Full-Tek Pharma" data-i="try">Essayer gratuitement</a>
    <button class="btn btn--ghost" type="button" data-open-access data-i="n_login">Se connecter</button>
   </div>
  </div>

  <!-- TERMINAL POS INTERACTIF PHARMA AVEC PHOTOS RÉELLES -->
  <div class="pos-screen" data-reveal style="--d:.15s" aria-label="Démonstration interactive Full-Tek Pharma">
   <div class="pos-topbar">
    <div class="pos-brand-mini">__MINI_PHARMA__<div><span data-i="pp_brand">Pharmacie Chinguetti · صيدلية شنقيط</span><small data-i="pp_sub">Règle FEFO Active &middot; Frigo +4,2 °C &middot; Tiers-Payant CNAM</small></div></div>
    <span class="pos-live-pill"><i></i><span data-i="pp_ctrl">CONTRÔLE LOTS ACTIF</span></span>
   </div>

   <div class="pharma-alert-bar" id="p-banner">
    <span data-i="pp_ban">Cliquez sur « Augmentin 1g · PÉRIMÉ » ci-dessous pour tester le blocage sécurité FEFO.</span>
   </div>

   <div class="pos-toolbar">
    <div class="pos-search-fake"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg><span data-i="pp_srch">DCI, nom commercial ou scan boîte...</span></div>
    <div class="pos-cats" role="group" aria-label="Familles Pharmacie">
     <button type="button" class="pos-cat-pill" data-pcat="all" aria-pressed="true" data-i="pp_c0">Tous (6)</button>
     <button type="button" class="pos-cat-pill" data-pcat="ordo" aria-pressed="false" data-i="pp_c1">Antibiotiques &amp; Frigo</button>
     <button type="button" class="pos-cat-pill" data-pcat="conseil" aria-pressed="false" data-i="pp_c2">Douleur &amp; Soins</button>
    </div>
   </div>

   <div class="pos-split active">
    <div class="pos-catalog">
     <div class="pos-items-grid">
      <button type="button" class="pos-item-btn" data-pcat-item="ordo" data-padd="Amoxicilline 500mg" data-price="185" data-exp="ok" data-img="assets/products/pharma_amox.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_amox.jpg" alt="Amoxicilline 500mg" loading="lazy"><span class="pos-card-badge" style="background:rgba(46,158,91,.88)" data-i="pb_m1">FEFO OK · 08/27</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="pn_1">Amoxicilline 500mg</b><span class="ar-sub" data-i="ps_1">Lot #A-892 · Gélules</span><span class="pr-tag" data-p="185">185 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-pcat-item="conseil" data-padd="Paracétamol 1 g" data-price="95" data-exp="ok" data-img="assets/products/pharma_para.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_para.jpg" alt="Paracétamol 1 g" loading="lazy"><span class="pos-card-badge" style="background:rgba(217,119,6,.9)" data-i="pb_m2">PRIORITÉ FEFO</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="pn_2">Paracétamol 1 g</b><span class="ar-sub" data-i="ps_2">Lot #P-410 · Exp 12/26</span><span class="pr-tag" data-p="95">95 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn expired" data-pcat-item="ordo" data-padd="Augmentin 1g" data-price="320" data-exp="blocked" data-img="assets/products/pharma_aug.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_aug.jpg" alt="Augmentin 1g Périmé" loading="lazy"><span class="pos-card-badge" style="background:#DC2626" data-i="pb_m3">BLOQUÉ · EXPIRÉ</span><span class="pos-card-plus">!</span></div>
        <div class="pos-card-body"><b data-i="pn_3">Augmentin 1g · PÉRIMÉ</b><span class="ar-sub" data-i="ps_3">Lot #EXP-2024 · Expiré</span><span class="pr-tag" data-i="pp_nosale">VENTE INTERDITE</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-pcat-item="ordo" data-padd="Insuline Lantus" data-price="680" data-exp="ok" data-img="assets/products/pharma_insuline.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_insuline.jpg" alt="Insuline Lantus Frigo" loading="lazy"><span class="pos-card-badge" style="background:rgba(27,143,217,.9)" data-i="pb_m4">FRIGO +4,2 °C</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="pn_4">Insuline Lantus (Frigo)</b><span class="ar-sub" data-i="ps_4">Lot #F-112 · Stylo 100UI</span><span class="pr-tag" data-p="680">680 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-pcat-item="conseil" data-padd="Vitamine C 1000mg" data-price="140" data-exp="ok" data-img="assets/products/pharma_vitc.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_vitc.jpg" alt="Vitamine C 1000mg" loading="lazy"><span class="pos-card-badge" data-i="pb_m5">LOT #V-304 · OK</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="pn_5">Vitamine C 1000mg</b><span class="ar-sub" data-i="ps_5">فيتامين سي فوار</span><span class="pr-tag" data-p="140">140 MRU</span></div>
      </button>
      <button type="button" class="pos-item-btn" data-pcat-item="conseil" data-padd="Sérum Physiologique" data-price="110" data-exp="ok" data-img="assets/products/pharma_serum.jpg">
        <div class="pos-card-media"><img src="assets/products/pharma_serum.jpg" alt="Sérum Physiologique" loading="lazy"><span class="pos-card-badge" data-i="pb_m6">40 UNIDOSES</span><span class="pos-card-plus">+</span></div>
        <div class="pos-card-body"><b data-i="pn_6">Sérum Physiologique</b><span class="ar-sub" data-i="ps_6">مصل فيزيولوجي معقم</span><span class="pr-tag" data-p="110">110 MRU</span></div>
      </button>
     </div>
    </div>

    <div class="pos-ticket-col">
     <div class="tk-head">
      <div><b data-i="pp_tk_h">Ordonnance #409</b><small data-i="pp_tk_sub">Assuré CNAM &middot; Contrôle FEFO actif</small></div>
      <button type="button" class="pos-chip" id="p-cnam-btn" aria-pressed="true" data-i="pp_cnam">CNAM 70%</button>
     </div>
     <div class="tk-list" id="p-tk-list"></div>
     <div class="tk-total"><small id="p-sub-lbl" data-i="p_part">PART PATIENT (30%)</small><span id="p-total"><span dir="ltr">84</span> <span data-i="cur">MRU</span></span></div>
     <div class="tk-pay-methods">
      <button type="button" class="tk-pm" data-ppm="Bankily" aria-pressed="true" data-i="pm_bk">Bankily</button>
      <button type="button" class="tk-pm" data-ppm="Masrivi" aria-pressed="false" data-i="pm_ms">Masrivi</button>
      <button type="button" class="tk-pm" data-ppm="Sedad" aria-pressed="false" data-i="pm_sd">Sedad</button>
      <button type="button" class="tk-pm" data-ppm="Cash MRU" aria-pressed="false" data-i="pm_cs">Cash</button>
     </div>
     <button type="button" class="tk-checkout-btn" id="p-pay-btn" data-i="pp_pay">Délivrer l'ordonnance</button>
     <div class="tk-feedback" id="p-fb" aria-live="polite"></div>
    </div>
   </div>
  </div>
 </div>
</section>

<!-- ========================================================================
     4. SECTION BOSS — APPLICATION MOBILE GÉRANT (iOS, ANDROID & PWA)
     ======================================================================== -->
<section class="sol flip" id="boss" style="--c:var(--boss)">
 <div class="wrap sol__in">
  <div class="sol__txt" data-reveal>
   <div class="sol__logo-glass">__LOGO_BOSS__</div>
   <div class="sol__tag"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><rect width="14" height="20" x="5" y="2" rx="2"/><path d="M12 18h.01"/></svg> <span data-i="tag_boss">APPLICATION MOBILE · iOS &amp; ANDROID</span></div>
   <h2 data-i="b_h">Votre commerce dans votre poche.</h2>
   <p class="sub" data-i="b_p">Pilotage temps réel depuis votre smartphone : voyez ce que chaque boutique encaisse en direct (Nouakchott, Nouadhibou, Atar), recevez des alertes push sur vos remises et validez la clôture Z à distance.</p>
   <ul class="benefits">
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="b1">Tableau de bord mobile multi-boutiques en direct (Bankily, Masrivi, Cash)</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="b2">Notifications push instantanées sur remises, annulations et ouvertures tiroir</span></li>
    <li><svg viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="b3">Validation biométrique / PIN de la clôture Z anti-fraude à distance</span></li>
   </ul>
   <div class="app-badges" aria-label="Compatibilité application mobile">
    <span class="app-badge"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993s-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993s-.4482.9997-.9993.9997m11.4045-6.02 1.9973-3.4592a.416.416 0 0 0-.1521-.5676.416.416 0 0 0-.5676.1521l-2.0223 3.503C15.5902 8.2439 13.8533 7.8508 12 7.8508s-3.5902.3931-5.1367 1.0989L4.841 5.4467a.4161.4161 0 0 0-.5677-.1521.4157.4157 0 0 0-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3432-4.1021-2.6889-7.5743-6.1185-9.4396"/></svg>Android APK</span>
    <span class="app-badge"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11Z"/></svg>iOS iPhone</span>
    <span class="app-badge"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M2 12h20M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>Web App PWA</span>
   </div>
   <div class="sol__cta">
    <a class="btn btn--c" href="#contact" data-pick="Full-Tek Boss (App Mobile)" data-i="try">Essayer gratuitement</a>
    <button class="btn btn--ghost" type="button" data-open-access data-i="n_login">Se connecter</button>
   </div>
  </div>

  <!-- SIMULATEUR APP MOBILE BOSS -->
  <div class="boss-stage" data-reveal style="--d:.15s">
   <div class="boss-aura" aria-hidden="true"></div>
   <div class="boss-push-toast" aria-hidden="true">
    <div class="boss-push-icon"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg></div>
    <div><b data-i="pb_push_h">Full·Tek Boss · Push</b><span data-i="pb_push">Bankily +18 400 MRU &middot; Tevragh Zeina</span></div>
   </div>
   <div class="boss-stores-float" aria-hidden="true">
    <small data-i="pb_net">RÉSEAU 3 BOUTIQUES EN DIRECT</small>
    <div class="boss-st-line"><b data-i="pb_st1">Dar El-Karam Resto</b><span><span dir="ltr">214 500</span> <span data-i="cur">MRU</span></span></div>
    <div class="boss-st-line"><b data-i="pb_st2">Al-Baraka Market</b><span><span dir="ltr">158 200</span> <span data-i="cur">MRU</span></span></div>
    <div class="boss-st-line"><b data-i="pb_st3">Pharma Chinguetti</b><span><span dir="ltr">114 200</span> <span data-i="cur">MRU</span></span></div>
   </div>

   <div class="boss-phone" aria-label="Démonstration interactive de l'application mobile Full-Tek Boss">
    <div class="boss-screen">
     <div class="boss-notch-bar" dir="ltr"><span>14:32</span><div class="boss-island"><i></i></div><span>5G &middot; 98%</span></div>
     <div class="boss-app-top">
      <div class="boss-app-id">__MINI_BOSS__<div><strong>Full·Tek</strong><span data-i="h_boss">BOSS MOBILE</span></div></div>
      <span class="boss-live-chip"><i></i><span data-i="pb_live">EN DIRECT</span></span>
     </div>
     <div class="boss-shops" role="group" aria-label="Filtrer par point de vente">
      <button type="button" class="shop-chip" data-shop="all" aria-pressed="true" data-i="pb_s0">Toutes (3)</button>
      <button type="button" class="shop-chip" data-shop="tz" aria-pressed="false" data-i="pb_s1">Tevragh Zeina</button>
      <button type="button" class="shop-chip" data-shop="ksar" aria-pressed="false" data-i="pb_s2">Ksar</button>
      <button type="button" class="shop-chip" data-shop="ndb" aria-pressed="false" data-i="pb_s3">Nouadhibou</button>
     </div>
     <div class="boss-app-body">
      <div class="boss-pane active" id="bp-overview">
       <div class="boss-hero-kpi">
        <small><span id="b-store-lbl" style="color:#D2DEE2">Chiffre d'affaires · 3 boutiques</span> <span id="b-delta" dir="ltr">+14,2%</span></small>
        <strong id="b-ca"><span dir="ltr">486 900</span> <span data-i="cur">MRU</span></strong>
        <div class="boss-split-bar"><div class="boss-split-bankily" id="b-bar-m" style="width:54%"></div><div class="boss-split-cash"></div></div>
        <div class="boss-split-legend"><span><span data-i="pb_lg_m">Bankily / Masrivi</span> (<span id="b-pm" dir="ltr">54%</span>)</span><span><span data-i="pb_lg_c">Cash MRU</span> (<span id="b-pc" dir="ltr">46%</span>)</span></div>
       </div>
       <div class="boss-mini-grid">
        <div class="boss-mini-card"><small data-i="pb_tk">Tickets émis</small><b id="b-tickets" dir="ltr">312</b></div>
        <div class="boss-mini-card"><small data-i="pb_ec">Écart de caisse</small><b style="color:#4ADE80"><span dir="ltr">0</span> <span data-i="cur">MRU</span></b></div>
       </div>
       <div class="boss-top-items">
        <small><span data-i="pb_top">TOP ARTICLES VENDUS</span><span data-i="pb_tod">AUJOURD'HUI</span></small>
        <div class="boss-top-row"><div><img src="assets/products/resto_mechoui.jpg" alt="Méchoui"><span data-i="pb_it1">1/2 Agneau Méchoui</span></div><b><span dir="ltr">117 600</span> <span data-i="cur">MRU</span></b></div>
        <div class="boss-top-row"><div><img src="assets/products/market_riz.jpg" alt="Riz Basmati"><span data-i="pb_it2">Riz Basmati 25 kg</span></div><b><span dir="ltr">88 200</span> <span data-i="cur">MRU</span></b></div>
       </div>
       <div class="boss-spark">
        <small data-i="pb_hr">Ventes par tranche horaire (08h → 22h)</small>
        <div class="boss-bars" id="b-bars"><i style="height:38%"></i><i style="height:56%"></i><i style="height:75%"></i><i style="height:64%"></i><i style="height:92%"></i><i style="height:82%"></i><i style="height:100%"></i></div>
       </div>
      </div>
      <div class="boss-pane" id="bp-alerts">
       <div class="boss-alert-item"><span class="boss-alert-dot" style="background:#F59E0B"></span><div><strong data-i="pb_a1h">Remise -15% accordée · Caisse 02</strong><span data-i="pb_a1s">Ksar · Caissier Ahmed S. &middot; il y a 4 min</span></div></div>
       <div class="boss-alert-item"><span class="boss-alert-dot" style="background:#EF4444"></span><div><strong data-i="pb_a2h">Ouverture tiroir sans encaissement</strong><span data-i="pb_a2s">Tevragh Zeina · Tiroir B &middot; il y a 18 min</span></div></div>
       <div class="boss-alert-item"><span class="boss-alert-dot" style="background:#1B8FD9"></span><div><strong data-i="pb_a3h">Lot périmé #EXP-2024 bloqué</strong><span data-i="pb_a3s">Pharma Ksar · Sécurité activée &middot; 13:45</span></div></div>
       <div class="boss-alert-item"><span class="boss-alert-dot" style="background:#2E9E5B"></span><div><strong data-i="pb_a4h">Synchronisation LAN → Cloud réussie</strong><span data-i="pb_a4s">Nouadhibou · 48 tickets envoyés &middot; 12:10</span></div></div>
      </div>
      <div class="boss-pane" id="bp-close">
       <div class="boss-z-card">
        <strong style="color:#FFFFFF;font-size:13.5px" data-i="pb_zh">Clôture de caisse du jour</strong>
        <div class="boss-z-row"><span data-i="pb_zr1">Total théorique caisse</span><b><span dir="ltr">223 974</span> <span data-i="cur">MRU</span></b></div>
        <div class="boss-z-row"><span data-i="pb_zr2">Cash compté en tiroir</span><b><span dir="ltr">223 974</span> <span data-i="cur">MRU</span></b></div>
        <div class="boss-z-row"><span data-i="pb_zr3">Bankily / Masrivi vérifiés</span><b><span dir="ltr">262 926</span> <span data-i="cur">MRU</span></b></div>
        <div class="boss-z-row" style="border-top:1px solid var(--line);padding-top:6px"><span data-i="pb_zr4">Écart constaté</span><b style="color:#4ADE80" data-i="pb_z0">0 MRU (Parfait)</b></div>
        <button type="button" class="boss-z-btn" id="btn-z-approve"><svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span id="btn-z-txt" data-i="pb_zbtn">Valider la clôture Z à distance</span></button>
       </div>
      </div>
     </div>
     <div class="boss-bottom-nav" role="tablist" aria-label="Vues de l'application mobile Boss">
      <button type="button" class="boss-tab" role="tab" data-btab="bp-overview" aria-selected="true"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg><span data-i="pb_t1">Aperçu</span></button>
      <button type="button" class="boss-tab" role="tab" data-btab="bp-alerts" aria-selected="false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg><span data-i="pb_t2">Alertes (4)</span></button>
      <button type="button" class="boss-tab" role="tab" data-btab="bp-close" aria-selected="false"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg><span data-i="pb_t3">Clôture Z</span></button>
     </div>
    </div>
   </div>
  </div>
 </div>
</section>

<!-- SIMULATEUR HORS LIGNE -->
<section class="offline-sec" id="offline">
 <div class="wrap off__in">
  <div data-reveal>
   <div class="eyebrow" data-i="o_eye">Pensé pour la Mauritanie</div>
   <h2 data-i="o_h" style="font:800 clamp(30px,3.6vw,48px)/1.1 var(--f-head);margin:0 0 16px">Internet coupe ? Vous continuez à vendre.</h2>
   <p class="sub" data-i="o_p" style="color:#D5E3E8">Vos caisses se parlent directement en réseau local. Rien n'est perdu : tout se synchronise dès le retour de la connexion.</p>
   <div class="network-switch" role="group" aria-label="Simulation de coupure Internet">
    <button type="button" data-net="on" aria-pressed="true"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M5 12.55a11 11 0 0 1 14.08 0M1.42 9a16 16 0 0 1 21.16 0M8.53 16.11a6 6 0 0 1 6.95 0M12 20h.01"/></svg><span data-i="o_on">Internet actif</span></button>
    <button type="button" data-net="off" aria-pressed="false"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><line x1="2" x2="22" y1="2" y2="22"/><path d="M8.5 16.5a5 5 0 0 1 7 0M2 8.82a15 15 0 0 1 4.17-2.65M10.66 5c4.01-.36 8.14.9 11.34 3.82M1.42 9a16 16 0 0 1 4.75-3.32M12 20h.01"/></svg><span data-i="o_off">Couper Internet</span></button>
   </div>
  </div>
  <div class="net-monitor" data-reveal style="--d:.15s">
   <div class="net-row"><span data-i="o_r1">Caisses du comptoir</span><span class="net-pill" id="p1">ACTIVES</span></div>
   <div class="net-row"><span data-i="o_r2">Réseau local du magasin</span><span class="net-pill warn" id="p2">EN VEILLE</span></div>
   <div class="net-row"><span data-i="o_r3">Suivi sur App Mobile Boss</span><span class="net-pill" id="p3">EN DIRECT</span></div>
   <p class="net-status-text" id="netmsg">Toutes les ventes sont enregistrées et synchronisées en direct avec le cloud Full-Tek.</p>
  </div>
 </div>
</section>

<!-- TARIFS -->
<section class="pricing-sec" id="tarifs">
 <div class="wrap">
  <div class="pricing-header" data-reveal>
   <div class="eyebrow" data-i="t_eye">Tarifs en ouguiya (MRU)</div>
   <h2 data-i="t_h">Un prix clair, sans surprise.</h2>
   <p class="sub" data-i="t_p">15 jours d'essai gratuit sur votre propre matériel. Sans engagement.</p>
   <div class="billing-toggle-wrap" role="group" aria-label="Fréquence de facturation">
     <button type="button" class="billing-btn" id="btn-monthly" aria-pressed="true" data-i="t_mo">Mensuel</button>
     <button type="button" class="billing-btn" id="btn-yearly" aria-pressed="false"><span data-i="t_yr">Annuel</span> <span class="discount-chip" data-i="t_disc">-20% ÉCONOMIE</span></button>
   </div>
  </div>
  <div class="plans-grid">
   <div class="plan-card" data-reveal>
    <h3 data-i="pl1_n">Start</h3><div class="price-display"><span class="price-val" dir="ltr" data-m="1 500" data-y="1 200">1 500</span> <small data-i="t_per">MRU / mois</small></div>
    <ul>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl1_1">1 caisse, 1 solution au choix</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl1_2">Fonctionne sans Internet</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl1_3">Bankily, Masrivi, Sedad, Karni</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl1_4">Français, العربية, English</span></li>
    </ul>
    <a class="btn btn--ghost" href="#contact" data-pick="Full-Tek Resto" data-i="try">Essayer gratuitement</a>
   </div>
   <div class="plan-card popular" data-reveal style="--d:.1s">
    <div class="plan-popular-badge" data-i="pl2_badge">LE PLUS CHOISI</div><h3 data-i="pl2_n">Pro</h3><div class="price-display"><span class="price-val" dir="ltr" data-m="3 000" data-y="2 400">3 000</span> <small data-i="t_per">MRU / mois</small></div>
    <ul>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl2_1">Jusqu'à 4 caisses en réseau LAN</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl2_2">App Mobile Full·Tek Boss incluse</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl2_3">KDS cuisine, balance COM1, FEFO &amp; CNAM</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl2_4">Support direct M. Taha 7j/7</span></li>
    </ul>
    <a class="btn btn--ochre" href="#contact" data-pick="Full-Tek Market" data-i="try">Essayer gratuitement</a>
   </div>
   <div class="plan-card" data-reveal style="--d:.2s">
    <h3 data-i="pl3_n">Entreprise</h3><div class="price-display"><span class="price-val" dir="ltr" data-m="5 500" data-y="4 400">5 500</span> <small data-i="t_per">MRU / mois</small></div>
    <ul>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl3_1">Boutiques et villes illimitées</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl3_2">Installation &amp; formation sur site</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl3_3">Import complet de votre catalogue</span></li>
     <li><svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><span data-i="pl3_4">Ligne dédiée M. Taha Chouaib</span></li>
    </ul>
    <a class="btn btn--ghost" href="#contact" data-pick="Full-Tek Boss (App Mobile)" data-i="demo">Demander une démo</a>
   </div>
  </div>
 </div>
</section>

<!-- CONTACT DIRECT M. TAHA (+222 42 74 42 42) -->
<section class="cta-sec" id="contact">
 <div class="wrap cta__in">
  <div data-reveal>
   <div class="eyebrow" data-i="c_eye">Prêt à démarrer ?</div>
   <h2 data-i="c_h" style="font:800 clamp(30px,3.6vw,48px)/1.1 var(--f-head);margin:0 0 16px">Votre caisse installée en 24 heures.</h2>
   <p class="sub" data-i="c_p">Laissez-nous vos coordonnées ou appelez directement M. Taha pour une démonstration en magasin et 15 jours d'essai gratuit.</p>

   <div class="taha-card">
    <div class="taha-top">
     <div class="taha-avatar">TC</div>
     <div>
       <b data-i="taha_name">M. Taha Chouaib</b>
       <span data-i="taha_role">Responsable Full·Tek POS Mauritanie &middot; Nouakchott</span>
     </div>
    </div>
    <div class="taha-actions">
     <a class="taha-btn-call" href="tel:+22242744242" dir="ltr">
       <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
       +222 42 74 42 42
     </a>
     <a class="taha-btn-wa" href="https://wa.me/22242744242" target="_blank" rel="noopener">
       <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12.04 2c-5.46 0-9.91 4.45-9.91 9.91 0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.816 9.816 0 0 0 12.04 2z"/></svg>
       <span data-i="taha_wa">WhatsApp Direct M. Taha</span>
     </a>
    </div>
   </div>
  </div>

  <form class="f-box" id="form" data-reveal style="--d:.15s" novalidate>
   <label class="col-full"><span data-i="f_biz">Nom du commerce *</span><input id="fn" required autocomplete="organization" data-i-ph="f_biz_ph" placeholder="Ex : Restaurant Al Khaima"></label>
   <label><span data-i="f_wa">Votre WhatsApp *</span><input id="fp" type="tel" required autocomplete="tel" placeholder="+222 XX XX XX XX" dir="ltr"></label>
   <label><span data-i="f_sol">Solution souhaitée</span><select id="fs"><option value="Full-Tek Resto" data-i="opt_r">Full-Tek Resto</option><option value="Full-Tek Market" data-i="opt_m">Full-Tek Market</option><option value="Full-Tek Pharma" data-i="opt_p">Full-Tek Pharma</option><option value="Full-Tek Boss (App Mobile)" data-i="opt_b">Full-Tek Boss (App Mobile)</option></select></label>
   <button class="btn btn--ochre" type="submit" id="btn-submit"><span data-i="c_btn">Activer mon essai gratuit</span><svg width="16" height="16" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M2 8h11M9 3.5 13.5 8 9 12.5"/></svg></button>
   <div class="form-ok-msg" id="ok" role="status" aria-live="polite"></div>
  </form>
 </div>
</section>
</main>

<!-- FOOTER -->
<footer>
 <div class="wrap">
  <div class="foot-grid">
   <div><img src="__L__logo_principal_sombre.svg" alt="Full·Tek POS"><p data-i="ft_desc">La suite de caisse intelligente pour restaurants, supermarchés et pharmacies de Mauritanie.</p></div>
   <div><h4 data-i="ft_c1">Solutions Métiers</h4><a href="#resto">Full·Tek Resto</a><a href="#market">Full·Tek Market</a><a href="#pharma">Full·Tek Pharma</a><a href="#boss" data-i="ft_boss">Full·Tek Boss (Mobile)</a></div>
   <div><h4 data-i="ft_c2">Infrastructure</h4><a href="#offline" data-i="ft_off">Résilience hors ligne</a><a href="#tarifs" data-i="ft_pr">Tarifs en ouguiya</a><a href="#contact" data-i="ft_sup">Assistance 7j/7</a></div>
   <div>
     <h4 data-i="ft_c3">Contact M. Taha Chouaib</h4>
     <a href="tel:+22242744242"><span data-i="ft_call">Appel direct</span> : <span dir="ltr">+222 42 74 42 42</span></a>
     <a href="https://wa.me/22242744242" target="_blank" rel="noopener"><span data-i="ft_wa_lbl">WhatsApp :</span> <span dir="ltr">42 74 42 42</span></a>
     <a href="#contact" data-i="ft_loc">Nouakchott &middot; Tevragh Zeina</a>
   </div>
  </div>
  <div class="copy-row">
   <span data-i="ft_copy">&copy; 2026 Full·Tek POS Mauritanie &middot; Tous droits réservés</span>
   <span data-i="ft_cities">Nouakchott &middot; Nouadhibou &middot; Atar &middot; Rosso</span>
   <button type="button" class="btn-replay" id="btn-replay-preloader" aria-label="Revoir l'animation de démarrage"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg><span data-i="ft_replay">Revoir l'animation</span></button>
  </div>
 </div>
</footer>

<!-- BOUTON FLOTTANT WHATSAPP M. TAHA -->
<a class="fab-wa" href="https://wa.me/22242744242" target="_blank" rel="noopener" aria-label="Contacter M. Taha sur WhatsApp au 42 74 42 42">
  <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.04 2c-5.46 0-9.91 4.45-9.91 9.91 0 1.75.46 3.45 1.32 4.95L2.05 22l5.25-1.38c1.45.79 3.08 1.21 4.74 1.21 5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.816 9.816 0 0 0 12.04 2z"/></svg>
  <span><span data-i="fab_wa">M. Taha</span> &middot; <span dir="ltr">42 74 42 42</span></span>
</a>

<!-- MODALE D'ACCÈS -->
<div class="modal" id="access" role="dialog" aria-modal="true" aria-labelledby="amt">
 <div class="modal__card">
  <button class="modal-close" type="button" id="ax" aria-label="Fermer la fenêtre"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M18 6L6 18M6 6l12 12"/></svg></button>
  <h3 id="amt" data-i="a_h">Accéder à ma solution</h3>
  <p data-i="a_p">Choisissez votre espace métier pour ouvrir votre caisse ou votre application mobile.</p>
  <div class="acc-grid">
   <a class="acc-link" href="#resto" style="--c:var(--resto)"><span class="emblem-badge">__MINI_RESTO__</span><div>Full·Tek Resto<small data-i="mod_r">Salle Khaima &amp; KDS</small></div></a>
   <a class="acc-link" href="#market" style="--c:var(--market)"><span class="emblem-badge">__MINI_MARKET__</span><div>Full·Tek Market<small data-i="mod_m">Balance &amp; Carnet Karni</small></div></a>
   <a class="acc-link" href="#pharma" style="--c:var(--pharma)"><span class="emblem-badge">__MINI_PHARMA__</span><div>Full·Tek Pharma<small data-i="mod_p">Lots FEFO &amp; CNAM</small></div></a>
   <a class="acc-link" href="#boss" style="--c:var(--boss)"><span class="emblem-badge">__MINI_BOSS__</span><div>Full·Tek Boss<small data-i="m_boss">App Mobile (iOS &amp; Android)</small></div></a>
  </div>
 </div>
</div>

<!-- SCRIPTS -->
<script>
(()=>{
 const $ = s => document.querySelector(s);
 const $$ = s => [...document.querySelectorAll(s)];
 let lang = 'fr', net = 'on';
 // 8. TRILINGUE
 const D = {
  fr: {
   dir:'ltr', cur:'MRU', doc_title:'Full·Tek : la caisse qui ne s\'arrête jamais — Mauritanie (Resto, Market, Pharma, Boss)', pre_init:'Initialisation du noyau POS...',
   n_sol:'Solutions', n_off:'Sans Internet', n_price:'Tarifs', n_contact:'Contact', n_login:'Se connecter', n_trial:'Essai gratuit',
   m_resto:'Restaurants, cafés, salons Khaima VIP', m_market:'Supermarchés, balances, carnet Karni', m_pharma:'Pharmacies, lots FEFO &amp; CNAM', m_boss:'App Mobile (iOS &amp; Android)',
   badge:'Fonctionne même sans Internet', h1:'La caisse qui <em>ne s\'arrête jamais</em>, pour votre commerce.',
   lead:'Restaurant, supermarché ou pharmacie en Mauritanie : encaissez en un éclair, acceptez Bankily, Masrivi, Sedad ou Karni, et pilotez vos boutiques en direct.',
   cta1:'Essai gratuit 15 jours', cta2:'Choisir ma solution', f1_n:'0,08 s', f1:'par article scanné', f2_n:'100 %', f2:'ventes sans coupure', f3_n:'15 j', f3:'d\'essai offert',
   h_lan:'Réseau LAN actif · zéro coupure', h_tbl:'Khaima VIP-02 · Nouakchott', h_online:'EN LIGNE',
   h_it1:'1/2 Agneau Méchoui', h_it2:'Thé Atay 3 Services', h_it3:'Plateau Dattes Atar',
   h_tot:'TOTAL À PAYER', h_pay:'Encaisser · Bankily / Masrivi',
   h_bok:'Bankily confirmé', h_bref:'Réf. ••4821 · 3 200 MRU', h_boss:'BOSS MOBILE',
   gt_resto:'Restaurants &amp; cafés', gt_market:'Supermarchés &amp; épiceries', gt_pharma:'Pharmacies &amp; dépôts', gt_boss:'App Mobile Gérant',
   g_resto:'Salons Khaima VIP, commandes sur tablette, écran cuisine KDS et addition partagée.',
   g_market:'Balances connectées, scan rapide, prix Détail / Demi-gros et Carnet de crédit Karni.',
   g_pharma:'Lots FEFO, blocage automatique des produits périmés et prise en charge CNAM.',
   g_boss:'Votre commerce en poche : ventes par boutique, alertes anti-fraude et clôture Z à distance.',
   discover:'Tester Resto en direct', discover2:'Tester Market en direct', discover3:'Tester Pharma en direct', discover4:'Tester l\'App Boss', try:'Essayer gratuitement', demo:'Demander une démo',
   st_bk:'Bankily', st_ms:'Masrivi', st_sd:'Sedad', st_kr:'Carnet Karni', st_pr:'Imprimante 80 mm FR/AR', st_sc:'Douchette EAN-13', st_bl:'Balance COM1', st_cn:'CNAM Officine',
   tag_resto:'RESTAURANTS, MÉCHOUIS &amp; SALONS KHAIMA VIP', tag_market:'SUPERMARCHÉS, BOUCHERIES &amp; GROS', tag_pharma:'PHARMACIES, OFFICINES &amp; CNAM MAURITANIE', tag_boss:'APPLICATION MOBILE · iOS &amp; ANDROID',
   r_h:'Servez plus vite, encaissez sans erreur.', r_p:'Du salon Khaima VIP à la terrasse : prenez la commande bilingue FR/AR sur tablette, envoyez en cuisine KDS et encaissez via Bankily, Masrivi ou Cash.',
   r1:'Plan de salle, Terrasses et Salons Khaima VIP (vente au plateau)', r2:'Écran cuisine KDS avec chronomètre et alerte rupture immédiate', r3:'Encaissement mixte Cash + Bankily / Masrivi + ticket 80 mm FR/AR',
   pr_brand:'Dar El-Karam · دار الكرم', pr_sub:'Tevragh Zeina · Serveur : Ahmed · Imprimante 80mm PRÊTE', pr_t1:'Caisse Tactile', pr_t2:'Khaima VIP (4)', pr_t3:'Cuisine KDS (3)',
   kds_h1:'#104 · VIP-02', kds_h2:'#105 · Ksar', kds_h3:'#108 · T-04',
   pr_srch:'Rechercher un plat FR / العربية...', pr_c0:'Tous (6)', pr_c1:'Méchouis &amp; Plats', pr_c2:'Atay &amp; Douceurs',
   rb_1:'PLAT STAR', rn_1:'1/2 Agneau Méchoui', rs_1:'مشوي نصف خروف',
   rb_2:'TRADITION', rn_2:'Thiéboudienne Royal', rs_2:'تيبودين ملكي',
   rb_3:'GRILLADE', rn_3:'Brochettes Chameau', rs_3:'مشوي لحم الإبل',
   rb_4:'KHAIMA VIP', rn_4:'Thé Atay 3 Services', rs_4:'أتاي موريتاني',
   rb_5:'100% FRAIS', rn_5:'Lait Chamelle Frais', rs_5:'لبن الإبل الطازج',
   rb_6:'ATAR BIO', rn_6:'Dattes Atar &amp; Bissap', rs_6:'تمر أطار و كركديه',
   rk_1h:'Salon Khaima VIP-01', rk_1s:'Libre · 8 places · Tapis Mauritanien', rk_st1:'LIBRE',
   rk_2h:'Salon Khaima VIP-02', rk_2s:'Occupée · 3 200 MRU · 6 couverts', rk_st2:'OCCUPÉE',
   rk_3h:'Terrasse T-04', rk_3s:'Addition demandée · 950 MRU', rk_st3:'ADDITION',
   rk_4h:'Livraison Ksar #43', rk_4s:'Moto en route · 1 400 MRU', rk_st4:'MOTO',
   kds_1:'1× 1/2 Agneau Méchoui<br>2× Thé Atay<br><span style="color:#FBBF24;font-weight:700">Sans oignon</span>',
   kds_2:'2× Chawarma viande<br>2× Jus Bissap frais',
   kds_3:'1× Thiéboudienne Royal<br>1× Lait Chamelle',
   pr_tk_sub:'6 couverts · Ticket #104 · FR / العربية', pos_act:'ACTIF', pos_ttc:'TOTAL TTC', pr_pay:'Encaisser &amp; Ticket 80mm',
   pm_bk:'Bankily', pm_ms:'Masrivi', pm_sd:'Sedad', pm_cs:'Cash', pm_kr:'Karni',
   m_h:'Une file d\'attente qui avance vite.', m_p:'Scannez en 0,08 s, lisez directement le poids de la balance électronique, basculez Détail / Demi-gros et gérez votre Carnet de crédit client (Karni) sans papier.',
   mk1:'Balance Poids-Prix connectée en direct (viande, dattes, fruits)', mk2:'Bascule instantanée Prix Détail / Prix Demi-Gros sur chaque produit', mk3:'Carnet de crédit numérique (Karni) avec plafond client et relance',
   pm_brand:'Al-Baraka Market', pm_pos:'Caisse #01', pm_sub:'سوبرماركت البركة · Scanner EAN-13 &amp; Balance COM1', pm_t1:'Tarif Détail', pm_t2:'Tarif Demi-Gros',
   pm_hw1:'BALANCE COM1 : 1,450 kg × 380 MRU = 551 MRU', pm_hw2:'DOUCHETTE EAN-13 PRÊTE',
   pm_srch:'Code-barres EAN-13 ou nom d\'article...', pm_c0:'Tous (6)', pm_c1:'Boucherie &amp; Lait', pm_c2:'Gros &amp; Boissons',
   mb_1:'PESÉE 1,45 KG', mn_1:'Viande Hachée 1,45kg', ms_1:'لحم مفروم (ميزان)',
   mb_2:'SAC 25 KG', mn_2:'Riz Basmati 25 kg', ms_2:'أرز بسمتي ٢٥ كغ',
   mb_3:'BIDON 5 L', mn_3:'Huile Végétale 5 L', ms_3:'زيت نباتي ٥ لتر',
   mb_4:'BOÎTE 900G', mn_4:'Lait Nido 900 g', ms_4:'حليب نيدو ٩٠٠غ',
   mb_5:'PACK ×6', mn_5:'Pack Benichab x6', ms_5:'مياه بنشاب ×٦',
   mb_6:'TOP VENTE', mn_6:'Thé Achoura 500g', ms_6:'شاي عشورة ٥٠٠غ',
   pm_tk_h:'Panier Caisse #01', pm_tk_sub:'Client Karni : Ould Sidi (Plafond 50 000 MRU)', pm_karni_ok:'KARNI OK', pm_net:'NET À PAYER', pm_pay:'Encaisser / Inscrire au Karni',
   p_h:'Aucun médicament périmé ne sort de votre officine.', p_p:'Gestion par lots FEFO (premier expiré, premier sorti) : la caisse verrouille automatiquement toute boîte expirée et calcule la part prise en charge par la CNAM.',
   p1:'Blocage instantané en caisse des lots expirés (Sécurité Patient)', p2:'Prise en charge CNAM &amp; mutuelles avec calcul automatique de la part patient', p3:'Alertes 90/30/7 jours, équivalents génériques et suivi chaîne du froid (+4°C)',
   pp_brand:'Pharmacie Chinguetti · صيدلية شنقيط', pp_sub:'Règle FEFO Active · Frigo +4,2 °C · Tiers-Payant CNAM', pp_ctrl:'CONTRÔLE LOTS ACTIF',
   pp_ban:'Cliquez sur « Augmentin 1g · PÉRIMÉ » ci-dessous pour tester le blocage sécurité FEFO.',
   pp_srch:'DCI, nom commercial ou scan boîte...', pp_c0:'Tous (6)', pp_c1:'Antibiotiques &amp; Frigo', pp_c2:'Douleur &amp; Soins',
   pb_m1:'FEFO OK · 08/27', pn_1:'Amoxicilline 500mg', ps_1:'Lot #A-892 · Gélules',
   pb_m2:'PRIORITÉ FEFO', pn_2:'Paracétamol 1 g', ps_2:'Lot #P-410 · Exp 12/26',
   pb_m3:'BLOQUÉ · EXPIRÉ', pn_3:'Augmentin 1g · PÉRIMÉ', ps_3:'Lot #EXP-2024 · Expiré', pp_nosale:'VENTE INTERDITE',
   pb_m4:'FRIGO +4,2 °C', pn_4:'Insuline Lantus (Frigo)', ps_4:'Lot #F-112 · Stylo 100UI',
   pb_m5:'LOT #V-304 · OK', pn_5:'Vitamine C 1000mg', ps_5:'فيتامين سي فوار',
   pb_m6:'40 UNIDOSES', pn_6:'Sérum Physiologique', ps_6:'مصل فيزيولوجي معقم',
   pp_tk_h:'Ordonnance #409', pp_tk_sub:'Assuré CNAM · Contrôle FEFO actif', pp_cnam:'CNAM 70%', pp_pay:'Délivrer l\'ordonnance',
   b_h:'Votre commerce dans votre poche.', b_p:'Pilotage temps réel depuis votre smartphone : voyez ce que chaque boutique encaisse en direct (Nouakchott, Nouadhibou, Atar), recevez des alertes push sur vos remises et validez la clôture Z à distance.',
   b1:'Tableau de bord mobile multi-boutiques en direct (Bankily, Masrivi, Cash)', b2:'Notifications push instantanées sur remises, annulations et ouvertures tiroir', b3:'Validation biométrique / PIN de la clôture Z anti-fraude à distance',
   pb_push_h:'Full·Tek Boss · Push', pb_push:'Bankily +18 400 MRU · Tevragh Zeina', pb_net:'RÉSEAU 3 BOUTIQUES EN DIRECT', pb_live:'EN DIRECT',
   pb_st1:'Dar El-Karam Resto', pb_st2:'Al-Baraka Market', pb_st3:'Pharma Chinguetti',
   pb_lg_m:'Bankily / Masrivi', pb_lg_c:'Cash MRU',
   pb_s0:'Toutes (3)', pb_s1:'Tevragh Zeina', pb_s2:'Ksar', pb_s3:'Nouadhibou',
   pb_tk:'Tickets émis', pb_ec:'Écart de caisse', pb_top:'TOP ARTICLES VENDUS', pb_tod:'AUJOURD\'HUI',
   pb_it1:'1/2 Agneau Méchoui', pb_it2:'Riz Basmati 25 kg', pb_hr:'Ventes par tranche horaire (08h → 22h)',
   pb_a1h:'Remise -15% accordée · Caisse 02', pb_a1s:'Ksar · Caissier Ahmed S. · il y a 4 min',
   pb_a2h:'Ouverture tiroir sans encaissement', pb_a2s:'Tevragh Zeina · Tiroir B · il y a 18 min',
   pb_a3h:'Lot périmé #EXP-2024 bloqué', pb_a3s:'Pharma Ksar · Sécurité activée · 13:45',
   pb_a4h:'Synchronisation LAN → Cloud réussie', pb_a4s:'Nouadhibou · 48 tickets envoyés · 12:10',
   pb_zh:'Clôture de caisse du jour', pb_zr1:'Total théorique caisse', pb_zr2:'Cash compté en tiroir', pb_zr3:'Bankily / Masrivi vérifiés', pb_zr4:'Écart constaté', pb_z0:'0 MRU (Parfait)',
   pb_zbtn:'Valider la clôture Z à distance', pb_zdone:'Clôture Z validée à distance ✔',
   pb_t1:'Aperçu', pb_t2:'Alertes (4)', pb_t3:'Clôture Z',
   o_eye:'Pensé pour la Mauritanie', o_h:'Internet coupe ? Vous continuez à vendre.', o_p:'Vos caisses se parlent directement en réseau local. Rien n\'est perdu : tout se synchronise dès le retour de la connexion.',
   o_on:'Internet actif', o_off:'Couper Internet', o_r1:'Caisses du comptoir', o_r2:'Réseau local du magasin', o_r3:'Suivi sur App Mobile Boss',
   net_p1:'ACTIVES', net_p2_on:'RELAIS LOCAL ACTIF', net_p2_off:'EN VEILLE', net_p3_on:'EN DIRECT', net_p3_off:'EN ATTENTE SYNC',
   t_eye:'Tarifs en ouguiya (MRU)', t_h:'Un prix clair, sans surprise.', t_p:'15 jours d\'essai gratuit sur votre propre matériel. Sans engagement.',
   t_mo:'Mensuel', t_yr:'Annuel', t_disc:'-20% ÉCONOMIE', t_per:'MRU / mois',
   pl1_n:'Start', pl1_1:'1 caisse, 1 solution au choix', pl1_2:'Fonctionne sans Internet', pl1_3:'Bankily, Masrivi, Sedad, Karni', pl1_4:'Français, العربية, English',
   pl2_badge:'LE PLUS CHOISI', pl2_n:'Pro', pl2_1:'Jusqu\'à 4 caisses en réseau LAN', pl2_2:'App Mobile Full·Tek Boss incluse', pl2_3:'KDS cuisine, balance COM1, FEFO &amp; CNAM', pl2_4:'Support direct M. Taha 7j/7',
   pl3_n:'Entreprise', pl3_1:'Boutiques et villes illimitées', pl3_2:'Installation &amp; formation sur site', pl3_3:'Import complet de votre catalogue', pl3_4:'Ligne dédiée M. Taha Chouaib',
   c_eye:'Prêt à démarrer ?', c_h:'Votre caisse installée en 24 heures.', c_p:'Laissez-nous vos coordonnées ou appelez directement M. Taha pour une démonstration en magasin et 15 jours d\'essai gratuit.',
   taha_name:'M. Taha Chouaib', taha_role:'Responsable Full·Tek POS Mauritanie · Nouakchott', taha_wa:'WhatsApp Direct M. Taha',
   f_biz:'Nom du commerce *', f_biz_ph:'Ex : Restaurant Al Khaima', f_wa:'Votre WhatsApp *', f_sol:'Solution souhaitée', c_btn:'Activer mon essai gratuit',
   opt_r:'Full-Tek Resto', opt_m:'Full-Tek Market', opt_p:'Full-Tek Pharma', opt_b:'Full-Tek Boss (App Mobile)',
   ft_desc:'La suite de caisse intelligente pour restaurants, supermarchés et pharmacies de Mauritanie.',
   ft_c1:'Solutions Métiers', ft_c2:'Infrastructure', ft_c3:'Contact M. Taha Chouaib',
   ft_boss:'Full·Tek Boss (Mobile)', ft_off:'Résilience hors ligne', ft_pr:'Tarifs en ouguiya', ft_sup:'Assistance 7j/7', ft_call:'Appel direct', ft_wa_lbl:'WhatsApp :', ft_loc:'Nouakchott · Tevragh Zeina',
   ft_copy:'© 2026 Full·Tek POS Mauritanie · Tous droits réservés', ft_cities:'Nouakchott · Nouadhibou · Atar · Rosso', ft_replay:'Revoir l\'animation',
   fab_wa:'M. Taha', a_h:'Accéder à ma solution', a_p:'Choisissez votre espace métier pour ouvrir votre caisse ou votre application mobile.',
   mod_r:'Salle Khaima &amp; KDS', mod_m:'Balance &amp; Carnet Karni', mod_p:'Lots FEFO &amp; CNAM', pre_skip:'Passer l\'introduction', pre_ready:'PRÊT',
   fb_r_pay:'Payé via {pm} · Ticket 80 mm envoyé en cuisine !', kds_ready:'Marquer Prêt', kds_done:'Plat Prêt ✔',
   fb_m_karni:'Inscrit au Carnet Karni (Ould Sidi) · Reçu imprimé', fb_m_cash:'Encaissé ({pm}) · Stock mis à jour automatiquement',
   p_part:'PART PATIENT (30% · CNAM 70%)', p_full:'TOTAL PATIENT (100%)',
   fb_p_blocked:'BLOCAGE SÉCURITÉ : Lot #EXP-2024 expiré ! Vente impossible en caisse.', fb_p_ok:'Contrôle FEFO conforme · Boîte ajoutée à l\'ordonnance.',
   fb_p_pay:'Ordonnance délivrée ({pm}) · Lots déstockés FEFO',
   form_err:'Veuillez indiquer le nom de votre commerce et votre numéro.',
   form_ok:'<strong>Merci {name} !</strong> Votre demande pour <strong>{sol}</strong> est prête pour M. Taha (<span dir="ltr">+222 42 74 42 42</span>).',
   form_wa_btn:'Envoyer directement à M. Taha sur WhatsApp',
   wa_tpl:'Bonjour M. Taha ! Je suis {name}. Je souhaite activer mon essai gratuit de 15 jours pour {sol}. Mon WhatsApp : {phone}'
  },
  ar: {
   dir:'rtl', cur:'أوقية', doc_title:'Full·Tek : منظومة الكاشير التي لا تتوقف أبداً — موريتانيا', pre_init:'جاري تشغيل نواة نظام البيع...',
   n_sol:'الحلول', n_off:'بدون إنترنت', n_price:'الأسعار', n_contact:'اتصل بنا', n_login:'تسجيل الدخول', n_trial:'جرّب مجاناً',
   m_resto:'المطاعم والمقاهي وصالونات الخيمة VIP', m_market:'السوبرماركت، الميزان، ودفتر الكارني', m_pharma:'الصيدليات، تتبّع الصلاحية وتأمين CNAM', m_boss:'تطبيق المدير على الهاتف (iOS و Android)',
   badge:'يعمل حتى بدون إنترنت', h1:'نظام الكاشير الذي <em>لا يتوقف أبداً</em> عن خدمة تجارتك.',
   lead:'لمطعمك أو متجرك أو صيدليتك في موريتانيا: بع وحصّل في ثوانٍ عبر بنكيلي ومصرفي وسداد أو دفتر الكارني، وتابع جميع فروعك لحظة بلحظة.',
   cta1:'تجربة مجانية 15 يوماً', cta2:'اختر الحل المناسب', f1_n:'<span dir="ltr">0.08</span> ث', f1:'سرعة قراءة الباركود', f2_n:'<span dir="ltr">100%</span>', f2:'بيع مستمر بلا انقطاع', f3_n:'<span dir="ltr">15</span> يوماً', f3:'تجربة مجانية متكاملة',
   h_lan:'الشبكة المحلية نشطة · دون أي انقطاع', h_tbl:'صالون الخيمة VIP-02 · نواكشوط', h_online:'متصل',
   h_it1:'نصف خروف مشوي', h_it2:'صينية أتاي 3 كؤوس', h_it3:'طبق تمور أطار',
   h_tot:'الإجمالي للدفع', h_pay:'تحصيل · بنكيلي / مصرفي',
   h_bok:'تم تأكيد الدفع عبر بنكيلي', h_bref:'مرجع <span dir="ltr">••4821</span> · <span dir="ltr">3 200</span> أوقية', h_boss:'تطبيق المدير',
   gt_resto:'المطاعم والمقاهي', gt_market:'السوبرماركت والبقالات', gt_pharma:'الصيدليات ومخازن الأدوية', gt_boss:'تطبيق المدير على الهاتف',
   g_resto:'قاعات الخيمة VIP، طلبات التابلت، شاشة المطبخ KDS وتقسيم الفاتورة.',
   g_market:'موازين إلكترونية متصلة، مسح سريع، أسعار التجزئة ونصف الجملة، ودفتر الكارني.',
   g_pharma:'إدارة الصلاحية بنظام FEFO، حظر فوري للأدوية المنتهية، وحساب تغطية CNAM.',
   g_boss:'متجرك في جيبك: مبيعات كل فرع لحظياً، تنبيهات الحماية، وإقفال الصندوق Z عن بُعد.',
   discover:'جرّب نظام Resto مباشرة', discover2:'جرّب نظام Market مباشرة', discover3:'جرّب نظام Pharma مباشرة', discover4:'جرّب تطبيق Boss', try:'جرّب مجاناً', demo:'اطلب عرضاً توضيحياً',
   st_bk:'دفع بنكيلي', st_ms:'دفع مصرفي', st_sd:'دفع سداد', st_kr:'دفتر الدَّين (كارني)', st_pr:'طابعة إيصالات 80 ملم', st_sc:'قارئ باركود EAN-13', st_bl:'ميزان COM1 متصل', st_cn:'تأمين CNAM للصيدليات',
   tag_resto:'المطاعم والمشويات وصالونات الخيمة VIP', tag_market:'السوبرماركت والملاحم والبيع بالجملة', tag_pharma:'الصيدليات وتأمين CNAM في موريتانيا', tag_boss:'تطبيق الهاتف · iOS و Android',
   r_h:'خدمة أسرع، ومحاسبة دقيقة بلا أخطاء.', r_p:'من صالون الخيمة VIP إلى الجلسات الخارجية: سجّل الطلب بالعربية أو الفرنسية على التابلت، أرسله فوراً إلى شاشة المطبخ KDS، وحصّل عبر بنكيلي أو مصرفي أو نقداً.',
   r1:'مخطط القاعة والجلسات وصالونات الخيمة VIP (البيع بالصينية أو بالطبق)', r2:'شاشة المطبخ KDS مع مؤقّت التحضير وتنبيه فوري عند نفاد الأصناف', r3:'دفع مختلط (نقدي + بنكيلي / مصرفي) مع طباعة فاتورة 80 ملم بالعربية والفرنسية',
   pr_brand:'مطعم دار الكرم · تفرغ زينة', pr_sub:'النادل: أحمد · طابعة 80 ملم جاهزة', pr_t1:'شاشة الكاشير', pr_t2:'خيمة VIP (4)', pr_t3:'مطبخ KDS (3)',
   kds_h1:'#104 · خيمة VIP-02', kds_h2:'#105 · لكصر', kds_h3:'#108 · جلسة T-04',
   pr_srch:'ابحث عن طبق بالعربية أو الفرنسية...', pr_c0:'الكل (6)', pr_c1:'مشويات وأطباق', pr_c2:'أتاي ومشروبات',
   rb_1:'الأكثر طلباً', rn_1:'نصف خروف مشوي', rs_1:'1/2 Agneau Méchoui',
   rb_2:'طبق تقليدي', rn_2:'تيبودين ملكي', rs_2:'Thiéboudienne Royal',
   rb_3:'مشويات', rn_3:'أسياخ لحم الإبل', rs_3:'Brochettes Chameau',
   rb_4:'خيمة VIP', rn_4:'صينية أتاي 3 كؤوس', rs_4:'Thé Atay 3 Services',
   rb_5:'طازج 100%', rn_5:'لبن الإبل الطازج', rs_5:'Lait Chamelle Frais',
   rb_6:'تمور أطار', rn_6:'تمر أطار وكركديه', rs_6:'Dattes Atar & Bissap',
   rk_1h:'صالون الخيمة VIP-01', rk_1s:'متاحة · 8 مقاعد · جلسة موريتانية', rk_st1:'متاحة',
   rk_2h:'صالون الخيمة VIP-02', rk_2s:'مشغولة · <span dir="ltr">3 200</span> أوقية · 6 أشخاص', rk_st2:'مشغولة',
   rk_3h:'الجلسة الخارجية T-04', rk_3s:'طلب الفاتورة · <span dir="ltr">950</span> أوقية', rk_st3:'الحساب',
   rk_4h:'توصيل لكصر #43', rk_4s:'الدراجة في الطريق · <span dir="ltr">1 400</span> أوقية', rk_st4:'توصيل',
   kds_1:'1× نصف خروف مشوي<br>2× شاي أتاي<br><span style="color:#FBBF24;font-weight:700">بدون بصل</span>',
   kds_2:'2× شاورما لحم<br>2× عصير كركديه طازج',
   kds_3:'1× تيبودين ملكي<br>1× لبن إبل طازج',
   pr_tk_sub:'6 أشخاص · فاتورة #104 · عربي / فرنسي', pos_act:'نشطة', pos_ttc:'الإجمالي شامل الضريبة', pr_pay:'تحصيل وإرسال للمطبخ KDS',
   pm_bk:'بنكيلي', pm_ms:'مصرفي', pm_sd:'سداد', pm_cs:'نقدي', pm_kr:'كارني',
   m_h:'خدمة سريعة عند الصندوق دون طوابير انتظار.', m_p:'امسح الباركود في 0.08 ثانية، اقرأ الوزن مباشرة من الميزان الإلكتروني، بدّل بين سعر التجزئة ونصف الجملة، وأدر دفتر الدَّين (كارني) بلا أوراق.',
   mk1:'ميزان إلكتروني متصل مباشرة (للحوم والتمور والفواكه)', mk2:'تبديل فوري بين سعر التجزئة وسعر نصف الجملة لكل منتج', mk3:'دفتر ائتمان رقمي للزبائن (كارني) مع تحديد السقف وتنبيهات السداد',
   pm_brand:'سوبرماركت البركة', pm_pos:'الصندوق #01', pm_sub:'قارئ باركود EAN-13 وميزان COM1', pm_t1:'سعر التجزئة', pm_t2:'سعر نصف الجملة',
   pm_hw1:'الميزان COM1 : <span dir="ltr">1.450</span> كغ × <span dir="ltr">380</span> = <span dir="ltr">551</span> أوقية', pm_hw2:'قارئ الباركود جاهز',
   pm_srch:'الباركود EAN-13 أو اسم المنتج...', pm_c0:'الكل (6)', pm_c1:'لحوم وألبان', pm_c2:'جملة ومشروبات',
   mb_1:'وزن 1.45 كغ', mn_1:'لحم مفروم (1.45 كغ)', ms_1:'بالميزان الإلكتروني',
   mb_2:'كيس 25 كغ', mn_2:'أرز بسمتي 25 كغ', ms_2:'كيس جملة وتجزئة',
   mb_3:'عبوة 5 لتر', mn_3:'زيت نباتي 5 لتر', ms_3:'زيت طبخ نقي',
   mb_4:'علبة 900 غ', mn_4:'حليب نيدو 900 غ', ms_4:'حليب مجفف كامل الدسم',
   mb_5:'حزمة ×6', mn_5:'مياه بنشاب (6 عبوات)', ms_5:'مياه معدنية موريتانية',
   mb_6:'الأكثر مبيعاً', mn_6:'شاي عاشوراء 500 غ', ms_6:'شاي أخضر موريتاني',
   pm_tk_h:'سلة الصندوق #01', pm_tk_sub:'زبون كارني: ولد سيدي (السقف <span dir="ltr">50 000</span> أوقية)', pm_karni_ok:'كارني مفعّل', pm_net:'الصافي للدفع', pm_pay:'تحصيل / تسجيل في الكارني',
   p_h:'لن يُصرف أي دواء منتهي الصلاحية من صيدليتك.', p_p:'إدارة الدفعات بنظام FEFO (الأقرب انتهاءً يُصرف أولاً): يمنع النظام تلقائياً بيع أي علبة منتهية الصلاحية ويحسب بدقة حصة المريض وتغطية CNAM.',
   p1:'حظر فوري عند الدفع لأي دواء منتهي الصلاحية (سلامة المرضى)', p2:'حساب تلقائي لتغطية تأمين CNAM والتعاضديات وصافي حصة المريض', p3:'تنبيهات قبل 90 و30 و7 أيام، مع البدائل الجنيسة ومراقبة سلسلة التبريد (+4°C)',
   pp_brand:'صيدلية شنقيط', pp_sub:'قاعدة FEFO نشطة · الثلاجة +4.2° · تأمين CNAM', pp_ctrl:'مراقبة الدفعات نشطة',
   pp_ban:'اضغط على « أوجمنتين 1 غ · منتهي » أدناه لتجربة نظام المنع التلقائي FEFO.',
   pp_srch:'الاسم العلمي أو التجاري أو مسح العلبة...', pp_c0:'الكل (6)', pp_c1:'مضادات حيوية وثلاجة', pp_c2:'مسكنات وعناية',
   pb_m1:'صالح · 08/27', pn_1:'أموكسيسيلين 500 ملغ', ps_1:'دفعة #A-892 · كبسولات',
   pb_m2:'أولوية FEFO', pn_2:'باراسيتامول 1 غ', ps_2:'دفعة #P-410 · ينتهي 12/26',
   pb_m3:'محظور · منتهي', pn_3:'أوجمنتين 1 غ · منتهي', ps_3:'دفعة #EXP-2024 · منتهي', pp_nosale:'البيع ممنوع',
   pb_m4:'تبريد <span dir="ltr">+4.2°C</span>', pn_4:'أنسولين لانتوس (مبرد)', ps_4:'دفعة #F-112 · قلم 100 وحدة',
   pb_m5:'دفعة #V-304 · سليم', pn_5:'فيتامين سي 1000 ملغ', ps_5:'أقراص فوارة · صالحة',
   pb_m6:'40 وحدة معقمة', pn_6:'مصل فيزيولوجي معقم', ps_6:'أمبولات معقمة',
   pp_tk_h:'وصفة #409', pp_tk_sub:'مؤمّن CNAM · فحص الصلاحية نشط', pp_cnam:'CNAM 70%', pp_pay:'صرف الوصفة الطبية',
   b_h:'تجارتك كلّها في جيبك.', b_p:'متابعة فورية من هاتفك الذكي: شاهد مبيعات كل فرع مباشرة (نواكشوط، نواذيبو، أطار)، وتلقَّ تنبيهات الخصومات، وصادق على الإقفال اليومي Z عن بُعد.',
   b1:'لوحة تحكم هاتفية لجميع الفروع مباشرة (بنكيلي، مصرفي، نقدي)', b2:'إشعارات فورية عند منح خصم أو إلغاء طلب أو فتح الدرج بدون بيع', b3:'اعتماد إقفال الصندوق Z عن بُعد بالبصمة أو الرمز لمنع التلاعب',
   pb_push_h:'إشعار فوري · Full·Tek Boss', pb_push:'بنكيلي <span dir="ltr">+18 400</span> أوقية · تفرغ زينة', pb_net:'شبكة 3 فروع مباشرة', pb_live:'مباشر',
   pb_st1:'مطعم دار الكرم', pb_st2:'سوبرماركت البركة', pb_st3:'صيدلية شنقيط',
   pb_lg_m:'بنكيلي / مصرفي', pb_lg_c:'نقداً (أوقية)',
   pb_s0:'الكل (3)', pb_s1:'تفرغ زينة', pb_s2:'لكصر', pb_s3:'نواذيبو',
   pb_tk:'الفواتير الصادرة', pb_ec:'فارق الصندوق', pb_top:'الأكثر مبيعاً', pb_tod:'اليوم',
   pb_it1:'نصف خروف مشوي', pb_it2:'أرز بسمتي 25 كغ', pb_hr:'المبيعات حسب الساعة (08:00 → 22:00)',
   pb_a1h:'منح خصم -15% · الصندوق 02', pb_a1s:'لكصر · أمين الصندوق أحمد س. · منذ 4 دقائق',
   pb_a2h:'فتح الدرج دون تحصيل مبيعات', pb_a2s:'تفرغ زينة · الدرج B · منذ 18 دقيقة',
   pb_a3h:'حظر بيع دفعة منتهية #EXP-2024', pb_a3s:'صيدلية لكصر · الحماية مفعّلة · 13:45',
   pb_a4h:'تمت المزامنة المحلية إلى السحابة', pb_a4s:'نواذيبو · إرسال 48 فاتورة · 12:10',
   pb_zh:'إقفال صندوق اليوم', pb_zr1:'الإجمالي النظري للصندوق', pb_zr2:'النقد المعدود في الدرج', pb_zr3:'مبالغ بنكيلي / مصرفي المؤكدة', pb_zr4:'الفارق المسجّل', pb_z0:'<span dir="ltr">0</span> أوقية (مطابق تماماً)',
   pb_zbtn:'اعتماد الإقفال Z عن بُعد', pb_zdone:'تم اعتماد الإقفال Z عن بُعد ✔',
   pb_t1:'نظرة عامة', pb_t2:'التنبيهات (4)', pb_t3:'إقفال Z',
   o_eye:'مصمّم لظروف موريتانيا', o_h:'انقطع الإنترنت؟ واصل البيع دون توقف.', o_p:'تتصل صناديق الكاشير ببعضها مباشرة عبر الشبكة المحلية. لا تضيع أي عملية بيع، وتتم المزامنة تلقائياً فور عودة الاتصال.',
   o_on:'الإنترنت متصل', o_off:'قطع الإنترنت', o_r1:'صناديق نقاط البيع', o_r2:'الشبكة المحلية للمتجر', o_r3:'المتابعة عبر تطبيق Boss',
   net_p1:'نشطة', net_p2_on:'الربط المحلي نشط', net_p2_off:'في وضع الاستعداد', net_p3_on:'مباشر', net_p3_off:'بانتظار المزامنة',
   t_eye:'الأسعار بالأوقية الجديدة (MRU)', t_h:'أسعار واضحة بلا أي مفاجآت.', t_p:'15 يوماً تجربة مجانية على جهازك الحالي. دون أي التزام مسبق.',
   t_mo:'شهري', t_yr:'سنوي', t_disc:'وفّر 20%', t_per:'أوقية / شهر',
   pl1_n:'الباقة الأساسية · Start', pl1_1:'صندوق واحد، حلّ واحد حسب اختيارك', pl1_2:'يعمل بكفاءة دون اتصال بالإنترنت', pl1_3:'بنكيلي، مصرفي، سداد، ودفتر الكارني', pl1_4:'العربية، الفرنسية، الإنجليزية',
   pl2_badge:'الأكثر طلباً', pl2_n:'الباقة الاحترافية · Pro', pl2_1:'حتى 4 صناديق مترابطة عبر الشبكة المحلية', pl2_2:'تطبيق المدير Full·Tek Boss مشمول مجاناً', pl2_3:'شاشة المطبخ KDS، ميزان COM1، تتبّع FEFO وتأمين CNAM', pl2_4:'دعم فني مباشر من السيد طه طوال أيام الأسبوع',
   pl3_n:'باقة المؤسسات · Entreprise', pl3_1:'عدد غير محدود من الفروع والمدن', pl3_2:'تركيب ميداني وتدريب كامل للفريق', pl3_3:'استيراد شامل لقائمة منتجاتك وأسعارك', pl3_4:'خط دعم مخصّص ومباشر مع السيد طه شعيب',
   c_eye:'هل أنت مستعد للانطلاق؟', c_h:'نجهّز كاشيرك خلال 24 ساعة.', c_p:'اترك بياناتك أو اتصل مباشرة بالسيد طه لحجز عرض توضيحي في متجرك والحصول على 15 يوماً تجربة مجانية.',
   taha_name:'السيد طه شعيب', taha_role:'المسؤول عن Full·Tek POS موريتانيا · نواكشوط', taha_wa:'واتساب مباشر للسيد طه',
   f_biz:'اسم النشاط التجاري *', f_biz_ph:'مثال: مطعم الخيمة أو سوبرماركت البركة', f_wa:'رقم الواتساب *', f_sol:'الحل المطلوب', c_btn:'فعّل تجربتي المجانية الآن',
   opt_r:'Full·Tek Resto — المطاعم والمقاهي', opt_m:'Full·Tek Market — المتاجر والسوبرماركت', opt_p:'Full·Tek Pharma — الصيدليات', opt_b:'Full·Tek Boss — تطبيق المدير على الهاتف',
   ft_desc:'منظومة كاشير متكاملة وتطبيق هاتف للمدير، مصمّمة خصيصاً للمطاعم والسوبرماركت والصيدليات في موريتانيا.',
   ft_c1:'الحلول المتخصصة', ft_c2:'البنية والخدمات', ft_c3:'التواصل مع السيد طه شعيب',
   ft_boss:'تطبيق المدير Boss', ft_off:'العمل بدون إنترنت', ft_pr:'الأسعار بالأوقية', ft_sup:'الدعم الفني 7/7', ft_call:'اتصال مباشر', ft_wa_lbl:'واتساب :', ft_loc:'نواكشوط · تفرغ زينة',
   ft_copy:'© 2026 Full·Tek POS موريتانيا · جميع الحقوق محفوظة', ft_cities:'نواكشوط · نواذيبو · أطار · روصو', ft_replay:'إعادة عرض مقدمة الترحيب',
   fab_wa:'السيد طه', a_h:'الدخول إلى حلّي', a_p:'اختر مساحتك المهنية لفتح الكاشير أو تطبيق الهاتف.',
   mod_r:'قاعات الخيمة والمطبخ KDS', mod_m:'الميزان ودفتر الكارني', mod_p:'دفعات FEFO وتأمين CNAM', pre_skip:'تخطي المقدمة', pre_ready:'جاهز',
   fb_r_pay:'تم الدفع عبر {pm} · أُرسلت الفاتورة 80 ملم إلى المطبخ!', kds_ready:'تأكيد الجاهزية', kds_done:'الطبق جاهز ✔',
   fb_m_karni:'تم التسجيل في دفتر كارني (ولد سيدي) · طُبع الإيصال', fb_m_cash:'تم التحصيل ({pm}) · تم تحديث المخزون تلقائياً',
   p_part:'حصة المريض (30% · تأمين CNAM 70%)', p_full:'إجمالي المريض (100%)',
   fb_p_blocked:'حظر أمني: الدفعة #EXP-2024 منتهية الصلاحية! البيع ممنوع في الصندوق.', fb_p_ok:'فحص الصلاحية FEFO سليم · أضيفت العلبة إلى الوصفة.',
   fb_p_pay:'تم صرف الوصفة ({pm}) · تم خصم الدفعة بنظام FEFO',
   form_err:'يرجى إدخال اسم النشاط التجاري ورقم الواتساب.',
   form_ok:'<strong>شكراً {name}!</strong> طلبك لنظام <strong>{sol}</strong> جاهز لإرساله إلى السيد طه (<span dir="ltr">+222 42 74 42 42</span>).',
   form_wa_btn:'أرسل الطلب مباشرة للسيد طه عبر واتساب',
   wa_tpl:'السلام عليكم السيد طه! اسمي {name}، وأرغب في تفعيل التجربة المجانية لمدة 15 يوماً لنظام {sol}. رقم الواتساب: {phone}'
  },
  en: {
   dir:'ltr', cur:'MRU', doc_title:'Full·Tek: the POS that never stops — Mauritania (Resto, Market, Pharma, Boss)', pre_init:'Initializing POS core...',
   n_sol:'Solutions', n_off:'Offline', n_price:'Pricing', n_contact:'Contact', n_login:'Sign in', n_trial:'Free trial',
   m_resto:'Restaurants, cafés, Khaima VIP', m_market:'Supermarkets, scales, Karni credit', m_pharma:'Pharmacies, FEFO batches &amp; CNAM', m_boss:'Mobile App (iOS &amp; Android)',
   badge:'Works even without Internet', h1:'The register that <em>never stops</em>, for your business.',
   lead:'Restaurant, supermarket or pharmacy in Mauritania: check out fast, accept Bankily, Masrivi, Sedad or Karni, and manage live.',
   cta1:'15-day free trial', cta2:'Pick my solution', f1_n:'0.08 s', f1:'per scanned item', f2_n:'100 %', f2:'sales, no downtime', f3_n:'15 d', f3:'free trial',
   h_lan:'LAN network active · zero downtime', h_tbl:'Khaima VIP-02 · Nouakchott', h_online:'ONLINE',
   h_it1:'1/2 Lamb Mechoui', h_it2:'Attaya Tea 3 Services', h_it3:'Atar Dates Platter',
   h_tot:'TOTAL DUE', h_pay:'Charge · Bankily / Masrivi',
   h_bok:'Bankily confirmed', h_bref:'Ref. ••4821 · 3,200 MRU', h_boss:'BOSS MOBILE',
   gt_resto:'Restaurants &amp; cafés', gt_market:'Supermarkets &amp; groceries', gt_pharma:'Pharmacies &amp; depots', gt_boss:'Owner Mobile App',
   g_resto:'Khaima VIP lounges, tablet orders, kitchen KDS screen and split bills.',
   g_market:'Connected scales, fast scan, Retail/Wholesale pricing and Karni credit book.',
   g_pharma:'FEFO batches, expired medicine blocking and CNAM insurance split.',
   g_boss:'Your business in your pocket: live store sales, fraud alerts and remote Z closing.',
   discover:'Try Resto live', discover2:'Try Market live', discover3:'Try Pharma live', discover4:'Try Boss App', try:'Try for free', demo:'Request a demo',
   st_bk:'Bankily', st_ms:'Masrivi', st_sd:'Sedad', st_kr:'Karni Ledger', st_pr:'80mm FR/AR Printer', st_sc:'EAN-13 Scanner', st_bl:'COM1 Scale', st_cn:'CNAM Pharmacy',
   tag_resto:'RESTAURANTS, MECHOUI &amp; KHAIMA VIP', tag_market:'SUPERMARKETS, BUTCHERY &amp; WHOLESALE', tag_pharma:'PHARMACIES &amp; CNAM MAURITANIA', tag_boss:'MOBILE APP · iOS &amp; ANDROID',
   r_h:'Serve faster, charge without errors.', r_p:'From Khaima VIP lounges to the terrace: order in FR/AR on tablet, send to KDS kitchen and charge via Bankily, Masrivi or Cash.',
   r1:'Floor plan, Terraces and Khaima VIP lounges', r2:'KDS kitchen screen with live timers & stock alerts', r3:'Mixed Cash + Bankily / Masrivi & 80mm FR/AR receipt',
   pr_brand:'Dar El-Karam · دار الكرم', pr_sub:'Tevragh Zeina · Waiter: Ahmed · 80mm Printer READY', pr_t1:'Touch Till', pr_t2:'Khaima VIP (4)', pr_t3:'Kitchen KDS (3)',
   kds_h1:'#104 · VIP-02', kds_h2:'#105 · Ksar', kds_h3:'#108 · T-04',
   pr_srch:'Search dish FR / العربية...', pr_c0:'All (6)', pr_c1:'Grills &amp; Dishes', pr_c2:'Atay &amp; Sweets',
   rb_1:'TOP DISH', rn_1:'1/2 Lamb Mechoui', rs_1:'مشوي نصف خروف',
   rb_2:'TRADITION', rn_2:'Royal Thieboudienne', rs_2:'تيبودين ملكي',
   rb_3:'GRILL', rn_3:'Camel Skewers', rs_3:'مشوي لحم الإبل',
   rb_4:'KHAIMA VIP', rn_4:'Attaya Tea 3 Services', rs_4:'أتاي موريتاني',
   rb_5:'100% FRESH', rn_5:'Fresh Camel Milk', rs_5:'لبن الإبل الطازج',
   rb_6:'ATAR BIO', rn_6:'Atar Dates &amp; Bissap', rs_6:'تمر أطار و كركديه',
   rk_1h:'Khaima Lounge VIP-01', rk_1s:'Free · 8 seats · Mauritanian Rug', rk_st1:'FREE',
   rk_2h:'Khaima Lounge VIP-02', rk_2s:'Occupied · 3,200 MRU · 6 guests', rk_st2:'OCCUPIED',
   rk_3h:'Terrace T-04', rk_3s:'Bill requested · 950 MRU', rk_st3:'BILL',
   rk_4h:'Ksar Delivery #43', rk_4s:'Rider on the way · 1,400 MRU', rk_st4:'DELIVERY',
   kds_1:'1× 1/2 Lamb Mechoui<br>2× Attaya Tea<br><span style="color:#FBBF24;font-weight:700">No onions</span>',
   kds_2:'2× Beef Shawarma<br>2× Fresh Bissap Juice',
   kds_3:'1× Royal Thieboudienne<br>1× Camel Milk',
   pr_tk_sub:'6 guests · Ticket #104 · FR / العربية', pos_act:'ACTIVE', pos_ttc:'TOTAL INCL. TAX', pr_pay:'Charge &amp; Print 80mm',
   pm_bk:'Bankily', pm_ms:'Masrivi', pm_sd:'Sedad', pm_cs:'Cash', pm_kr:'Karni',
   m_h:'A queue that moves fast.', m_p:'Scan in 0.08s, read live scale weights, switch Retail/Wholesale prices and track Karni customer credit seamlessly.',
   mk1:'Live connected weight-price electronic scales', mk2:'Instant Retail / Semi-Wholesale price toggle', mk3:'Digital Karni customer credit ledger with limits',
   pm_brand:'Al-Baraka Market', pm_pos:'Till #01', pm_sub:'Al-Baraka Market · EAN-13 Scanner &amp; COM1 Scale', pm_t1:'Retail Price', pm_t2:'Wholesale Price',
   pm_hw1:'COM1 SCALE: 1.450 kg × 380 MRU = 551 MRU', pm_hw2:'EAN-13 SCANNER READY',
   pm_srch:'EAN-13 barcode or item name...', pm_c0:'All (6)', pm_c1:'Butchery &amp; Dairy', pm_c2:'Bulk &amp; Drinks',
   mb_1:'WEIGHED 1.45 KG', mn_1:'Minced Beef 1.45kg', ms_1:'لحم مفروم (ميزان)',
   mb_2:'25 KG BAG', mn_2:'Basmati Rice 25 kg', ms_2:'أرز بسمتي ٢٥ كغ',
   mb_3:'5L JUG', mn_3:'Vegetable Oil 5 L', ms_3:'زيت نباتي ٥ لتر',
   mb_4:'900G TIN', mn_4:'Nido Milk 900 g', ms_4:'حليب نيدو ٩٠٠غ',
   mb_5:'PACK ×6', mn_5:'Benichab Water x6', ms_5:'مياه بنشاب ×٦',
   mb_6:'TOP SELLER', mn_6:'Achoura Tea 500g', ms_6:'شاي عشورة ٥٠٠غ',
   pm_tk_h:'Till #01 Cart', pm_tk_sub:'Karni Client: Ould Sidi (Limit 50,000 MRU)', pm_karni_ok:'KARNI OK', pm_net:'NET DUE', pm_pay:'Charge / Add to Karni',
   p_h:'No expired drug leaves your pharmacy.', p_p:'FEFO batch control locks any expired box at checkout and calculates CNAM patient/insurer split automatically.',
   p1:'Instant checkout blocking of expired batches', p2:'Automatic CNAM insurance &amp; patient split calculation', p3:'90/30/7-day expiry alerts and cold-chain tracking (+4°C)',
   pp_brand:'Pharmacie Chinguetti · صيدلية شنقيط', pp_sub:'FEFO Rule Active · Fridge +4.2 °C · CNAM Third-Party', pp_ctrl:'BATCH CONTROL ACTIVE',
   pp_ban:'Click "Augmentin 1g · EXPIRED" below to test the FEFO safety block.',
   pp_srch:'INN, brand name or box scan...', pp_c0:'All (6)', pp_c1:'Antibiotics &amp; Fridge', pp_c2:'Pain &amp; Care',
   pb_m1:'FEFO OK · 08/27', pn_1:'Amoxicillin 500mg', ps_1:'Batch #A-892 · Capsules',
   pb_m2:'FEFO PRIORITY', pn_2:'Paracetamol 1 g', ps_2:'Batch #P-410 · Exp 12/26',
   pb_m3:'BLOCKED · EXPIRED', pn_3:'Augmentin 1g · EXPIRED', ps_3:'Batch #EXP-2024 · Expired', pp_nosale:'SALE BLOCKED',
   pb_m4:'FRIDGE +4.2 °C', pn_4:'Insulin Lantus (Fridge)', ps_4:'Batch #F-112 · Pen 100UI',
   pb_m5:'BATCH #V-304 · OK', pn_5:'Vitamin C 1000mg', ps_5:'فيتامين سي فوار',
   pb_m6:'40 VIALS', pn_6:'Saline Solution', ps_6:'مصل فيزيولوجي معقم',
   pp_tk_h:'Prescription #409', pp_tk_sub:'CNAM Insured · FEFO check active', pp_cnam:'CNAM 70%', pp_pay:'Dispense prescription',
   b_h:'Your business in your pocket.', b_p:'Real-time mobile control across Nouakchott, Nouadhibou and Atar with instant push alerts and remote Z-closing.',
   b1:'Live multi-store dashboard (Bankily, Masrivi, Cash)', b2:'Instant push alerts on discounts, voids &amp; drawer opens', b3:'Remote Z-closing approval against fraud',
   pb_push_h:'Full·Tek Boss · Push', pb_push:'Bankily +18,400 MRU · Tevragh Zeina', pb_net:'LIVE 3-STORE NETWORK', pb_live:'LIVE',
   pb_st1:'Dar El-Karam Resto', pb_st2:'Al-Baraka Market', pb_st3:'Pharma Chinguetti',
   pb_lg_m:'Bankily / Masrivi', pb_lg_c:'Cash MRU',
   pb_s0:'All (3)', pb_s1:'Tevragh Zeina', pb_s2:'Ksar', pb_s3:'Nouadhibou',
   pb_tk:'Receipts issued', pb_ec:'Cash variance', pb_top:'TOP SELLING ITEMS', pb_tod:'TODAY',
   pb_it1:'1/2 Lamb Mechoui', pb_it2:'Basmati Rice 25 kg', pb_hr:'Hourly sales (08:00 → 22:00)',
   pb_a1h:'-15% discount granted · Till 02', pb_a1s:'Ksar · Cashier Ahmed S. · 4m ago',
   pb_a2h:'Cash drawer opened without sale', pb_a2s:'Tevragh Zeina · Drawer B · 18m ago',
   pb_a3h:'Expired batch #EXP-2024 blocked', pb_a3s:'Pharma Ksar · Safety active · 13:45',
   pb_a4h:'LAN → Cloud sync succeeded', pb_a4s:'Nouadhibou · 48 receipts sent · 12:10',
   pb_zh:'Daily cash register closing', pb_zr1:'Expected drawer total', pb_zr2:'Cash counted in drawer', pb_zr3:'Verified Bankily / Masrivi', pb_zr4:'Detected variance', pb_z0:'0 MRU (Perfect)',
   pb_zbtn:'Approve Z-closing remotely', pb_zdone:'Z-closing approved remotely ✔',
   pb_t1:'Overview', pb_t2:'Alerts (4)', pb_t3:'Z-Close',
   o_eye:'Built for Mauritania', o_h:'Internet down? Keep selling.', o_p:'Your tills talk directly over the local network. Nothing is lost: everything syncs seamlessly when connected.',
   o_on:'Internet on', o_off:'Cut Internet', o_r1:'Counter tills', o_r2:'Store local network', o_r3:'Boss Mobile App tracking',
   net_p1:'ACTIVE', net_p2_on:'LOCAL RELAY ACTIVE', net_p2_off:'STANDBY', net_p3_on:'LIVE', net_p3_off:'PENDING SYNC',
   t_eye:'Pricing in ouguiya (MRU)', t_h:'A clear price, no surprises.', t_p:'15-day free trial on your own hardware. No commitment.',
   t_mo:'Monthly', t_yr:'Yearly', t_disc:'SAVE 20%', t_per:'MRU / mo',
   pl1_n:'Start', pl1_1:'1 till, 1 solution of your choice', pl1_2:'Works without Internet', pl1_3:'Bankily, Masrivi, Sedad, Karni', pl1_4:'French, العربية, English',
   pl2_badge:'MOST POPULAR', pl2_n:'Pro', pl2_1:'Up to 4 tills on local LAN', pl2_2:'Boss Mobile App included', pl2_3:'Kitchen KDS, COM1 scale, FEFO &amp; CNAM', pl2_4:'7/7 direct support from Mr. Taha',
   pl3_n:'Enterprise', pl3_1:'Unlimited stores &amp; cities', pl3_2:'On-site installation &amp; training', pl3_3:'Full catalog &amp; price import', pl3_4:'Dedicated hotline Mr. Taha Chouaib',
   c_eye:'Ready to start?', c_h:'Your register installed in 24 hours.', c_p:'Leave your details or call Mr. Taha directly at +222 42 74 42 42 for an in-store demo and 15-day free trial.',
   taha_name:'Mr. Taha Chouaib', taha_role:'Full·Tek POS Mauritania Lead · Nouakchott', taha_wa:'Direct WhatsApp Mr. Taha',
   f_biz:'Business name *', f_biz_ph:'e.g. Al Khaima Restaurant', f_wa:'Your WhatsApp *', f_sol:'Desired solution', c_btn:'Start my free trial',
   opt_r:'Full-Tek Resto', opt_m:'Full-Tek Market', opt_p:'Full-Tek Pharma', opt_b:'Full-Tek Boss (Mobile App)',
   ft_desc:'The smart POS software suite built for restaurants, supermarkets and pharmacies in Mauritania.',
   ft_c1:'Business Solutions', ft_c2:'Infrastructure', ft_c3:'Contact Mr. Taha Chouaib',
   ft_boss:'Full·Tek Boss (Mobile)', ft_off:'Offline resilience', ft_pr:'MRU pricing', ft_sup:'7/7 Support', ft_call:'Direct call', ft_wa_lbl:'WhatsApp:', ft_loc:'Nouakchott · Tevragh Zeina',
   ft_copy:'© 2026 Full·Tek POS Mauritania · All rights reserved', ft_cities:'Nouakchott · Nouadhibou · Atar · Rosso', ft_replay:'Replay intro',
   fab_wa:'Mr. Taha', a_h:'Access my solution', a_p:'Choose your business space to open your register or mobile app.',
   mod_r:'Khaima Room &amp; KDS', mod_m:'Scale &amp; Karni Ledger', mod_p:'FEFO Batches &amp; CNAM', pre_skip:'Skip intro', pre_ready:'READY',
   fb_r_pay:'Paid via {pm} · 80mm ticket sent to kitchen!', kds_ready:'Mark Ready', kds_done:'Dish Ready ✔',
   fb_m_karni:'Added to Karni Ledger (Ould Sidi) · Receipt printed', fb_m_cash:'Charged ({pm}) · Stock updated automatically',
   p_part:'PATIENT SHARE (30% · CNAM 70%)', p_full:'PATIENT TOTAL (100%)',
   fb_p_blocked:'SAFETY BLOCK: Batch #EXP-2024 expired! Sale blocked at till.', fb_p_ok:'FEFO check passed · Box added to prescription.',
   fb_p_pay:'Prescription dispensed ({pm}) · FEFO stock updated',
   form_err:'Please enter your business name and WhatsApp number.',
   form_ok:'<strong>Thank you {name}!</strong> Your request for <strong>{sol}</strong> is ready for Mr. Taha (<span dir="ltr">+222 42 74 42 42</span>).',
   form_wa_btn:'Send directly to Mr. Taha on WhatsApp',
   wa_tpl:'Hello Mr. Taha! My name is {name}. I would like to start my 15-day free trial for {sol}. My WhatsApp: {phone}'
  }
 };

 // 1. PRELOADER
 const preloader = $('#preloader'), preBar = $('#pre-bar-fill'), prePercent = $('#pre-percent'), preMsg = $('#pre-msg'), preSkip = $('#pre-skip-btn');
 let preTimer = null, isPreloaderDone = false, preProgress = 0;
 const preCards = $$('.pre-pos-card');
 const preMsgs = {
   fr: [{at:0,text:'Initialisation Full·Tek Resto · Khaima & KDS...'},{at:26,text:'Chargement Full·Tek Market · Balance & Karni...'},{at:52,text:'Vérification Full·Tek Pharma · FEFO & CNAM...'},{at:76,text:'Synchronisation Full·Tek Boss & LAN Hors ligne...'},{at:96,text:'4 solutions POS prêtes. Bienvenue sur Full·Tek.'}],
   ar: [{at:0,text:'تهيئة Full·Tek Resto · الخيمة والمطبخ...'},{at:26,text:'تحميل Full·Tek Market · الميزان وكارني...'},{at:52,text:'فحص Full·Tek Pharma · FEFO وتأمين CNAM...'},{at:76,text:'تفعيل تطبيق Boss والشبكة المحلية...'},{at:96,text:'جميع أنظمة البيع الأربعة جاهزة.'}],
   en: [{at:0,text:'Initializing Full·Tek Resto · Khaima & KDS...'},{at:26,text:'Loading Full·Tek Market · Scale & Karni...'},{at:52,text:'Checking Full·Tek Pharma · FEFO & CNAM...'},{at:76,text:'Syncing Full·Tek Boss App & Offline LAN...'},{at:96,text:'All 4 POS solutions ready. Welcome.'}]
 };
 const preCardTags = {
   fr: ['POS Resto', 'POS Market', 'POS Pharma', 'Boss App'],
   ar: ['كاشير مطعم', 'كاشير متجر', 'كاشير صيدلية', 'تطبيق المدير'],
   en: ['POS Resto', 'POS Market', 'POS Pharma', 'Boss App']
 };
 function setPreProgress(p, curLang) {
   const val = Math.min(100, Math.max(0, p));
   preProgress = val;
   const l = curLang || lang;
   if (preBar) preBar.style.width = val + '%';
   if (prePercent) prePercent.textContent = Math.round(val) + '%';
   const list = preMsgs[l] || preMsgs.fr;
   for (let i = list.length - 1; i >= 0; i--) { if (val >= list[i].at) { if (preMsg) preMsg.textContent = list[i].text; break; } }
   const tags = preCardTags[l] || preCardTags.fr;
   preCards.forEach((c, idx) => {
     const at = +c.dataset.at, next = +c.dataset.next;
     const isReady = val >= next || val >= 96;
     const isActive = !isReady && val >= at;
     c.classList.toggle('active', isActive);
     c.classList.toggle('ready', isReady);
     const lbl = c.querySelector('.pre-pos-st-lbl');
     if (lbl) lbl.textContent = isReady ? (D[l]?.pre_ready || 'PRÊT') : tags[idx];
   });
 }
 function finishPreloader() {
   if (isPreloaderDone) return; isPreloaderDone = true;
   if (preTimer) clearInterval(preTimer); setPreProgress(100);
   setTimeout(() => { if (preloader) { preloader.classList.add('fade-out'); setTimeout(() => { preloader.style.display = 'none'; }, 750); } }, 450);
 }
 function startPreloader() {
   if (!preloader) return;
   if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) { preloader.style.display = 'none'; return; }
   isPreloaderDone = false; if (preTimer) clearInterval(preTimer);
   const logoWrap = $('#pre-logo-wrap');
   if (logoWrap) { const clone = logoWrap.cloneNode(true); logoWrap.parentNode.replaceChild(clone, logoWrap); }
   const tags = preCardTags[lang] || preCardTags.fr;
   preCards.forEach((c, idx) => {
     c.classList.remove('active', 'ready');
     const lbl = c.querySelector('.pre-pos-st-lbl');
     if (lbl) lbl.textContent = tags[idx];
   });
   preloader.style.display = 'flex'; preloader.classList.remove('fade-out'); setPreProgress(0);
   const startTime = performance.now(), duration = 2800;
   preTimer = setInterval(() => {
     const factor = Math.min(1, (performance.now() - startTime) / duration);
     const eased = factor < 0.5 ? 2 * factor * factor : -1 + (4 - 2 * factor) * factor;
     setPreProgress(eased * 100); if (factor >= 1) { clearInterval(preTimer); finishPreloader(); }
   }, 30);
 }
 if (preSkip) preSkip.onclick = finishPreloader;
 if ($('#btn-replay-preloader')) $('#btn-replay-preloader').onclick = () => { window.scrollTo({ top: 0, behavior: 'smooth' }); startPreloader(); };
 startPreloader();

 // 2. NAV & REVEAL & MODAL
 const nav = $('#nav');
 addEventListener('scroll', () => nav.classList.toggle('scrolled', window.scrollY > 30), { passive: true });
 const burger = $('#burger');
 if (burger) burger.onclick = e => { const o = nav.classList.toggle('open'); e.currentTarget.setAttribute('aria-expanded', o); };
 $$('.nav__links a').forEach(a => a.addEventListener('click', () => { nav.classList.remove('open'); if (burger) burger.setAttribute('aria-expanded', 'false'); }));
 const io = new IntersectionObserver(es => es.forEach(x => { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } }), { threshold: 0.12 });
 $$('[data-reveal]').forEach(el => io.observe(el));
 const modal = $('#access'), openModal = () => { modal.classList.add('open'); $('#ax').focus(); }, closeModal = () => modal.classList.remove('open');
 $$('[data-open-access]').forEach(b => b.addEventListener('click', openModal));
 if ($('#ax')) $('#ax').addEventListener('click', closeModal);
 modal.addEventListener('click', e => { if (e.target === modal) closeModal(); });
 addEventListener('keydown', e => { if (e.key === 'Escape' && modal.classList.contains('open')) closeModal(); });
 $$('.acc-link').forEach(a => a.addEventListener('click', closeModal));
 $$('[data-pick]').forEach(b => b.addEventListener('click', () => { if ($('#fs')) $('#fs').value = b.dataset.pick; }));

 // 3. SIMULATEUR INTERACTIF RESTO (CAISSE + PHOTOS RÉELLES + SALLE KHAIMA + KDS)
 const fmt = n => n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
 const ITEM_I18N = {
   '1/2 Agneau Méchoui': { fr:'1/2 Agneau Méchoui', ar:'نصف خروف مشوي', en:'1/2 Lamb Mechoui' },
   'Thiéboudienne Royal': { fr:'Thiéboudienne Royal', ar:'تيبودين ملكي', en:'Royal Thieboudienne' },
   'Brochettes Chameau': { fr:'Brochettes Chameau', ar:'أسياخ لحم الإبل', en:'Camel Skewers' },
   'Thé Atay 3 Services': { fr:'Thé Atay 3 Services', ar:'صينية أتاي 3 كؤوس', en:'Attaya Tea 3 Services' },
   'Lait Chamelle Frais': { fr:'Lait Chamelle Frais', ar:'لبن الإبل الطازج', en:'Fresh Camel Milk' },
   'Dattes Atar & Bissap': { fr:'Dattes Atar & Bissap', ar:'تمر أطار وكركديه', en:'Atar Dates & Bissap' },
   'Viande Hachée (1,45kg)': { fr:'Viande Hachée (1,45kg)', ar:'لحم مفروم (1.45 كغ)', en:'Minced Beef (1.45kg)' },
   'Sac Riz Basmati 25 kg': { fr:'Sac Riz Basmati 25 kg', ar:'أرز بسمتي 25 كغ', en:'Basmati Rice 25 kg' },
   'Huile Végétale 5 L': { fr:'Huile Végétale 5 L', ar:'زيت نباتي 5 لتر', en:'Vegetable Oil 5 L' },
   'Lait Nido Poudre 900g': { fr:'Lait Nido 900 g', ar:'حليب نيدو 900 غ', en:'Nido Milk 900 g' },
   'Pack Eau Benichab x6': { fr:'Pack Benichab x6', ar:'مياه بنشاب (×6)', en:'Benichab Water x6' },
   'Thé Achoura 500g': { fr:'Thé Achoura 500g', ar:'شاي عاشوراء 500 غ', en:'Achoura Tea 500g' },
   'Amoxicilline 500mg': { fr:'Amoxicilline 500mg', ar:'أموكسيسيلين 500 ملغ', en:'Amoxicillin 500mg' },
   'Paracétamol 1 g': { fr:'Paracétamol 1 g', ar:'باراسيتامول 1 غ', en:'Paracetamol 1 g' },
   'Insuline Lantus': { fr:'Insuline Lantus', ar:'أنسولين لانتوس', en:'Insulin Lantus' },
   'Vitamine C 1000mg': { fr:'Vitamine C 1000mg', ar:'فيتامين سي 1000 ملغ', en:'Vitamin C 1000mg' },
   'Sérum Physiologique': { fr:'Sérum Physiologique', ar:'مصل فيزيولوجي معقم', en:'Saline Solution' }
 };
 const trItem = n => (ITEM_I18N[n] && ITEM_I18N[n][lang]) || n;
 const trPay = p => {
   const map = { 'Bankily':'pm_bk', 'Masrivi':'pm_ms', 'Sedad':'pm_sd', 'Cash MRU':'pm_cs', 'Carnet Karni':'pm_kr' };
   return (map[p] && D[lang][map[p]]) || p;
 };
 let rPay = 'Bankily', rTblKey = 'rk_2h';
 let rItems = [
   { name: '1/2 Agneau Méchoui', qty: 1, price: 2800, img: 'assets/products/resto_mechoui.jpg' },
   { name: 'Thé Atay 3 Services', qty: 1, price: 150, img: 'assets/products/resto_atay.jpg' },
   { name: 'Dattes Atar & Bissap', qty: 1, price: 250, img: 'assets/products/resto_dattes.jpg' }
 ];
 function paintResto() {
   $$('#resto .pr-tag[data-p]').forEach(el => { el.innerHTML = `<span dir="ltr">${fmt(+el.dataset.p)}</span> ${D[lang].cur}`; });
   const box = $('#r-tk-list'); if (!box) return;
   let sum = 0;
   box.innerHTML = rItems.map(it => {
     sum += it.qty * it.price;
     return `<div class="tk-row"><div class="tk-row-left"><img class="tk-thumb" src="${it.img}" alt=""><span class="tk-qty">${it.qty}</span><span class="tk-row-title">${trItem(it.name)}</span></div><b><span dir="ltr">${fmt(it.qty * it.price)}</span></b></div>`;
   }).join('');
   $('#r-total').innerHTML = `<span dir="ltr">${fmt(sum)}</span> ${D[lang].cur}`;
 }
 paintResto();
 $$('[data-add-resto]').forEach(btn => {
   btn.onclick = () => {
     const name = btn.dataset.addResto, price = +btn.dataset.price, img = btn.dataset.img || 'assets/products/resto_mechoui.jpg';
     const ex = rItems.find(x => x.name === name);
     if (ex) ex.qty++; else rItems.push({ name, qty: 1, price, img });
     paintResto();
     $('#r-fb').textContent = '';
   };
 });
 $$('[data-rcat]').forEach(pill => pill.onclick = () => {
   const cat = pill.dataset.rcat;
   $$('[data-rcat]').forEach(x => x.setAttribute('aria-pressed', x === pill));
   $$('[data-rcat-item]').forEach(card => {
     card.style.display = (cat === 'all' || card.dataset.rcatItem === cat) ? 'flex' : 'none';
   });
 });
 $$('[data-rpm]').forEach(b => b.onclick = () => {
   rPay = b.dataset.rpm;
   $$('[data-rpm]').forEach(x => x.setAttribute('aria-pressed', x === b));
 });
 $('#r-pay-btn').onclick = () => {
   $('#r-fb').textContent = D[lang].fb_r_pay.replace('{pm}', trPay(rPay));
 };
 $$('[data-rtab]').forEach(t => t.onclick = () => {
   $$('[data-rtab]').forEach(x => x.setAttribute('aria-selected', x === t));
   ['r-pos', 'r-salle', 'r-kds'].forEach(id => {
     const el = $('#' + id);
     el.classList.toggle('active', id === t.dataset.rtab);
   });
 });
 $$('[data-pick-tbl]').forEach(k => k.onclick = () => {
   rTblKey = k.dataset.pickTbl;
   $('#r-tbl-name').textContent = D[lang][rTblKey] || k.dataset.pickTbl;
   $$('[data-rtab]')[0].click();
 });
 $$('[data-kds-btn]').forEach(b => b.onclick = () => {
   b.classList.toggle('done');
   b.textContent = b.classList.contains('done') ? D[lang].kds_done : D[lang].kds_ready;
 });

 // 4. SIMULATEUR INTERACTIF MARKET (DÉTAIL/DEMI-GROS + PHOTOS RÉELLES + BALANCE + KARNI)
 let mMode = 'd', mPay = 'Cash MRU';
 let mItems = [
   { name: 'Viande Hachée (1,45kg)', qty: 1, d: 551, g: 510, img: 'assets/products/market_viande.jpg' },
   { name: 'Sac Riz Basmati 25 kg', qty: 1, d: 980, g: 910, img: 'assets/products/market_riz.jpg' }
 ];
 function paintMarket() {
   $$('[data-madd]').forEach(b => {
     const p = mMode === 'd' ? b.dataset.d : b.dataset.g;
     b.querySelector('.m-price').innerHTML = `<span dir="ltr">${fmt(+p)}</span> ${D[lang].cur}`;
   });
   const box = $('#m-tk-list'); if (!box) return;
   let sum = 0;
   box.innerHTML = mItems.map(it => {
     const u = mMode === 'd' ? it.d : it.g;
     sum += it.qty * u;
     return `<div class="tk-row"><div class="tk-row-left"><img class="tk-thumb" src="${it.img}" alt=""><span class="tk-qty">${it.qty}</span><span class="tk-row-title">${trItem(it.name)}</span></div><b><span dir="ltr">${fmt(it.qty * u)}</span></b></div>`;
   }).join('');
   $('#m-total').innerHTML = `<span dir="ltr">${fmt(sum)}</span> ${D[lang].cur}`;
 }
 paintMarket();
 $('#m-btn-detail').onclick = () => { mMode = 'd'; $('#m-btn-detail').setAttribute('aria-pressed', 'true'); $('#m-btn-gros').setAttribute('aria-pressed', 'false'); paintMarket(); };
 $('#m-btn-gros').onclick = () => { mMode = 'g'; $('#m-btn-gros').setAttribute('aria-pressed', 'true'); $('#m-btn-detail').setAttribute('aria-pressed', 'false'); paintMarket(); };
 $$('[data-madd]').forEach(btn => {
   btn.onclick = () => {
     const name = btn.dataset.madd, d = +btn.dataset.d, g = +btn.dataset.g, img = btn.dataset.img || 'assets/products/market_viande.jpg';
     const ex = mItems.find(x => x.name === name);
     if (ex) ex.qty++; else mItems.push({ name, qty: 1, d, g, img });
     paintMarket(); $('#m-fb').textContent = '';
   };
 });
 $$('[data-mcat]').forEach(pill => pill.onclick = () => {
   const cat = pill.dataset.mcat;
   $$('[data-mcat]').forEach(x => x.setAttribute('aria-pressed', x === pill));
   $$('[data-mcat-item]').forEach(card => {
     card.style.display = (cat === 'all' || card.dataset.mcatItem === cat) ? 'flex' : 'none';
   });
 });
 $$('[data-mpm]').forEach(b => b.onclick = () => { mPay = b.dataset.mpm; $$('[data-mpm]').forEach(x => x.setAttribute('aria-pressed', x === b)); });
 $('#m-pay-btn').onclick = () => {
   $('#m-fb').textContent = mPay === 'Carnet Karni'
     ? D[lang].fb_m_karni
     : D[lang].fb_m_cash.replace('{pm}', trPay(mPay));
 };

 // 5. SIMULATEUR INTERACTIF PHARMA (FEFO + PHOTOS RÉELLES + BLOCAGE EXPIRÉ + CNAM)
 let pCnam = true, pPay = 'Bankily';
 let pItems = [
   { name: 'Amoxicilline 500mg', qty: 1, price: 185, img: 'assets/products/pharma_amox.jpg' },
   { name: 'Paracétamol 1 g', qty: 1, price: 95, img: 'assets/products/pharma_para.jpg' }
 ];
 function paintPharma() {
   $$('#pharma .pr-tag[data-p]').forEach(el => { el.innerHTML = `<span dir="ltr">${fmt(+el.dataset.p)}</span> ${D[lang].cur}`; });
   const box = $('#p-tk-list'); if (!box) return;
   let sum = 0;
   box.innerHTML = pItems.map(it => {
     sum += it.qty * it.price;
     return `<div class="tk-row"><div class="tk-row-left"><img class="tk-thumb" src="${it.img}" alt=""><span class="tk-qty">${it.qty}</span><span class="tk-row-title">${trItem(it.name)}</span></div><b><span dir="ltr">${fmt(it.qty * it.price)}</span></b></div>`;
   }).join('');
   const final = pCnam ? Math.round(sum * 0.3) : sum;
   $('#p-sub-lbl').textContent = pCnam ? D[lang].p_part : D[lang].p_full;
   $('#p-total').innerHTML = `<span dir="ltr">${fmt(final)}</span> ${D[lang].cur}`;
 }
 paintPharma();
 $('#p-cnam-btn').onclick = () => { pCnam = !pCnam; $('#p-cnam-btn').setAttribute('aria-pressed', pCnam); paintPharma(); };
 $$('[data-padd]').forEach(btn => {
   btn.onclick = () => {
     const bnr = $('#p-banner');
     if (btn.dataset.exp === 'blocked') {
       bnr.classList.add('danger');
       bnr.innerHTML = `<span>${D[lang].fb_p_blocked}</span>`;
       $('#p-fb').textContent = '';
       return;
     }
     bnr.classList.remove('danger');
     bnr.innerHTML = `<span>${D[lang].fb_p_ok}</span>`;
     const name = btn.dataset.padd, price = +btn.dataset.price, img = btn.dataset.img || 'assets/products/pharma_amox.jpg';
     const ex = pItems.find(x => x.name === name);
     if (ex) ex.qty++; else pItems.push({ name, qty: 1, price, img });
     paintPharma(); $('#p-fb').textContent = '';
   };
 });
 $$('[data-pcat]').forEach(pill => pill.onclick = () => {
   const cat = pill.dataset.pcat;
   $$('[data-pcat]').forEach(x => x.setAttribute('aria-pressed', x === pill));
   $$('[data-pcat-item]').forEach(card => {
     card.style.display = (cat === 'all' || card.dataset.pcatItem === cat) ? 'flex' : 'none';
   });
 });
 $$('[data-ppm]').forEach(b => b.onclick = () => { pPay = b.dataset.ppm; $$('[data-ppm]').forEach(x => x.setAttribute('aria-pressed', x === b)); });
 $('#p-pay-btn').onclick = () => { $('#p-fb').textContent = D[lang].fb_p_pay.replace('{pm}', trPay(pPay)); };

 // 6. APP MOBILE BOSS
 let bShop = 'all';
 const BOSS_STORES = {
   all:  { lbl: { fr: "Chiffre d'affaires · 3 boutiques", ar: "إجمالي المبيعات · 3 فروع", en: "Revenue · 3 stores" }, ca: "486 900", delta: "+14,2%", pm: "54%", pc: "46%", t: "312", bars: [38, 56, 75, 64, 92, 82, 100] },
   tz:   { lbl: { fr: "Boutique Tevragh Zeina", ar: "فرع تفرغ زينة", en: "Tevragh Zeina Store" }, ca: "214 500", delta: "+18,5%", pm: "62%", pc: "38%", t: "142", bars: [45, 70, 80, 60, 95, 88, 92] },
   ksar: { lbl: { fr: "Boutique Ksar Centre", ar: "فرع لكصر", en: "Ksar Center Store" }, ca: "158 200", delta: "+9,8%",  pm: "48%", pc: "52%", t: "104", bars: [30, 50, 68, 72, 80, 74, 85] },
   ndb:  { lbl: { fr: "Boutique Nouadhibou", ar: "فرع نواذيبو", en: "Nouadhibou Store" }, ca: "114 200", delta: "+11,4%", pm: "45%", pc: "55%", t: "66",  bars: [25, 42, 60, 55, 78, 70, 88] }
 };
 function paintBossShop() {
   const d = BOSS_STORES[bShop]; if (!d) return;
   $('#b-store-lbl').textContent = d.lbl[lang] || d.lbl.fr;
   $('#b-ca').innerHTML = `<span dir="ltr">${d.ca}</span> ${D[lang].cur}`;
   $('#b-delta').textContent = d.delta;
   $('#b-pm').textContent = d.pm; $('#b-pc').textContent = d.pc; $('#b-bar-m').style.width = d.pm; $('#b-tickets').textContent = d.t;
   const bars = $$('#b-bars i'); d.bars.forEach((h, i) => { if (bars[i]) bars[i].style.height = h + '%'; });
 }
 $$('.shop-chip').forEach(chip => chip.onclick = () => {
   bShop = chip.dataset.shop;
   $$('.shop-chip').forEach(c => c.setAttribute('aria-pressed', c === chip));
   paintBossShop();
 });
 $$('.boss-tab').forEach(tab => tab.onclick = () => {
   $$('.boss-tab').forEach(t => t.setAttribute('aria-selected', t === tab));
   $$('.boss-pane').forEach(p => p.classList.toggle('active', p.id === tab.dataset.btab));
 });
 if ($('#btn-z-approve')) $('#btn-z-approve').onclick = function() {
   this.classList.toggle('done');
   $('#btn-z-txt').textContent = this.classList.contains('done') ? D[lang].pb_zdone : D[lang].pb_zbtn;
 };

 // 7. FACTURATION + HORS LIGNE + FORMULAIRE WHATSAPP M. TAHA (+222 42 74 42 42)
 const btnMonthly = $('#btn-monthly'), btnYearly = $('#btn-yearly');
 function updatePricing(yearly) {
   if (btnMonthly) btnMonthly.setAttribute('aria-pressed', !yearly);
   if (btnYearly) btnYearly.setAttribute('aria-pressed', yearly);
   $$('.price-val').forEach(el => { el.textContent = yearly ? el.dataset.y : el.dataset.m; });
 }
 if (btnMonthly) btnMonthly.onclick = () => updatePricing(false);
 if (btnYearly) btnYearly.onclick = () => updatePricing(true);

 const netMsgs = {
   fr: { on: 'Toutes les ventes sont enregistrées et synchronisées en direct avec le cloud Full-Tek.', off: 'Internet est coupé : les caisses continuent de vendre et d\'imprimer en réseau local. 142 ventes stockées en toute sécurité.' },
   ar: { on: 'يتم تسجيل جميع المبيعات ومزامنتها مباشرة مع سحابة Full-Tek.', off: 'الإنترنت مقطوع: الصناديق تواصل البيع والطباعة عبر الشبكة المحلية. تم حفظ 142 عملية بأمان تام.' },
   en: { on: 'Every sale is recorded and synced live with the Full-Tek cloud.', off: 'Internet is down: tills keep selling and printing over the local LAN. 142 sales safely stored.' }
 };
 const paintNet = () => {
   const isOff = (net === 'off'), d = D[lang];
   if ($('#netmsg')) $('#netmsg').textContent = netMsgs[lang][net];
   if ($('#p1')) $('#p1').textContent = d.net_p1;
   if ($('#p2')) { $('#p2').textContent = isOff ? d.net_p2_on : d.net_p2_off; $('#p2').className = 'net-pill' + (isOff ? '' : ' warn'); }
   if ($('#p3')) { $('#p3').textContent = isOff ? d.net_p3_off : d.net_p3_on; $('#p3').className = 'net-pill' + (isOff ? ' bad' : ''); }
   $$('[data-net]').forEach(b => b.setAttribute('aria-pressed', b.dataset.net === net));
 };
 $$('[data-net]').forEach(b => b.onclick = () => { net = b.dataset.net; paintNet(); });

 const form = $('#form'), okBox = $('#ok');
 if (form) {
   form.addEventListener('submit', e => {
     e.preventDefault();
     const sel = $('#fs'), name = $('#fn').value.trim(), phone = $('#fp').value.trim(), sol = (sel && sel.options[sel.selectedIndex]) ? sel.options[sel.selectedIndex].text : (sel ? sel.value : ''), d = D[lang];
     if (!name || !phone) { alert(d.form_err); return; }
     const waText = (d.wa_tpl || D.fr.wa_tpl).replace('{name}', name).replace('{sol}', sol).replace('{phone}', phone);
     const waUrl = `https://wa.me/22242744242?text=${encodeURIComponent(waText)}`;
     okBox.style.display = 'block';
     okBox.innerHTML = `<div style="display:flex;align-items:flex-start;gap:12px"><svg width="22" height="22" viewBox="0 0 20 20" fill="currentColor" style="flex:none;color:var(--market)"><path fill-rule="evenodd" d="M16.704 4.153a.75.75 0 0 1 .143 1.052l-8 10.5a.75.75 0 0 1-1.127.075l-4.5-4.5a.75.75 0 0 1 1.06-1.06l3.894 3.893 7.48-9.817a.75.75 0 0 1 1.05-.143Z" clip-rule="evenodd"/></svg><div><div>${d.form_ok.replace('{name}', name).replace('{sol}', sol)}</div><a class="wa-btn" href="${waUrl}" target="_blank" rel="noopener">${d.form_wa_btn}</a></div></div>`;
   });
 }

 $$('[data-lang]').forEach(b => b.onclick = () => {
   lang = b.dataset.lang; const d = D[lang];
   document.documentElement.lang = lang; document.documentElement.dir = d.dir;
   if (d.doc_title) document.title = d.doc_title;
   $$('[data-lang]').forEach(x => x.setAttribute('aria-pressed', x === b));
   $$('[data-i]').forEach(e => { const k = e.dataset.i; if (d[k] !== undefined) e.innerHTML = d[k]; });
   $$('[data-i-ph]').forEach(e => { const k = e.dataset.iPh; if (d[k] !== undefined) e.placeholder = d[k]; });
   if ($('#r-tbl-name')) $('#r-tbl-name').textContent = d[rTblKey] || $('#r-tbl-name').textContent;
   $$('[data-kds-btn]').forEach(k => { k.textContent = k.classList.contains('done') ? d.kds_done : d.kds_ready; });
   if ($('#btn-z-txt') && $('#btn-z-approve')) $('#btn-z-txt').textContent = $('#btn-z-approve').classList.contains('done') ? d.pb_zdone : d.pb_zbtn;
   setPreProgress(isPreloaderDone ? 100 : preProgress, lang);
   paintResto();
   paintMarket();
   paintPharma();
   paintBossShop();
   paintNet();
 });
})();
</script>
</body>
</html>
"""

def inline_local_assets(html: str) -> str:
    """Embed local product images and SVG logos as Base64 data URIs so downloaded HTML is 100% standalone."""
    pattern = re.compile(r"(?:assets/products|Logos_Full-Tek/Modele_11_Pilules)/[^\"'\s>]+")
    cache: dict[str, str] = {}

    def _to_data_uri(match: re.Match[str]) -> str:
        rel = match.group(0)
        if rel not in cache:
            fp = ROOT / rel
            if not fp.is_file():
                raise FileNotFoundError(f"Missing local asset: {fp}")
            mime = "image/svg+xml" if fp.suffix.lower() == ".svg" else (mimetypes.guess_type(fp.name)[0] or "image/jpeg")
            b64 = base64.b64encode(fp.read_bytes()).decode("ascii")
            cache[rel] = f"data:{mime};base64,{b64}"
        return cache[rel]

    return pattern.sub(_to_data_uri, html)


HTML = inline_local_assets(
    HTML_TEMPLATE
    .replace("__L__", L)
    .replace("__LOGO_RESTO__", dark_logo_svg("resto", "RESTO"))
    .replace("__LOGO_MARKET__", dark_logo_svg("market", "MARKET"))
    .replace("__LOGO_PHARMA__", dark_logo_svg("pharma", "PHARMA"))
    .replace("__LOGO_BOSS__", dark_logo_svg("boss", "BOSS"))
    .replace("__PRE_RESTO__", dark_logo_svg("resto", "RESTO", "ft-logo-svg pre-pos-svg"))
    .replace("__PRE_MARKET__", dark_logo_svg("market", "MARKET", "ft-logo-svg pre-pos-svg"))
    .replace("__PRE_PHARMA__", dark_logo_svg("pharma", "PHARMA", "ft-logo-svg pre-pos-svg"))
    .replace("__PRE_BOSS__", dark_logo_svg("boss", "BOSS", "ft-logo-svg pre-pos-svg"))
    .replace("__MINI_RESTO__", mini_emblem_svg("resto"))
    .replace("__MINI_MARKET__", mini_emblem_svg("market"))
    .replace("__MINI_PHARMA__", mini_emblem_svg("pharma"))
    .replace("__MINI_BOSS__", mini_emblem_svg("boss"))
)

(ROOT / "index.html").write_text(HTML, encoding="utf-8")
(ROOT / "Full-Tek_Accueil_Interactif_Prototype.html").write_text(HTML, encoding="utf-8")
print("OK: Page avec numero de M. Taha (42 74 42 42) + 4 terminaux POS mauritaniens interactifs generee !")
