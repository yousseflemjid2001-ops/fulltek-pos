# Design System Master File — Full-Tek POS

> **LOGIC:** When building a specific page, first check `design-system/pages/[page-name].md`.
> If that file exists, its rules **override** this Master file.
> If not, strictly follow the rules below.

---

**Project:** Full-Tek POS Suite (Mauritania)
**Standard:** UI/UX Pro Max + Anti-Slop High-Design
**Brand Charter:** Modèle 11 « Pilules » (Officiel)
**Category:** POS Suite / SaaS + LAN Edge Offline Architecture (Resto, Market, Pharma, Boss)

---

## Global Rules

### Official Brand Color Palette (Modèle 11 « Pilules »)

| Role | Hex | CSS Variable | Usage & Contrast Check |
|------|-----|--------------|-------------------------|
| Primary Base / Petrol | `#264653` | `--color-primary` | Deep petrol base, container surfaces, brand foundation |
| Primary Light / Petrol 2 | `#315869` | `--color-primary-light` | Elevated surfaces, cards, interactive borders |
| Accent / Warm Ochre | `#E9A23B` | `--color-accent` | Primary CTA, glowing pill, brand focus, active indicators |
| On Accent / CTA Text | `#141E15` / `#0F1B20` | `--color-on-accent` | Contrast > 8:1 against `#E9A23B` (AAA compliant) |
| Deep Ground / Night | `#0F1B20` | `--color-night-1` | Root page background (never pure cold black #000) |
| Elevated Surface / Night 2 | `#14262D` | `--color-night-2` | Cards, navigation bar, footer |
| High Surface / Night 3 | `#1B323B` | `--color-night-3` | Modals, interactive popups, active cards |
| Text Primary / Ink | `#F4F7F8` | `--color-foreground` | Contrast 14.8:1 on `#0F1B20` (AAA) |
| Text Muted / Secondary | `#A9B8BE` | `--color-muted-foreground`| Contrast 6.8:1 on `#0F1B20` (AA >= 4.5:1 compliant) |
| Border / Subtle Line | `rgba(255,255,255,0.08)`| `--color-border` | Clean pixel-crisp separation |

### The 4 Business Suite Accents

| Suite | Solution | Hex Accent | Usage |
|-------|----------|------------|-------|
| 🍽️ Resto | Full-Tek Resto | `#E4572E` | Kitchen tickets, table management, VIP Khaima salons |
| 🛒 Market | Full-Tek Market | `#2E9E5B` | Barcode scan, connected scales, wholesale/retail pricing |
| 💊 Pharma | Full-Tek Pharma | `#1B8FD9` | FEFO batch tracking, expiry blocker, cold chain |
| 📱 Boss | Full-Tek Boss | `#C99A2E` | Owner mobile cockpit, live revenue, multi-shop KPIs |

---

## Typography

- **Heading Font:** `Plus Jakarta Sans`, 700 / 800 (letter-spacing: -0.03em)
- **Body Font:** `Plus Jakarta Sans`, 400 / 500 / 600 (line-height: 1.6)
- **Arabic Heading & Body:** `Cairo`, 500 / 700 / 800 (line-height: 1.65 for Arabic optical balance)
- **Monospace (KPIs / Timers / POS totals):** `'JetBrains Mono', 'Courier New', monospace`

### Google Fonts Link
```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Cairo:wght@500;600;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
```

---

## 8dp Spacing System

| Token | Value | Rem | Usage |
|-------|-------|-----|-------|
| `--space-1` | `4px` | `0.25rem` | Micro badges, tight gaps |
| `--space-2` | `8px` | `0.5rem` | Icon-to-label spacing, tags |
| `--space-3` | `12px` | `0.75rem` | Button gap, compact padding |
| `--space-4` | `16px` | `1rem` | Standard card internal padding |
| `--space-5` | `20px` | `1.25rem` | Component gutter |
| `--space-6` | `24px` | `1.5rem` | Card padding, grid gap |
| `--space-8` | `32px` | `2rem` | Section header gap |
| `--space-12`| `48px` | `3rem` | Major module separation |
| `--space-16`| `64px` | `4rem` | Section vertical rhythm |
| `--space-24`| `96px` | `6rem` | Hero / major landmark padding |

---

## UI/UX Pro Max Rules & Polish Standards

### 1. Zero Emoji Icons
- **Strict Rule:** Never use system emojis (🎨 🚀 ⚙️ ✓ ⚠) in structural controls, alerts, badges, or buttons.
- **Implementation:** Always use crisp inline SVG vector icons (Lucide/Heroicons standard), stroke 1.75px–2.2px with rounded ends, and `aria-hidden="true"`.

### 2. Touch Targets & Interaction Feedback
- **Touch Targets:** Minimum 44×44px for all buttons, inputs, tabs, dropdowns, and switchers.
- **Hover Transitions:** 150ms–250ms with `cubic-bezier(0.16, 1, 0.3, 1)`.
- **Active Compression:** Interactive press feedback (`transform: scale(0.98)` or `translateY(1px)`).
- **Cursor:** `cursor: pointer` on all clickable items; `cursor: not-allowed` on disabled items.

### 3. Glassmorphism & Visual Depth
- **Backdrop Blur:** 14px–20px frosted glass on navigation bar and modal overlays.
- **Multi-layer Borders:** `1px solid rgba(255, 255, 255, 0.08)` with colored glow matched to suite accent.
- **Ambient Glow:** Subtle radial background aura (`filter: blur(80px)`) to establish atmosphere without visual clutter.

### 4. Accessibility & Inclusive Design (WCAG 2.2 AA)
- **Contrast Ratio:** Text contrast >= 4.5:1 everywhere.
- **Focus Indicators:** Uncompromised `:focus-visible` with `outline: 2px solid var(--ochre); outline-offset: 3px;`.
- **Scroll Padding:** `scroll-padding-top: 84px` so fixed navigation never covers focused elements.
- **Reduced Motion:** Full `prefers-reduced-motion: reduce` fallback disables long animations and immediately finishes the preloader.
- **Screen Reader Clarity:** Form inputs have visible `<label>`, announcements use `role="status"` and `aria-live="polite"`.

### 5. Right-to-Left (RTL / Arabic) Native Perfection
- Bidirectional support: English & French (LTR) + Arabic (RTL).
- CSS Logical Properties: `margin-inline`, `padding-inline`, `inset-inline-start`, `text-align: start`.
- Mirrored navigation chevrons and progress directions when `dir="rtl"`.

---

## Pre-Delivery Checklist
- [x] No emojis as icons (100% SVG vectors).
- [x] Strict brand color compliance (Modèle 11 « Pilules »: #264653 / #E9A23B / #0F1B20).
- [x] All 4 solutions represented with their official SVGs and dedicated accents.
- [x] Animated preloader splash screen with skip and replay controls.
- [x] Touch targets >= 44px.
- [x] Text contrast >= 4.5:1.
- [x] Keyboard navigation + visible focus rings.
- [x] Offline resilience simulator functional.
- [x] Responsive layout tested across 375px, 768px, 1024px, 1440px.
