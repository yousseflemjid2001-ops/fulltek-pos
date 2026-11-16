# -*- coding: utf-8 -*-
"""
Generates the upgraded High-End Interactive Landing Page for FULL-TEK POS:
- Official Model 11 ("Pilules") Master Logo & 4 Official Business Line Logos (Resto, Market, Pharma, Boss)
- Animated SVG Slide-In Pill Logos in cards, navbar, and POS topbar
- Hardware POS Frame + 80mm Thermal Printer + Live Full-Tek Boss Mobile Sync Counter
- Interactive Bankily/Masrivi QR Payment Feedback + FEFO Security Blocker
- Interactive Cloud + Edge LAN Outage Topology Simulator
- Interactive MRU ROI / Anti-Fraud Savings Calculator
- Mouse-tracking Spotlight Glow on premium glassmorphic cards
"""

HTML_CONTENT = r"""<!DOCTYPE html>
<html lang="fr" dir="ltr" data-site-mode="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Full-Tek — L'Écosystème POS Cloud & Offline LAN N°1 en Mauritanie</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@500;600;700;800;900&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Space+Grotesk:wght@600;700;800&family=JetBrains+Mono:wght@500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --petrol: #264653;
      --petrol-deep: #060B10;
      --petrol-surface: #0C151E;
      --ochre: #E9A23B;
      --ochre-bright: #F7B955;
      --resto: #E4572E;
      --market: #2E9E5B;
      --pharma: #1B8FD9;
      --boss: #C99A2E;
      --emerald: #10B981;
      --danger: #EF4444;
      --text-main: #F8FAFC;
      --text-muted: #94A3B8;
      --font-sans: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      --font-display: 'Space Grotesk', 'Plus Jakarta Sans', sans-serif;
      --font-mono: 'JetBrains Mono', monospace;
    }

    html[dir="rtl"] {
      --font-sans: 'Cairo', sans-serif;
      --font-display: 'Cairo', sans-serif;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }

    html {
      scroll-behavior: smooth;
      background-color: var(--petrol-deep);
      color: var(--text-main);
      font-family: var(--font-sans);
      overflow-x: hidden;
    }

    body {
      background-color: var(--petrol-deep);
      color: var(--text-main);
      overflow-x: hidden;
      position: relative;
      line-height: 1.55;
      -webkit-font-smoothing: antialiased;
    }

    /* Scroll Progress Bar */
    .scroll-progress {
      position: fixed;
      top: 0;
      left: 0;
      height: 3px;
      width: 0%;
      background: linear-gradient(90deg, var(--ochre), var(--resto), var(--emerald));
      z-index: 2500;
      box-shadow: 0 0 12px rgba(233, 162, 59, 0.7);
      transition: width 0.08s linear;
    }

    /* Ambient Stage */
    .ambient-stage {
      position: fixed;
      inset: 0;
      pointer-events: none;
      z-index: 0;
      overflow: hidden;
    }

    .aurora-orb {
      position: absolute;
      border-radius: 50%;
      filter: blur(115px);
      opacity: 0.4;
      animation: orbFloat 19s ease-in-out infinite alternate;
    }

    .aurora-1 {
      width: 700px; height: 700px;
      background: radial-gradient(circle, rgba(38, 70, 83, 0.85) 0%, rgba(16, 185, 129, 0.16) 60%, transparent 100%);
      top: -240px; left: -160px;
    }

    .aurora-2 {
      width: 600px; height: 600px;
      background: radial-gradient(circle, rgba(233, 162, 59, 0.24) 0%, rgba(228, 87, 46, 0.12) 60%, transparent 100%);
      top: 90px; right: -180px;
      animation-delay: -6s;
    }

    .aurora-3 {
      width: 720px; height: 520px;
      background: radial-gradient(circle, rgba(27, 143, 217, 0.16) 0%, rgba(38, 70, 83, 0.35) 65%, transparent 100%);
      bottom: -200px; left: 25%;
      animation-delay: -11s;
    }

    @keyframes orbFloat {
      0% { transform: translate3d(0, 0, 0) scale(1); }
      50% { transform: translate3d(38px, 24px, 0) scale(1.06); }
      100% { transform: translate3d(-26px, 48px, 0) scale(0.96); }
    }

    .arch-grid {
      position: absolute;
      inset: 0;
      background-image:
        linear-gradient(to right, rgba(255,255,255,0.028) 1px, transparent 1px),
        linear-gradient(to bottom, rgba(255,255,255,0.028) 1px, transparent 1px);
      background-size: 64px 64px;
      mask-image: radial-gradient(ellipse 85% 65% at 50% 25%, #000 35%, transparent 100%);
      -webkit-mask-image: radial-gradient(ellipse 85% 65% at 50% 25%, #000 35%, transparent 100%);
    }

    .grid-beam-h {
      position: absolute;
      height: 1px;
      width: 240px;
      background: linear-gradient(90deg, transparent, var(--ochre), transparent);
      top: 256px;
      left: -240px;
      animation: beamHoriz 9s cubic-bezier(0.4, 0, 0.2, 1) infinite;
      box-shadow: 0 0 12px var(--ochre);
    }

    .grid-beam-h.beam-2 {
      top: 512px;
      background: linear-gradient(90deg, transparent, var(--emerald), transparent);
      animation-delay: 4.5s;
      animation-duration: 11s;
    }

    @keyframes beamHoriz {
      0% { left: -240px; opacity: 0; }
      15% { opacity: 0.9; }
      85% { opacity: 0.9; }
      100% { left: 105%; opacity: 0; }
    }

    /* Official Model 11 Pill Slide Animation */
    @keyframes ftPillSlide {
      0%, 100% { transform: translateX(0); opacity: 1; }
      45% { transform: translateX(4px); opacity: 0.92; }
      50% { transform: translateX(4px); opacity: 0.92; }
    }
    .ft-p1 { animation: ftPillSlide 3.8s cubic-bezier(0.2, 0.8, 0.2, 1) infinite; }
    .ft-p2 { animation: ftPillSlide 3.8s cubic-bezier(0.2, 0.8, 0.2, 1) infinite 0.16s; }
    .ft-p3 { animation: ftPillSlide 3.8s cubic-bezier(0.2, 0.8, 0.2, 1) infinite 0.32s; }

    /* Navbar */
    .nav-wrapper {
      position: sticky;
      top: 14px;
      z-index: 1000;
      max-width: 1380px;
      margin: 0 auto;
      padding: 0 24px;
    }

    .navbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 14px;
      padding: 9px 18px;
      background: rgba(10, 18, 26, 0.84);
      backdrop-filter: blur(22px) saturate(165%);
      -webkit-backdrop-filter: blur(22px) saturate(165%);
      border: 1px solid rgba(255, 255, 255, 0.11);
      border-radius: 999px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.45), inset 0 1px 0 rgba(255, 255, 255, 0.12);
    }

    .brand-link {
      display: flex;
      align-items: center;
      gap: 10px;
      text-decoration: none;
      color: var(--text-main);
      flex-shrink: 0;
    }

    .nav-links {
      display: flex;
      align-items: center;
      gap: 4px;
      list-style: none;
    }

    .nav-links a {
      color: #CBD5E1;
      text-decoration: none;
      font-size: 0.84rem;
      font-weight: 600;
      padding: 8px 13px;
      border-radius: 999px;
      white-space: nowrap;
      transition: all 0.22s ease;
    }

    .nav-links a:hover {
      color: #FFFFFF;
      background: rgba(255, 255, 255, 0.08);
    }

    .nav-actions {
      display: flex;
      align-items: center;
      gap: 8px;
      flex-shrink: 0;
    }

    .lang-pill {
      display: inline-flex;
      align-items: center;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 999px;
      padding: 3px;
    }

    .lang-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      font-size: 0.72rem;
      font-weight: 700;
      padding: 5px 9px;
      border-radius: 999px;
      cursor: pointer;
      transition: all 0.2s ease;
      font-family: var(--font-sans);
      white-space: nowrap;
    }

    .lang-btn.active {
      background: var(--ochre);
      color: #081017;
      box-shadow: 0 2px 10px rgba(233, 162, 59, 0.4);
    }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      font-family: var(--font-sans);
      font-size: 0.83rem;
      font-weight: 700;
      padding: 9px 15px;
      border-radius: 999px;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
      text-decoration: none;
      border: 1px solid transparent;
    }

    .btn svg { width: 15px; height: 15px; flex-shrink: 0; }

    .btn-ghost {
      background: rgba(255, 255, 255, 0.05);
      color: #E2E8F0;
      border-color: rgba(255, 255, 255, 0.12);
    }

    .btn-ghost:hover {
      background: rgba(255, 255, 255, 0.11);
      border-color: rgba(255, 255, 255, 0.26);
      transform: translateY(-1px);
    }

    .btn-boss-pill {
      background: rgba(201, 154, 46, 0.14);
      color: #FDE68A;
      border-color: rgba(233, 162, 59, 0.4);
    }

    .btn-boss-pill:hover {
      background: rgba(233, 162, 59, 0.24);
      transform: translateY(-1px);
    }

    .btn-primary {
      background: linear-gradient(135deg, #F7B955 0%, #E9A23B 55%, #D48820 100%);
      color: #081017;
      font-weight: 800;
      box-shadow: 0 8px 24px rgba(233, 162, 59, 0.35), inset 0 1px 0 rgba(255, 255, 255, 0.45);
      position: relative;
      overflow: hidden;
    }

    .btn-primary::after {
      content: '';
      position: absolute;
      top: 0; left: -100%;
      width: 60%; height: 100%;
      background: linear-gradient(90deg, transparent, rgba(255,255,255,0.45), transparent);
      transform: skewX(-20deg);
      animation: btnSheen 4.5s infinite;
    }

    @keyframes btnSheen {
      0%, 70% { left: -100%; }
      100% { left: 160%; }
    }

    .btn-primary:hover {
      transform: translateY(-2px);
      box-shadow: 0 12px 30px rgba(233, 162, 59, 0.52);
    }

    /* Container & Hero */
    .container {
      max-width: 1380px;
      margin: 0 auto;
      padding: 0 24px;
      position: relative;
      z-index: 2;
    }

    .hero {
      padding: 40px 0 36px;
    }

    .hero-top-grid {
      display: grid;
      grid-template-columns: 1.08fr 0.92fr;
      gap: 40px;
      align-items: center;
      margin-bottom: 34px;
    }

    .eyebrow-badge {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 6px 14px 6px 8px;
      border-radius: 999px;
      background: rgba(38, 70, 83, 0.45);
      border: 1px solid rgba(233, 162, 59, 0.35);
      margin-bottom: 20px;
    }

    .eyebrow-pulse {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(16, 185, 129, 0.18);
      color: #34D399;
      font-size: 0.7rem;
      font-weight: 800;
      padding: 3px 9px;
      border-radius: 999px;
      letter-spacing: 0.04em;
      text-transform: uppercase;
    }

    .live-dot {
      width: 7px; height: 7px;
      border-radius: 50%;
      background: #10B981;
      box-shadow: 0 0 10px #10B981;
      animation: pulseGlow 1.8s infinite;
    }

    @keyframes pulseGlow {
      0%, 100% { transform: scale(1); opacity: 1; }
      50% { transform: scale(1.45); opacity: 0.55; }
    }

    .eyebrow-text { font-size: 0.79rem; font-weight: 600; color: #E2E8F0; }

    .hero-title {
      font-family: var(--font-display);
      font-size: clamp(2.4rem, 4vw, 3.75rem);
      font-weight: 800;
      line-height: 1.06;
      letter-spacing: -0.035em;
      margin-bottom: 18px;
      color: #FFFFFF;
    }

    .hero-title .gradient-ochre {
      background: linear-gradient(135deg, #FFF3D1 0%, #F7B955 45%, #E9A23B 85%, #E4572E 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .hero-lead {
      font-size: 1.04rem;
      color: #94A3B8;
      max-width: 610px;
      margin-bottom: 26px;
      line-height: 1.66;
    }

    .hero-cta-row {
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 14px;
    }

    .btn-xl { padding: 14px 26px; font-size: 0.94rem; }

    /* Telemetry Card */
    .hero-telemetry-card {
      background: linear-gradient(160deg, rgba(19, 34, 46, 0.88) 0%, rgba(10, 18, 26, 0.94) 100%);
      border: 1px solid rgba(255, 255, 255, 0.11);
      border-radius: 24px;
      padding: 22px;
      box-shadow: 0 24px 60px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.12);
    }

    .telemetry-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding-bottom: 14px;
      margin-bottom: 16px;
      border-bottom: 1px solid rgba(255,255,255,0.08);
    }

    .telemetry-title {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 0.83rem;
      font-weight: 700;
      color: #E2E8F0;
    }

    .ecg-line {
      stroke-dasharray: 200;
      stroke-dashoffset: 200;
      animation: ecgSweep 3s linear infinite;
    }

    @keyframes ecgSweep {
      0% { stroke-dashoffset: 200; }
      50% { stroke-dashoffset: 0; }
      100% { stroke-dashoffset: -200; }
    }

    .telemetry-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 11px;
      margin-bottom: 14px;
    }

    .telemetry-metric {
      background: rgba(255, 255, 255, 0.035);
      border: 1px solid rgba(255, 255, 255, 0.07);
      border-radius: 15px;
      padding: 13px 15px;
      transition: all 0.25s ease;
    }

    .telemetry-metric:hover {
      border-color: rgba(233, 162, 59, 0.45);
      transform: translateY(-2px);
    }

    .metric-val {
      font-family: var(--font-display);
      font-size: 1.5rem;
      font-weight: 800;
      color: #FFFFFF;
      display: flex;
      align-items: baseline;
      gap: 4px;
    }

    .metric-unit { font-size: 0.78rem; font-weight: 700; color: var(--ochre); }
    .metric-lbl { font-size: 0.74rem; color: #94A3B8; margin-top: 2px; }

    /* Brand Logos Strip inside Suite Switcher Bar */
    .suite-switcher-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 14px;
      background: rgba(13, 23, 32, 0.92);
      border: 1px solid rgba(255, 255, 255, 0.12);
      padding: 12px 16px;
      border-radius: 20px;
      margin-bottom: 18px;
      box-shadow: 0 16px 40px rgba(0,0,0,0.35);
    }

    .suite-tabs { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }

    .suite-tab {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 8px 14px;
      border-radius: 13px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: #CBD5E1;
      font-family: var(--font-sans);
      font-size: 0.83rem;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .suite-tab:hover { background: rgba(255, 255, 255, 0.09); transform: translateY(-1px); }

    .suite-tab.active[data-mode="resto"] {
      background: linear-gradient(135deg, rgba(228, 87, 46, 0.25), rgba(228, 87, 46, 0.08));
      border-color: #E4572E; color: #FFFFFF;
      box-shadow: 0 8px 25px rgba(228, 87, 46, 0.28);
    }
    .suite-tab.active[data-mode="market"] {
      background: linear-gradient(135deg, rgba(46, 158, 91, 0.25), rgba(46, 158, 91, 0.08));
      border-color: #2E9E5B; color: #FFFFFF;
      box-shadow: 0 8px 25px rgba(46, 158, 91, 0.28);
    }
    .suite-tab.active[data-mode="pharma"] {
      background: linear-gradient(135deg, rgba(27, 143, 217, 0.25), rgba(27, 143, 217, 0.08));
      border-color: #1B8FD9; color: #FFFFFF;
      box-shadow: 0 8px 25px rgba(27, 143, 217, 0.28);
    }
    .suite-tab.active[data-mode="boss"] {
      background: linear-gradient(135deg, rgba(201, 154, 46, 0.28), rgba(201, 154, 46, 0.1));
      border-color: #E9A23B; color: #FFFFFF;
      box-shadow: 0 8px 25px rgba(233, 162, 59, 0.28);
    }

    .theme-pills { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
    .theme-pill-label { font-size: 0.72rem; font-weight: 700; color: #94A3B8; margin-right: 4px; text-transform: uppercase; letter-spacing: 0.06em; }

    .theme-btn {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 6px 11px; border-radius: 10px;
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid rgba(255, 255, 255, 0.09);
      color: #CBD5E1; font-size: 0.74rem; font-weight: 700;
      cursor: pointer; transition: all 0.2s ease;
    }

    .theme-swatch { width: 11px; height: 11px; border-radius: 50%; border: 1px solid rgba(255,255,255,0.45); }
    .theme-btn.active { background: rgba(255, 255, 255, 0.14); border-color: var(--ochre); color: #FFFFFF; }

    /* Hardware Stage: Tablet POS + Right Printer & Boss Live Mobile Dock */
    .hardware-stage {
      display: grid;
      grid-template-columns: 1fr 315px;
      gap: 20px;
      align-items: stretch;
    }

    .pos-bezel {
      border-radius: 26px;
      padding: 12px;
      background: linear-gradient(145deg, #1E293B 0%, #0F172A 50%, #090D16 100%);
      border: 2px solid rgba(255, 255, 255, 0.16);
      box-shadow: 0 35px 90px rgba(0, 0, 0, 0.65), inset 0 1px 1px rgba(255, 255, 255, 0.25);
      position: relative;
    }

    .bezel-camera {
      width: 8px; height: 8px; border-radius: 50%;
      background: radial-gradient(circle, #38BDF8 10%, #0F172A 70%);
      border: 1px solid rgba(255,255,255,0.2);
      margin: 0 auto 8px;
    }

    .pos-screen {
      border-radius: 18px;
      overflow: hidden;
      min-height: 550px;
      display: flex;
      flex-direction: column;
      position: relative;
      transition: background 0.35s ease, color 0.35s ease;
      --pos-bg: #0B1220;
      --pos-panel: #111C2D;
      --pos-card: #162338;
      --pos-border: rgba(255, 255, 255, 0.09);
      --pos-text: #F8FAFC;
      --pos-muted: #94A3B8;
      --pos-accent: #10B981;
      background: var(--pos-bg);
      color: var(--pos-text);
      border: 1px solid var(--pos-border);
    }

    .pos-screen[data-theme="06"] {
      --pos-bg: #F1F5F9; --pos-panel: #FFFFFF; --pos-card: #FFFFFF;
      --pos-border: #CBD5E1; --pos-text: #0F172A; --pos-muted: #475569; --pos-accent: #2563EB;
    }
    .pos-screen[data-theme="07"] {
      --pos-bg: #062219; --pos-panel: #0A3124; --pos-card: #0F3F2F;
      --pos-border: rgba(245, 158, 11, 0.26); --pos-text: #F8FAFC; --pos-muted: #A7F3D0; --pos-accent: #F59E0B;
    }
    .pos-screen[data-theme="11"] {
      --pos-bg: #F5F5F7; --pos-panel: #FFFFFF; --pos-card: #FFFFFF;
      --pos-border: #D2D2D7; --pos-text: #1D1D1F; --pos-muted: #6E6E73; --pos-accent: #264653;
    }

    .laser-sweep {
      position: absolute; left: 0; right: 0; height: 3px;
      background: linear-gradient(90deg, transparent, #EF4444, #FCA5A5, #EF4444, transparent);
      box-shadow: 0 0 22px 4px rgba(239, 68, 68, 0.85);
      z-index: 60; pointer-events: none; opacity: 0; top: 10%;
    }
    .laser-sweep.scanning { animation: laserScanAnim 1.1s cubic-bezier(0.4, 0, 0.2, 1) forwards; }
    @keyframes laserScanAnim { 0% { top: 8%; opacity: 1; } 50% { top: 88%; opacity: 1; } 100% { top: 15%; opacity: 0; } }

    .pos-topbar {
      display: flex; align-items: center; justify-content: space-between;
      padding: 10px 16px; background: var(--pos-panel);
      border-bottom: 1px solid var(--pos-border); gap: 10px; flex-wrap: wrap;
    }

    .pos-brand-head { display: flex; align-items: center; gap: 10px; }
    .pos-mode-badge { font-family: var(--font-display); font-size: 0.85rem; font-weight: 800; }
    .pos-controls-right { display: flex; align-items: center; gap: 7px; flex-wrap: wrap; }

    .pos-chip-btn {
      display: inline-flex; align-items: center; gap: 6px;
      padding: 6px 10px; border-radius: 999px; font-size: 0.72rem; font-weight: 700;
      cursor: pointer; border: 1px solid var(--pos-border);
      background: var(--pos-card); color: var(--pos-text); transition: all 0.2s ease;
    }
    .pos-chip-btn:hover { border-color: var(--ochre); transform: translateY(-1px); }
    .pos-chip-btn.online { background: rgba(16, 185, 129, 0.15); color: #10B981; border-color: rgba(16, 185, 129, 0.4); }
    .pos-chip-btn.offline { background: rgba(245, 158, 11, 0.18); color: #F59E0B; border-color: rgba(245, 158, 11, 0.45); }

    .pos-body { display: grid; grid-template-columns: 1fr 300px; flex: 1; }
    .pos-catalog { padding: 15px; display: flex; flex-direction: column; gap: 13px; }
    .pos-cat-bar { display: flex; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap; }
    .pos-cat-pills { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }

    .cat-pill {
      padding: 6px 12px; border-radius: 9px; font-size: 0.74rem; font-weight: 700;
      background: var(--pos-panel); color: var(--pos-muted);
      border: 1px solid var(--pos-border); cursor: pointer; transition: all 0.2s ease;
    }
    .cat-pill.active { background: var(--pos-accent); color: #FFFFFF; border-color: transparent; }

    .pos-items-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 11px; }

    .pos-item-card {
      background: var(--pos-card); border: 1px solid var(--pos-border); border-radius: 14px;
      padding: 12px; cursor: pointer; transition: all 0.22s cubic-bezier(0.16, 1, 0.3, 1);
      display: flex; flex-direction: column; justify-content: space-between; min-height: 128px;
    }
    .pos-item-card:hover { transform: translateY(-3px); border-color: var(--pos-accent); box-shadow: 0 12px 24px rgba(0,0,0,0.18); }
    .pos-item-card.expired-item {
      border-color: rgba(239, 68, 68, 0.65);
      background: linear-gradient(145deg, rgba(239, 68, 68, 0.12), var(--pos-card));
    }

    .item-top-row { display: flex; align-items: flex-start; justify-content: space-between; gap: 6px; margin-bottom: 10px; }
    .item-art-box {
      width: 40px; height: 40px; border-radius: 11px;
      display: flex; align-items: center; justify-content: center;
      background: rgba(148, 163, 184, 0.12); flex-shrink: 0;
    }
    .item-art-box svg { width: 22px; height: 22px; }

    .item-badge {
      font-family: var(--font-mono); font-size: 0.62rem; font-weight: 700;
      padding: 3px 6px; border-radius: 6px; background: rgba(16, 185, 129, 0.15); color: #10B981;
    }
    .item-badge.warn { background: rgba(245, 158, 11, 0.18); color: #F59E0B; }
    .item-badge.danger { background: rgba(239, 68, 68, 0.22); color: #EF4444; animation: pulseDanger 1.4s infinite; }
    @keyframes pulseDanger { 0%, 100% { opacity: 1; } 50% { opacity: 0.55; } }

    .item-name { font-size: 0.81rem; font-weight: 700; line-height: 1.25; margin-bottom: 6px; }
    .item-price-row { display: flex; align-items: center; justify-content: space-between; }
    .item-price { font-family: var(--font-mono); font-size: 0.84rem; font-weight: 800; color: var(--ochre); }
    .pos-screen[data-theme="06"] .item-price, .pos-screen[data-theme="11"] .item-price { color: var(--pos-accent); }
    .item-add-circle {
      width: 23px; height: 23px; border-radius: 50%; background: rgba(148, 163, 184, 0.15);
      display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 0.85rem;
    }

    .pos-cart-panel {
      background: var(--pos-panel); border-left: 1px solid var(--pos-border);
      padding: 15px; display: flex; flex-direction: column; justify-content: space-between;
    }
    html[dir="rtl"] .pos-cart-panel { border-left: none; border-right: 1px solid var(--pos-border); }

    .cart-head {
      display: flex; align-items: center; justify-content: space-between;
      padding-bottom: 10px; border-bottom: 1px dashed var(--pos-border); margin-bottom: 10px;
    }
    .cart-title { font-size: 0.79rem; font-weight: 800; display: flex; align-items: center; gap: 6px; }
    .cart-lines { flex: 1; overflow-y: auto; max-height: 220px; display: flex; flex-direction: column; gap: 7px; }
    .cart-line {
      display: flex; align-items: center; justify-content: space-between;
      padding: 7px 9px; border-radius: 9px; background: var(--pos-card);
      border: 1px solid var(--pos-border); font-size: 0.76rem;
    }
    .cart-total-box { padding-top: 12px; border-top: 1px solid var(--pos-border); margin-top: 10px; }
    .cart-total-row { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 12px; }
    .cart-total-lbl { font-size: 0.74rem; font-weight: 700; color: var(--pos-muted); text-transform: uppercase; }
    .cart-total-val { font-family: var(--font-display); font-size: 1.35rem; font-weight: 800; }

    .pay-methods-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 7px; }
    .pay-btn {
      display: flex; align-items: center; justify-content: center; gap: 6px;
      padding: 9px 8px; border-radius: 10px; border: none;
      font-family: var(--font-sans); font-size: 0.75rem; font-weight: 800; color: #FFFFFF; cursor: pointer; transition: all 0.2s ease;
    }
    .pay-btn:hover { transform: translateY(-2px); filter: brightness(1.1); }
    .pay-cash { background: linear-gradient(135deg, #10B981, #059669); }
    .pay-bankily { background: linear-gradient(135deg, #F59E0B, #D97706); color: #091118; }
    .pay-masrivi { background: linear-gradient(135deg, #2563EB, #1D4ED8); }
    .pay-karni { background: linear-gradient(135deg, #8B5CF6, #6D28D9); }

    /* Right Dock: 80mm Printer + Live Full-Tek Boss Mobile Sync Card */
    .right-hardware-col {
      display: flex;
      flex-direction: column;
      gap: 14px;
    }

    .printer-dock {
      flex: 1;
      background: linear-gradient(165deg, #16222F 0%, #0B131B 100%);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 24px;
      padding: 18px 16px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: 0 24px 60px rgba(0,0,0,0.5);
      overflow: hidden;
    }

    .printer-top-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
    .printer-label { font-size: 0.73rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.08em; color: #94A3B8; display: flex; align-items: center; gap: 7px; }
    .printer-slot { height: 11px; background: #04080C; border-radius: 999px; border: 1px solid rgba(255,255,255,0.14); position: relative; z-index: 5; }

    .receipt-stage { display: flex; flex-direction: column; align-items: center; overflow: hidden; padding-top: 2px; }
    .thermal-paper {
      width: 95%; background: #FFFDF9; color: #0F172A;
      border-radius: 0 0 10px 10px; padding: 14px 12px 16px;
      font-family: var(--font-mono); font-size: 0.7rem;
      box-shadow: 0 14px 30px rgba(0,0,0,0.45); position: relative;
    }
    .thermal-paper.printing { animation: printSlideOut 0.65s cubic-bezier(0.22, 1, 0.36, 1); }
    @keyframes printSlideOut { 0% { transform: translateY(-85%); opacity: 0.5; } 100% { transform: translateY(0); opacity: 1; } }

    .receipt-logo-row { text-align: center; border-bottom: 1px dashed #94A3B8; padding-bottom: 7px; margin-bottom: 7px; }
    .receipt-store-title { font-weight: 800; font-size: 0.8rem; }
    .receipt-meta { font-size: 0.61rem; color: #475569; }
    .receipt-items { display: flex; flex-direction: column; gap: 3px; margin-bottom: 7px; border-bottom: 1px dashed #94A3B8; padding-bottom: 7px; }
    .receipt-line { display: flex; justify-content: space-between; font-size: 0.65rem; }
    .receipt-total { display: flex; justify-content: space-between; font-weight: 800; font-size: 0.78rem; margin-bottom: 6px; }
    .receipt-stamp { text-align: center; padding: 4px 8px; border-radius: 5px; background: #DCFCE7; color: #166534; font-weight: 800; font-size: 0.63rem; margin-bottom: 6px; }

    /* Live Full-Tek Boss Mobile Sync Widget */
    .boss-live-card {
      background: linear-gradient(145deg, rgba(201, 154, 46, 0.16) 0%, rgba(15, 23, 35, 0.96) 100%);
      border: 1px solid rgba(233, 162, 59, 0.42);
      border-radius: 20px;
      padding: 15px 16px;
      box-shadow: 0 16px 40px rgba(0,0,0,0.4);
      transition: transform 0.25s ease;
    }
    .boss-live-card.flash { animation: bossFlash 0.65s ease; }
    @keyframes bossFlash {
      0% { box-shadow: 0 0 0 0 rgba(233, 162, 59, 0.8); transform: scale(1.02); }
      100% { box-shadow: 0 16px 40px rgba(0,0,0,0.4); transform: scale(1); }
    }

    /* FEFO Alert Overlay */
    .fefo-overlay {
      position: absolute; inset: 0; background: rgba(9, 13, 22, 0.88);
      backdrop-filter: blur(10px); display: none; align-items: center; justify-content: center; z-index: 80; padding: 20px;
    }
    .fefo-overlay.active { display: flex; animation: fadeInFast 0.2s ease; }
    @keyframes fadeInFast { from { opacity: 0; transform: scale(0.95); } to { opacity: 1; transform: scale(1); } }
    .fefo-card { max-width: 430px; width: 100%; background: #161F2E; border: 2px solid #EF4444; border-radius: 20px; padding: 24px; text-align: center; color: #F8FAFC; }
    .fefo-icon-ring { width: 56px; height: 56px; border-radius: 50%; background: rgba(239, 68, 68, 0.18); color: #EF4444; display: flex; align-items: center; justify-content: center; margin: 0 auto 12px; border: 1px solid rgba(239, 68, 68, 0.45); }

    /* Marquee */
    .marquee-section {
      margin: 34px 0 56px;
      border-top: 1px solid rgba(255,255,255,0.07);
      border-bottom: 1px solid rgba(255,255,255,0.07);
      background: rgba(10, 18, 26, 0.65);
      padding: 15px 0; overflow: hidden; position: relative; z-index: 2;
    }
    .marquee-track { display: flex; width: max-content; gap: 38px; animation: marqueeScroll 34s linear infinite; }
    .marquee-track:hover { animation-play-state: paused; }
    @keyframes marqueeScroll { 0% { transform: translateX(0); } 100% { transform: translateX(-50%); } }
    .marquee-item { display: inline-flex; align-items: center; gap: 10px; font-size: 0.83rem; font-weight: 700; color: #CBD5E1; white-space: nowrap; }
    .marquee-badge { padding: 3px 8px; border-radius: 6px; font-size: 0.67rem; font-weight: 800; background: rgba(233, 162, 59, 0.16); color: var(--ochre); border: 1px solid rgba(233, 162, 59, 0.3); }

    /* Sections & Heads */
    .section-block { padding: 52px 0; position: relative; z-index: 2; }
    .section-head { text-align: center; max-width: 780px; margin: 0 auto 40px; }
    .section-kicker {
      display: inline-flex; align-items: center; gap: 8px;
      font-size: 0.75rem; font-weight: 800; text-transform: uppercase; letter-spacing: 0.12em;
      color: var(--ochre); background: rgba(233, 162, 59, 0.12);
      border: 1px solid rgba(233, 162, 59, 0.3); padding: 6px 14px; border-radius: 999px; margin-bottom: 13px;
    }
    .section-title { font-family: var(--font-display); font-size: clamp(1.85rem, 3vw, 2.7rem); font-weight: 800; letter-spacing: -0.03em; line-height: 1.12; margin-bottom: 12px; }
    .section-desc { color: #94A3B8; font-size: 0.98rem; }

    /* Spotlight Hover Effect on All Cards */
    .spotlight-card {
      position: relative;
      overflow: hidden;
    }
    .spotlight-card::after {
      content: "";
      position: absolute;
      inset: 0;
      pointer-events: none;
      background: radial-gradient(360px circle at var(--mx, 50%) var(--my, 50%), rgba(233, 162, 59, 0.13), transparent 70%);
      opacity: 0;
      transition: opacity 0.3s ease;
    }
    .spotlight-card:hover::after { opacity: 1; }

    /* Official 4 Business Lines Grid WITH THEIR FULL-TEK LOGOS */
    .suites-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 22px;
    }

    .suite-card {
      background: linear-gradient(165deg, rgba(18, 31, 43, 0.88) 0%, rgba(9, 16, 24, 0.96) 100%);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 26px;
      padding: 26px 26px 24px;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      transition: all 0.32s cubic-bezier(0.16, 1, 0.3, 1);
    }

    .suite-card::before {
      content: ''; position: absolute; top: 0; left: 0; right: 0; height: 4px;
      background: var(--suite-color, var(--ochre));
    }

    .suite-card:hover {
      transform: translateY(-6px);
      border-color: var(--suite-color, var(--ochre));
      box-shadow: 0 25px 55px rgba(0, 0, 0, 0.52);
    }

    .suite-official-logo-box {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 16px;
      padding: 12px 16px;
      margin-bottom: 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .suite-logo-svg {
      height: 54px;
      width: auto;
      display: block;
    }

    .suite-tag-pill {
      font-size: 0.7rem;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.06em;
      padding: 5px 10px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.06);
      color: var(--suite-color);
      border: 1px solid rgba(255, 255, 255, 0.1);
      white-space: nowrap;
    }

    .suite-feature-list {
      list-style: none; display: flex; flex-direction: column; gap: 9px;
      margin-bottom: 22px; font-size: 0.87rem; color: #CBD5E1;
    }
    .suite-feature-list li { display: flex; align-items: flex-start; gap: 9px; }
    .suite-feature-list svg { width: 16px; height: 16px; color: var(--suite-color); flex-shrink: 0; margin-top: 3px; }

    /* Topology Card */
    .topology-card {
      background: linear-gradient(160deg, rgba(16, 28, 39, 0.92) 0%, rgba(8, 15, 22, 0.96) 100%);
      border: 1px solid rgba(255, 255, 255, 0.11);
      border-radius: 28px;
      padding: 30px;
      box-shadow: 0 30px 70px rgba(0,0,0,0.45);
    }

    .topology-controls {
      display: flex; align-items: center; justify-content: space-between;
      flex-wrap: wrap; gap: 16px; margin-bottom: 24px; padding-bottom: 18px;
      border-bottom: 1px solid rgba(255,255,255,0.08);
    }

    .outage-sim-btn {
      display: inline-flex; align-items: center; gap: 10px; padding: 11px 20px; border-radius: 14px;
      font-family: var(--font-sans); font-size: 0.86rem; font-weight: 800; cursor: pointer;
      background: rgba(239, 68, 68, 0.16); color: #FCA5A5; border: 1px solid rgba(239, 68, 68, 0.45);
      transition: all 0.25s ease;
    }
    .outage-sim-btn.active { background: rgba(16, 185, 129, 0.2); color: #6EE7B7; border-color: rgba(16, 185, 129, 0.5); }

    .net-line-anim { stroke-dasharray: 8 8; animation: dashFlow 1.2s linear infinite; }
    @keyframes dashFlow { to { stroke-dashoffset: -16; } }

    /* Interactive ROI Calculator in MRU */
    .roi-card {
      background: linear-gradient(155deg, rgba(19, 34, 46, 0.9) 0%, rgba(9, 16, 24, 0.96) 100%);
      border: 1px solid rgba(233, 162, 59, 0.35);
      border-radius: 28px;
      padding: 34px;
      display: grid;
      grid-template-columns: 1.05fr 0.95fr;
      gap: 32px;
      align-items: center;
      box-shadow: 0 28px 70px rgba(0,0,0,0.45);
    }

    .slider-group { margin-bottom: 20px; }
    .slider-label-row { display: flex; justify-content: space-between; font-size: 0.88rem; font-weight: 700; margin-bottom: 8px; }
    .roi-slider {
      width: 100%; accent-color: var(--ochre); height: 7px; border-radius: 999px; cursor: pointer;
    }

    .roi-result-box {
      background: rgba(8, 15, 22, 0.72);
      border: 1px solid rgba(255,255,255,0.1);
      border-radius: 22px;
      padding: 26px;
      text-align: center;
    }

    /* Bento Grid */
    .bento-grid { display: grid; grid-template-columns: 1.15fr 0.85fr; gap: 22px; }
    .bento-card {
      background: linear-gradient(160deg, rgba(18, 31, 43, 0.88) 0%, rgba(9, 16, 24, 0.95) 100%);
      border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 26px; padding: 26px;
    }

    .fefo-timeline-bar { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin-top: 18px; }
    .fefo-step { padding: 12px; border-radius: 14px; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.03); }

    .rbac-pills { display: flex; flex-wrap: wrap; gap: 7px; margin: 14px 0; }
    .rbac-role-btn {
      padding: 7px 12px; border-radius: 999px; font-size: 0.75rem; font-weight: 700;
      background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1);
      color: #CBD5E1; cursor: pointer; font-family: var(--font-sans);
    }
    .rbac-role-btn.active { background: var(--ochre); color: #081017; border-color: var(--ochre); }
    .rbac-matrix-box { background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.08); border-radius: 16px; padding: 15px; font-size: 0.82rem; line-height: 1.65; }

    /* Pricing */
    .pricing-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; align-items: stretch; }
    .price-card {
      background: linear-gradient(165deg, rgba(17, 29, 40, 0.88) 0%, rgba(9, 16, 24, 0.95) 100%);
      border: 1px solid rgba(255, 255, 255, 0.1); border-radius: 26px; padding: 30px 24px;
      display: flex; flex-direction: column; justify-content: space-between; transition: all 0.3s ease;
    }
    .price-card.featured { border: 2px solid var(--ochre); box-shadow: 0 28px 65px rgba(233, 162, 59, 0.2); transform: translateY(-6px); }
    .price-amount { font-family: var(--font-display); font-size: 2.45rem; font-weight: 800; color: #FFFFFF; margin: 12px 0 4px; }
    .price-currency { font-size: 0.98rem; color: var(--ochre); font-weight: 700; }

    /* Modals */
    .modal-backdrop {
      position: fixed; inset: 0; background: rgba(5, 10, 15, 0.84); backdrop-filter: blur(14px);
      z-index: 2000; display: none; align-items: center; justify-content: center; padding: 20px;
    }
    .modal-backdrop.open { display: flex; animation: fadeInFast 0.22s ease; }
    .modal-window {
      max-width: 580px; width: 100%; background: linear-gradient(165deg, #132230 0%, #0A131C 100%);
      border: 1px solid rgba(233, 162, 59, 0.35); border-radius: 26px; padding: 30px; position: relative;
    }
    .modal-close {
      position: absolute; top: 18px; right: 18px; width: 34px; height: 34px; border-radius: 50%;
      border: 1px solid rgba(255,255,255,0.14); background: rgba(255,255,255,0.05); color: #CBD5E1; cursor: pointer;
    }
    .pin-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; max-width: 280px; margin: 18px auto; }
    .pin-key {
      padding: 14px; border-radius: 14px; background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.12); color: #FFFFFF; font-family: var(--font-display);
      font-size: 1.2rem; font-weight: 800; cursor: pointer;
    }
    .pin-key:hover { background: rgba(233, 162, 59, 0.22); border-color: var(--ochre); }
    .form-input {
      width: 100%; padding: 12px 15px; border-radius: 12px; background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.14); color: #FFFFFF; font-family: var(--font-sans); font-size: 0.9rem; margin-bottom: 12px;
    }

    footer { border-top: 1px solid rgba(255,255,255,0.08); padding: 40px 0 30px; margin-top: 36px; color: #94A3B8; font-size: 0.85rem; position: relative; z-index: 2; }

    @media (max-width: 1120px) {
      .hero-top-grid, .hardware-stage, .pos-body, .bento-grid, .suites-grid, .pricing-grid, .roi-card { grid-template-columns: 1fr; }
      .nav-links { display: none; }
    }
  </style>
</head>
<body>

  <div class="scroll-progress" id="scroll-progress"></div>

  <!-- Ambient Stage -->
  <div class="ambient-stage" aria-hidden="true">
    <div class="aurora-orb aurora-1"></div>
    <div class="aurora-orb aurora-2"></div>
    <div class="aurora-orb aurora-3"></div>
    <div class="arch-grid"></div>
    <div class="grid-beam-h"></div>
    <div class="grid-beam-h beam-2"></div>
  </div>

  <!-- Floating Glassmorphic Navbar with Official Model 11 Animated SVG Logo -->
  <div class="nav-wrapper">
    <nav class="navbar" aria-label="Navigation principale">
      <a href="#" class="brand-link" title="Logo Officiel Modèle 11 — Pilules">
        <svg width="166" height="42" viewBox="0 0 400 100">
          <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
          <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#E9A23B"/>
          <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
          <text x="115" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
          <text x="117" y="83" font-family="'Plus Jakarta Sans',sans-serif" font-size="12" font-weight="700" letter-spacing="4.5" fill="#E9A23B">SUITE POS</text>
        </svg>
      </a>

      <ul class="nav-links">
        <li><a href="#simulateur" data-i18n="nav_sim">Simulateur Live</a></li>
        <li><a href="#gammes" data-i18n="nav_suites">Les 4 Logos & Gammes</a></li>
        <li><a href="#topologie" data-i18n="nav_net">Cloud + Edge LAN</a></li>
        <li><a href="#roi" data-i18n="nav_roi">Calculateur MRU</a></li>
        <li><a href="#tarifs" data-i18n="nav_price">Tarifs</a></li>
      </ul>

      <div class="nav-actions">
        <div class="lang-pill">
          <button class="lang-btn active" onclick="setLanguage('fr')" id="lang-fr">FR</button>
          <button class="lang-btn" onclick="setLanguage('ar')" id="lang-ar">العربية</button>
          <button class="lang-btn" onclick="setLanguage('en')" id="lang-en">EN</button>
        </div>

        <button class="btn btn-boss-pill" onclick="openModal('modal-superadmin')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 2L15.09 8.26L22 9.27L17 14.14L18.18 21.02L12 17.77L5.82 21.02L7 14.14L2 9.27L8.91 8.26L12 2Z"/></svg>
          <span data-i18n="btn_superadmin">Full-Tek Control</span>
        </button>

        <button class="btn btn-ghost" onclick="openModal('modal-login')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          <span data-i18n="btn_login">Accès Caisse</span>
        </button>

        <button class="btn btn-primary" onclick="openModal('modal-trial')">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
          <span data-i18n="btn_trial">Essai 15 Jours</span>
        </button>
      </div>
    </nav>
  </div>

  <!-- HERO SECTION -->
  <header class="hero container">
    <div class="hero-top-grid">
      <div>
        <div class="eyebrow-badge">
          <span class="eyebrow-pulse"><span class="live-dot"></span> <span data-i18n="hero_live_badge">Architecture Hybride V4</span></span>
          <span class="eyebrow-text" data-i18n="hero_eyebrow">Mauritanie · Bankily · Masrivi · Bouclier FEFO · Offline LAN</span>
        </div>

        <h1 class="hero-title" data-i18n="hero_title">
          L'écosystème de caisse qui <span class="gradient-ochre">encaisse en 0,08 seconde</span>, même sans Internet.
        </h1>

        <p class="hero-lead" data-i18n="hero_lead">
          Une marque forte déclinée en 4 logiciels spécialisés : Full-Tek Resto, Full-Tek Market, Full-Tek Pharma (avec blocage automatique FEFO des lots périmés) et Full-Tek Boss en temps réel.
        </p>

        <div class="hero-cta-row">
          <button class="btn btn-primary btn-xl" onclick="openModal('modal-trial')">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
            <span data-i18n="cta_start">Déployer ma Boutique (15j Gratuits)</span>
          </button>
          <a href="#gammes" class="btn btn-ghost btn-xl">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>
            <span data-i18n="cta_logos">Voir les 4 Logos & Solutions</span>
          </a>
        </div>
      </div>

      <!-- Right Hero Telemetry Card -->
      <div class="hero-telemetry-card spotlight-card">
        <div class="telemetry-header">
          <div class="telemetry-title">
            <span class="live-dot"></span>
            <span data-i18n="telemetry_head">Télémétrie Réseau — Nouakchott & Nouadhibou</span>
          </div>
          <svg width="90" height="26" viewBox="0 0 90 26" fill="none">
            <path class="ecg-line" d="M0 13 H22 L28 4 L35 22 L42 9 L47 16 L53 13 H90" stroke="#10B981" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>

        <div class="telemetry-grid">
          <div class="telemetry-metric">
            <div class="metric-val">0,08 <span class="metric-unit">sec</span></div>
            <div class="metric-lbl" data-i18n="metric_1">Sync LAN Locale (Caisse ↔ Cuisine KDS)</div>
          </div>
          <div class="telemetry-metric">
            <div class="metric-val">100 <span class="metric-unit">%</span></div>
            <div class="metric-lbl" data-i18n="metric_2">Continuité Offline sur coupure fibre / 4G</div>
          </div>
          <div class="telemetry-metric">
            <div class="metric-val">0 <span class="metric-unit">MRU</span></div>
            <div class="metric-lbl" data-i18n="metric_3">Pertes périmées (Bouclier FEFO actif)</div>
          </div>
          <div class="telemetry-metric">
            <div class="metric-val">9 <span class="metric-unit">Rôles</span></div>
            <div class="metric-lbl" data-i18n="metric_4">RBAC & Clôture Z à l'aveugle anti-fraude</div>
          </div>
        </div>

        <div style="display:flex; align-items:center; justify-content:space-between; font-size:0.76rem; color:#94A3B8; padding-top:6px;">
          <span>Identité Officielle : <strong style="color:#FFF;">Logo N°11 « Pilules »</strong></span>
          <span>4 Thèmes : <strong style="color:var(--ochre);">01 · 06 · 07 · 11</strong></span>
        </div>
      </div>
    </div>

    <!-- ======================================================================
         INTERACTIVE HARDWARE SIMULATOR WITH OFFICIAL SUB-BRAND LOGOS
         ====================================================================== -->
    <div id="simulateur">
      <div class="suite-switcher-bar">
        <div class="suite-tabs" role="tablist">
          <!-- Official Mini Logos in Simulator Switcher -->
          <button class="suite-tab active" data-mode="resto" onclick="switchPosMode('resto')">
            <svg width="112" height="28" viewBox="0 0 400 100">
              <rect x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect x="10" y="43" width="52" height="16" rx="8" fill="#E4572E"/>
              <rect x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(118,67) scale(.95)" fill="none" stroke="#E4572E" stroke-width="2.4" stroke-linecap="round"><path d="M7 3v6a2 2 0 0 0 4 0V3M9 3v18M17 21V3c-2.5 1.8-3.5 4.5-3.5 8H17"/></g>
              <text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#E4572E">RESTO</text>
            </svg>
          </button>

          <button class="suite-tab" data-mode="market" onclick="switchPosMode('market')">
            <svg width="118" height="28" viewBox="0 0 400 100">
              <rect x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect x="10" y="43" width="52" height="16" rx="8" fill="#2E9E5B"/>
              <rect x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(118,67) scale(.95)" fill="none" stroke="#2E9E5B" stroke-width="2.4" stroke-linecap="round"><path d="M3 4h3l2.4 11h9.6l2-8H7"/><circle cx="10" cy="19.5" r="1.6"/><circle cx="17" cy="19.5" r="1.6"/></g>
              <text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#2E9E5B">MARKET</text>
            </svg>
          </button>

          <button class="suite-tab" data-mode="pharma" onclick="switchPosMode('pharma')">
            <svg width="118" height="28" viewBox="0 0 400 100">
              <rect x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect x="10" y="43" width="52" height="16" rx="8" fill="#1B8FD9"/>
              <rect x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(118,67) scale(.95)"><path fill="#1B8FD9" d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/></g>
              <text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#1B8FD9">PHARMA</text>
            </svg>
          </button>

          <button class="suite-tab" data-mode="boss" onclick="switchPosMode('boss')">
            <svg width="108" height="28" viewBox="0 0 400 100">
              <rect x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect x="10" y="43" width="52" height="16" rx="8" fill="#C99A2E"/>
              <rect x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(118,67) scale(.95)" fill="#C99A2E"><rect x="3" y="12" width="5" height="9" rx="1"/><rect x="10" y="4" width="5" height="17" rx="1"/><rect x="17" y="8" width="5" height="13" rx="1"/></g>
              <text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#C99A2E">BOSS</text>
            </svg>
          </button>
        </div>

        <div class="theme-pills">
          <span class="theme-pill-label" data-i18n="lbl_themes">4 Thèmes :</span>
          <button class="theme-btn active" onclick="setPosTheme('01', this)"><span class="theme-swatch" style="background:#10B981;"></span><span>01 · Émeraude</span></button>
          <button class="theme-btn" onclick="setPosTheme('06', this)"><span class="theme-swatch" style="background:#2563EB;"></span><span>06 · Ocean</span></button>
          <button class="theme-btn" onclick="setPosTheme('07', this)"><span class="theme-swatch" style="background:#F59E0B;"></span><span>07 · Mauritanie</span></button>
          <button class="theme-btn" onclick="setPosTheme('11', this)"><span class="theme-swatch" style="background:#264653;"></span><span>11 · Nordic</span></button>
        </div>
      </div>

      <!-- Hardware Stage -->
      <div class="hardware-stage">
        <div class="pos-bezel">
          <div class="bezel-camera"></div>
          <div class="pos-screen" id="pos-screen" data-theme="01">
            <div class="laser-sweep" id="laser-sweep"></div>

            <!-- FEFO Overlay -->
            <div class="fefo-overlay" id="fefo-overlay">
              <div class="fefo-card">
                <div class="fefo-icon-ring">
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                </div>
                <div style="font-size:0.74rem; font-weight:800; color:#EF4444; letter-spacing:0.1em; text-transform:uppercase; margin-bottom:6px;">Bouclier Sanitaire FEFO Actif</div>
                <h3 style="font-family:var(--font-display); font-size:1.25rem; margin-bottom:8px;" id="fefo-item-title">Vente Bloquée — Lot Périmé !</h3>
                <p style="font-size:0.83rem; color:#94A3B8; margin-bottom:18px;">
                  Conformément aux règles <strong>Full-Tek FEFO</strong>, l'encaissement d'un lot expiré est bloqué automatiquement sur toutes les caisses.
                </p>
                <div style="display:flex; gap:10px; justify-content:center;">
                  <button class="btn btn-ghost" onclick="closeFefoModal()">Retirer du panier</button>
                  <button class="btn btn-primary" onclick="overrideFefoWithPin()">Déblocage Gérant (PIN)</button>
                </div>
              </div>
            </div>

            <!-- POS Top Status Bar with Dynamic Business Logo -->
            <div class="pos-topbar">
              <div class="pos-brand-head">
                <div id="pos-dynamic-logo"></div>
                <span class="pos-mode-badge" id="pos-header-title">Salon Khaima VIP-04</span>
              </div>

              <div class="pos-controls-right">
                <button class="pos-chip-btn" onclick="triggerLaserScan()">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#EF4444" stroke-width="2.3"><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/><line x1="7" y1="12" x2="17" y2="12"/></svg>
                  <span>Scan Laser 2D</span>
                </button>

                <button class="pos-chip-btn online" id="net-toggle-btn" onclick="togglePosNetwork()">
                  <span class="live-dot"></span>
                  <span id="net-status-lbl">Cloud + LAN (0.08s)</span>
                </button>

                <span class="pos-chip-btn" style="cursor:default;">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                  <span id="pos-role-badge">PIN #4821</span>
                </span>
              </div>
            </div>

            <!-- POS Body -->
            <div class="pos-body">
              <div class="pos-catalog">
                <div class="pos-cat-bar">
                  <div class="pos-cat-pills" id="pos-cat-pills"></div>
                </div>
                <div class="pos-items-grid" id="pos-items-grid"></div>
              </div>

              <div class="pos-cart-panel">
                <div>
                  <div class="cart-head">
                    <div class="cart-title">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>
                      <span id="ticket-num-lbl">Ticket #FT-1048</span>
                    </div>
                    <button onclick="clearCart()" style="background:none; border:none; color:#EF4444; font-size:0.72rem; font-weight:700; cursor:pointer;">Vider</button>
                  </div>
                  <div class="cart-lines" id="cart-lines"></div>
                </div>

                <div class="cart-total-box">
                  <div class="cart-total-row">
                    <span class="cart-total-lbl">Total TTC</span>
                    <span class="cart-total-val" id="cart-total-val">1 520 MRU</span>
                  </div>
                  <div class="pay-methods-grid">
                    <button class="pay-btn pay-cash" onclick="payOrder('CASH MRU')">Cash MRU</button>
                    <button class="pay-btn pay-bankily" onclick="payOrder('BANKILY BPM')">Bankily</button>
                    <button class="pay-btn pay-masrivi" onclick="payOrder('MASRIVI BMCI')">Masrivi</button>
                    <button class="pay-btn pay-karni" onclick="payOrder('CRÉDIT KARNI')">Karni Crédit</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Right Hardware Column: 80mm Printer + Live Full-Tek Boss Sync -->
        <div class="right-hardware-col">
          <div class="printer-dock">
            <div>
              <div class="printer-top-head">
                <div class="printer-label"><span class="live-dot"></span><span>Imprimante 80mm ESC/POS</span></div>
                <span style="font-size:0.68rem; font-weight:700; color:var(--ochre);">Auto-Cut</span>
              </div>
              <div class="printer-slot"></div>
              <div class="receipt-stage">
                <div class="thermal-paper" id="thermal-paper">
                  <div class="receipt-logo-row">
                    <div class="receipt-store-title" id="rcpt-store">FULL-TEK RESTO</div>
                    <div class="receipt-meta">Tevragh Zeina · Nouakchott</div>
                    <div class="receipt-meta" id="rcpt-time">Ticket #FT-1048 · Sync Cloud+LAN</div>
                  </div>
                  <div class="receipt-items" id="rcpt-items"></div>
                  <div class="receipt-total"><span>TOTAL MRU</span><span id="rcpt-total">1 520 MRU</span></div>
                  <div class="receipt-stamp" id="rcpt-stamp">PAYÉ · BANKILY VERIFIÉ</div>
                  <div style="display:flex; justify-content:center; margin-top:4px;">
                    <svg width="160" height="24" viewBox="0 0 170 32" fill="#0F172A">
                      <rect x="4" y="2" width="3" height="26"/><rect x="10" y="2" width="1.5" height="26"/><rect x="15" y="2" width="4" height="26"/><rect x="22" y="2" width="2" height="26"/><rect x="27" y="2" width="1.5" height="26"/><rect x="32" y="2" width="5" height="26"/><rect x="40" y="2" width="2" height="26"/><rect x="45" y="2" width="3" height="26"/><rect x="52" y="2" width="1.5" height="26"/><rect x="57" y="2" width="4" height="26"/><rect x="65" y="2" width="2" height="26"/><rect x="70" y="2" width="4" height="26"/><rect x="77" y="2" width="1.5" height="26"/><rect x="82" y="2" width="3" height="26"/><rect x="89" y="2" width="5" height="26"/><rect x="97" y="2" width="2" height="26"/><rect x="102" y="2" width="1.5" height="26"/><rect x="107" y="2" width="4" height="26"/><rect x="115" y="2" width="3" height="26"/><rect x="121" y="2" width="1.5" height="26"/><rect x="126" y="2" width="4" height="26"/><rect x="133" y="2" width="2" height="26"/><rect x="139" y="2" width="5" height="26"/><rect x="147" y="2" width="2" height="26"/><rect x="152" y="2" width="3" height="26"/>
                    </svg>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Live Full-Tek Boss Mobile Sync Widget -->
          <div class="boss-live-card" id="boss-live-card">
            <div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:8px;">
              <svg width="110" height="26" viewBox="0 0 400 100">
                <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
                <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#C99A2E"/>
                <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
                <text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
                <text x="118" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#C99A2E">BOSS MOBILE</text>
              </svg>
              <span style="font-size:0.68rem; font-weight:800; color:#10B981; display:flex; align-items:center; gap:5px;"><span class="live-dot"></span>SYNC LIVE</span>
            </div>
            <div style="font-size:0.74rem; color:#94A3B8;">Recette Jour (Temps Réel Patron) :</div>
            <div style="font-family:var(--font-display); font-size:1.55rem; font-weight:800; color:#FFFFFF; margin:2px 0 4px;" id="boss-live-total">148 520 MRU</div>
            <div style="font-size:0.72rem; color:#FDE68A;" id="boss-live-event">Dernier encaissement synchronisé depuis la caisse.</div>
          </div>
        </div>
      </div>
    </div>
  </header>

  <!-- MARQUEE -->
  <div class="marquee-section">
    <div class="marquee-track">
      <div class="marquee-item"><span class="marquee-badge">MOBILE MONEY</span> Bankily (BPM) · Masrivi (BMCI) · Sedad · Bimbank · Click</div>
      <div class="marquee-item"><span class="marquee-badge">MATÉRIEL POS</span> Terminaux Sunmi T2 · iPadOS · Android APK Direct (0€ Stores)</div>
      <div class="marquee-item"><span class="marquee-badge">PÉRIPHÉRIQUES</span> Imprimantes 80mm ESC/POS · Douchettes Laser 2D · Balances Poids-Prix</div>
      <div class="marquee-item"><span class="marquee-badge">TRAÇABILITÉ</span> Gestion Lots & Péremption FEFO · Alertes J-90 / J-30 / J-7</div>
      <div class="marquee-item"><span class="marquee-badge">MAURITANIE</span> Nouakchott · Nouadhibou · Rosso · Kiffa · Atar · Zouérate</div>
      <div class="marquee-item"><span class="marquee-badge">MOBILE MONEY</span> Bankily (BPM) · Masrivi (BMCI) · Sedad · Bimbank · Click</div>
      <div class="marquee-item"><span class="marquee-badge">MATÉRIEL POS</span> Terminaux Sunmi T2 · iPadOS · Android APK Direct (0€ Stores)</div>
      <div class="marquee-item"><span class="marquee-badge">PÉRIPHÉRIQUES</span> Imprimantes 80mm ESC/POS · Douchettes Laser 2D · Balances Poids-Prix</div>
      <div class="marquee-item"><span class="marquee-badge">TRAÇABILITÉ</span> Gestion Lots & Péremption FEFO · Alertes J-90 / J-30 / J-7</div>
    </div>
  </div>

  <!-- ======================================================================
       SECTION: LES 4 LOGOS OFFICIELS & SOLUTIONS MÉTIER (MODÈLE N°11)
       ====================================================================== -->
  <section class="section-block container" id="gammes">
    <div class="section-head">
      <div class="section-kicker">Identité Officielle Modèle N°11 (« Pilules »)</div>
      <h2 class="section-title">Les 4 Solutions Métier & Leurs Logos Officiels</h2>
      <p class="section-desc">
        Chaque logiciel Full-Tek possède sa propre identité visuelle issue du logo N°11 validé par M. Taha Chouaib : code couleur dédié, icône métier sur-mesure et ergonomie optimisée.
      </p>
    </div>

    <div class="suites-grid">
      <!-- 1. FULL-TEK RESTO -->
      <div class="suite-card spotlight-card" style="--suite-color: #E4572E;">
        <div>
          <div class="suite-official-logo-box">
            <svg class="suite-logo-svg" viewBox="0 0 400 100">
              <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#E4572E"/>
              <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="120" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(120,67) scale(.95)" fill="none" stroke="#E4572E" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 3v6a2 2 0 0 0 4 0V3M9 3v18M17 21V3c-2.5 1.8-3.5 4.5-3.5 8H17"/></g>
              <text x="147" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#E4572E">RESTO</text>
            </svg>
            <span class="suite-tag-pill">Restauration & VIP</span>
          </div>

          <ul class="suite-feature-list">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Plan de salle interactif & Salons Khaima VIP</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Écran Cuisine KDS temps réel (&lt;0,08s sur Wi-Fi local)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Division d'addition, transfert de table & suivi livreurs</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Fiches techniques recettes & déstockage automatique</span></li>
          </ul>
        </div>
        <a href="#simulateur" onclick="switchPosMode('resto')" class="btn btn-ghost" style="width:100%; border-color:rgba(228,87,46,0.45);">Charger Full·Tek Resto dans le Simulateur ↑</a>
      </div>

      <!-- 2. FULL-TEK MARKET -->
      <div class="suite-card spotlight-card" style="--suite-color: #2E9E5B;">
        <div>
          <div class="suite-official-logo-box">
            <svg class="suite-logo-svg" viewBox="0 0 400 100">
              <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#2E9E5B"/>
              <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="120" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(120,67) scale(.95)" fill="none" stroke="#2E9E5B" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 4h3l2.4 11h9.6l2-8H7"/><circle cx="10" cy="19.5" r="1.6"/><circle cx="17" cy="19.5" r="1.6"/></g>
              <text x="147" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#2E9E5B">MARKET</text>
            </svg>
            <span class="suite-tag-pill">Supermarchés</span>
          </div>

          <ul class="suite-feature-list">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Scan code-barres ultra-rapide & étiquettes balances</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Blocage automatique des produits périmés (FEFO)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Double tarification Détail / Carton (Demi-gros)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Carnet de crédit numérique Karni avec plafond client</span></li>
          </ul>
        </div>
        <a href="#simulateur" onclick="switchPosMode('market')" class="btn btn-ghost" style="width:100%; border-color:rgba(46,158,91,0.45);">Charger Full·Tek Market dans le Simulateur ↑</a>
      </div>

      <!-- 3. FULL-TEK PHARMA -->
      <div class="suite-card spotlight-card" style="--suite-color: #1B8FD9;">
        <div>
          <div class="suite-official-logo-box">
            <svg class="suite-logo-svg" viewBox="0 0 400 100">
              <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#1B8FD9"/>
              <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="120" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(120,67) scale(.95)"><path fill="#1B8FD9" d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/></g>
              <text x="147" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#1B8FD9">PHARMA</text>
            </svg>
            <span class="suite-tag-pill">Officines & Dépôts</span>
          </div>

          <ul class="suite-feature-list">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Traçabilité stricte par N° de Lot et Date d'expiration</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Recherche instantanée par molécule / DCI & équivalents</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Vente à la boîte ou au blister (déconditionnement)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Alertes J-90 / J-30 / J-7 & état des retours fournisseurs</span></li>
          </ul>
        </div>
        <a href="#simulateur" onclick="switchPosMode('pharma')" class="btn btn-ghost" style="width:100%; border-color:rgba(27,143,217,0.45);">Charger Full·Tek Pharma dans le Simulateur ↑</a>
      </div>

      <!-- 4. FULL-TEK BOSS -->
      <div class="suite-card spotlight-card" style="--suite-color: #C99A2E;">
        <div>
          <div class="suite-official-logo-box">
            <svg class="suite-logo-svg" viewBox="0 0 400 100">
              <rect class="ft-p1" x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
              <rect class="ft-p2" x="10" y="43" width="52" height="16" rx="8" fill="#C99A2E"/>
              <rect class="ft-p3" x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
              <text x="120" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
              <g transform="translate(120,67) scale(.95)" fill="#C99A2E"><rect x="3" y="12" width="5" height="9" rx="1"/><rect x="10" y="4" width="5" height="17" rx="1"/><rect x="17" y="8" width="5" height="13" rx="1"/></g>
              <text x="147" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#C99A2E">BOSS</text>
            </svg>
            <span class="suite-tag-pill">Patrons & Super-Admin</span>
          </div>

          <ul class="suite-feature-list">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Tableau de bord mobile en direct (CA, Marges, Stocks)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Journal d'audit anti-fraude (annulations, remises, tiroir)</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Clôture Z à l'aveugle avec écart de caisse automatique</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Portail Super-Admin MRR pour gérer les abonnements</span></li>
          </ul>
        </div>
        <a href="#simulateur" onclick="switchPosMode('boss')" class="btn btn-ghost" style="width:100%; border-color:rgba(201,154,46,0.45);">Charger Full·Tek Boss dans le Simulateur ↑</a>
      </div>
    </div>
  </section>

  <!-- INTERACTIVE NETWORK TOPOLOGY -->
  <section class="section-block container" id="topologie">
    <div class="section-head">
      <div class="section-kicker">Architecture Hybride Cloud + Edge LAN</div>
      <h2 class="section-title">Zéro Coupure : Même si Internet S'arrête</h2>
      <p class="section-desc">Testez la résilience du système en simulant une coupure fibre/4G en plein service.</p>
    </div>

    <div class="topology-card">
      <div class="topology-controls">
        <div>
          <div style="font-weight:800; font-size:1.05rem; margin-bottom:4px;" id="topo-state-title">État Actuel : Cloud Synchronisé + Réseau Local Wi-Fi Actif</div>
          <div style="font-size:0.84rem; color:#94A3B8;" id="topo-state-desc">Les ventes sont sauvegardées en local (SQLite) ET répliquées sur le Cloud Full-Tek.</div>
        </div>
        <button class="outage-sim-btn" id="outage-sim-btn" onclick="toggleTopologyOutage()">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
          <span id="outage-btn-lbl">Simuler une Coupure Internet</span>
        </button>
      </div>

      <svg viewBox="0 0 1100 250" width="100%" height="250" fill="none">
        <path id="cloud-link-line" class="net-line-anim" d="M230 125 H450" stroke="#10B981" stroke-width="3"/>
        <path class="net-line-anim" d="M630 125 L840 50" stroke="#E9A23B" stroke-width="2.5"/>
        <path class="net-line-anim" d="M630 125 L840 125" stroke="#10B981" stroke-width="2.5"/>
        <path class="net-line-anim" d="M630 125 L840 200" stroke="#38BDF8" stroke-width="2.5"/>

        <g transform="translate(50, 70)">
          <rect width="180" height="110" rx="18" fill="#111E2B" stroke="#10B981" stroke-width="2" id="cloud-box"/>
          <text x="90" y="45" text-anchor="middle" fill="#FFFFFF" font-family="Space Grotesk" font-weight="700" font-size="15">Cloud Full-Tek</text>
          <text x="90" y="68" text-anchor="middle" fill="#94A3B8" font-family="Plus Jakarta Sans" font-size="11">PostgreSQL · Multi-Tenant</text>
          <text x="90" y="88" text-anchor="middle" fill="#10B981" font-family="JetBrains Mono" font-weight="700" font-size="11" id="cloud-status-txt">● EN LIGNE (TLS 1.3)</text>
        </g>

        <g transform="translate(450, 60)">
          <rect width="185" height="130" rx="20" fill="#172A3A" stroke="#E9A23B" stroke-width="2.5"/>
          <text x="92" y="42" text-anchor="middle" fill="#E9A23B" font-family="JetBrains Mono" font-weight="700" font-size="11">SERVEUR LOCAL EDGE</text>
          <text x="92" y="66" text-anchor="middle" fill="#FFFFFF" font-family="Space Grotesk" font-weight="700" font-size="16">Caisse Master</text>
          <text x="92" y="88" text-anchor="middle" fill="#CBD5E1" font-family="Plus Jakarta Sans" font-size="11">SQLite + WebSocket LAN</text>
          <text x="92" y="110" text-anchor="middle" fill="#10B981" font-family="JetBrains Mono" font-weight="700" font-size="11">● 100% AUTONOME</text>
        </g>

        <g transform="translate(840, 16)">
          <rect width="210" height="66" rx="14" fill="#111E2B" stroke="rgba(233,162,59,0.5)" stroke-width="1.5"/>
          <text x="105" y="29" text-anchor="middle" fill="#FFFFFF" font-family="Space Grotesk" font-weight="700" font-size="13">Tablettes Serveurs / Caisses</text>
          <text x="105" y="49" text-anchor="middle" fill="#E9A23B" font-family="JetBrains Mono" font-size="11">Sync Wi-Fi Local : 0,08s</text>
        </g>
        <g transform="translate(840, 92)">
          <rect width="210" height="66" rx="14" fill="#111E2B" stroke="rgba(16,185,129,0.5)" stroke-width="1.5"/>
          <text x="105" y="29" text-anchor="middle" fill="#FFFFFF" font-family="Space Grotesk" font-weight="700" font-size="13">Écran Cuisine KDS & Bar</text>
          <text x="105" y="49" text-anchor="middle" fill="#10B981" font-family="JetBrains Mono" font-size="11">Bons instantanés sans papier</text>
        </g>
        <g transform="translate(840, 168)">
          <rect width="210" height="66" rx="14" fill="#111E2B" stroke="rgba(56,189,248,0.5)" stroke-width="1.5"/>
          <text x="105" y="29" text-anchor="middle" fill="#FFFFFF" font-family="Space Grotesk" font-weight="700" font-size="13">Imprimantes 80mm & Balances</text>
          <text x="105" y="49" text-anchor="middle" fill="#38BDF8" font-family="JetBrains Mono" font-size="11">ESC/POS LAN / USB Direct</text>
        </g>
      </svg>
    </div>
  </section>

  <!-- INTERACTIVE ROI & SAVINGS CALCULATOR (MRU) -->
  <section class="section-block container" id="roi">
    <div class="section-head">
      <div class="section-kicker">Simulateur d'Économies & Anti-Pertes</div>
      <h2 class="section-title">Calculez Vos Gains avec Full-Tek dès le 1er Mois</h2>
      <p class="section-desc">Estimez l'argent économisé grâce au blocage des produits périmés (FEFO), à la Clôture Z aveugle et à l'encaissement sans coupure.</p>
    </div>

    <div class="roi-card spotlight-card">
      <div>
        <div class="slider-group">
          <div class="slider-label-row">
            <span>Nombre de caisses / points de vente</span>
            <span style="color:var(--ochre);" id="roi-pos-lbl">3 Caisses</span>
          </div>
          <input type="range" min="1" max="15" value="3" class="roi-slider" id="roi-pos-range" oninput="calcRoi()">
        </div>

        <div class="slider-group">
          <div class="slider-label-row">
            <span>Pertes mensuelles estimées (erreurs, oublis, périmés)</span>
            <span style="color:var(--ochre);" id="roi-loss-lbl">25 000 MRU / mois</span>
          </div>
          <input type="range" min="5000" max="150000" step="5000" value="25000" class="roi-slider" id="roi-loss-range" oninput="calcRoi()">
        </div>

        <div style="font-size:0.83rem; color:#94A3B8; line-height:1.6;">
          L'audit anti-fraude RBAC + alertes FEFO J-30 réduisent en moyenne les pertes de stock et les écarts de caisse de <strong>85 % dès la première semaine</strong>.
        </div>
      </div>

      <div class="roi-result-box">
        <div style="font-size:0.75rem; font-weight:800; color:var(--ochre); text-transform:uppercase; letter-spacing:0.08em;">Économie Nette Estimée / An</div>
        <div style="font-family:var(--font-display); font-size:2.6rem; font-weight:800; color:#10B981; margin:8px 0;" id="roi-annual-val">+ 255 000 MRU</div>
        <div style="font-size:0.84rem; color:#CBD5E1; margin-bottom:18px;" id="roi-payback-lbl">Abonnement Full-Tek Pro rentabilisé en 4 jours par mois.</div>
        <button class="btn btn-primary" style="width:100%;" onclick="openModal('modal-trial')">Démarrer l'Essai Gratuit 15 Jours</button>
      </div>
    </div>
  </section>

  <!-- BENTO GRID: FEFO & RBAC -->
  <section class="section-block container" id="securite">
    <div class="bento-grid">
      <div class="bento-card spotlight-card">
        <div class="section-kicker" style="margin-bottom:10px;">Section 07-B · Traçabilité</div>
        <h3 style="font-family:var(--font-display); font-size:1.5rem; font-weight:800; margin-bottom:8px;">Bouclier FEFO : J-90 jusqu'au Blocage Jour J</h3>
        <div class="fefo-timeline-bar">
          <div class="fefo-step" style="border-color:rgba(56,189,248,0.4);"><div style="font-family:var(--font-mono); font-weight:800; color:#38BDF8;">J - 90</div><div style="font-weight:700; font-size:0.79rem; margin:3px 0;">Priorité FEFO</div><div style="font-size:0.71rem; color:#94A3B8;">Sortie prioritaire</div></div>
          <div class="fefo-step" style="border-color:rgba(245,158,11,0.45);"><div style="font-family:var(--font-mono); font-weight:800; color:#F59E0B;">J - 30</div><div style="font-weight:700; font-size:0.79rem; margin:3px 0;">Promo Auto</div><div style="font-size:0.71rem; color:#94A3B8;">Remise suggérée</div></div>
          <div class="fefo-step" style="border-color:rgba(249,115,22,0.5);"><div style="font-family:var(--font-mono); font-weight:800; color:#FB923C;">J - 7</div><div style="font-weight:700; font-size:0.79rem; margin:3px 0;">Retrait Rayon</div><div style="font-size:0.71rem; color:#94A3B8;">Alerte Patron</div></div>
          <div class="fefo-step" style="border-color:#EF4444; background:rgba(239,68,68,0.12);"><div style="font-family:var(--font-mono); font-weight:800; color:#EF4444;">JOUR J</div><div style="font-weight:700; font-size:0.79rem; margin:3px 0;">Scan Bloqué</div><div style="font-size:0.71rem; color:#FCA5A5;">Vente verrouillée</div></div>
        </div>
      </div>

      <div class="bento-card spotlight-card">
        <div class="section-kicker" style="margin-bottom:10px;">Section 07-A · RBAC</div>
        <h3 style="font-family:var(--font-display); font-size:1.5rem; font-weight:800; margin-bottom:6px;">9 Rôles & Clôture Z Aveugle</h3>
        <div class="rbac-pills">
          <button class="rbac-role-btn active" onclick="inspectRole('caissier', this)">Caissier</button>
          <button class="rbac-role-btn" onclick="inspectRole('serveur', this)">Serveur</button>
          <button class="rbac-role-btn" onclick="inspectRole('pharmacien', this)">Pharmacien</button>
          <button class="rbac-role-btn" onclick="inspectRole('gerant', this)">Gérant</button>
          <button class="rbac-role-btn" onclick="inspectRole('superadmin', this)">Super-Admin</button>
        </div>
        <div class="rbac-matrix-box" id="rbac-matrix-box">
          <div style="font-weight:800; color:var(--ochre); margin-bottom:4px;">Rôle : Caissier Principal (PIN 4 chiffres)</div>
          <div style="color:#10B981;">✓ Encaisser Cash MRU, Bankily, Masrivi, Sedad</div>
          <div style="color:#EF4444;">✗ Interdiction de supprimer une ligne après validation</div>
          <div style="color:#EF4444;">✗ Clôture Z à l'aveugle obligatoire</div>
        </div>
      </div>
    </div>
  </section>

  <!-- PRICING -->
  <section class="section-block container" id="tarifs">
    <div class="section-head">
      <div class="section-kicker">Tarification SaaS Mauritanie</div>
      <h2 class="section-title">Des Abonnements Simples en MRU</h2>
    </div>

    <div class="pricing-grid">
      <div class="price-card spotlight-card">
        <div>
          <div style="font-weight:800; color:#94A3B8; font-size:0.78rem;">PACK STARTER</div>
          <h3 style="font-family:var(--font-display); font-size:1.45rem;">Boutique Solo</h3>
          <div class="price-amount">1 500 <span class="price-currency">MRU / mois</span></div>
          <ul class="suite-feature-list" style="margin-top:16px;">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>1 Caisse + 1 App Full-Tek Boss</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Offline Local 100% autonome</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Bankily, Masrivi & Carnet Karni</span></li>
          </ul>
        </div>
        <button class="btn btn-ghost" style="width:100%;" onclick="openModal('modal-trial')">Choisir Starter</button>
      </div>

      <div class="price-card featured spotlight-card">
        <div>
          <div style="display:flex; justify-content:space-between; align-items:center;">
            <span style="font-weight:800; color:var(--ochre); font-size:0.78rem;">PACK PRO MULTI-POSTES</span>
            <span style="background:var(--ochre); color:#081017; font-size:0.68rem; font-weight:800; padding:3px 9px; border-radius:999px;">POPULAIRE</span>
          </div>
          <h3 style="font-family:var(--font-display); font-size:1.45rem;">Resto · Market · Pharma</h3>
          <div class="price-amount">3 000 <span class="price-currency">MRU / mois</span></div>
          <ul class="suite-feature-list" style="margin-top:16px;">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Jusqu'à 6 Caisses / Tablettes en LAN</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Bouclier FEFO Lots & Péremption</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>9 Rôles RBAC + Clôture Z Aveugle</span></li>
          </ul>
        </div>
        <button class="btn btn-primary" style="width:100%;" onclick="openModal('modal-trial')">Démarrer l'Essai Gratuit 15j</button>
      </div>

      <div class="price-card spotlight-card">
        <div>
          <div style="font-weight:800; color:#38BDF8; font-size:0.78rem;">PACK ENTERPRISE</div>
          <h3 style="font-family:var(--font-display); font-size:1.45rem;">Multi-Sites & Franchises</h3>
          <div class="price-amount">5 500 <span class="price-currency">MRU / mois</span></div>
          <ul class="suite-feature-list" style="margin-top:16px;">
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Caisses & Dépôts illimités</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Consolidation Groupe Full-Tek Boss</span></li>
            <li><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg><span>Support Prioritaire 24/7 Mauritanie</span></li>
          </ul>
        </div>
        <button class="btn btn-ghost" style="width:100%;" onclick="openModal('modal-trial')">Contacter Full-Tek</button>
      </div>
    </div>
  </section>

  <footer>
    <div class="container" style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:16px;">
      <div style="display:flex; align-items:center; gap:12px;">
        <svg width="130" height="32" viewBox="0 0 400 100">
          <rect x="10" y="18" width="78" height="16" rx="8" fill="#FFFFFF"/>
          <rect x="10" y="43" width="52" height="16" rx="8" fill="#E9A23B"/>
          <rect x="10" y="68" width="30" height="16" rx="8" fill="#FFFFFF"/>
          <text x="115" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="#FFFFFF">Full·Tek</text>
          <text x="117" y="83" font-family="'Plus Jakarta Sans',sans-serif" font-size="12" font-weight="700" letter-spacing="4.5" fill="#E9A23B">SUITE POS</text>
        </svg>
        <span>Direction M. Taha Chouaib · Nouakchott, Mauritanie</span>
      </div>
      <span>Français · العربية · English · Architecture Cloud + Edge LAN</span>
    </div>
  </footer>

  <!-- MODALS -->
  <div class="modal-backdrop" id="modal-login">
    <div class="modal-window">
      <button class="modal-close" onclick="closeModal('modal-login')">✕</button>
      <div style="text-align:center;">
        <div class="section-kicker" style="margin-bottom:8px;">Portail Caisse</div>
        <h3 style="font-family:var(--font-display); font-size:1.5rem;">Connexion Rapide par Code PIN</h3>
        <div id="pin-dots" style="font-family:var(--font-mono); font-size:1.8rem; letter-spacing:0.4em; color:var(--ochre); margin:14px 0;">• • • •</div>
        <div class="pin-grid">
          <button class="pin-key" onclick="pressPin('1')">1</button><button class="pin-key" onclick="pressPin('2')">2</button><button class="pin-key" onclick="pressPin('3')">3</button>
          <button class="pin-key" onclick="pressPin('4')">4</button><button class="pin-key" onclick="pressPin('5')">5</button><button class="pin-key" onclick="pressPin('6')">6</button>
          <button class="pin-key" onclick="pressPin('7')">7</button><button class="pin-key" onclick="pressPin('8')">8</button><button class="pin-key" onclick="pressPin('9')">9</button>
          <button class="pin-key" onclick="pressPin('C')" style="color:#EF4444;">C</button><button class="pin-key" onclick="pressPin('0')">0</button><button class="pin-key" onclick="pressPin('OK')" style="background:var(--ochre); color:#081017;">OK</button>
        </div>
      </div>
    </div>
  </div>

  <div class="modal-backdrop" id="modal-superadmin">
    <div class="modal-window" style="max-width:650px;">
      <button class="modal-close" onclick="closeModal('modal-superadmin')">✕</button>
      <div class="section-kicker" style="margin-bottom:8px;">admin.full-tek.com</div>
      <h3 style="font-family:var(--font-display); font-size:1.5rem; margin-bottom:10px;">Full·Tek Control — Cockpit Super-Admin</h3>
      <div style="display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-bottom:18px;">
        <div style="background:rgba(255,255,255,0.04); padding:12px; border-radius:12px;"><div style="font-size:0.72rem; color:#94A3B8;">MRR Actif</div><div style="font-family:var(--font-display); font-size:1.3rem; font-weight:800; color:#10B981;">184 500 MRU</div></div>
        <div style="background:rgba(255,255,255,0.04); padding:12px; border-radius:12px;"><div style="font-size:0.72rem; color:#94A3B8;">Boutiques</div><div style="font-family:var(--font-display); font-size:1.3rem; font-weight:800;">54 Tenants</div></div>
        <div style="background:rgba(255,255,255,0.04); padding:12px; border-radius:12px;"><div style="font-size:0.72rem; color:#94A3B8;">Serveur VPS</div><div style="font-family:var(--font-display); font-size:1.3rem; font-weight:800; color:var(--ochre);">255 MRU/m</div></div>
      </div>
      <button class="btn btn-primary" onclick="closeModal('modal-superadmin'); switchPosMode('boss');">Ouvrir dans le Simulateur</button>
    </div>
  </div>

  <div class="modal-backdrop" id="modal-trial">
    <div class="modal-window">
      <button class="modal-close" onclick="closeModal('modal-trial')">✕</button>
      <div class="section-kicker" style="margin-bottom:8px;">15 Jours Gratuits</div>
      <h3 style="font-family:var(--font-display); font-size:1.45rem; margin-bottom:14px;">Déployer ma Boutique Full·Tek</h3>
      <input class="form-input" type="text" placeholder="Nom du commerce (ex: Pharmacie Chinguetti)" />
      <select class="form-input" style="background:#0F1C28;">
        <option>Full-Tek Resto (Restaurant / Khaima VIP)</option>
        <option>Full-Tek Market (Supermarché / Supérette)</option>
        <option>Full-Tek Pharma (Pharmacie)</option>
        <option>Full-Tek Boss (Multi-Boutiques)</option>
      </select>
      <input class="form-input" type="tel" placeholder="Numéro WhatsApp / Bankily (+222 ...)" />
      <button class="btn btn-primary" style="width:100%; padding:13px;" onclick="closeModal('modal-trial');">Activer mon Espace Boutique</button>
    </div>
  </div>

  <script>
    const LOGO_SVGS = {
      resto: `<svg width="118" height="30" viewBox="0 0 400 100"><rect x="10" y="18" width="78" height="16" rx="8" fill="currentColor"/><rect x="10" y="43" width="52" height="16" rx="8" fill="#E4572E"/><rect x="10" y="68" width="30" height="16" rx="8" fill="currentColor"/><text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="currentColor">Full·Tek</text><g transform="translate(118,67) scale(.95)" fill="none" stroke="#E4572E" stroke-width="2.4"><path d="M7 3v6a2 2 0 0 0 4 0V3M9 3v18M17 21V3c-2.5 1.8-3.5 4.5-3.5 8H17"/></g><text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#E4572E">RESTO</text></svg>`,
      market: `<svg width="124" height="30" viewBox="0 0 400 100"><rect x="10" y="18" width="78" height="16" rx="8" fill="currentColor"/><rect x="10" y="43" width="52" height="16" rx="8" fill="#2E9E5B"/><rect x="10" y="68" width="30" height="16" rx="8" fill="currentColor"/><text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="currentColor">Full·Tek</text><g transform="translate(118,67) scale(.95)" fill="none" stroke="#2E9E5B" stroke-width="2.4"><path d="M3 4h3l2.4 11h9.6l2-8H7"/><circle cx="10" cy="19.5" r="1.6"/><circle cx="17" cy="19.5" r="1.6"/></g><text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#2E9E5B">MARKET</text></svg>`,
      pharma: `<svg width="124" height="30" viewBox="0 0 400 100"><rect x="10" y="18" width="78" height="16" rx="8" fill="currentColor"/><rect x="10" y="43" width="52" height="16" rx="8" fill="#1B8FD9"/><rect x="10" y="68" width="30" height="16" rx="8" fill="currentColor"/><text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="currentColor">Full·Tek</text><g transform="translate(118,67) scale(.95)"><path fill="#1B8FD9" d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/></g><text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#1B8FD9">PHARMA</text></svg>`,
      boss: `<svg width="114" height="30" viewBox="0 0 400 100"><rect x="10" y="18" width="78" height="16" rx="8" fill="currentColor"/><rect x="10" y="43" width="52" height="16" rx="8" fill="#C99A2E"/><rect x="10" y="68" width="30" height="16" rx="8" fill="currentColor"/><text x="118" y="56" font-family="'Space Grotesk',sans-serif" font-size="44" font-weight="800" fill="currentColor">Full·Tek</text><g transform="translate(118,67) scale(.95)" fill="#C99A2E"><rect x="3" y="12" width="5" height="9" rx="1"/><rect x="10" y="4" width="5" height="17" rx="1"/><rect x="17" y="8" width="5" height="13" rx="1"/></g><text x="145" y="87" font-family="'Plus Jakarta Sans',sans-serif" font-size="17" font-weight="800" letter-spacing="4" fill="#C99A2E">BOSS</text></svg>`
    };

    const SVG_ICONS = {
      dish: `<svg viewBox="0 0 24 24" fill="none" stroke="#E4572E" stroke-width="2"><path d="M12 5a7 7 0 0 1 7 7H5a7 7 0 0 1 7-7z"/><path d="M3 15h18"/><path d="M12 2v3"/></svg>`,
      grill: `<svg viewBox="0 0 24 24" fill="none" stroke="#F59E0B" stroke-width="2"><path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/></svg>`,
      tea: `<svg viewBox="0 0 24 24" fill="none" stroke="#10B981" stroke-width="2"><path d="M17 8h1a4 4 0 1 1 0 8h-1"/><path d="M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4Z"/><line x1="6" y1="2" x2="6" y2="4"/><line x1="10" y1="2" x2="10" y2="4"/></svg>`,
      box: `<svg viewBox="0 0 24 24" fill="none" stroke="#2E9E5B" stroke-width="2"><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/></svg>`,
      alert: `<svg viewBox="0 0 24 24" fill="none" stroke="#EF4444" stroke-width="2.2"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`,
      pill: `<svg viewBox="0 0 24 24" fill="none" stroke="#1B8FD9" stroke-width="2"><path d="m10.5 20.5 10-10a4.95 4.95 0 1 0-7-7l-10 10a4.95 4.95 0 1 0 7 7Z"/><path d="m8.5 8.5 7 7"/></svg>`,
      chart: `<svg viewBox="0 0 24 24" fill="none" stroke="#E9A23B" stroke-width="2"><path d="M3 3v18h18"/><path d="m19 9-5 5-4-4-3 3"/></svg>`
    };

    const CATALOG_DATA = {
      resto: {
        title: "Salon Khaima VIP-04", role: "Caissier · PIN #4821", storeName: "FULL-TEK RESTO",
        categories: ["Plats Mauritaniens", "Grillades & Méchoui", "Burgers", "Atay & Jus"],
        items: [
          { name: "Thieboudienne Royal Poisson", price: 450, badge: "KDS Cuisine", badgeType: "ok", icon: "dish" },
          { name: "1/2 Agneau Méchoui Braisé", price: 2800, badge: "Grill VIP", badgeType: "ok", icon: "grill" },
          { name: "Brochettes Chameau Grillées", price: 520, badge: "KDS Grill", badgeType: "ok", icon: "grill" },
          { name: "Chawarma Double Fromage", price: 240, badge: "Rapide", badgeType: "ok", icon: "dish" },
          { name: "Thé Atay Mauritanien", price: 150, badge: "Salon VIP", badgeType: "ok", icon: "tea" },
          { name: "Jus Bissap & Zrig Frais", price: 120, badge: "Bar Frais", badgeType: "ok", icon: "tea" }
        ]
      },
      market: {
        title: "Caisse Express N°02", role: "Caissier · FEFO Actif", storeName: "FULL-TEK MARKET",
        categories: ["Crémerie", "Épicerie", "Boissons", "Boucherie Pesée"],
        items: [
          { name: "Lait Frais Tiviski 1L", price: 95, badge: "Lot #L84 (J-45)", badgeType: "ok", icon: "box" },
          { name: "Yaourt Nature Lot #L12", price: 35, badge: "PÉRIMÉ !", badgeType: "danger", icon: "alert", expired: true },
          { name: "Riz Parfumé 25 kg", price: 1450, badge: "Lot #R09 (OK)", badgeType: "ok", icon: "box" },
          { name: "Huile Végétale 5L", price: 420, badge: "Promo J-25", badgeType: "warn", icon: "box" },
          { name: "Viande Bovine Pesée", price: 580, badge: "Balance 2D", badgeType: "ok", icon: "grill" },
          { name: "Thé Vert Achoura 500g", price: 260, badge: "Stock: 142", badgeType: "ok", icon: "tea" }
        ]
      },
      pharma: {
        title: "Officine Chinguetti", role: "Pharmacien · Ordre 904", storeName: "FULL-TEK PHARMA",
        categories: ["Antibiotiques", "Antalgiques", "Diabète", "Pédiatrie"],
        items: [
          { name: "Amoxicilline 1g", price: 310, badge: "Lot #A91 (2027)", badgeType: "ok", icon: "pill" },
          { name: "Sirop Pédiatrique #P02", price: 190, badge: "EXPIRÉ ! FEFO", badgeType: "danger", icon: "alert", expired: true },
          { name: "Paracétamol 1000mg", price: 85, badge: "Lot #D44", badgeType: "ok", icon: "pill" },
          { name: "Insuline Rapide Stylo", price: 980, badge: "Lot #F19 (J-28)", badgeType: "warn", icon: "pill" },
          { name: "Vitamine C Efferv.", price: 145, badge: "Blister OK", badgeType: "ok", icon: "pill" },
          { name: "Lait Infantile 1er Âge", price: 460, badge: "Lot #M88", badgeType: "ok", icon: "box" }
        ]
      },
      boss: {
        title: "Cockpit Super-Admin MRR", role: "Direction M. Taha Chouaib", storeName: "FULL-TEK CONTROL",
        categories: ["Abonnements MRR", "Audit Fraude", "Multi-Sites", "Licences 30j"],
        items: [
          { name: "Resto El Khaima (Pro)", price: 3000, badge: "MRR Actif", badgeType: "ok", icon: "chart" },
          { name: "Pharmacie Salam (Pro)", price: 3000, badge: "MRR Actif", badgeType: "ok", icon: "chart" },
          { name: "Supermarché Baraka", price: 5500, badge: "6 Caisses LAN", badgeType: "ok", icon: "chart" },
          { name: "Boulangerie Tidjikja", price: 1500, badge: "Renouvelé", badgeType: "ok", icon: "chart" },
          { name: "Licence Offline 30j", price: 3000, badge: "Clé ECDSA OK", badgeType: "ok", icon: "chart" },
          { name: "Audit Clôture Z Aveugle", price: 0, badge: "Écart: 0 MRU", badgeType: "ok", icon: "chart" }
        ]
      }
    };

    let currentMode = "resto";
    let cart = [{ name: "Thieboudienne Royal Poisson", price: 450, qty: 2 }, { name: "Brochettes Chameau Grillées", price: 520, qty: 1 }, { name: "Thé Atay Mauritanien", price: 150, qty: 1 }];
    let pendingExpiredItem = null;
    let isOnline = true;
    let topoOutage = false;
    let bossTotalRevenue = 148520;

    function renderPosSimulator() {
      const data = CATALOG_DATA[currentMode];
      document.getElementById("pos-dynamic-logo").innerHTML = LOGO_SVGS[currentMode];
      document.getElementById("pos-header-title").textContent = data.title;
      document.getElementById("pos-role-badge").textContent = data.role;
      document.getElementById("rcpt-store").textContent = data.storeName;

      document.getElementById("pos-cat-pills").innerHTML = data.categories.map((c, idx) =>
        `<button class="cat-pill ${idx === 0 ? 'active' : ''}" onclick="selectCategory(this)">${c}</button>`
      ).join("");

      document.getElementById("pos-items-grid").innerHTML = data.items.map((item, idx) => `
        <div class="pos-item-card ${item.expired ? 'expired-item' : ''}" onclick="clickPosItem(${idx})">
          <div class="item-top-row">
            <div class="item-art-box">${SVG_ICONS[item.icon]}</div>
            <span class="item-badge ${item.badgeType}">${item.badge}</span>
          </div>
          <div>
            <div class="item-name">${item.name}</div>
            <div class="item-price-row">
              <span class="item-price">${item.price.toLocaleString('fr-FR')} MRU</span>
              <span class="item-add-circle">+</span>
            </div>
          </div>
        </div>
      `).join("");

      renderCartAndReceipt("BANKILY VERIFIÉ");
    }

    function selectCategory(btn) {
      btn.parentElement.querySelectorAll(".cat-pill").forEach(el => el.classList.remove("active"));
      btn.classList.add("active");
    }

    function switchPosMode(mode) {
      currentMode = mode;
      document.querySelectorAll(".suite-tab").forEach(btn => btn.classList.toggle("active", btn.getAttribute("data-mode") === mode));
      const firstItems = CATALOG_DATA[mode].items.filter(i => !i.expired).slice(0, 2);
      cart = firstItems.map(i => ({ name: i.name, price: i.price, qty: 1 }));
      renderPosSimulator();
    }

    function setPosTheme(themeId, btn) {
      document.getElementById("pos-screen").setAttribute("data-theme", themeId);
      document.querySelectorAll(".theme-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
    }

    function clickPosItem(idx) {
      const item = CATALOG_DATA[currentMode].items[idx];
      if (item.expired) {
        pendingExpiredItem = item;
        document.getElementById("fefo-item-title").textContent = `Vente Bloquée — ${item.name}`;
        document.getElementById("fefo-overlay").classList.add("active");
        return;
      }
      addItemToCart(item);
    }

    function addItemToCart(item) {
      const existing = cart.find(c => c.name === item.name);
      if (existing) existing.qty += 1;
      else cart.push({ name: item.name, price: item.price, qty: 1 });
      renderCartAndReceipt("EN COURS DE SAISIE");
    }

    function closeFefoModal() { document.getElementById("fefo-overlay").classList.remove("active"); pendingExpiredItem = null; }
    function overrideFefoWithPin() { if (pendingExpiredItem) addItemToCart(pendingExpiredItem); closeFefoModal(); }
    function clearCart() { cart = []; renderCartAndReceipt("PANIER VIDE"); }

    function getCartTotal() { return cart.reduce((acc, c) => acc + c.price * c.qty, 0); }

    function renderCartAndReceipt(stampText) {
      const linesEl = document.getElementById("cart-lines");
      const rcptEl = document.getElementById("rcpt-items");
      const total = getCartTotal();

      if (cart.length === 0) {
        linesEl.innerHTML = `<div style="text-align:center; color:var(--pos-muted); padding:28px 10px; font-size:0.77rem;">Cliquez sur un produit à gauche</div>`;
        rcptEl.innerHTML = `<div class="receipt-line"><span>Aucun article</span><span>0 MRU</span></div>`;
      } else {
        linesEl.innerHTML = cart.map(c => `<div class="cart-line"><div><strong>${c.qty}x</strong> ${c.name}</div><div style="font-family:var(--font-mono); font-weight:700;">${(c.price * c.qty).toLocaleString('fr-FR')} MRU</div></div>`).join("");
        rcptEl.innerHTML = cart.map(c => `<div class="receipt-line"><span>${c.qty}x ${c.name.substring(0, 18)}</span><span>${(c.price * c.qty).toLocaleString('fr-FR')}</span></div>`).join("");
      }

      document.getElementById("cart-total-val").textContent = `${total.toLocaleString('fr-FR')} MRU`;
      document.getElementById("rcpt-total").textContent = `${total.toLocaleString('fr-FR')} MRU`;
      document.getElementById("rcpt-stamp").textContent = stampText;
    }

    function payOrder(method) {
      const total = getCartTotal();
      const paper = document.getElementById("thermal-paper");
      paper.classList.remove("printing");
      void paper.offsetWidth;
      paper.classList.add("printing");
      const num = Math.floor(1050 + Math.random() * 8900);
      document.getElementById("ticket-num-lbl").textContent = `Ticket #FT-${num}`;
      document.getElementById("rcpt-time").textContent = `Ticket #FT-${num} · ${isOnline ? 'Sync Cloud+LAN' : 'Stocké Offline LAN'}`;
      renderCartAndReceipt(`PAYÉ · ${method}`);

      // Update Live Full-Tek Boss Mobile Sync Widget!
      bossTotalRevenue += total;
      document.getElementById("boss-live-total").textContent = `${bossTotalRevenue.toLocaleString('fr-FR')} MRU`;
      document.getElementById("boss-live-event").textContent = `+${total.toLocaleString('fr-FR')} MRU encaissés (${method}) sur #FT-${num}`;
      const bossCard = document.getElementById("boss-live-card");
      bossCard.classList.remove("flash");
      void bossCard.offsetWidth;
      bossCard.classList.add("flash");
    }

    function triggerLaserScan() {
      const laser = document.getElementById("laser-sweep");
      laser.classList.remove("scanning");
      void laser.offsetWidth;
      laser.classList.add("scanning");
      setTimeout(() => {
        const items = CATALOG_DATA[currentMode].items;
        const expIdx = items.findIndex(i => i.expired);
        clickPosItem(expIdx !== -1 ? expIdx : 0);
      }, 650);
    }

    function togglePosNetwork() {
      isOnline = !isOnline;
      const btn = document.getElementById("net-toggle-btn");
      const lbl = document.getElementById("net-status-lbl");
      btn.className = isOnline ? "pos-chip-btn online" : "pos-chip-btn offline";
      lbl.textContent = isOnline ? "Cloud + LAN (0.08s)" : "Offline LAN Actif";
    }

    function toggleTopologyOutage() {
      topoOutage = !topoOutage;
      document.getElementById("cloud-link-line").setAttribute("stroke", topoOutage ? "#EF4444" : "#10B981");
      document.getElementById("cloud-box").setAttribute("stroke", topoOutage ? "#EF4444" : "#10B981");
      document.getElementById("cloud-status-txt").setAttribute("fill", topoOutage ? "#EF4444" : "#10B981");
      document.getElementById("cloud-status-txt").textContent = topoOutage ? "✕ FIBRE / 4G COUPÉE" : "● EN LIGNE (TLS 1.3)";
      document.getElementById("outage-sim-btn").classList.toggle("active", topoOutage);
      document.getElementById("outage-btn-lbl").textContent = topoOutage ? "Rétablir la Connexion Internet" : "Simuler une Coupure Internet";
      document.getElementById("topo-state-title").textContent = topoOutage
        ? "Coupure Internet Simulée : Le Réseau Local LAN Prend le Relais (0,08s)"
        : "État Actuel : Cloud Synchronisé + Réseau Local Wi-Fi Actif";
    }

    function calcRoi() {
      const posCount = parseInt(document.getElementById("roi-pos-range").value, 10);
      const monthlyLoss = parseInt(document.getElementById("roi-loss-range").value, 10);
      document.getElementById("roi-pos-lbl").textContent = `${posCount} Caisse${posCount > 1 ? 's' : ''}`;
      document.getElementById("roi-loss-lbl").textContent = `${monthlyLoss.toLocaleString('fr-FR')} MRU / mois`;

      const annualSaved = Math.round(monthlyLoss * 0.85 * 12);
      document.getElementById("roi-annual-val").textContent = `+ ${annualSaved.toLocaleString('fr-FR')} MRU`;
    }

    const RBAC_ROLES = {
      caissier: { title: "Rôle : Caissier Principal (PIN 4 chiffres)", ok: "✓ Encaisser Cash MRU, Bankily, Masrivi, Sedad", no1: "✗ Interdiction de supprimer une ligne après validation", no2: "✗ Clôture Z à l'aveugle obligatoire" },
      serveur: { title: "Rôle : Serveur Salle & Khaima VIP", ok: "✓ Prendre commande sur tablette vers écran KDS", no1: "✗ Aucun accès au tiroir-caisse ni aux remises", no2: "✗ Masquage du chiffre d'affaires global" },
      pharmacien: { title: "Rôle : Docteur Pharmacien / Responsable Lot", ok: "✓ Contrôle lots FEFO, substitution DCI et ordonnances", no1: "✓ Retrait et blocage de lots suspects", no2: "✗ Journal d'audit horodaté immuable" },
      gerant: { title: "Rôle : Gérant Boutique (PIN Superviseur)", ok: "✓ Validation retours, remises et écart Z", no1: "✓ Réception bons de livraison & stocks", no2: "✗ Notifications temps réel sur Full-Tek Boss" },
      superadmin: { title: "Rôle : Super-Admin Plateforme (M. Taha Chouaib)", ok: "✓ Création boutiques, essais 15j & suivi MRR", no1: "✓ Génération licences Offline 30j ECDSA", no2: "✓ Supervision multi-tenant admin.full-tek.com" }
    };

    function inspectRole(roleKey, btn) {
      document.querySelectorAll(".rbac-role-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      const r = RBAC_ROLES[roleKey];
      document.getElementById("rbac-matrix-box").innerHTML = `<div style="font-weight:800; color:var(--ochre); margin-bottom:4px;">${r.title}</div><div style="color:#10B981;">${r.ok}</div><div style="color:${r.no1.startsWith('✓') ? '#10B981' : '#EF4444'};">${r.no1}</div><div style="color:${r.no2.startsWith('✓') ? '#10B981' : '#EF4444'};">${r.no2}</div>`;
    }

    function openModal(id) { document.getElementById(id).classList.add("open"); }
    function closeModal(id) { document.getElementById(id).classList.remove("open"); }

    let pinValue = "";
    function pressPin(key) {
      if (key === "C") pinValue = "";
      else if (key === "OK") { closeModal("modal-login"); pinValue = ""; }
      else if (pinValue.length < 4) pinValue += key;
      document.getElementById("pin-dots").textContent = pinValue.padEnd(4, "•").split("").join(" ");
    }

    const I18N = {
      fr: { dir: "ltr", nav_sim: "Simulateur Live", nav_suites: "Les 4 Logos & Gammes", nav_net: "Cloud + Edge LAN", nav_roi: "Calculateur MRU", nav_price: "Tarifs", btn_superadmin: "Full-Tek Control", btn_login: "Accès Caisse", btn_trial: "Essai 15 Jours", hero_live_badge: "Architecture Hybride V4", hero_eyebrow: "Mauritanie · Bankily · Masrivi · Bouclier FEFO · Offline LAN", hero_title: `L'écosystème de caisse qui <span class="gradient-ochre">encaisse en 0,08 seconde</span>, même sans Internet.`, hero_lead: "Une marque forte déclinée en 4 logiciels spécialisés : Full-Tek Resto, Full-Tek Market, Full-Tek Pharma (avec blocage automatique FEFO des lots périmés) et Full-Tek Boss en temps réel.", cta_start: "Déployer ma Boutique (15j Gratuits)", cta_logos: "Voir les 4 Logos & Solutions" },
      ar: { dir: "rtl", nav_sim: "المحاكي التفاعلي", nav_suites: "الشعارات والأنظمة", nav_net: "السحابة و LAN", nav_roi: "حاسبة الأرباح", nav_price: "الأسعار", btn_superadmin: "لوحة المالك", btn_login: "دخول الكاشير", btn_trial: "تجربة 15 يوماً", hero_live_badge: "الجيل الرابع الهجين", hero_eyebrow: "موريتانيا · بنكيلي · مصرفي · حماية FEFO · يعمل بدون إنترنت", hero_title: `نظام الكاشير الذكي الذي <span class="gradient-ochre">يعمل في 0.08 ثانية</span> حتى عند انقطاع الإنترنت.`, hero_lead: "هوية واحدة بأربعة أنظمة متخصصة: المطاعم والخيم، السوبرماركت، الصيدليات (حظر تلقائي للأدوية منتهية الصلاحية FEFO) وإدارة الفروع للملاك.", cta_start: "ابدأ التجربة المجانية (15 يوماً)", cta_logos: "استكشف الأنظمة والشعارات الأربعة" },
      en: { dir: "ltr", nav_sim: "Live Simulator", nav_suites: "4 Logos & Suites", nav_net: "Cloud + Edge LAN", nav_roi: "ROI Calculator", nav_price: "Pricing", btn_superadmin: "Full-Tek Control", btn_login: "POS Login", btn_trial: "15-Day Trial", hero_live_badge: "Hybrid Architecture V4", hero_eyebrow: "Mauritania · Bankily · Masrivi · FEFO Shield · Offline LAN", hero_title: `The intelligent POS ecosystem that <span class="gradient-ochre">checks out in 0.08s</span>, even without Internet.`, hero_lead: "One unified brand across 4 dedicated apps: Full-Tek Resto, Full-Tek Market, Full-Tek Pharma (automatic FEFO expired batch blocker) and real-time Full-Tek Boss.", cta_start: "Deploy My Store (15 Days Free)", cta_logos: "Explore 4 Logos & Suites" }
    };

    function setLanguage(lang) {
      const dict = I18N[lang];
      document.documentElement.lang = lang;
      document.documentElement.dir = dict.dir;
      document.querySelectorAll(".lang-btn").forEach(b => b.classList.remove("active"));
      document.getElementById(`lang-${lang}`).classList.add("active");
      document.querySelectorAll("[data-i18n]").forEach(el => {
        const key = el.getAttribute("data-i18n");
        if (dict[key]) el.innerHTML = dict[key];
      });
    }

    // Spotlight cursor tracking & Scroll progress
    document.querySelectorAll(".spotlight-card").forEach(card => {
      card.addEventListener("mousemove", e => {
        const rect = card.getBoundingClientRect();
        card.style.setProperty("--mx", `${e.clientX - rect.left}px`);
        card.style.setProperty("--my", `${e.clientY - rect.top}px`);
      });
    });

    window.addEventListener("scroll", () => {
      const h = document.documentElement;
      const pct = (h.scrollTop / (h.scrollHeight - h.clientHeight)) * 100;
      document.getElementById("scroll-progress").style.width = `${pct}%`;
    });

    renderPosSimulator();
    calcRoi();
  </script>
</body>
</html>
"""

with open(r"d:\_Documents\Bureau\caissamrr\Full-Tek_Accueil_Interactif_Prototype.html", "w", encoding="utf-8") as f:
    f.write(HTML_CONTENT)

print("Updated luxury landing page with all 4 official Model 11 sub-brand logos, Live Boss sync & ROI calculator!")
