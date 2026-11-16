import os, subprocess

OUT = r"d:\_Documents\Bureau\caissamrr"

NAMES = [
    dict(n="Full-Tek", ar="", tag="Le nom proposé par le client", color="#0F766E",
         decl="Full-Tek Resto · Full-Tek Market · Full-Tek Pharma · Full-Tek Boss",
         pros=["Court, moderne, sonorité technologique internationale",
               "Se décline très facilement en gamme de produits par secteur",
               "Évoque une solution « complète » (Full) et technique (Tek)"],
         cons=["Des sociétés au nom très proche existent déjà (dont une société de logiciels/POS en Égypte) : risque de confusion sur Google",
               "Peut faire penser à un magasin de matériel informatique plutôt qu'à un logiciel de caisse",
               "Le tiret est souvent oublié à l'oral"],
         dom="full-tek.com · fulltek.mr · fulltek-pos.com", note="À utiliser uniquement avec le suffixe POS (« Full-Tek POS »)", score=3),
    dict(n="Full-Tek POS", ar="", tag="Version sécurisée du nom du client", color="#0F766E",
         decl="Full-Tek POS Resto · Full-Tek POS Market · Full-Tek POS Pharma",
         pros=["Garde le nom voulu par le client",
               "Le suffixe POS explique immédiatement le métier (logiciel de caisse)",
               "Réduit le risque de confusion avec les autres « Fulltek »"],
         cons=["Nom un peu long à l'oral", "Reste proche de marques existantes : vérification de marque nécessaire"],
         dom="fulltek-pos.com · fulltekpos.mr", note="Meilleur compromis si le client tient à Full-Tek", score=4),
    dict(n="Nokta POS", ar="نقطة", tag="« Point » : Point de Vente / نقطة بيع", color="#1D4ED8",
         decl="Nokta Resto · Nokta Market · Nokta Pharma · Nokta Boss",
         pros=["Mot arabe courant, compris par tous les commerçants mauritaniens",
               "Double sens direct avec « Point de Vente »",
               "Très court, facile à prononcer en français comme en arabe, logo simple (un point)"],
         cons=["Mot assez répandu dans la région : bien vérifier la disponibilité de la marque",
               "Moins « tech » à l'international"],
         dom="nokta.mr · noktapos.com", note="Fort ancrage local et sens immédiat", score=5),
    dict(n="Sahl POS / SahlTek", ar="سهل", tag="« Facile » : la caisse simple pour tous", color="#B45309",
         decl="Sahl Resto · Sahl Market · Sahl Pharma",
         pros=["Promesse commerciale claire : un logiciel facile à utiliser",
               "Rassure les commerçants peu familiers avec l'informatique",
               "Bilingue FR/AR, agréable à dire"],
         cons=["Peut sembler moins « premium » / haut de gamme", "Le mot existe dans beaucoup de marques : vérifier"],
         dom="sahlpos.com · sahltek.com · sahl.mr", note="Idéal pour une cible TPE (cafés, boutiques, petits market)", score=4),
    dict(n="Mizan POS", ar="ميزان", tag="« Balance / Précision » : rigueur et contrôle", color="#6D28D9",
         decl="Mizan Resto · Mizan Market · Mizan Pharma",
         pros=["Évoque la balance, le juste prix, l'exactitude des comptes",
               "Cohérent avec supermarché (pesée), pharmacie (rigueur) et restaurant",
               "Image sérieuse et fiable"],
         cons=["Nom très utilisé dans le monde arabe (comptabilité, banque) : plus difficile à protéger"],
         dom="mizanpos.com · mizan.mr", note="Pour une image sérieuse, orientée gestion et contrôle", score=3),
    dict(n="MauriTek", ar="", tag="Ancrage mauritanien + technologie", color="#047857",
         decl="MauriTek Resto · MauriTek Market · MauriTek Pharma",
         pros=["Identité nationale immédiate, bon pour la confiance locale",
               "Cohérent avec « Tek » voulu par le client",
               "Avantage commercial sur les logiciels étrangers"],
         cons=["Plusieurs sociétés « Mauri… » existent déjà à Nouakchott : risque de confusion locale",
               "Limite l'image en cas d'expansion à l'international"],
         dom="mauritek.com · mauritek.mr", note="À vérifier avec le registre local avant tout achat", score=3),
    dict(n="CaissaPro", ar="", tag="Direct et explicite", color="#BE123C",
         decl="CaissaPro Resto · CaissaPro Market · CaissaPro Pharma",
         pros=["Le produit se comprend immédiatement (Caisse + Pro)",
               "Prononciation simple en français", "Bonne mémorisation pour les commerçants"],
         cons=["Nom descriptif, plus difficile à protéger comme marque", "Moins original"],
         dom="caissapro.com · caissa.mr", note="Très clair sur le terrain, moins distinctif", score=3),
    dict(n="TekPOS / NovaTek POS", ar="", tag="Technologie et modernité", color="#0369A1",
         decl="TekPOS Resto · TekPOS Market · TekPOS Pharma",
         pros=["Reprend l'idée « Tek » du client avec un sens produit clair",
               "Look moderne et international", "Bon potentiel de logo"],
         cons=["Noms génériques « tek » très nombreux dans le monde : forte probabilité de homonymes"],
         dom="tekpos.com · novatekpos.com", note="Alternative proche de Full-Tek dans l'esprit", score=3),
]


