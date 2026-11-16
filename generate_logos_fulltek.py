# -*- coding: utf-8 -*-
"""Full-Tek : 12 concepts de logos + déclinaisons Resto / Market / Pharma / Boss.
Sorties : SVG individuels (statiques + animés), showcase HTML animé, PDF de présentation."""
import os, subprocess

OUT = r"d:\_Documents\Bureau\caissamrr"
LOGO_DIR = os.path.join(OUT, "Logos_Full-Tek")
os.makedirs(LOGO_DIR, exist_ok=True)


# ------------------------------------------------------------------ utils
def mix(c1, c2, t):
    a = [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(c2[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def R(x, y, w, h, f, c, rx=0, st=""):
    return '<rect class="p %s" x="%s" y="%s" width="%s" height="%s" rx="%s" fill="%s"%s/>' % (c, x, y, w, h, rx, f, st)


def P(d, f, c):
    return '<path class="p %s" d="%s" fill="%s"/>' % (c, d, f)


def S(d, col, w, c):
    return ('<path class="p st %s" d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
            'stroke-linejoin="round" pathLength="1"/>') % (c, d, col, w)


def C(cx, cy, r, f, c, stroke=None, sw=0):
    s = ' stroke="%s" stroke-width="%s"' % (stroke, sw) if stroke else ""
    return '<circle class="p %s" cx="%s" cy="%s" r="%s" fill="%s"%s/>' % (c, cx, cy, r, f, s)


# ------------------------------------------------------------------ marks (viewBox 0 0 100 100)
def m1(ink, acc, bg):  # Barre partagée : le F prête sa barre au T
    return (P("M10 20 H92 V34 H25 V82 H10 Z", ink, "p1") + R(25, 49, 24, 12, acc, "p2", 1.5) + R(63, 34, 14, 48, ink, "p3"))


def m2(ink, acc, bg):  # Circuit : traits + noeuds
    return (S("M22 82 V26 H48", ink, 9, "p1") + S("M22 53 H40", ink, 9, "p2") + S("M62 26 H94 M78 26 V82", ink, 9, "p3")
            + C(48, 26, 6.5, bg, "p4", acc, 4) + C(40, 53, 6.5, bg, "p4", acc, 4) + C(78, 82, 6.5, bg, "p4", acc, 4))


def m3(ink, acc, bg):  # Pastille : F en négatif + le « point » de vente
    return (R(6, 6, 88, 88, ink, "p1", 24) + P("M27 28 H73 V40 H40 V48 H62 V59 H40 V74 H27 Z", bg, "p2") + C(74, 70, 8.5, acc, "p3"))


def m4(ink, acc, bg):  # Hexagone (écrou / cellule) + F-T
    return (S("M50 8 L88 29 V71 L50 92 L12 71 V29 Z", ink, 7, "p1") + S("M34 70 V37 H72", ink, 8, "p2")
            + S("M34 54 H54", ink, 8, "p2") + S("M62 37 V70", acc, 8, "p3"))


def m5(ink, acc, bg):  # Ticket de caisse
    z = "M16 8 H84 V92 L76 85 L68 92 L60 85 L52 92 L44 85 L36 92 L28 85 L20 92 L16 88 Z"
    return (P(z, ink, "p1") + P("M30 24 H70 V34 H41 V43 H60 V52 H41 V66 H30 Z", bg, "p2") + R(47, 68, 23, 5, acc, "p3", 2))


def m6(ink, acc, bg):  # F + flèche (vitesse)
    return (P("M16 20 H66 V34 H30 V82 H16 Z", ink, "p1") + R(30, 49, 25, 12, ink, "p2") + P("M63 13 L95 27 L63 41 Z", acc, "p3"))


def m7(ink, acc, bg):  # Monogramme serif premium
    return ('<circle class="p st p1" cx="50" cy="50" r="44" fill="none" stroke="%s" stroke-width="2.4" pathLength="1"/>' % acc
            + '<text class="p p2" x="50" y="64" text-anchor="middle" font-family="Georgia,\'Times New Roman\',serif" '
              'font-size="45" font-weight="700" fill="%s" letter-spacing="-2">FT</text>' % ink
            + R(40, 75, 20, 2.6, acc, "p3", 1.3))


def m8(ink, acc, bg):  # Disque plein : T en réserve
    return (C(50, 50, 44, ink, "p1") + P("M27 32 H73 V44 H56 V75 H44 V44 H27 Z", bg, "p2") + C(75, 72, 7.5, acc, "p3"))


def m9(ink, acc, bg):  # F-Stack : couches cloud / edge
    return (R(11, 18, 15, 64, ink, "p1", 2) + R(35, 18, 54, 14, ink, "p2", 3) + R(35, 43, 38, 14, acc, "p3", 3)
            + R(35, 68, 22, 14, ink, "p4", 3))


def m10(ink, acc, bg):  # Pixel
    F = ["XXXX", "X...", "XXX.", "X...", "X...", "X...", "X..."]
    T = ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "..X.."]
    out, n = "", 0
    for r in range(7):
        for ci, ch in enumerate(F[r]):
            if ch == "X":
                out += R(5 + ci * 9, 18 + r * 9, 8, 8, ink, "pq", 1.4, ' style="animation-delay:%.2fs"' % (n * 0.045)); n += 1
        for ci, ch in enumerate(T[r]):
            if ch == "X":
                col = acc if r > 0 else ink
                out += R(5 + (5 + ci) * 9, 18 + r * 9, 8, 8, col, "pq", 1.4, ' style="animation-delay:%.2fs"' % (n * 0.045)); n += 1
    return out


def m11(ink, acc, bg):  # Pilules : lignes de ticket qui diminuent
    return (R(10, 18, 78, 16, ink, "p1", 8) + R(10, 43, 52, 16, acc, "p2", 8) + R(10, 68, 30, 16, ink, "p3", 8))


def m12(ink, acc, bg):  # T + signal (online / offline edge)
    def arc(r, c):
        return S("M%.1f %.1f A%d %d 0 0 1 %.1f %.1f" % (50 - 0.766 * r, 40 - 0.643 * r, r, r, 50 + 0.766 * r, 40 - 0.643 * r), acc, 6, c)
    return (S("M24 42 H76", ink, 12, "p1") + S("M50 42 V88", ink, 12, "p2") + arc(15, "p3") + arc(26, "p4") + arc(37, "p5"))


# ------------------------------------------------------------------ variants / glyphs
VARS = {
    "resto": dict(name="Resto", col="#E4572E"),
    "market": dict(name="Market", col="#2E9E5B"),
    "pharma": dict(name="Pharma", col="#1B8FD9"),
    "boss": dict(name="Boss", col="#C99A2E"),
}


def glyph(key, col):
    if key == "resto":
        return ('<g fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
                '<path d="M7 3v6a2 2 0 0 0 4 0V3M9 3v18M17 21V3c-2.5 1.8-3.5 4.5-3.5 8H17"/></g>') % col
    if key == "market":
        return ('<g fill="none" stroke="%s" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'
                '<path d="M3 4h3l2.4 11h9.6l2-8H7"/><circle cx="10" cy="19.5" r="1.6"/><circle cx="17" cy="19.5" r="1.6"/></g>') % col
    if key == "pharma":
        return '<path fill="%s" d="M9 3h6v6h6v6h-6v6H9v-6H3V9h6z"/>' % col
    return ('<g fill="%s"><rect x="3" y="12" width="5" height="9" rx="1"/><rect x="10" y="4" width="5" height="17" rx="1"/>'
            '<rect x="17" y="8" width="5" height="13" rx="1"/></g>') % col


# ------------------------------------------------------------------ 12 concepts
CONCEPTS = [
    dict(id=1, name="Barre Partagée", mark=m1, ink="#14233B", acc="#F2A900", font="'Segoe UI',Arial,sans-serif", w1=800, w2=800,
         case="mixed", sep="-", two=False, spacing=0, layout="h", anim="slide",
         story="Le F et le T partagent une seule barre horizontale : deux lettres, une seule structure. Exprime « solution complète ».",
         human="Un seul accent (la barre du F en ambre) et un espace de respiration réglé à l'œil entre le F et le T : aucun effet, aucun dégradé.",
         anim_txt="La barre glisse depuis la gauche, puis le T et la barre du F se posent.", usage="Idéal pour une identité sobre et solide, très lisible en petit (icône d'application, ticket)."),
    dict(id=2, name="Circuit", mark=m2, ink="#0E3B43", acc="#FF6B35", font="Bahnschrift,'Segoe UI',sans-serif", w1=700, w2=700,
         case="mixed", sep="-", two=True, spacing=0, layout="h", anim="draw",
         story="Lettres tracées comme un tracé de carte électronique, avec des nœuds aux extrémités : la tech au service de la caisse.",
         human="Trait de 9 unités à bouts arrondis, nœuds évidés (anneau orange) : le dessin d'un schéma fait main, pas une icône générique.",
         anim_txt="Les lignes se tracent comme un circuit, puis les nœuds s'allument.", usage="Parfait pour un positionnement « technologie / cloud » (Full-Tek Boss, Super-Admin)."),
    dict(id=3, name="Pastille Point", mark=m3, ink="#1F3C88", acc="#FFC23E", font="'Trebuchet MS','Segoe UI',sans-serif", w1=800, w2=800,
         case="lower", sep="", two=False, spacing=0, layout="h", anim="pop",
         story="Un F en réserve dans une pastille, avec un point jaune : le « point » de vente. Compact comme une icône d'appli.",
         human="Le F est volontairement un peu épais en bas pour la stabilité ; le point est décalé du centre, comme posé à la main.",
         anim_txt="La pastille apparaît en rebond, le F se révèle, le point tombe.", usage="Très efficace sur tablette, borne et écran client (forme compacte)."),
    dict(id=4, name="Hexagone Tek", mark=m4, ink="#2D2A26", acc="#D1495B", font="'Segoe UI Semibold','Segoe UI',sans-serif", w1=600, w2=600,
         case="upper", sep="·", two=False, spacing=4, layout="v", anim="draw",
         story="Un hexagone, comme un écrou ou une cellule : solidité industrielle. À l'intérieur, un F et un T partagent la barre.",
         human="Encre charbon et corail plutôt que bleu/violet « tech » ; contours à l'épaisseur régulière, comme un tampon.",
         anim_txt="Le contour se dessine d'un seul trait, puis le F et le T apparaissent.", usage="Pour une image « institutionnelle et fiable » (grands comptes, hôtels)."),
    dict(id=5, name="Ticket", mark=m5, ink="#7A1F2B", acc="#F4B942", font="Georgia,'Times New Roman',serif", w1=700, w2=700,
         case="mixed", sep="-", two=False, spacing=0, layout="h", anim="rise",
         story="Un ticket de caisse avec son bord dentelé et un F en réserve : le produit se reconnaît en une seconde.",
         human="Les dents du bas sont irrégulières de 1 unité (dernière dent plus courte), comme un vrai papier déchiré.",
         anim_txt="Le ticket sort de l'imprimante : il monte, puis la ligne du total s'imprime.", usage="Très parlant pour la restauration et les commerces de proximité."),
    dict(id=6, name="Flèche Full", mark=m6, ink="#0B6E4F", acc="#F18F01", font="'Segoe UI',Arial,sans-serif", w1=800, w2=800,
         case="mixed", sep="", two=True, spacing=0, layout="h", anim="slide",
         story="Le F porte une flèche vers l'avant : rapidité d'encaissement, croissance, progression.",
         human="Vert profond (couleur de confiance et de commerce) avec une flèche orange légèrement trop grande pour dynamiser, volontairement.",
         anim_txt="Le F se construit, puis la flèche file vers la droite.", usage="Message « vitesse et croissance » pour Full-Tek Market et Boss."),
    dict(id=7, name="Monogramme Premium", mark=m7, ink="#1C1C1C", acc="#B8924A", font="Georgia,'Times New Roman',serif", w1=400, w2=400,
         case="upper", sep="-", two=False, spacing=6, layout="v", anim="draw",
         story="Un monogramme FT serif dans un cercle fin doré : l'élégance d'une maison de confiance.",
         human="Lettres légèrement resserrées (-2) et filet doré sous le monogramme : détails de typographe, pas de générateur.",
         anim_txt="Le cercle doré se trace, le monogramme se pose, le filet s'allume.", usage="Pour l'offre haut de gamme (hôtels, restaurants VIP, version imprimée)."),
    dict(id=8, name="Disque Plein", mark=m8, ink="#5B2A86", acc="#35D0BA", font="Verdana,'Segoe UI',sans-serif", w1=700, w2=700,
         case="mixed", sep="-", two=False, spacing=0, layout="h", anim="pop",
         story="« Full » = disque plein ; le T est découpé dedans. Un point menthe rappelle le point de vente.",
         human="Violet profond et menthe, un duo moins vu dans la caisse enregistreuse ; T aux angles vifs contre un disque parfait.",
         anim_txt="Le disque se gonfle, le T se découpe, le point apparaît.", usage="Fort impact sur les affiches, enseignes et vitrophanies."),
    dict(id=9, name="F-Stack", mark=m9, ink="#1B4965", acc="#FF7F50", font="Bahnschrift,'Segoe UI',sans-serif", w1=600, w2=600,
         case="upper", sep="-", two=True, spacing=2, layout="h", anim="slide",
         story="Un F dont les barres sont des couches empilées : Cloud, Synchronisation, Local (architecture du produit).",
         human="Les trois barres ont des longueurs et des arrondis différents ; la barre du milieu en corail marque la synchronisation.",
         anim_txt="Les couches se superposent de haut en bas.", usage="Pour présenter l'architecture technique et l'espace Super-Admin."),
    dict(id=10, name="Pixel", mark=m10, ink="#111827", acc="#22A559", font="Consolas,'Courier New',monospace", w1=700, w2=700,
         case="lower", sep="-", two=False, spacing=0, layout="h", anim="pop",
         story="F et T dessinés en pixels comme sur un afficheur de caisse ou un écran 8 bits.",
         human="Grille de 7 lignes : le pied du T est en vert, comme une LED allumée.",
         anim_txt="Les pixels s'allument un à un, comme sur un afficheur.", usage="Pour l'univers afficheur client et caisse tactile (clin d'œil rétro-tech)."),
    dict(id=11, name="Pilules", mark=m11, ink="#264653", acc="#E9A23B", font="'Segoe UI',Arial,sans-serif", w1=800, w2=800,
         case="mixed", sep="·", two=False, spacing=0, layout="h", anim="slide",
         story="Trois lignes de ticket de longueurs décroissantes dessinent un F : lecture immédiate, très simple à décliner.",
         human="Couleurs terre (bleu-vert pétrole et ocre) pour un rendu chaleureux ; les pilules sont alignées à gauche comme un vrai texte.",
         anim_txt="Les trois lignes s'impriment l'une après l'autre.", usage="Très lisible en petit : application mobile, favicon, icône WhatsApp."),
    dict(id=12, name="Signal Edge", mark=m12, ink="#0A2342", acc="#2CA58D", font="'Segoe UI Semibold','Segoe UI',sans-serif", w1=600, w2=600,
         case="mixed", sep="-", two=True, spacing=0, layout="h", anim="draw",
         story="Un T qui émet un signal : fonctionne en ligne comme hors ligne (Edge local + Cloud), la promesse du produit.",
         human="Les arcs sont plus fins que le T pour hiérarchiser, et le T garde un pied plus long que sa barre pour rester stable.",
         anim_txt="Le T se trace, puis les trois ondes s'émettent.", usage="Pour porter le message « fonctionne sans Internet » en communication."),
]
for c in CONCEPTS:
    c["dark"] = mix(c["ink"], "#000000", 0.62)
    c["tint"] = mix(c["ink"], "#FFFFFF", 0.9)

# ------------------------------------------------------------------ animation css
KEYS = {
    "pop": "0%{opacity:0;transform:scale(.15)}14%{opacity:1;transform:scale(1.1)}20%{transform:scale(1)}88%{opacity:1;transform:scale(1)}100%{opacity:0;transform:scale(.15)}",
    "slide": "0%{opacity:0;transform:translateX(-26px)}16%{opacity:1;transform:translateX(0)}88%{opacity:1;transform:translateX(0)}100%{opacity:0;transform:translateX(-26px)}",
    "rise": "0%{opacity:0;transform:translateY(24px)}16%{opacity:1;transform:translateY(0)}88%{opacity:1;transform:translateY(0)}100%{opacity:0;transform:translateY(24px)}",
    "draw": "0%{opacity:0;stroke-dashoffset:1}2%{opacity:1}22%{stroke-dashoffset:0}88%{opacity:1;stroke-dashoffset:0}100%{opacity:0;stroke-dashoffset:1}",
}
DRAWFADE = "0%{opacity:0}18%{opacity:1}88%{opacity:1}100%{opacity:0}"


def anim_css(scope, kinds):
    css = ""
    for k in kinds:
        s = scope % k if "%s" in scope else scope
        css += "@keyframes k_%s{%s}\n" % (k, KEYS[k])
        css += ("%s .p{animation:k_%s 5.2s cubic-bezier(.2,.8,.2,1) infinite both;transform-box:fill-box;transform-origin:center}\n" % (s, k))
        css += "%s .p1{animation-delay:0s}%s .p2{animation-delay:.14s}%s .p3{animation-delay:.28s}%s .p4{animation-delay:.42s}%s .p5{animation-delay:.56s}%s .w{animation:k_fade 5.2s ease infinite both;animation-delay:.7s}\n" % ((s,) * 6)
        if k == "draw":
            css += "%s .st{stroke-dasharray:1}\n" % s
            css += "%s .p:not(.st){animation:k_fade 5.2s ease infinite both}\n" % s
        css += "%s .pq{animation:k_pop 5.2s cubic-bezier(.2,.8,.2,1) infinite both}\n" % s
    css += "@keyframes k_fade{%s}\n" % DRAWFADE
    return css


# ------------------------------------------------------------------ lockup
def wm(c, x, y, size, anchor, fill, acc):
    a, s, b = "Full", c["sep"], "Tek"
    if c["case"] == "upper":
        a, b = a.upper(), b.upper()
    elif c["case"] == "lower":
        a, b = a.lower(), b.lower()
    tek_fill = acc if c["two"] else fill
    ls = ' letter-spacing="%s"' % c["spacing"] if c["spacing"] else ""
    return ('<text class="w" x="%s" y="%s" font-family="%s" font-size="%s" text-anchor="%s" fill="%s"%s>'
            '<tspan font-weight="%s">%s%s</tspan><tspan font-weight="%s" fill="%s">%s</tspan></text>'
            ) % (x, y, c["font"].replace('"', "'"), size, anchor, fill, ls, c["w1"], a, s, c["w2"], tek_fill, b)


def lockup(c, variant=None, dark=False, layout=None, anim=False, kind=None, standalone=False, mark_only=False):
    layout = layout or c["layout"]
    ink = "#FFFFFF" if dark else c["ink"]
    bg = c["dark"] if dark else "#FFFFFF"
    acc = VARS[variant]["col"] if variant else c["acc"]
    mark = c["mark"](ink, acc, bg)
    kind = kind or c["anim"]
    attrs = ' data-anim="%s"' % kind if anim else ""
    style = ""
    if standalone:
        style = "<style>%s</style>" % anim_css("svg", [kind]) if anim else ""
    if mark_only:
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"%s>%s%s</svg>' % (attrs, style, mark)
    lab_col = VARS[variant]["col"] if variant else ("#94A3B8" if dark else "#64748B")
    lab = ("%s" % VARS[variant]["name"]).upper() if variant else "SUITE POS"
    tf = "#FFFFFF" if dark else c["ink"]
    if layout == "h":
        vb = "0 0 400 100"
        txt = wm(c, 120, 56 if True else 64, 44, "start", tf, acc)
        if variant:
            sub = ('<g class="w" transform="translate(120,67) scale(.95)">%s</g><text class="w" x="147" y="87" font-family="Segoe UI,Arial,sans-serif" '
                   'font-size="17" font-weight="700" letter-spacing="4" fill="%s">%s</text>') % (glyph(variant, lab_col), lab_col, lab)
        else:
            sub = ('<text class="w" x="121" y="82" font-family="Segoe UI,Arial,sans-serif" font-size="12" font-weight="700" '
                   'letter-spacing="5" fill="%s">%s</text>') % (lab_col, lab)
        body = '<g>%s</g>%s%s' % (mark, txt, sub)
    else:
        vb = "0 0 300 205"
        size = 30 if c["spacing"] >= 4 else 36
        txt = wm(c, 150, 142, size, "middle", tf, acc)
        if variant:
            lw = len(lab) * 12.5
            gx = 150 - lw / 2 - 12
            sub = ('<g class="w" transform="translate(%.1f,155) scale(.8)">%s</g><text class="w" x="%.1f" y="173" font-family="Segoe UI,Arial,sans-serif" '
                   'font-size="17" font-weight="700" letter-spacing="4" text-anchor="middle" fill="%s">%s</text>'
                   ) % (gx, glyph(variant, lab_col), 150 + 12, lab_col, lab)
        else:
            sub = ('<text class="w" x="151" y="172" font-family="Segoe UI,Arial,sans-serif" font-size="12" font-weight="700" '
                   'letter-spacing="5" text-anchor="middle" fill="%s">%s</text>') % (lab_col, lab)
        body = '<g transform="translate(100,0)">%s</g>%s%s' % (mark, txt, sub)
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s"%s>%s%s</svg>' % (vb, attrs, style, body)


def icon(c, anim=False, standalone=False, variant=None):
    inner = c["mark"]("#FFFFFF", VARS[variant]["col"] if variant else c["acc"], c["ink"])
    kind = c["anim"]
    attrs = ' data-anim="%s"' % kind if anim else ""
    style = "<style>%s</style>" % anim_css("svg", [kind]) if (anim and standalone) else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"%s>%s<rect width="100" height="100" rx="22" fill="%s"/>'
            '<g transform="translate(17,17) scale(.66)">%s</g></svg>') % (attrs, style, c["ink"], inner)


def sv(svg, h, extra=""):
    return svg.replace("<svg ", '<svg style="height:%spx;width:auto;max-width:100%%;display:block;%s" ' % (h, extra), 1)


# ------------------------------------------------------------------ screens (250 x 160)
POS_NAMES = {
    "header": "Barre haute de la caisse", "splash": "Écran de démarrage (centre)", "login": "Connexion (panneau gauche)",
    "sidebar": "Menu latéral (haut-gauche)", "ticket": "Ticket 80 mm (en-tête)", "kiosk": "Borne client (haut-centre)",
    "customer": "Afficheur client (coin bas-droit)", "mobile": "Application Boss (haut mobile)",
}
POS_ORDER = ["header", "splash", "login", "sidebar", "ticket", "kiosk", "customer", "mobile"]


def bars(n, w, col, h=5, gap=5):
    return "".join('<div style="width:%s%%;height:%spx;background:%s;border-radius:3px;margin-bottom:%spx"></div>' % (w - (i % 3) * 14, h, col, gap) for i in range(n))


def screen(c, pos, variant, anim=False):
    ink, tint, dark = c["ink"], c["tint"], c["dark"]
    acc = VARS[variant]["col"]
    base = "position:relative;width:250px;height:160px;border-radius:8px;overflow:hidden;border:1px solid #CBD5E1;box-shadow:0 2px 8px rgba(15,23,42,.12);"
    if pos == "header":
        tiles = "".join('<div style="background:%s;border-radius:5px;height:25px"></div>' % (acc if i == 4 else tint) for i in range(12))
        return ('<div style="%sbackground:#F8FAFC"><div style="height:26px;background:%s;display:flex;align-items:center;padding:0 8px;justify-content:space-between">%s'
                '<div style="width:46px;height:8px;border-radius:4px;background:rgba(255,255,255,.35)"></div></div>'
                '<div style="display:flex;gap:8px;padding:8px"><div style="flex:1;display:grid;grid-template-columns:repeat(4,1fr);gap:6px;align-content:start">%s</div>'
                '<div style="width:62px;background:#fff;border-radius:5px;padding:6px;border:1px solid #E2E8F0">%s<div style="height:16px;background:%s;border-radius:4px;margin-top:20px"></div></div></div></div>'
                ) % (base, ink, sv(lockup(c, variant, True, "h", anim), 17), tiles, bars(5, 90, "#CBD5E1"), acc)
    if pos == "splash":
        return ('<div style="%sbackground:%s;display:flex;align-items:center;justify-content:center;flex-direction:column">%s'
                '<div style="width:90px;height:3px;background:rgba(255,255,255,.18);border-radius:2px;margin-top:10px"><div style="width:55%%;height:3px;background:%s;border-radius:2px"></div></div></div>'
                ) % (base, dark, sv(lockup(c, variant, True, "v", anim), 92), acc)
    if pos == "login":
        return ('<div style="%sdisplay:flex;background:#fff"><div style="width:45%%;background:%s;display:flex;align-items:center;justify-content:center">%s</div>'
                '<div style="flex:1;padding:22px 16px"><div style="height:7px;width:50%%;background:%s;border-radius:3px;margin-bottom:14px"></div>'
                '<div style="height:16px;border:1px solid #CBD5E1;border-radius:4px;margin-bottom:8px"></div><div style="height:16px;border:1px solid #CBD5E1;border-radius:4px;margin-bottom:12px"></div>'
                '<div style="height:17px;background:%s;border-radius:4px"></div></div></div>'
                ) % (base, ink, sv(lockup(c, variant, True, "v", anim), 62), ink, acc)
    if pos == "sidebar":
        dots = "".join('<div style="width:14px;height:14px;border-radius:4px;background:rgba(255,255,255,%s);margin:9px auto 0"></div>' % ("0.9" if i == 1 else "0.28") for i in range(5))
        rows = "".join('<div style="display:flex;gap:6px;margin-bottom:7px"><div style="flex:2;height:8px;background:#E2E8F0;border-radius:3px"></div><div style="flex:1;height:8px;background:%s;border-radius:3px"></div><div style="flex:1;height:8px;background:#E2E8F0;border-radius:3px"></div></div>' % (acc if i == 2 else "#E2E8F0") for i in range(8))
        return ('<div style="%sdisplay:flex;background:#F8FAFC"><div style="width:44px;background:%s;padding-top:9px">%s%s</div>'
                '<div style="flex:1;padding:10px 12px"><div style="height:11px;width:40%%;background:%s;border-radius:3px;margin-bottom:12px"></div>%s</div></div>'
                ) % (base, ink, sv(lockup(c, variant, True, mark_only=True, anim=anim), 24, "margin:0 auto"), dots, ink, rows)
    if pos == "ticket":
        return ('<div style="%sbackground:#E2E8F0;display:flex;justify-content:center"><div style="width:104px;background:#fff;margin-top:8px;padding:9px 10px;box-shadow:0 1px 4px rgba(0,0,0,.2)">'
                '<div style="display:flex;justify-content:center;margin-bottom:6px">%s</div>%s<div style="border-top:1px dashed #94A3B8;margin:5px 0"></div>'
                '<div style="display:flex;justify-content:space-between;font:700 8px Segoe UI;color:%s"><span>TOTAL</span><span>1 600 MRU</span></div>'
                '<div style="width:34px;height:34px;margin:7px auto 0;background:repeating-conic-gradient(%s 0 25%%,#fff 0 50%%) 0 0/8px 8px"></div></div></div>'
                ) % (base, sv(lockup(c, variant, False, "v", anim), 36), bars(5, 92, "#CBD5E1", 4, 4), ink, ink)
    if pos == "kiosk":
        tiles = "".join('<div style="background:%s;border-radius:7px;height:36px"></div>' % (acc if i == 0 else tint) for i in range(4))
        return ('<div style="%sbackground:#fff"><div style="display:flex;justify-content:center;padding-top:10px">%s</div>'
                '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:12px 18px 0">%s</div>'
                '<div style="position:absolute;left:18px;right:18px;bottom:9px;height:15px;background:%s;border-radius:8px"></div></div>'
                ) % (base, sv(lockup(c, variant, False, "h", anim), 24), tiles, ink)
    if pos == "customer":
        return ('<div style="%sbackground:%s;display:flex;align-items:center;justify-content:center;flex-direction:column;color:#fff">'
                '<div style="font:600 9px Segoe UI;opacity:.7;letter-spacing:2px">TOTAL À PAYER</div><div style="font:800 28px Segoe UI;margin-top:3px">1 600 <span style="font-size:13px">MRU</span></div>'
                '<div style="position:absolute;right:10px;bottom:8px;opacity:.9">%s</div></div>'
                ) % (base, dark, sv(lockup(c, variant, True, "h", anim), 15))
    # mobile
    return ('<div style="%sbackground:%s;display:flex;justify-content:center;align-items:center"><div style="width:96px;height:146px;background:#fff;border-radius:14px;border:3px solid #0F172A;padding:7px 7px;overflow:hidden">'
            '<div style="display:flex;justify-content:center;margin-bottom:8px">%s</div><div style="height:22px;background:%s;border-radius:6px;margin-bottom:6px"></div>'
            '<div style="display:flex;gap:5px"><div style="flex:1;height:26px;background:%s;border-radius:5px"></div><div style="flex:1;height:26px;background:%s;border-radius:5px"></div></div>'
            '<div style="margin-top:7px">%s</div></div></div>'
            ) % (base, tint, sv(lockup(c, variant, False, "h", anim), 14), ink, tint, acc, bars(3, 90, "#CBD5E1", 4, 4))


# ------------------------------------------------------------------ pages
CSS = """
@page{size:297mm 210mm;margin:0}
*{box-sizing:border-box}
body{margin:0;font-family:'Segoe UI',Arial,sans-serif;color:#0F172A;font-size:10.5px;line-height:1.4;background:#fff}
.pg{width:297mm;height:210mm;position:relative;overflow:hidden;page-break-after:always;padding:12mm 14mm 0 14mm}
.foot{position:absolute;left:14mm;right:14mm;bottom:7mm;display:flex;justify-content:space-between;font-size:8px;color:#64748B;border-top:1px solid #E2E8F0;padding-top:5px}
.pill{background:#0F172A;color:#fff;border-radius:9px;padding:1px 9px;font-weight:700}
.top{display:flex;justify-content:space-between;font-size:8.5px;color:#64748B;letter-spacing:.5px;margin-bottom:8px}
h1{margin:0;font-size:25px} h2{margin:0 0 4px 0;font-size:21px} h3{margin:0 0 3px 0;font-size:12px}
.cover{width:297mm;height:210mm;page-break-after:always;position:relative;overflow:hidden;background:#0B1B2B;color:#fff;padding:18mm 20mm}
.cover .tag{font-size:10px;letter-spacing:3px;color:#7DD3C0;font-weight:700}
.cover h1{font-size:50px;line-height:1.08;margin-top:18mm;max-width:210mm}
.cover h1 em{font-style:normal;color:#F2A900}
.cover p{font-size:15px;color:#CBD5E1;max-width:190mm;margin-top:8mm}
.cover .row{position:absolute;left:20mm;right:20mm;bottom:16mm;display:flex;gap:10px;align-items:flex-end;justify-content:space-between;border-top:1px solid rgba(255,255,255,.2);padding-top:7mm;font-size:11px;color:#CBD5E1}
.cover .row b{display:block;color:#fff;font-size:16px}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:9px;margin-top:8px}
.card{border:1px solid #E2E8F0;border-radius:9px;padding:9px 11px;background:#F8FAFC}
.card b{display:block;margin-bottom:2px;font-size:11.5px}
.hero{display:flex;gap:12px;height:124mm}
.panelL{flex:1.55;border:1px solid #E2E8F0;border-radius:12px;display:flex;align-items:center;justify-content:center;background:#fff;position:relative}
.panelL .lab{position:absolute;left:14px;top:10px;font-size:9px;letter-spacing:2px;color:#94A3B8;font-weight:700}
.colR{flex:1;display:flex;flex-direction:column;gap:10px}
.dk{border-radius:12px;display:flex;align-items:center;justify-content:center;height:40mm;position:relative}
.dk .lab{position:absolute;left:12px;top:8px;font-size:8.5px;letter-spacing:2px;color:rgba(255,255,255,.55);font-weight:700}
.mini{display:flex;gap:10px}
.mini>div{flex:1;border:1px solid #E2E8F0;border-radius:12px;padding:8px;display:flex;align-items:center;justify-content:space-around;gap:6px;height:26mm}
.sw{display:flex;gap:6px;align-items:center}.sw i{display:block;width:26px;height:26px;border-radius:7px;border:1px solid rgba(0,0,0,.1)}
.txt{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin-top:9px}
.txt div{border-radius:9px;padding:8px 11px;font-size:10px}
.fam{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin:8px 0 10px}
.fam>div{border:1px solid #E2E8F0;border-radius:10px;height:42mm;min-width:0;overflow:hidden;padding:0 10px;display:flex;align-items:center;justify-content:center;position:relative}
.fam .lab{position:absolute;left:9px;top:6px;font-size:8px;letter-spacing:1.5px;color:#94A3B8;font-weight:700}
.scr{display:grid;grid-template-columns:repeat(4,250px);gap:12px;justify-content:center}
.cap{font-size:9px;color:#475569;margin-top:5px;text-align:center}
.cap b{color:#0F172A}
.sec{font-size:8.5px;letter-spacing:2px;color:#94A3B8;font-weight:700;margin:2px 0 4px}
"""


def page_shell(inner, no, total, concept=""):
    return ('<div class="pg"><div class="top"><span>FULL-TEK &mdash; IDENTITÉ VISUELLE &bull; %s</span><span>Client : M. Taha Chouaib</span></div>%s'
            '<div class="foot"><span>CONFIDENTIEL &mdash; Propositions de logos Full-Tek (concepts à affiner avant dépôt de marque)</span><span class="pill">Page %02d / %02d</span></div></div>'
            ) % (concept, inner, no, total)


def page_a(c, anim, no, total):
    sw = "".join('<span class="sw"><i style="background:%s"></i><span style="font-size:9px"><b>%s</b><br>%s</span></span>' % (col, nm, col) for nm, col in
                 [("Encre", c["ink"]), ("Accent", c["acc"]), ("Nuit", c["dark"])])
    inner = ('<div style="display:flex;align-items:flex-end;justify-content:space-between;margin-bottom:8px"><div><div style="font-size:10px;color:#64748B;font-weight:700;letter-spacing:2px">MODÈLE %02d / %02d</div>'
             '<h2>%s</h2><div style="color:#475569">%s</div></div><div style="font-size:9px;color:#64748B;text-align:right">Animation : <b style="color:#0F172A">%s</b></div></div>'
             '<div class="hero"><div class="panelL"><span class="lab">VERSION PRINCIPALE &bull; FOND CLAIR</span>%s</div>'
             '<div class="colR"><div class="dk" style="background:%s"><span class="lab">VERSION INVERSÉE &bull; FOND SOMBRE</span>%s</div>'
             '<div class="mini"><div><span style="width:70px">%s</span><span style="font-size:8.5px;color:#64748B;line-height:1.3">Icône<br>d\'application</span></div>'
             '<div style="flex-direction:column;gap:7px"><div style="display:flex;gap:7px;align-items:center">%s%s</div><span style="font-size:8.5px;color:#64748B">Favicon 16 / 32 px</span></div></div>'
             '<div class="mini"><div style="height:17mm;justify-content:flex-start;gap:13px">%s</div></div></div></div>'
             '<div class="txt"><div style="background:#ECFDF5;border:1px solid #6EE7B7"><b>Le concept</b><br>%s</div>'
             '<div style="background:#FFF7ED;border:1px solid #FDBA74"><b>Le détail « fait main »</b><br>%s</div>'
             '<div style="background:#EFF6FF;border:1px solid #93C5FD"><b>Où l\'utiliser</b><br>%s</div>'
             '<div style="background:#F5F3FF;border:1px solid #C4B5FD"><b>Animation</b><br>%s</div></div>'
             ) % (c["id"], len(CONCEPTS), c["name"], "Logo principal Full-Tek &mdash; suite POS Cloud &amp; Edge", c["anim"].upper(),
                  sv(lockup(c, None, False, c["layout"], anim), 200 if c["layout"] == "v" else 105), c["dark"],
                  sv(lockup(c, None, True, c["layout"], anim), 118 if c["layout"] == "v" else 60), sv(icon(c, anim), 58),
                  sv(icon(c, anim), 32), sv(icon(c, anim), 16), sw, c["story"], c["human"], c["usage"], c["anim_txt"])
    return page_shell(inner, no, total, c["name"].upper())


def page_b(c, anim, no, total):
    fam = ""
    for key in ("resto", "market", "pharma", "boss"):
        fam += '<div><span class="lab">FULL-TEK %s</span>%s</div>' % (VARS[key]["name"].upper(), sv(lockup(c, key, False, "h", anim), 66))
    icons = "".join('<div style="display:flex;align-items:center;gap:7px">%s<b style="font-size:9px;color:#475569">%s</b></div>' %
                    (sv(icon(c, anim, False, k), 54), VARS[k]["name"]) for k in VARS)
    i = c["id"] - 1
    chosen = [POS_ORDER[(i + o) % 8] for o in ((0, 2, 5, 7) if c["id"] % 2 == 1 else (1, 3, 4, 6))]
    variants = ["resto", "market", "pharma", "boss"]
    scr = ""
    for k, pos in enumerate(chosen):
        v = variants[(i + k) % 4]
        scr += '<div>%s<div class="cap"><b>%s</b><br>Full-Tek %s</div></div>' % (screen(c, pos, v, anim), POS_NAMES[pos], VARS[v]["name"])
    inner = ('<div style="margin-bottom:2px"><div style="font-size:10px;color:#64748B;font-weight:700;letter-spacing:2px">MODÈLE %02d / %02d &mdash; SUITE</div>'
             '<h2>%s &mdash; la gamme et le logo dans les écrans</h2></div>'
             '<div class="sec">LA GAMME : FULL-TEK RESTO &bull; MARKET &bull; PHARMA &bull; BOSS</div><div class="fam">%s</div>'
             '<div class="sec">POSITIONS DU LOGO DANS LES ÉCRANS (CHAQUE MODÈLE A SES PROPRES EMPLACEMENTS)</div><div class="scr">%s</div>'
             '<div class="sec" style="margin-top:12px">ICÔNES D\'APPLICATION &bull; VERSIONS MONOCHROMES (NOIR / BLANC)</div><div style="display:flex;gap:14px;align-items:center">%s<div style="background:#F1F5F9;border-radius:9px;padding:9px 14px;margin-left:10px">%s</div><div style="background:#0F172A;border-radius:9px;padding:9px 14px">%s</div></div>'
             ) % (c["id"], len(CONCEPTS), c["name"], fam, scr, icons, sv(lockup(dict(c, ink="#111111", acc="#111111", two=False), None, False, "h", anim), 36), sv(lockup(dict(c, ink="#FFFFFF", acc="#FFFFFF", two=False), None, True, "h", anim), 36))
    return page_shell(inner, no, total, c["name"].upper())


def cover_page(anim):
    row = "".join('<div style="background:#fff;border-radius:10px;padding:9px 12px">%s</div>' % sv(lockup(c, None, False, "h", anim), 36) for c in CONCEPTS[:6])
    row2 = "".join('<div style="background:#fff;border-radius:10px;padding:9px 12px">%s</div>' % sv(lockup(c, None, False, "h", anim), 36) for c in CONCEPTS[6:])
    return ('<div class="cover"><div class="tag">IDENTITÉ VISUELLE &bull; FULL-TEK</div>'
            '<h1>12 propositions de logos<br>pour <em>Full-Tek</em> et sa gamme</h1>'
            '<p>Le logo de la plateforme, et celui de chaque point de vente : <b>Full-Tek Resto</b>, <b>Full-Tek Market</b>, <b>Full-Tek Pharma</b> et <b>Full-Tek Boss</b>. '
            'Pour chaque modèle : versions claire et sombre, icône, déclinaison de gamme, positions dans les écrans et animation.</p>'
            '<div style="display:grid;grid-template-columns:repeat(6,1fr);gap:9px;margin-top:10mm">%s%s</div>'
            '<div class="row"><div>Préparé pour<b>M. Taha Chouaib</b></div><div style="text-align:right">Novembre 2026<b>Document de choix</b></div></div></div>') % (row, row2)


def intro_page(anim, no, total):
    cards = [
        ("Aucun dégradé, aucun effet", "Des aplats de couleur et des formes construites sur grille : ce qui rend un logo durable et lisible, du ticket 80 mm à l'enseigne."),
        ("Deux couleurs, pas plus", "Une couleur de base et un accent. Chaque métier prend sa couleur d'accent : Resto orange, Market vert, Pharma bleu, Boss or."),
        ("Un détail dessiné à la main", "Chaque modèle a une correction optique volontaire (épaisseur, décalage, dent de ticket) pour éviter l'aspect « généré »."),
        ("Testés en petit", "Chaque marque reste lisible en icône de 16 px, en favicon et en impression noir et blanc."),
        ("Gamme cohérente", "Même signe, même structure : seul le mot (Resto, Market, Pharma, Boss), le pictogramme et l'accent changent."),
        ("Animation prête", "Un fichier SVG animé par modèle (introduction du logo à l'ouverture de l'application, sur le site ou en vidéo)."),
    ]
    cs = "".join('<div class="card"><b>%s</b>%s</div>' % t for t in cards)
    pict = "".join('<div style="border:1px solid #E2E8F0;border-radius:10px;padding:10px;text-align:center"><svg viewBox="0 0 24 24" style="height:34px">%s</svg>'
                   '<div style="font-weight:700;margin-top:4px;color:%s">Full-Tek %s</div></div>' % (glyph(k, v["col"]), v["col"], v["name"]) for k, v in VARS.items())
    inner = ('<h2>Les principes de conception</h2><div style="color:#475569">Ce que le client doit savoir avant de choisir</div><div class="cards">%s</div>'
             '<h2 style="margin-top:12px">La gamme et ses pictogrammes</h2><div style="display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-top:6px">%s</div>'
             '<div style="margin-top:12px;background:#FFFBEB;border:1px solid #FCD34D;border-radius:9px;padding:9px 12px;font-size:10px"><b>Important :</b> ce sont des propositions de concepts vectoriels. '
             'Le modèle retenu sera finalisé (tracés, polices vectorisées, déclinaisons) puis soumis à une recherche d\'antériorité avant dépôt de marque.</div>') % (cs, pict)
    return page_shell(inner, no, total, "PRINCIPES")


def choice_page(anim, no, total):
    cells = "".join('<div style="border:1px solid #E2E8F0;border-radius:10px;padding:7px 9px;display:flex;align-items:center;gap:10px">'
                    '<div style="font-weight:800;color:#94A3B8;width:20px">%02d</div>%s<div><b>%s</b></div></div>' % (c["id"], sv(icon(c, anim), 34), c["name"]) for c in CONCEPTS)
    inner = ('<h2>Vue d\'ensemble et choix</h2><div style="color:#475569;margin-bottom:6px">Les 12 modèles en un coup d\'œil</div>'
             '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:8px">%s</div>'
             '<div style="margin-top:12px;display:grid;grid-template-columns:repeat(3,1fr);gap:10px">'
             '<div class="card" style="background:#ECFDF5;border-color:#6EE7B7"><b>Pour un look sobre et solide</b>Modèles 01 Barre Partagée, 05 Ticket, 11 Pilules.</div>'
             '<div class="card" style="background:#EFF6FF;border-color:#93C5FD"><b>Pour une image technologique</b>Modèles 02 Circuit, 09 F-Stack, 12 Signal Edge.</div>'
             '<div class="card" style="background:#F5F3FF;border-color:#C4B5FD"><b>Pour une image premium</b>Modèles 07 Monogramme, 04 Hexagone, 08 Disque Plein.</div></div>'
             '<div style="margin-top:12px;display:flex;gap:12px"><div style="flex:1;border:1.5px dashed #94A3B8;border-radius:10px;padding:10px 14px;height:30mm"><b>Modèle retenu pour Full-Tek :</b><br><br>.................................................</div>'
             '<div style="flex:1;border:1.5px dashed #94A3B8;border-radius:10px;padding:10px 14px;height:30mm"><b>Date &amp; signature de M. Taha Chouaib :</b><br><br>.................................................</div></div>') % cells
    return page_shell(inner, no, total, "CHOIX")


def build(anim):
    total = 2 + len(CONCEPTS) * 2 + 1
    pages = [cover_page(anim), intro_page(anim, 2, total)]
    n = 3
    for c in CONCEPTS:
        pages.append(page_a(c, anim, n, total)); n += 1
        pages.append(page_b(c, anim, n, total)); n += 1
    pages.append(choice_page(anim, n, total))
    css = CSS
    if anim:
        css += anim_css('[data-anim="%s"]', list(KEYS.keys()))
    return '<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>Logos Full-Tek</title><style>%s</style></head><body>%s</body></html>' % (css, "".join(pages))


# ------------------------------------------------------------------ output files
def write_svgs():
    for c in CONCEPTS:
        d = os.path.join(LOGO_DIR, "Modele_%02d_%s" % (c["id"], c["name"].replace(" ", "_").replace("é", "e").replace("è", "e")))
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, "logo_principal_clair.svg"), "w", encoding="utf-8").write(lockup(c, None, False, standalone=True))
        open(os.path.join(d, "logo_principal_sombre.svg"), "w", encoding="utf-8").write(lockup(c, None, True, standalone=True))
        open(os.path.join(d, "logo_anime.svg"), "w", encoding="utf-8").write(lockup(c, None, False, anim=True, standalone=True))
        open(os.path.join(d, "icone_application.svg"), "w", encoding="utf-8").write(icon(c, False, True))
        for key in VARS:
            open(os.path.join(d, "Full-Tek_%s.svg" % VARS[key]["name"]), "w", encoding="utf-8").write(lockup(c, key, False, "h", standalone=True))


def render_pdf(html_path, pdf_path):
    chrome = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    edge = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    b = chrome if os.path.exists(chrome) else edge
    subprocess.run([b, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--print-to-pdf=" + pdf_path, html_path], check=True)


if __name__ == "__main__":
    write_svgs()
    static_html = os.path.join(OUT, "Logos_Full-Tek_12_Modeles.html")
    open(static_html, "w", encoding="utf-8").write(build(False))
    anim_html = os.path.join(LOGO_DIR, "Presentation_ANIMEE_Logos_Full-Tek.html")
    open(anim_html, "w", encoding="utf-8").write(build(True))
    pdf = os.path.join(OUT, "Logos_Full-Tek_12_Modeles.pdf")
    render_pdf(static_html, pdf)
    print("OK", pdf)