def stars(n):
    return "★" * n + "☆" * (5 - n)


def card(x):
    pros = "".join("<li>%s</li>" % p for p in x["pros"])
    cons = "".join("<li>%s</li>" % p for p in x["cons"])
    ar = '<span class="ar">%s</span>' % x["ar"] if x["ar"] else ""
    return (
        '<div class="card" style="border-top:4px solid %s">'
        '<div class="ch"><div><h3 style="color:%s">%s %s</h3><div class="tag">%s</div></div>'
        '<div class="st">%s<small>Potentiel global</small></div></div>'
        '<div class="decl"><b>Déclinaison de gamme :</b> %s</div>'
        '<div class="cols"><div class="col pro"><h4>Avantages</h4><ul>%s</ul></div>'
        '<div class="col con"><h4>Points d\'attention</h4><ul>%s</ul></div></div>'
        '<div class="ft"><span><b>Domaines à tester :</b> %s</span><span class="nt">%s</span></div></div>'
    ) % (x["color"], x["color"], x["n"], ar, x["tag"], stars(x["score"]), x["decl"], pros, cons, x["dom"], x["note"])


def page(inner, no, total):
    return (
        '<div class="page"><div class="pb">%s</div>'
        '<div class="foot"><span>CONFIDENTIEL &mdash; Propositions de noms pour la plateforme SaaS POS (M. Taha Chouaib)</span>'
        '<span class="pill">Page %02d / %02d</span></div></div>'
    ) % (inner, no, total)


CSS = """
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Segoe UI',Arial,sans-serif; color:#0f172a; font-size:9.2pt; line-height:1.4; }
.page { width:210mm; height:297mm; position:relative; overflow:hidden; page-break-after:always; background:#fff; }
.pb { padding:13mm 14mm 0 14mm; }
.foot { position:absolute; left:14mm; right:14mm; bottom:8mm; display:flex; justify-content:space-between;
  font-size:7pt; color:#64748b; border-top:1px solid #e2e8f0; padding-top:3mm; }
.pill { background:#0f172a; color:#fff; border-radius:10px; padding:1px 8px; font-weight:700; }
.top { display:flex; justify-content:space-between; font-size:7pt; color:#64748b; margin-bottom:5mm; letter-spacing:.4px; }
h1 { margin:0 0 3mm 0; font-size:19pt; color:#0f172a; }
h2 { margin:0 0 3mm 0; font-size:14pt; color:#0f172a; border-left:5px solid #0F766E; padding-left:8px; }
p { margin:0 0 3mm 0; }
.cover { width:210mm; height:297mm; page-break-after:always; position:relative; overflow:hidden;
  background:linear-gradient(150deg,#06222b 0%,#0b3b45 55%,#0F766E 100%); color:#fff; padding:22mm 18mm; }
.cover .brand { font-size:8pt; letter-spacing:2px; color:#5eead4; font-weight:700; }
.cover h1 { color:#fff; font-size:30pt; line-height:1.15; margin:38mm 0 8mm 0; }
.cover h1 span { color:#fbbf24; }
.cover .sub { font-size:11.5pt; color:#cbd5e1; max-width:150mm; }
.cover .chips { margin-top:14mm; display:flex; flex-wrap:wrap; gap:6px; }
.chip { border:1px solid rgba(255,255,255,.35); border-radius:20px; padding:4px 12px; font-size:9.5pt; }
.cover .cl { position:absolute; left:18mm; bottom:20mm; right:18mm; display:flex; justify-content:space-between;
  border-top:1px solid rgba(255,255,255,.3); padding-top:6mm; font-size:9pt; color:#cbd5e1; }
.cover .cl b { color:#fff; font-size:12pt; display:block; }
.card { border:1px solid #e2e8f0; border-radius:8px; padding:4mm 5mm; margin-bottom:4.5mm; background:#fff; }
.ch { display:flex; justify-content:space-between; align-items:flex-start; }
.card h3 { margin:0; font-size:13pt; }
.ar { font-family:'Segoe UI',Tahoma,Arial; margin-left:6px; font-size:12pt; color:#334155; }
.tag { font-size:8.3pt; color:#475569; margin-top:1px; }
.st { text-align:right; color:#f59e0b; font-size:12pt; letter-spacing:1px; }
.st small { display:block; font-size:6.5pt; color:#94a3b8; letter-spacing:0; }
.decl { background:#f1f5f9; border-radius:5px; padding:2mm 3mm; margin:2.5mm 0; font-size:8.2pt; }
.cols { display:flex; gap:4mm; }
.col { flex:1; border-radius:6px; padding:2.5mm 3.5mm; }
.col h4 { margin:0 0 1mm 0; font-size:8.5pt; }
.col ul { margin:0; padding-left:4mm; font-size:8.2pt; }
.pro { background:#ecfdf5; } .pro h4 { color:#047857; }
.con { background:#fff7ed; } .con h4 { color:#c2410c; }
.ft { display:flex; justify-content:space-between; gap:6mm; margin-top:2.5mm; font-size:7.8pt; color:#475569; }
.nt { font-weight:700; color:#0f172a; text-align:right; }
table { width:100%; border-collapse:collapse; font-size:8.4pt; margin:2mm 0 4mm 0; }
th { background:#0f172a; color:#fff; text-align:left; padding:5px 7px; }
td { border-bottom:1px solid #e2e8f0; padding:5px 7px; vertical-align:top; }
tr:nth-child(even) td { background:#f8fafc; }
.box { border-radius:8px; padding:4mm 5mm; margin-bottom:4mm; }
.rec { background:#ecfdf5; border:1.5px solid #10b981; }
.warn { background:#fffbeb; border:1.5px solid #f59e0b; }
.box h4 { margin:0 0 1.5mm 0; font-size:10.5pt; }
ul.l { margin:0; padding-left:5mm; }
.sig { display:flex; gap:6mm; margin-top:5mm; }
.sig div { flex:1; border:1px dashed #94a3b8; border-radius:6px; padding:3mm 4mm; height:24mm; font-size:8pt; }
"""

cover = (
    '<div class="cover"><div class="brand">PROPOSITIONS DE NOMS &bull; PLATEFORME SAAS POS</div>'
    '<h1>Quel nom pour votre<br>plateforme de <span>caisse &amp; gestion</span> ?</h1>'
    '<div class="sub">Analyse du nom proposé <b>Full-Tek</b> et 7 alternatives, avec les avantages, les points d\'attention '
    'et la déclinaison de gamme de chaque proposition (Restaurant, Market, Pharmacie).</div>'
    '<div class="chips"><span class="chip">Full-Tek</span><span class="chip">Full-Tek POS</span><span class="chip">Nokta POS &middot; نقطة</span>'
    '<span class="chip">Sahl POS &middot; سهل</span><span class="chip">Mizan POS &middot; ميزان</span>'
    '<span class="chip">MauriTek</span><span class="chip">CaissaPro</span><span class="chip">TekPOS</span></div>'
    '<div class="cl"><div><span>Préparé pour</span><b>M. Taha Chouaib</b></div>'
    '<div style="text-align:right"><span>Novembre 2026</span><b>Document de décision</b></div></div></div>'
)

top = '<div class="top"><span>PROPOSITIONS DE NOMS &mdash; SAAS POS MAURITANIE</span><span>Client : M. Taha Chouaib</span></div>'

TOTAL = 6

p2 = top + (
    '<h2>1. Le nom « Full-Tek » est-il un bon nom ?</h2>'
    '<p>Résultat d\'une <b>vérification préliminaire</b> sur le web (novembre 2026) :</p>'
    '<div class="box rec"><h4>Points positifs</h4><ul class="l">'
    '<li>Aucune entreprise connue portant exactement ce nom n\'a été trouvée <b>en Mauritanie</b>.</li>'
    '<li>Nom court, moderne, à consonance technologique, facile à décliner par métier : '
    '<b>Full-Tek Resto</b>, <b>Full-Tek Market</b>, <b>Full-Tek Pharma</b>.</li></ul></div>'
    '<div class="box warn"><h4>Points de vigilance</h4><ul class="l">'
    '<li>Des sociétés aux noms identiques ou très proches existent déjà ailleurs, dont <b>une société de développement logiciel en Égypte '
    'qui propose déjà des systèmes de caisse (POS)</b> : risque de confusion dans les recherches Google.</li>'
    '<li>Le nom peut évoquer un magasin de matériel informatique plutôt qu\'un logiciel de caisse.</li>'
    '<li>Le tiret du nom est facilement oublié à l\'oral et dans les adresses web.</li></ul></div>'
    '<h2>2. Verdict</h2>'
    '<table><thead><tr><th style="width:30%">Critère</th><th style="width:15%">Note</th><th>Commentaire</th></tr></thead><tbody>'
    '<tr><td>Facilité de mémorisation</td><td>&#9733;&#9733;&#9733;&#9733;&#9734;</td><td>Court et rythmé</td></tr>'
    '<tr><td>Compréhension du métier</td><td>&#9733;&#9733;&#9734;&#9734;&#9734;</td><td>Ne dit pas « caisse » ou « point de vente »</td></tr>'
    '<tr><td>Unicité / protection de la marque</td><td>&#9733;&#9733;&#9734;&#9734;&#9734;</td><td>Noms très proches existants</td></tr>'
    '<tr><td>Extension à d\'autres secteurs</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>Excellente déclinaison de gamme</td></tr>'
    '<tr><td>Ancrage local mauritanien</td><td>&#9733;&#9733;&#9734;&#9734;&#9734;</td><td>Nom neutre, pas de lien local</td></tr>'
    '</tbody></table>'
    '<div class="box rec"><h4>Conclusion</h4>'
    '<p style="margin:0">Full-Tek est <b>utilisable, mais pas idéal seul</b>. Pour qu\'il fonctionne, il doit toujours apparaître sous la forme '
    '<b>« Full-Tek POS »</b> (ou Full-Tek Resto / Market / Pharma). Les pages suivantes présentent des alternatives plus distinctives.</p></div>'
    '<h2>3. Comment lire les propositions</h2>'
    '<p>Chaque fiche présente : le sens du nom, sa déclinaison de gamme, ses <b>avantages</b>, ses <b>points d\'attention</b>, les noms de domaine à tester '
    'et une note de potentiel (indicative, basée sur la clarté, la mémorisation, l\'ancrage local et la facilité de protection).</p>'
)

p3 = top + '<h2>4. Les propositions (1/2)</h2>' + card(NAMES[0]) + card(NAMES[1]) + card(NAMES[2])
p4 = top + '<h2>4. Les propositions (2/2)</h2>' + card(NAMES[3]) + card(NAMES[4]) + card(NAMES[5])
p5 = top + '<h2>4. Les propositions (suite)</h2>' + card(NAMES[6]) + card(NAMES[7]) + (
    '<h2>5. Tableau comparatif</h2>'
    '<table><thead><tr><th>Nom</th><th>Sens</th><th>Clarté métier</th><th>Ancrage local</th><th>Distinctif</th></tr></thead><tbody>'
    '<tr><td><b>Full-Tek</b></td><td>Tech complète</td><td>&#9733;&#9733;</td><td>&#9733;&#9733;</td><td>&#9733;&#9733;</td></tr>'
    '<tr><td><b>Full-Tek POS</b></td><td>Tech complète + caisse</td><td>&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;</td></tr>'
    '<tr><td><b>Nokta POS</b></td><td>Point de vente</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;&#9733;</td></tr>'
    '<tr><td><b>Sahl POS</b></td><td>Facile</td><td>&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;</td></tr>'
    '<tr><td><b>Mizan POS</b></td><td>Balance / précision</td><td>&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;</td></tr>'
    '<tr><td><b>MauriTek</b></td><td>Mauritanie + tech</td><td>&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;</td></tr>'
    '<tr><td><b>CaissaPro</b></td><td>Caisse pro</td><td>&#9733;&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;</td></tr>'
    '<tr><td><b>TekPOS</b></td><td>Tech caisse</td><td>&#9733;&#9733;&#9733;&#9733;</td><td>&#9733;&#9733;</td><td>&#9733;&#9733;</td></tr>'
    '</tbody></table>'
)

p6 = top + (
    '<h2>6. Notre recommandation</h2>'
    '<div class="box rec"><h4>Choix n°1 : Nokta POS (نقطة)</h4><p style="margin:0">Sens immédiat « Point de Vente », mot arabe familier à tous les commerçants, '
    'très court, logo simple (un point), gamme naturelle : Nokta Resto, Nokta Market, Nokta Pharma, Nokta Boss.</p></div>'
    '<div class="box rec" style="background:#eff6ff;border-color:#3b82f6"><h4>Choix n°2 : Full-Tek POS</h4><p style="margin:0">Si le client tient à son idée de départ : '
    'le suffixe POS lève l\'ambiguïté du métier et limite la confusion avec les autres « Fulltek ».</p></div>'
    '<div class="box rec" style="background:#fffbeb;border-color:#f59e0b"><h4>Choix n°3 : Sahl POS (سهل)</h4><p style="margin:0">Promesse commerciale très parlante auprès des petits commerces : « la caisse facile ».</p></div>'
    '<h2>7. Avant de décider : vérifications indispensables</h2>'
    '<div class="box warn"><ul class="l">'
    '<li><b>Noms de domaine :</b> vérifier la disponibilité du .com et du .mr du nom choisi avant tout achat.</li>'
    '<li><b>Recherche Google et réseaux sociaux :</b> taper « nom + POS » pour s\'assurer qu\'aucun concurrent ne sort en premier ; vérifier les pseudos Facebook, Instagram, WhatsApp Business, TikTok.</li>'
    '<li><b>Marque :</b> faire une recherche d\'antériorité (OAPI / registre mauritanien) avant d\'imprimer logos, cartes et contrats.</li>'
    '<li><b>Test de prononciation :</b> faire dire le nom à 5 commerçants (en français et en arabe) et noter ceux qui l\'écrivent correctement.</li></ul></div>'
    '<p style="font-size:8pt;color:#64748b">Les notes ci-dessus sont indicatives. La disponibilité exacte des noms et des marques doit être confirmée auprès des registrars et des offices de propriété industrielle.</p>'
    '<h2>8. Décision du client</h2>'
    '<div class="sig"><div><b>Nom retenu :</b><br><br>..............................................</div>'
    '<div><b>Date &amp; Signature de M. Taha Chouaib :</b><br><br>..............................................</div></div>'
)

html = ('<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>Propositions de noms</title><style>%s</style></head><body>%s%s%s%s%s%s</body></html>'
        % (CSS, cover, page(p2, 2, TOTAL), page(p3, 3, TOTAL), page(p4, 4, TOTAL), page(p5, 5, TOTAL), page(p6, 6, TOTAL)))

base = "Propositions_Noms_Plateforme_POS_Taha_Chouaib"
hp = os.path.join(OUT, base + ".html")
pp = os.path.join(OUT, base + ".pdf")
open(hp, "w", encoding="utf-8").write(html)
chrome = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
edge = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
b = chrome if os.path.exists(chrome) else edge
subprocess.run([b, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--print-to-pdf=" + pp, hp], check=True)
print("OK", pp)
