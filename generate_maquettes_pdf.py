import os
import sys
import subprocess

OUT = r"d:\_Documents\Bureau\caissamrr"
HTML_PATH = os.path.join(OUT, "Maquettes_Interfaces_POS_Taha_Chouaib.html")
PDF_PATH = os.path.join(OUT, "Maquettes_Interfaces_POS_Taha_Chouaib.pdf")
PNG_DIR = os.path.join(OUT, "Maquettes_PNG")

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
if not os.path.exists(CHROME):
    CHROME = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"


# ---------------------------------------------------------------- THEMES
def T(**kw):
    base = dict(ok="#22c55e", warn="#f59e0b", bad="#ef4444", info="#3b82f6",
                hd="var(--sf)", hdtx="var(--tx)", tl="var(--sf)",
                tbd="1px solid var(--bd)", sh="none",
                ff="'Inter','Segoe UI',sans-serif", hf="'Inter','Segoe UI',sans-serif")
    base.update(kw)
    return base


THEMES = [
    dict(
        id=1, name="Émeraude Night", tag="Dark Pro · sombre, net et ultra lisible",
        ticket="right", cat="tabs", logo="🍽",
        v=T(bg="#0b1220", sf="#131c2e", sf2="#1b2742", tx="#e8eefc", mu="#8b9bb8", ac="#10b981", ac2="#34d399",
            actx="#03180f", bd="rgba(255,255,255,.08)", r="12px", hd="#0f1729"),
        palette=[("Fond", "#0B1220"), ("Surface", "#131C2E"), ("Accent", "#10B981"), ("Texte", "#E8EEFC")],
        typo="Inter — sans-serif géométrique", mood="Technologique, calme, professionnel",
        philo="Interface sombre à fort contraste, pensée pour les longs services. Les prix et boutons d'action ressortent immédiatement et la fatigue visuelle est réduite en salle peu éclairée.",
        ideal="Restaurants, lounges, cafés de nuit, fast-foods ouverts tard, caisses utilisées 12 h par jour.",
        atouts="Excellente lisibilité · Économie de batterie sur tablettes OLED · Image moderne et « tech » · Fatigue visuelle réduite",
        mode="Sombre", vitesse=5, premium=4,
    ),
    dict(
        id=2, name="Ivoire Chic", tag="Clair & chaleureux · élégance accueillante",
        ticket="left", cat="rail", logo="☕",
        v=T(bg="#f6f3ee", sf="#ffffff", sf2="#f1ebe2", tx="#1f2430", mu="#7a7468", ac="#d9480f", ac2="#f08c00",
            actx="#ffffff", bd="#e7e0d5", r="16px", sh="0 2px 10px rgba(60,40,10,.07)", hd="#ffffff"),
        palette=[("Fond", "#F6F3EE"), ("Surface", "#FFFFFF"), ("Accent", "#D9480F"), ("Texte", "#1F2430")],
        typo="Inter — humaniste, arrondi", mood="Chaleureux, gourmand, accueillant",
        philo="Palette ivoire et terre cuite inspirée des intérieurs de salons de thé et pâtisseries. Le ticket est placé à gauche pour un geste naturel de la main droite sur le catalogue.",
        ideal="Cafés, salons de thé, pâtisseries, boulangeries, restaurants familiaux.",
        atouts="Très lumineux en plein jour · Ambiance conviviale · Ticket à gauche, catalogue à droite · Lecture douce et claire",
        mode="Clair", vitesse=4, premium=4,
    ),
    dict(
        id=3, name="Sahara Or", tag="Luxe & prestige · noir profond et dorures",
        ticket="right", cat="rail", logo="♛",
        v=T(bg="#14100c", sf="#1e1914", sf2="#2a2218", tx="#f5ead6", mu="#a89574", ac="#d4a24c", ac2="#ecd49a",
            actx="#1a1206", bd="rgba(212,162,76,.22)", r="6px", hd="#0e0b08",
            hf="'Playfair Display',Georgia,serif"),
        palette=[("Fond", "#14100C"), ("Surface", "#1E1914"), ("Or", "#D4A24C"), ("Texte", "#F5EAD6")],
        typo="Playfair Display + Inter", mood="Premium, raffiné, haut de gamme",
        philo="Noir chaud et dorures fines pour valoriser les établissements haut de gamme. Les angles nets et les titres en serif donnent une image de prestige dès le premier regard.",
        ideal="Restaurants gastronomiques, hôtels, salons VIP / Khaima, traiteurs événementiels.",
        atouts="Image premium immédiate · Typographie élégante · Idéal pour les clients exigeants · Se démarque de la concurrence",
        mode="Sombre", vitesse=4, premium=5,
    ),
    dict(
        id=4, name="Aurora Glass", tag="Glassmorphism · futuriste et spectaculaire",
        ticket="left", cat="tabs", logo="✦",
        v=T(bg="linear-gradient(135deg,#1e1b4b 0%,#4c1d95 48%,#0e7490 100%)", sf="rgba(255,255,255,.10)",
            sf2="rgba(255,255,255,.17)", tx="#ffffff", mu="rgba(255,255,255,.66)", ac="#22d3ee", ac2="#c084fc",
            actx="#06222b", bd="rgba(255,255,255,.20)", r="20px", hd="rgba(255,255,255,.07)", tl="rgba(255,255,255,.10)",
            sh="0 8px 24px rgba(0,0,0,.18)"),
        palette=[("Dégradé", "#4C1D95"), ("Verre", "#FFFFFF1A"), ("Cyan", "#22D3EE"), ("Violet", "#C084FC")],
        typo="Inter — léger et aéré", mood="Innovant, jeune, « wow »",
        philo="Cartes translucides sur un dégradé aurore : l'interface la plus spectaculaire du catalogue. Elle donne un effet « application de demain » dès la démonstration.",
        ideal="Concepts modernes, dark kitchens, enseignes jeunes, démonstrations commerciales.",
        atouts="Effet « wow » garanti · Image innovante · Superbe sur tablette · Très mémorable en présentation",
        mode="Sombre (verre)", vitesse=4, premium=5,
    ),
    dict(
        id=5, name="Fast Pop", tag="Fast-food · gros boutons, couleurs vives",
        ticket="right", cat="tabs", logo="🍔",
        v=T(bg="#fff7ed", sf="#ffffff", sf2="#ffedd5", tx="#2b1b0e", mu="#8a6d52", ac="#ef233c", ac2="#ffb703",
            actx="#ffffff", bd="#fed7aa", r="22px", sh="0 3px 0 #fdba74", hd="#ef233c", hdtx="#ffffff",
            tbd="3px solid #ffd6a5"),
        palette=[("Fond", "#FFF7ED"), ("Rouge", "#EF233C"), ("Jaune", "#FFB703"), ("Texte", "#2B1B0E")],
        typo="Inter Black — gros et lisible", mood="Dynamique, joyeux, appétissant",
        philo="Boutons XXL, couleurs « fast-food » et gestes simplifiés : un nouveau caissier est opérationnel en 10 minutes. Conçu pour encaisser vite aux heures de pointe.",
        ideal="Fast-foods, tacos, burgers, chawarma, snacks, kiosques et bornes tactiles.",
        atouts="Rapidité maximale · Formation du personnel quasi nulle · Gros boutons tactiles · Énergie visuelle forte",
        mode="Clair", vitesse=5, premium=3,
    ),
    dict(
        id=6, name="Ocean Fintech", tag="Bleu pro · sobre, rassurant, SaaS moderne",
        ticket="right", cat="rail", logo="◆",
        v=T(bg="#f4f7fb", sf="#ffffff", sf2="#eaf0f9", tx="#0f1b33", mu="#6b7a99", ac="#2563eb", ac2="#06b6d4",
            actx="#ffffff", bd="#e1e8f4", r="14px", sh="0 4px 16px rgba(37,99,235,.08)", hd="#ffffff"),
        palette=[("Fond", "#F4F7FB"), ("Surface", "#FFFFFF"), ("Bleu", "#2563EB"), ("Texte", "#0F1B33")],
        typo="Inter — neutre, précis", mood="Fiable, structuré, professionnel",
        philo="Style SaaS contemporain, blanc et bleu, proche des applications bancaires. Il inspire confiance et assure une cohérence parfaite avec le tableau de bord web et l'application mobile du propriétaire.",
        ideal="Toutes activités, chaînes multi-sites, restauration + market, clients institutionnels.",
        atouts="Aspect sérieux et rassurant · Cohérence avec l'App Boss · Facile à personnaliser au logo · Polyvalent",
        mode="Clair", vitesse=4, premium=4,
    ),
    dict(
        id=7, name="Mauritanie Prestige", tag="Vert national & Or sable · identité traditionnelle & familiale",
        ticket="left", cat="tabs", logo="🇲🇷",
        brand_name="Dar El-Karam · دار الكرم", brand_sub="Khaima VIP & Cuisine Mauritanienne",
        banner="⛺ Salon Khaima VIP-02 · Affichage Bilingue Priorité Arabe (RTL) & Français · Vente au Plateau",
        cats=[("🍖", "Méchoui"), ("🍛", "Plats Trad."), ("🐪", "Spécialités"), ("🍵", "Atay & Jus"), ("Dates", "Dattes"), ("⛺", "Salons VIP")],
        prods=[
            ("🍖", "1/2 Agneau Méchoui", "مشوي نصف خروف", "2 800", "hot", ""),
            ("🍛", "Thieboudienne Royal", "تيبودين ملكي", "450", "hot", ""),
            ("🥘", "Couscous Mauritanien", "كسكس موريتاني", "380", "", ""),
            ("🐪", "Brochettes Chameau", "مشوي لحم الإبل", "520", "hot", ""),
            ("🥛", "Lait de Chamelle Frais", "لبن الإبل الطازج", "120", "", ""),
            ("🍵", "Thé Atay 3 Services", "أتاي موريتاني", "150", "", ""),
            ("🌴", "Plateau Dattes Atar", "تمر أطار فاخر", "250", "", ""),
            ("🍲", "Harira & Dattes", "حريرة بالتمر", "180", "", ""),
            ("🥤", "Jus Bissap & Zrig", "كركديه و زريك", "100", "", ""),
        ],
        v=T(bg="#06281e", sf="#0c3b2e", sf2="#134e3e", tx="#f7fee7", mu="#a7f3d0", ac="#f59e0b", ac2="#10b981",
            actx="#052e16", bd="rgba(245,158,11,.25)", r="14px", hd="#041f17",
            hf="'Playfair Display',Georgia,serif"),
        palette=[("Vert Mauritanie", "#06281E"), ("Émeraude", "#0C3B2E"), ("Or Sable", "#F59E0B"), ("Ivoire", "#F7FEE7")],
        typo="Playfair Display + Inter Arabe", mood="Authentique, hospitalier, prestigieux",
        philo="Hommage aux couleurs et à l'hospitalité mauritanienne : vert profond et or sable avec mise en valeur de la langue arabe, idéal pour les grands restaurants traditionnels, méchouis et salons Khaima.",
        ideal="Restaurants traditionnels mauritaniens, méchouis, salons Khaima VIP, traiteurs mariages & réceptions.",
        atouts="Forte identité locale mauritanienne · Parfait en Arabe RTL · Gestion des plateaux & demi-agneaux · Très apprécié des familles",
        mode="Sombre (Vert & Or)", vitesse=5, premium=5,
    ),
    dict(
        id=8, name="HyperMarket & Supérette Pro", tag="Mode Supermarché, Boucherie & Grossiste · Balance + Code-barres",
        ticket="right", cat="rail", logo="🛒",
        brand_name="Al-Baraka Market · سوبرماركت البركة", brand_sub="Caisse #01 · Scan EAN-13 & Pesée COM1",
        banner="⚖ BALANCE COM1 : 1,450 kg × 380 MRU = 551 MRU  |  🔍 Scanner EAN-13 Actif  |  📦 Grille Détail / Demi-Gros / Karni",
        cats=[("⚖", "Boucherie"), ("🥖", "Boulangerie"), ("🥛", "Crèmerie"), ("🌾", "Épicerie Gros"), ("🍎", "Fruits/Lég."), ("💧", "Boissons")],
        prods=[
            ("🥩", "Viande Hachée (1,45kg)", "لحم بقري مفروم", "551", "hot", ""),
            ("🥛", "Lait Nido Poudre 900g", "حليب نيدو ٩٠٠غ", "380", "hot", ""),
            ("🌾", "Sac Riz Importé 25 kg", "أرز مستورد ٢٥ كغ", "950", "", ""),
            ("🌻", "Huile Végétale 5 L", "زيت نباتي ٥ لتر", "420", "", ""),
            ("🌴", "Dattes Atar (Pesée 1kg)", "تمر أطار ١ كغ", "250", "", ""),
            ("🥖", "Baguette Tradition x5", "خبز فرنسي ×٥", "50", "", ""),
            ("💧", "Pack Eau Benichab x6", "مياه بنشاب ×٦", "110", "hot", ""),
            ("🍃", "Thé Vert Achoura 500g", "شاي أخضر ٥٠٠غ", "180", "", ""),
            ("🧀", "Fromage Portions x24", "جبن ٢٤ قطعة", "140", "", ""),
        ],
        v=T(bg="#f1f5f9", sf="#ffffff", sf2="#e2e8f0", tx="#0f172a", mu="#475569", ac="#16a34a", ac2="#0284c7",
            actx="#ffffff", bd="#cbd5e1", r="8px", sh="0 1px 4px rgba(0,0,0,.06)", hd="#0f172a", hdtx="#ffffff"),
        palette=[("Fond Clair", "#F1F5F9"), ("En-tête Pro", "#0F172A"), ("Vert Caisse", "#16A34A"), ("Bleu Stock", "#0284C7")],
        typo="Inter + JetBrains Mono (chiffres)", mood="Ultra-rapide, industriel, précis",
        philo="Conçu spécifiquement pour le secteur Market, Supérette, Boucherie et Demi-Gros : lecture code-barres instantanée, affichage du poids de la balance électronique en direct et gestion du Carnet Karni.",
        ideal="Supermarchés, supérettes, boucheries, épiceries fines, vendeurs demi-gros, dépôts alimentaires.",
        atouts="Intégration Balance Poids-Prix · Bascule Détail / Demi-Gros · Suivi dates de péremption (FEFO) · Carnet crédit Karni",
        mode="Clair Haute Densité", vitesse=5, premium=4,
    ),
    dict(
        id=9, name="Mocha Pâtisserie & Café", tag="Chocolat, Caramel & Rose Poudré · Boulangerie, Glacier & Coffee-Shop",
        ticket="left", cat="tabs", logo="🥐",
        brand_name="Maison Délice · ميزون ديليس", brand_sub="Pâtisserie Fine, Boulangerie & Glacier",
        banner="🎂 Commande Gâteau Anniversaire #A-42 (Acompte Arboun : 500 MRU déduit) · ⚖ Pesée Pâtisserie 250g / 500g / 1kg",
        cats=[("🎂", "Gâteaux"), ("🥐", "Viennoiseries"), ("🍨", "Glaces"), ("☕", "Coffee Bar"), ("🥞", "Crêpes"), ("🥪", "Salé")],
        prods=[
            ("🎂", "Entremets Royal Chocolat", "كعكة الشوكولاتة", "1 400", "hot", ""),
            ("🥮", "Coffret Orientales 1 kg", "حلويات شرقية ١ كغ", "680", "hot", ""),
            ("🥐", "Croissant Pur Beurre", "كرواسون بالزبدة", "45", "", ""),
            ("🍨", "Coupe Glace 3 Boules", "آيس كريم ٣ كرات", "180", "hot", ""),
            ("☕", "Cappuccino Latte Art", "كابتشينو إيطالي", "120", "", ""),
            ("🥞", "Crêpe Nutella Banane", "كريب نوتيلا وموز", "190", "", ""),
            ("🍓", "Tartelette Fraises", "تارت الفراولة", "140", "", ""),
            ("🧋", "Iced Matcha / Frappé", "قهوة مثلجة", "160", "", ""),
            ("🥖", "Pain Complet Céréales", "خبز الحبوب الكاملة", "35", "", ""),
        ],
        v=T(bg="#fff8f4", sf="#ffffff", sf2="#f9ebe2", tx="#2c1810", mu="#8c6252", ac="#e11d48", ac2="#d97706",
            actx="#ffffff", bd="#f0d9cc", r="18px", sh="0 4px 14px rgba(140,60,40,.08)", hd="#2c1810", hdtx="#fff8f4",
            hf="'Playfair Display',Georgia,serif"),
        palette=[("Crème Chantilly", "#FFF8F4"), ("Expresso", "#2C1810"), ("Framboise", "#E11D48"), ("Caramel", "#D97706")],
        typo="Playfair Display + Inter", mood="Gourmand, élégant, artisanal",
        philo="Alliance raffinée de tons chocolat expresso, crème chantilly et framboise : met en appétit et intègre les fonctions clés des pâtisseries (vente au poids 250g/500g/1kg, commandes de gâteaux avec acompte).",
        ideal="Pâtisseries, boulangeries modernes, salons de thé, glaciers, crêperies, coffee-shops.",
        atouts="Gestion des acomptes gâteaux (Arboun) · Vente au poids ou à la pièce · Composition de coupes glacées · Look très chic",
        mode="Clair Gourmand", vitesse=4, premium=5,
    ),
    dict(
        id=10, name="Cyber Néon Street-Food", tag="Noir Carbone & Vert Citron Néon · Pizzeria, Tacos & Night-Food",
        ticket="right", cat="tabs", logo="⚡",
        brand_name="Neon Street Kitchen · نيون ستريت", brand_sub="Smash Burger, Pizza 50/50 & Tacos XL",
        banner="🍕 Configurateur Pizza Moitié-Moitié (50% Reine / 50% 4 Fromages) · 🛵 Dispatch Moto Express Nouakchott",
        cats=[("🍕", "Pizzas 50/50"), ("🌯", "Tacos XL"), ("🍔", "Smash"), ("🍗", "Crispy"), ("🍟", "Loaded Fries"), ("🥤", "Drinks")],
        prods=[
            ("🍕", "Pizza Moitié-Moitié XL", "بيتزا نصفين كبيرة", "420", "hot", ""),
            ("🌯", "Tacos Géant 3 Viandes", "تاكوس عملاق ٣ لحوم", "310", "hot", ""),
            ("🍔", "Triple Smash Cheddar", "تريبل سماش برغر", "340", "hot", ""),
            ("🍗", "Bucket Crispy Wings x12", "أجنحة دجاج مقرمشة", "390", "", ""),
            ("🥙", "Chawarma Spécial Cheese", "شاورما اكسترا جبن", "240", "", ""),
            ("🍟", "Frites Cheddar Bacon", "بطاطس بالجبن", "160", "", ""),
            ("🍕", "Pizza Pepperoni Feu", "بيتزا بيبروني حارة", "360", "", ""),
            ("🥤", "Mojito Menthe Citron", "موهيتو نعناع وليمون", "130", "", ""),
            ("🍩", "Donut Oreo Glacé", "دونات أوريو", "90", "", ""),
        ],
        v=T(bg="#09090b", sf="#141418", sf2="#1f1f26", tx="#fafafa", mu="#a1a1aa", ac="#84cc16", ac2="#f97316",
            actx="#09090b", bd="rgba(132,204,22,.28)", r="12px", hd="#09090b"),
        palette=[("Carbone", "#09090B"), ("Asphalte", "#141418"), ("Néon Lime", "#84CC16"), ("Orange Feu", "#F97316")],
        typo="Inter ExtraBold — impact urbain", mood="Urbain, ultra-rapide, jeune, nocturne",
        philo="Contraste maximal noir carbone et vert néon conçu pour les concepts street-food à fort volume nocturne. Intègre le configurateur de Pizza Moitié-Moitié et le choix rapide des tailles S/M/L/XL.",
        ideal="Pizzerias, french tacos, smash burgers, dark kitchens, restaurants de nuit et livraison rapide.",
        atouts="Option Pizza Moitié-Moitié native · Tailles S/M/L/XL en 1 clic · Zéro éblouissement la nuit · Ultra-rapide",
        mode="Sombre Néon", vitesse=5, premium=4,
    ),
    dict(
        id=11, name="Nordic Minimal (Apple Style)", tag="Blanc pur & Bleu iOS · minimalisme absolu inspiré d'iPadOS",
        ticket="right", cat="rail", logo="",
        brand_name="L'Atelier · الأتيليه", brand_sub="Bistro Contemporain · iPad Pro POS",
        banner="✨ Interface Minimaliste Haute Couture · Navigation Fluide sans Bordures · Idéal sur Tablette & iPad",
        cats=[("🥗", "Entrées"), ("🥩", "Signatures"), ("🍝", "Risottos"), ("🐟", "Océan"), ("🍰", "Pâtisseries"), ("🍹", "Mocktails")],
        prods=[
            ("🥩", "Filet de Boeuf Rossini", "فيليه لحم بقري", "690", "hot", ""),
            ("🐟", "Pavé de Courbine Grillé", "سمك كوربين مشوي", "540", "hot", ""),
            ("🍝", "Risotto Champignons", "ريزوتو بالفطر", "440", "", ""),
            ("🥗", "Salade César Crispy", "سلطة سيزر مقرمشة", "290", "", ""),
            ("🍤", "Gambas Royales Ail", "روبيان ملكي بالثوم", "620", "hot", ""),
            ("🍰", "Cheesecake Pistache", "تشيزكيك بالفستق", "220", "", ""),
            ("🍫", "Fondant Coeur Coulant", "فوندان الشوكولاتة", "200", "", ""),
            ("🍹", "Detox Mangue Passion", "عصير مانجو وباشن", "150", "", ""),
            ("☕", "Espresso Spécialité", "إسبريسو مختص", "90", "", ""),
        ],
        v=T(bg="#f5f5f7", sf="#ffffff", sf2="#eef0f4", tx="#1d1d1f", mu="#86868b", ac="#0071e3", ac2="#34c759",
            actx="#ffffff", bd="#e5e5ea", r="18px", sh="0 6px 20px rgba(0,0,0,.05)", hd="#ffffff"),
        palette=[("Gris Apple", "#F5F5F7"), ("Blanc Pur", "#FFFFFF"), ("Bleu iOS", "#0071E3"), ("Noir Encre", "#1D1D1F")],
        typo="SF Pro / Inter — clarté maximale", mood="Épuré, luxueux, intuitif, moderne",
        philo="Inspiré des interfaces Apple Store et Square iPad POS : aucune surcharge visuelle, des cartes flottantes aux coins doux et une hiérarchie typographique cristalline.",
        ideal="Restaurants contemporains, lounges modernes à Tevragh Zeina, franchises internationales, caisses sur iPad/tablette.",
        atouts="Élégance internationale · Prise en main immédiate · Superbe sur écran tactile HD · Aucune surcharge",
        mode="Clair Minimaliste", vitesse=5, premium=5,
    ),
    dict(
        id=12, name="Oasis Resort & Hôtel", tag="Bleu Lagune & Sable Doré · Hôtels, Auberges, Plages & Multi-Devises",
        ticket="left", cat="rail", logo="🏝",
        brand_name="Oasis Atlantic Resort · منتجع الواحة", brand_sub="Restaurant Hôtel, Piscine & Room-Service",
        banner="🏨 Facturation Chambre #204 (Room Charge)  |  💱 Multi-Devises : 1 610 MRU ≈ 38,00 € / 41,00 $  |  🏖 Zone Piscine & Plage",
        cats=[("🦞", "Fruits de Mer"), ("🍖", "Grillades"), ("🥐", "Brunch Hôtel"), ("🍹", "Pool Bar"), ("💨", "Chicha VIP"), ("🏨", "Room Svc")],
        prods=[
            ("🦞", "Langouste Nouadhibou", "جراد البحر نواذيبو", "1 250", "hot", ""),
            ("🦐", "Plateau Fruits de Mer", "طبق فواكه البحر", "1 600", "hot", ""),
            ("🍖", "Méchoui Bord Piscine", "مشوي المسبح", "580", "", ""),
            ("🥐", "Buffet Petit-Déjeuner", "بوفيه إفطار الفندق", "450", "hot", ""),
            ("🍹", "Cocktail Sunset Plage", "كوكتيل الغروب", "180", "", ""),
            ("💨", "Chicha Lounge Premium", "شيشة فاخرة", "400", "", ""),
            ("🐟", "Thiof Braisé Entier", "سمك تيوف مشوي", "650", "", ""),
            ("🥗", "Salade Exotique Avocat", "سلطة الأفوكادو", "260", "", ""),
            ("🍨", "Assiette Fruits Frais", "طبق فواكه طازجة", "220", "", ""),
        ],
        v=T(bg="#082f49", sf="#0c4a6e", sf2="#075985", tx="#f0f9ff", mu="#7dd3fc", ac="#f59e0b", ac2="#38bdf8",
            actx="#082f49", bd="rgba(56,189,248,.25)", r="14px", hd="#051e30"),
        palette=[("Bleu Océan", "#082F49"), ("Lagune", "#0C4A6E"), ("Or Soleil", "#F59E0B"), ("Azur", "#38BDF8")],
        typo="Inter + titres dorés", mood="Balnéaire, touristique, international, VIP",
        philo="Conçu pour l'hôtellerie, les auberges du désert et les complexes balnéaires : intègre le transfert de note sur la chambre d'hôtel (Room Charge) et l'affichage multi-devises MRU / EUR / USD.",
        ideal="Hôtels, auberges touristiques (Atar, Chinguetti, Nouadhibou, Nouakchott), clubs de plage, lounges piscine.",
        atouts="Transfert sur facture Chambre Hôtel · Multi-devises MRU / € / $ · Gestion Piscine, Plage & Salon · Bilingue + Anglais",
        mode="Sombre Lagune", vitesse=4, premium=5,
    ),
]


# ---------------------------------------------------------------- CSS
CSS = """
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=Playfair+Display:wght@600;700;800&display=swap');
@page{size:A4 landscape;margin:0}
*{box-sizing:border-box;-webkit-print-color-adjust:exact!important;print-color-adjust:exact!important}
html,body{margin:0;padding:0;font-family:'Inter','Segoe UI',sans-serif;color:#0f172a}

/* ---------- SCREEN (design canvas 1024x640) ---------- */
.scr{width:1024px;height:640px;position:relative;overflow:hidden;display:flex;flex-direction:column;background:var(--bg);color:var(--tx);font-family:var(--ff);font-size:13px;line-height:1.3}
.scr *{box-sizing:border-box}
.scr b,.scr strong{font-weight:700}
.tb{height:48px;flex:none;display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:var(--hd);color:var(--hdtx);border-bottom:1px solid var(--bd)}
.brand{display:flex;align-items:center;gap:8px}
.logo{width:28px;height:28px;border-radius:9px;background:linear-gradient(135deg,var(--ac),var(--ac2));color:var(--actx);display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:800}
.brand b{font-family:var(--hf);font-size:15px}
.brand i{font-style:normal;opacity:.65;font-size:11px}
.modes{display:flex;gap:6px}
.modes span{padding:6px 12px;border-radius:999px;font-weight:600;font-size:12px;opacity:.75}
.modes span.on{background:var(--ac);color:var(--actx);opacity:1}
.mid-title{font-family:var(--hf);font-size:16px;font-weight:700}
.st{display:flex;align-items:center;gap:8px;font-size:11px;font-weight:600}
.dot{width:8px;height:8px;border-radius:50%;background:var(--ok);display:inline-block}
.dot.b{background:var(--info)}
.av{width:26px;height:26px;border-radius:50%;background:var(--ac2);color:var(--actx);display:inline-flex;align-items:center;justify-content:center;font-weight:800;font-size:12px}
.lang{padding:3px 9px;border-radius:999px;border:1px solid var(--bd);font-size:12px}

/* POS */
.pos{flex:1;display:flex;min-height:0}
.pos.tl{flex-direction:row-reverse}
.pm{flex:1;display:flex;min-width:0}
.pm.col{flex-direction:column}
.rail{width:78px;flex:none;padding:10px 8px;display:flex;flex-direction:column;gap:8px;border-right:1px solid var(--bd);background:var(--sf)}
.rail div{border-radius:var(--r);padding:8px 2px;text-align:center;font-size:10.5px;font-weight:600;color:var(--mu)}
.rail div b{display:block;font-size:21px;margin-bottom:2px}
.rail div.on{background:var(--ac);color:var(--actx)}
.tabs{display:flex;gap:8px;padding:12px 14px 0;flex:none}
.tabs span{padding:8px 14px;border-radius:999px;background:var(--sf);border:1px solid var(--bd);font-weight:600;font-size:12px;color:var(--mu)}
.tabs span.on{background:var(--ac);color:var(--actx);border-color:var(--ac)}
.search{margin:12px 14px 0;padding:9px 14px;border-radius:var(--r);background:var(--sf);border:1px solid var(--bd);color:var(--mu);font-size:12px;flex:none}
.grid{flex:1;display:grid;grid-template-columns:repeat(3,1fr);grid-auto-rows:1fr;gap:9px;padding:10px 14px;min-width:0;min-height:0}
.tile{background:var(--tl);border:var(--tbd);border-radius:var(--r);box-shadow:var(--sh);padding:9px 10px;display:flex;flex-direction:column;justify-content:space-between;position:relative;overflow:hidden}
.em{font-size:26px;width:44px;height:44px;border-radius:50%;background:var(--sf2);display:flex;align-items:center;justify-content:center}
.nm{font-weight:700;font-size:13.5px}
.ar{color:var(--mu);font-size:11.5px}
.pr{color:var(--ac);font-weight:800;font-size:14px}
.tile.off{opacity:.5}
.tile .tag{position:absolute;top:8px;right:8px;background:var(--bad);color:#fff;font-size:9.5px;font-weight:800;padding:2px 7px;border-radius:999px}
.tile .hot{position:absolute;top:8px;right:8px;background:var(--ac2);color:var(--actx);font-size:9.5px;font-weight:800;padding:2px 7px;border-radius:999px}
.tk{width:300px;flex:none;background:var(--sf);border-left:1px solid var(--bd);display:flex;flex-direction:column;padding:12px;gap:8px}
.pos.tl .tk{border-left:0;border-right:1px solid var(--bd)}
.tkh{display:flex;justify-content:space-between;align-items:center;padding-bottom:8px;border-bottom:1px solid var(--bd)}
.tkh b{font-family:var(--hf);font-size:15px}
.chip{padding:3px 9px;border-radius:999px;background:var(--sf2);font-size:10.5px;font-weight:700;color:var(--mu)}
.chip.ac{background:var(--ac);color:var(--actx)}
.ln{display:flex;justify-content:space-between;gap:6px;padding:7px 0;border-bottom:1px dashed var(--bd)}
.ln small{display:block;color:var(--mu);font-size:10.5px}
.qty{display:inline-flex;width:22px;height:22px;border-radius:7px;background:var(--sf2);align-items:center;justify-content:center;font-weight:800;font-size:11.5px;margin-right:6px;color:var(--ac)}
.sp{flex:1}
.tot{display:flex;flex-direction:column;gap:3px;font-size:12px;color:var(--mu)}
.tot div{display:flex;justify-content:space-between}
.tot .big{font-size:20px;font-weight:800;color:var(--tx);font-family:var(--hf);margin-top:3px}
.tot .big span:last-child{color:var(--ac)}
.acts{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.acts span,.pays span{padding:7px 0;text-align:center;background:var(--sf2);border-radius:calc(var(--r)*.6);font-size:11px;font-weight:700}
.pays{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}
.pays span{font-size:10.5px;color:#fff}
.cta{background:linear-gradient(135deg,var(--ac),var(--ac2));color:var(--actx);text-align:center;font-weight:800;padding:13px;border-radius:var(--r);font-size:15px}

/* FLOOR */
.fp{flex:1;display:flex;min-height:0}
.zn{width:150px;flex:none;padding:12px 10px;display:flex;flex-direction:column;gap:8px;background:var(--sf);border-right:1px solid var(--bd)}
.zn div{padding:10px;border-radius:var(--r);font-weight:600;font-size:12px;color:var(--mu);display:flex;justify-content:space-between;align-items:center}
.zn div span{font-size:10.5px;background:var(--sf2);padding:1px 7px;border-radius:999px}
.zn div.on{background:var(--ac);color:var(--actx)}
.zn div.on span{background:rgba(255,255,255,.25);color:inherit}
.cv{flex:1;position:relative;margin:12px;border-radius:var(--r);background-color:var(--sf);border:1px solid var(--bd);background-image:radial-gradient(var(--bd) 1px,transparent 1px);background-size:18px 18px}
.tbl{position:absolute;display:flex;flex-direction:column;align-items:center;justify-content:center;font-weight:800;border:2px solid;font-size:13px;gap:1px}
.tbl small{font-size:10px;font-weight:600;opacity:.85}
.tbl.rd{border-radius:50%}
.tbl:not(.rd){border-radius:calc(var(--r)*.8)}
.s-free{border-color:var(--bd);background:var(--sf2);color:var(--mu)}
.s-busy{border-color:#3b82f6;background:rgba(59,130,246,.2)}
.s-wait{border-color:#f59e0b;background:rgba(245,158,11,.22)}
.s-bill{border-color:#a855f7;background:rgba(168,85,247,.22)}
.s-resv{border-color:var(--ac2);border-style:dashed;background:transparent}
.tbl.sel{box-shadow:0 0 0 4px var(--ac)}
.deco{position:absolute;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:var(--mu);border-radius:var(--r);background:var(--sf2);letter-spacing:1px}
.lg{position:absolute;left:14px;bottom:10px;display:flex;gap:12px;font-size:10.5px;color:var(--mu);font-weight:600}
.lg i{display:inline-block;width:9px;height:9px;border-radius:3px;margin-right:4px}
.dp{width:250px;flex:none;background:var(--sf);border-left:1px solid var(--bd);padding:14px;display:flex;flex-direction:column;gap:10px}
.dp h3{margin:0;font-family:var(--hf);font-size:20px}
.dp .row{display:flex;justify-content:space-between;font-size:12px;color:var(--mu);padding:5px 0;border-bottom:1px dashed var(--bd)}
.dp .row b{color:var(--tx)}
.btn{padding:9px;text-align:center;border-radius:calc(var(--r)*.7);background:var(--sf2);font-weight:700;font-size:12px}
.btn.ac{background:var(--ac);color:var(--actx)}

/* KDS */
.kd{flex:1;padding:12px 14px;display:flex;flex-direction:column;gap:10px;min-height:0}
.flt{display:flex;gap:8px;align-items:center}
.flt span{padding:7px 14px;border-radius:999px;background:var(--sf);border:1px solid var(--bd);font-weight:600;font-size:12px;color:var(--mu)}
.flt span.on{background:var(--ac);color:var(--actx);border-color:var(--ac)}
.flt .r{margin-left:auto;background:transparent;border:0;color:var(--mu)}
.kc{flex:1;display:grid;grid-template-columns:repeat(4,1fr);gap:10px;min-height:0}
.kt{background:var(--sf);border:1px solid var(--bd);border-radius:var(--r);overflow:hidden;display:flex;flex-direction:column;box-shadow:var(--sh)}
.kh{padding:9px 11px;display:flex;justify-content:space-between;align-items:center;font-weight:800;color:#fff;font-size:13px}
.kh.g{background:#16a34a}.kh.o{background:#d97706}.kh.rr{background:#dc2626}
.ksub{padding:6px 11px;font-size:10.5px;color:var(--mu);border-bottom:1px solid var(--bd);display:flex;justify-content:space-between}
.ki{padding:7px 11px;border-bottom:1px solid var(--bd);font-weight:600}
.ki b{color:var(--ac);margin-right:5px}
.ki small{display:block;color:var(--warn);font-size:10.5px;font-weight:600}
.kb{margin:8px;padding:9px;text-align:center;border-radius:calc(var(--r)*.7);background:var(--ac);color:var(--actx);font-weight:800;font-size:12px}
.rup{flex:none;display:flex;align-items:center;gap:10px;padding:9px 14px;border-radius:var(--r);background:rgba(239,68,68,.14);border:1px solid rgba(239,68,68,.45);font-size:12px;font-weight:600}
.rup b{color:var(--bad)}

/* PAY */
.py{flex:1;display:flex;gap:12px;padding:12px;min-height:0}
.pc{background:var(--sf);border:1px solid var(--bd);border-radius:var(--r);padding:12px;display:flex;flex-direction:column;gap:7px;box-shadow:var(--sh)}
.pc h4{margin:0 0 3px;font-family:var(--hf);font-size:14px}
.due{text-align:center;padding:8px 0}
.due small{display:block;color:var(--mu);font-size:11px;font-weight:600}
.due b{font-size:34px;font-family:var(--hf);color:var(--ac);letter-spacing:-.5px}
.mt{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}
.mt div{padding:11px 4px;border-radius:calc(var(--r)*.8);text-align:center;font-weight:800;font-size:11.5px;color:#fff;line-height:1.2}
.mt div small{display:block;font-weight:600;font-size:9px;opacity:.85}
.mt div.sel{outline:3px solid var(--tx);outline-offset:2px}
.spl{display:flex;justify-content:space-between;align-items:center;padding:8px 10px;border-radius:calc(var(--r)*.7);background:var(--sf2);font-weight:600;font-size:12px}
.spl b{font-size:13px}
.spl.rest{background:transparent;border:2px dashed var(--ac);color:var(--ac)}
.kp2{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}
.kp2 div{padding:11px 0;text-align:center;border-radius:calc(var(--r)*.6);background:var(--sf2);font-weight:800;font-size:15px}
.qr{width:112px;height:112px;margin:2px auto;border-radius:10px;background:#fff;padding:7px;display:grid;grid-template-columns:repeat(9,1fr);grid-template-rows:repeat(9,1fr);gap:1.5px}
.qr i{background:#111;border-radius:1px}.qr i.w{background:transparent}

/* DASH */
.db{flex:1;padding:12px;display:flex;flex-direction:column;gap:10px;min-height:0}
.kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;flex:none}
.kp{background:var(--sf);border:1px solid var(--bd);border-radius:var(--r);padding:11px 13px;box-shadow:var(--sh)}
.kp small{color:var(--mu);font-weight:600;font-size:11px}
.kp b{display:block;font-size:22px;font-family:var(--hf);margin:2px 0}
.kp span{font-size:11px;font-weight:700;color:var(--ok)}
.rw{display:flex;gap:10px;min-height:0}
.card{background:var(--sf);border:1px solid var(--bd);border-radius:var(--r);padding:12px 14px;box-shadow:var(--sh);display:flex;flex-direction:column;gap:6px;min-width:0}
.card h4{margin:0;font-family:var(--hf);font-size:13.5px;display:flex;justify-content:space-between}
.card h4 span{font-family:var(--ff);font-size:10.5px;color:var(--mu);font-weight:600}
.bars{display:flex;align-items:flex-end;gap:8px;height:120px;margin-top:6px}
.bars div{flex:1;border-radius:6px 6px 0 0;background:linear-gradient(var(--ac),var(--ac2));opacity:.85}
.bars div.pk{opacity:1;box-shadow:0 0 0 2px var(--ac2)}
.bl{display:flex;gap:8px;font-size:9.5px;color:var(--mu);text-align:center}
.bl span{flex:1}
.dnw{display:flex;gap:14px;align-items:center;margin-top:4px}
.dn{width:112px;height:112px;border-radius:50%;display:flex;align-items:center;justify-content:center;flex:none}
.dn i{width:72px;height:72px;border-radius:50%;background:var(--sf);display:flex;flex-direction:column;align-items:center;justify-content:center;font-style:normal;font-weight:800;font-size:13px}
.dn i small{font-weight:600;color:var(--mu);font-size:9px}
.lgd{display:flex;flex-direction:column;gap:5px;font-size:11px;font-weight:600}
.lgd div{display:flex;align-items:center;gap:6px}
.lgd i{width:9px;height:9px;border-radius:3px;display:inline-block}
.lst{display:flex;flex-direction:column;gap:5px;font-size:11.5px}
.lst div{display:flex;justify-content:space-between;align-items:center;padding:5px 0;border-bottom:1px dashed var(--bd)}
.lst div b{color:var(--ac)}
.al{padding:7px 9px;border-radius:calc(var(--r)*.6);font-size:11px;font-weight:600;background:rgba(245,158,11,.15);border-left:3px solid var(--warn)}
.al.r{background:rgba(239,68,68,.14);border-color:var(--bad)}
.al.g{background:rgba(34,197,94,.14);border-color:var(--ok)}

/* ---------- SHOT FRAME ---------- */
.shot{width:calc(1024px*var(--s));height:calc(640px*var(--s));overflow:hidden;border-radius:calc(14px*var(--s)*1.6);position:relative;box-shadow:0 10px 30px rgba(15,23,42,.28),0 0 0 calc(5px*var(--s)*1.6) #0f172a;flex:none}
.shot .scr{transform:scale(var(--s));transform-origin:top left;position:absolute;top:0;left:0}

/* ---------- PAGES ---------- */
.pg{width:297mm;height:210mm;padding:10mm 11mm;position:relative;overflow:hidden;page-break-after:always;background:#fff;display:flex;flex-direction:column}
.pg:last-child{page-break-after:auto}
.cover{background:linear-gradient(140deg,#050b18 0%,#0b1f3a 55%,#0b3b33 100%);color:#fff;padding:14mm 16mm;justify-content:space-between}
.cover:before{content:"";position:absolute;top:-120px;right:-90px;width:560px;height:560px;border-radius:50%;background:radial-gradient(circle,rgba(16,185,129,.28),transparent 68%)}
.cover:after{content:"";position:absolute;bottom:-160px;left:-120px;width:520px;height:520px;border-radius:50%;background:radial-gradient(circle,rgba(168,85,247,.22),transparent 68%)}
.cover>*{position:relative;z-index:2}
.cv-top{display:flex;justify-content:space-between;align-items:center;font-size:11px;color:#94a3b8;border-bottom:1px solid rgba(255,255,255,.14);padding-bottom:10px}
.cv-top b{color:#fff;font-size:14px;letter-spacing:.5px}
.cv-tag{display:inline-block;padding:5px 13px;border-radius:6px;background:rgba(16,185,129,.18);border:1px solid #34d399;color:#6ee7b7;font-weight:700;font-size:10.5px;letter-spacing:1.6px;text-transform:uppercase}
.cv-h{font-size:40px;line-height:1.08;font-weight:900;margin:14px 0 12px;letter-spacing:-1px}
.cv-h span{background:linear-gradient(90deg,#34d399,#fbbf24);-webkit-background-clip:text;background-clip:text;color:transparent}
.cv-p{font-size:14px;color:#cbd5e1;max-width:620px;line-height:1.5}
.cv-shots{display:flex;gap:22px;align-items:flex-end;justify-content:center;margin:6px 0}
.cv-bot{display:flex;justify-content:space-between;align-items:center;border-top:1px solid rgba(255,255,255,.14);padding-top:12px}
.cv-cl small{display:block;color:#94a3b8;font-size:9.5px;text-transform:uppercase;letter-spacing:1.2px;font-weight:600}
.cv-cl b{font-size:17px;color:#fbbf24}
.cv-stat{display:flex;gap:26px}
.cv-stat div{text-align:center}
.cv-stat b{display:block;font-size:24px;color:#34d399;font-weight:900}
.cv-stat span{font-size:10px;color:#94a3b8}

.ph{display:flex;align-items:center;gap:14px;margin-bottom:10px;flex:none}
.pn{background:#0f172a;color:#fff;font-weight:800;font-size:11px;letter-spacing:1.5px;padding:8px 13px;border-radius:8px}
.ph h2{margin:0;font-size:23px;font-weight:900;letter-spacing:-.4px;line-height:1.1}
.ph p{margin:2px 0 0;color:#64748b;font-size:12px;font-weight:500}
.sw{margin-left:auto;display:flex;gap:7px}
.sw div{display:flex;flex-direction:column;align-items:center;gap:3px;font-size:8.5px;color:#64748b;font-weight:600}
.sw i{width:34px;height:34px;border-radius:50%;border:2px solid #fff;box-shadow:0 0 0 1px #cbd5e1;display:block}
.heroRow{display:flex;gap:16px;align-items:flex-start;flex:none}
.cap{margin-top:7px;font-size:10.5px;font-weight:700;color:#334155}
.cap span{color:#10b981;margin-right:5px}
.side{flex:1;display:flex;flex-direction:column;gap:9px}
.sd{border:1px solid #e2e8f0;background:#f8fafc;border-radius:10px;padding:10px 12px}
.sd h5{margin:0 0 5px;font-size:9.5px;letter-spacing:1.2px;text-transform:uppercase;color:#10b981;font-weight:800}
.sd p{margin:0;font-size:11px;color:#334155;line-height:1.4}
.pal{display:flex;flex-direction:column;gap:5px}
.pal div{display:flex;align-items:center;gap:8px;font-size:10.5px;font-weight:600}
.pal i{width:22px;height:22px;border-radius:6px;box-shadow:0 0 0 1px #cbd5e1;display:block}
.pal code{margin-left:auto;color:#64748b;font-size:9.5px}
.stars{color:#f59e0b;letter-spacing:1px}
.cards3{display:grid;grid-template-columns:1fr 1fr 1.15fr;gap:12px;margin-top:12px;flex:none}
.cd{border:1px solid #e2e8f0;border-radius:10px;padding:11px 14px;background:#fff;border-top:3px solid #10b981}
.cd:nth-child(2){border-top-color:#f59e0b}.cd:nth-child(3){border-top-color:#6366f1}
.cd h5{margin:0 0 5px;font-size:11px;font-weight:800;color:#0f172a}
.cd p{margin:0;font-size:11px;color:#475569;line-height:1.45}
.pfoot{position:absolute;left:11mm;right:11mm;bottom:5mm;display:flex;justify-content:space-between;font-size:8.5px;color:#94a3b8;font-weight:600;border-top:1px solid #e2e8f0;padding-top:4px}
.g22{display:grid;grid-template-columns:1fr 1fr;gap:12px 22px;justify-content:center;justify-items:center;flex:none}
.g22>div{display:flex;flex-direction:column;align-items:flex-start}
.pt{display:flex;align-items:baseline;justify-content:space-between;margin-bottom:10px;flex:none}
.pt h2{margin:0;font-size:26px;font-weight:900;letter-spacing:-.5px}
.pt p{margin:0;color:#64748b;font-size:12px;max-width:520px;text-align:right}
.mg{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;flex:none}
.mc{border:1px solid #e2e8f0;border-radius:12px;padding:10px 12px;background:#f8fafc;display:flex;flex-direction:column;gap:8px;align-items:center}.mc .t{width:100%}
.mc .t{display:flex;justify-content:space-between;align-items:center}
.mc .t b{font-size:13px}
.mc .t span{font-size:9.5px;font-weight:800;color:#fff;background:#0f172a;border-radius:6px;padding:3px 8px;letter-spacing:1px}
.mc p{margin:0;font-size:10.5px;color:#64748b}
.how{margin-top:12px;display:grid;grid-template-columns:repeat(5,1fr);gap:10px;flex:none}
.how div{background:#0f172a;color:#fff;border-radius:10px;padding:9px 11px;font-size:10.5px}
.how b{display:block;color:#34d399;font-size:11.5px;margin-bottom:2px}
table.cmp{width:100%;border-collapse:collapse;font-size:11px;margin-top:2px}
table.cmp th{background:#0f172a;color:#fff;text-align:left;padding:8px 9px;font-size:10px;letter-spacing:.5px}
table.cmp td{padding:8px 9px;border-bottom:1px solid #e2e8f0;vertical-align:middle}
table.cmp tr:nth-child(even) td{background:#f8fafc}
.mb{display:inline-block;width:14px;height:14px;border-radius:50%;margin-right:7px;vertical-align:middle;box-shadow:0 0 0 1px #cbd5e1}
.box{display:inline-block;width:16px;height:16px;border:2px solid #0f172a;border-radius:4px}
.note{margin-top:12px;display:grid;grid-template-columns:1.4fr 1fr;gap:12px;flex:none}
.nb{border:1px solid #a7f3d0;background:#ecfdf5;border-radius:10px;padding:11px 14px;font-size:11px;color:#065f46;line-height:1.5}
.nb b{color:#064e3b}
.sg{border:2px solid #0f172a;border-radius:10px;padding:11px 14px;font-size:10.5px}
.sg b{display:block;margin-bottom:12px}
"""


# ---------------------------------------------------------------- SCREEN BUILDERS
def vars_style(v):
    return ";".join(f"--{k}:{val}" for k, val in v.items())


def topbar(mid, t):
    bname = t.get("brand_name", "Le Sultan")
    bsub = t.get("brand_sub", "Caisse 1 · Nouakchott")
    return (f'<div class="tb"><div class="brand"><span class="logo">{t["logo"]}</span><b>{bname}</b>'
            f'<i>{bsub}</i></div>{mid}'
            f'<div class="st"><span class="dot"></span>LAN <span class="dot b"></span>Cloud '
            f'<span class="av">A</span><span class="lang">عربي</span></div></div>')


MODES = '<div class="modes"><span class="on">🍽 Sur place</span><span>🥡 Emporter</span><span>🛵 Livraison</span></div>'

PRODUCTS = [
    ("🍖", "Méchoui Royal", "مشوي ملكي", "450", "hot", ""),
    ("🌯", "Chawarma Arabe", "شاورما عربي", "220", "", ""),
    ("🍕", "Pizza Reine", "بيتزا ملكة", "350", "", ""),
    ("🍔", "Burger Smash", "برغر سماش", "260", "hot", ""),
    ("🌮", "Tacos XL", "تاكوس", "280", "", ""),
    ("🐟", "Poisson Braisé", "سمك مشوي", "550", "", "off"),
    ("🍹", "Jus Bissap", "عصير كركديه", "100", "", ""),
    ("🍵", "Thé à la menthe", "أتاي", "50", "", ""),
    ("🥗", "Salade Fraîche", "سلطة", "120", "", ""),
]
CATS = [("🔥", "Grillades"), ("🍕", "Pizzas"), ("🍔", "Burgers"), ("🥤", "Boissons"), ("🍰", "Desserts"), ("⭐", "Menus")]


def tiles(t=None):
    prods = t.get("prods", PRODUCTS) if t else PRODUCTS
    out = ""
    for em, n, ar, p, hot, off in prods:
        tag = ""
        if off:
            tag = '<span class="tag">ÉPUISÉ</span>'
        elif hot:
            tag = '<span class="hot">TOP</span>'
        out += (f'<div class="tile {off}">{tag}<div class="em">{em}</div>'
                f'<div><div class="nm">{n}</div><div class="ar">{ar}</div></div>'
                f'<div class="pr">{p} MRU</div></div>')
    return out


def s_pos(t):
    cat_list = t.get("cats", CATS)
    bnr = ""
    if t.get("banner"):
        bnr = f'<div style="margin:8px 14px 0;padding:6px 12px;border-radius:8px;background:var(--sf2);border:1px solid var(--ac);font-size:11px;font-weight:700;color:var(--tx)">{t["banner"]}</div>'
    if t["cat"] == "rail":
        cats = "".join(f'<div class="{"on" if i == 0 else ""}"><b>{e}</b>{n}</div>' for i, (e, n) in enumerate(cat_list))
        main = f'<div class="pm"><div class="rail">{cats}</div><div style="flex:1;display:flex;flex-direction:column;min-width:0">{bnr}<div class="grid">{tiles(t)}</div></div></div>'
    else:
        cats = "".join(f'<span class="{"on" if i == 0 else ""}">{e} {n}</span>' for i, (e, n) in enumerate(cat_list))
        main = f'<div class="pm col"><div class="tabs">{cats}</div>{bnr}<div class="grid">{tiles(t)}</div></div>'
    p1 = t.get("prods", PRODUCTS)[0]
    p2 = t.get("prods", PRODUCTS)[1]
    p3 = t.get("prods", PRODUCTS)[3]
    ticket = (
        f'<div class="tk"><div class="tkh"><div><b>Table T-08</b><div class="ar" style="margin-top:1px">{t.get("brand_sub", "Terrasse · 4 couverts")}</div></div>'
        '<span class="chip ac">Actif</span></div>'
        f'<div class="ln"><div><span class="qty">2</span>{p1[1]}<small>{p1[2]} · Option spéciale</small></div><b>900</b></div>'
        f'<div class="ln"><div><span class="qty">1</span>{p2[1]}<small>{p2[2]}</small></div><b>410</b></div>'
        f'<div class="ln"><div><span class="qty">3</span>{p3[1]}</div><b>300</b></div>'
        '<div class="sp"></div>'
        '<div class="tot"><div><span>Dont TVA 16 %</span><span>222 MRU</span></div>'
        '<div class="big"><span>Total</span><span>1 610 MRU</span></div></div>'
        '<div class="acts"><span>👨‍🍳 Cuisine</span><span>✂️ Diviser</span><span>🏷 Remise</span></div>'
        '<div class="pays"><span style="background:#059669">Cash</span><span style="background:#d97706">Bankily</span>'
        '<span style="background:#2563eb">Masrivi</span><span style="background:#7c3aed">Mixte</span></div>'
        '<div class="cta">ENCAISSER · 1 610 MRU</div></div>'
    )
    cls = "pos tl" if t["ticket"] == "left" else "pos"
    return f'<div class="{cls}">{main}{ticket}</div>'


def tbl(n, st, x, y, w, h, sub="", rd=False, sel=False):
    c = f"tbl s-{st}" + (" rd" if rd else "") + (" sel" if sel else "")
    return f'<div class="{c}" style="left:{x}px;top:{y}px;width:{w}px;height:{h}px"><span>{n}</span><small>{sub}</small></div>'


def s_floor(t):
    zones = ('<div class="on">Terrasse <span>12</span></div><div>Salle clim. <span>18</span></div>'
             '<div>Étage <span>10</span></div><div>Salon VIP <span>4</span></div>')
    tables = (
        tbl("T-01", "free", 30, 28, 84, 60, "4 places") + tbl("T-02", "busy", 140, 28, 84, 60, "1 240 MRU") +
        tbl("T-03", "wait", 250, 28, 84, 60, "28 min ⏱") + tbl("T-04", "free", 370, 24, 70, 70, "2 places", rd=True) +
        tbl("T-05", "busy", 36, 140, 78, 78, "860 MRU", rd=True) + tbl("T-06", "resv", 150, 140, 78, 78, "20:30", rd=True) +
        tbl("T-07", "busy", 262, 140, 130, 78, "2 350 MRU") + tbl("T-08", "bill", 424, 136, 86, 86, "1 610 MRU", rd=True, sel=True) +
        tbl("T-09", "free", 30, 252, 84, 60, "4 places") + tbl("T-10", "busy", 140, 252, 84, 60, "540 MRU") +
        tbl("T-11", "resv", 250, 252, 160, 60, "Famille · 21:00") + tbl("T-12", "free", 440, 250, 70, 70, "2 places", rd=True) +
        '<div class="deco" style="left:30px;right:30px;top:352px;height:34px">COMPTOIR · BAR · CAISSE</div>'
    )
    legend = ('<div class="lg"><span><i style="background:var(--sf2);box-shadow:0 0 0 1px var(--bd)"></i>Libre</span>'
              '<span><i style="background:#3b82f6"></i>Occupée</span><span><i style="background:#f59e0b"></i>Attente &gt; 20 min</span>'
              '<span><i style="background:#a855f7"></i>Addition</span><span><i style="background:var(--ac2)"></i>Réservée</span></div>')
    panel = ('<div class="dp"><div><span class="chip ac">ADDITION IMPRIMÉE</span></div><h3>Table T-08</h3>'
             '<div class="ar">Terrasse · 4 couverts</div>'
             '<div><div class="row"><span>Serveur</span><b>Ahmed</b></div><div class="row"><span>Durée</span><b>42 min</b></div>'
             '<div class="row"><span>Articles</span><b>6</b></div><div class="row"><span>Total</span><b>1 610 MRU</b></div></div>'
             '<div class="sp"></div><div class="btn">↔ Transférer la table</div><div class="btn">⊕ Fusionner</div>'
             '<div class="btn ac">💳 Encaisser</div></div>')
    mid = '<div class="mid-title">Plan de salle</div>'
    return (f'<div class="fp"><div class="zn">{zones}</div><div class="cv">{tables}{legend}</div>{panel}</div>', mid)


def kt(cls, num, timer, ctx, where, items, btn):
    its = "".join(f'<div class="ki"><b>{q}×</b>{n}{("<small>" + nt + "</small>") if nt else ""}</div>' for q, n, nt in items)
    return (f'<div class="kt"><div class="kh {cls}"><span>#{num}</span><span>⏱ {timer}</span></div>'
            f'<div class="ksub"><span>{ctx}</span><span>{where}</span></div>{its}<div class="sp"></div>'
            f'<div class="kb">{btn}</div></div>')


def s_kds(t):
    f = ('<div class="flt"><span class="on">Tous</span><span>🔥 Grill</span><span>🍕 Pizza</span><span>🍹 Bar</span>'
         '<span>💨 Chicha</span><span class="r">6 en cours · temps moyen 11 min</span></div>')
    cols = (
        kt("g", "41", "04:10", "Sur place", "T-03", [("1", "Chawarma Arabe", ""), ("2", "Jus Bissap", "")], "✔ PRÊT") +
        kt("o", "42", "12:30", "Sur place", "T-08", [("2", "Méchoui Royal", "Sans oignon"), ("1", "Pizza Reine", "+ Mozzarella")], "✔ PRÊT") +
        kt("rr", "43", "19:45", "🛵 Livraison", "Ksar", [("2", "Burger Smash", "Bien cuit"), ("1", "Tacos XL", ""), ("2", "Thé menthe", "")], "✔ PRÊT") +
        kt("g", "44", "01:05", "🥡 Emporter", "N° 44", [("3", "Chawarma Arabe", "Sans sauce")], "✔ PRÊT")
    )
    rup = '<div class="rup"><b>⛔ RUPTURE (86)</b> Poisson Braisé — bloqué sur toutes les caisses, tablettes et menus QR</div>'
    mid = '<div class="mid-title">Écran Cuisine · KDS</div>'
    return f'<div class="kd">{f}<div class="kc">{cols}</div>{rup}</div>', mid


def qr_html():
    pat = ("111111101010111111100000101001000001101110101101010111011010111010111011011010110101110110000010100101000001"
           "111111101010111111")
    cells = ""
    rows = [
        "111101111", "100101001", "101100101", "100101101", "111100111", "000011100", "110101011", "010110101", "111010110"
    ]
    for r in rows:
        for c in r:
            cells += '<i></i>' if c == "1" else '<i class="w"></i>'
    return f'<div class="qr">{cells}</div>'


def s_pay(t):
    left = ('<div class="pc" style="width:240px"><h4>Résumé · T-08</h4>'
            '<div class="ln"><div>2× Méchoui Royal</div><b>900</b></div><div class="ln"><div>1× Pizza Reine</div><b>410</b></div>'
            '<div class="ln"><div>3× Jus Bissap</div><b>300</b></div><div class="sp"></div>'
            '<div class="tot"><div><span>Sous-total HT</span><span>1 388</span></div><div><span>TVA 16 %</span><span>222</span></div>'
            '<div class="big"><span>Total</span><span>1 610</span></div></div></div>')
    methods = [("#059669", "Cash", "MRU", ""), ("#d97706", "Bankily", "BPM", "sel"), ("#2563eb", "Masrivi", "BMCI", ""),
               ("#0d9488", "Sedad", "BCI", ""), ("#7c3aed", "Bimbank", "", ""), ("#e11d48", "Click", "", ""),
               ("#475569", "Carte", "GIMTEL", ""), ("#a16207", "Karni", "Crédit", "")]
    mt = "".join(f'<div class="{s}" style="background:{c}">{n}<small>{sub}</small></div>' for c, n, sub, s in methods)
    center = ('<div class="pc" style="width:420px"><h4>Paiement mixte (Split)</h4>'
              '<div class="due"><small>RESTE À PAYER</small><b>110 MRU</b></div>'
              f'<div class="mt">{mt}</div>'
              '<div class="spl"><span>✔ Bankily · réf. •• 4821</span><b>1 000 MRU</b></div>'
              '<div class="spl"><span>✔ Cash</span><b>500 MRU</b></div>'
              '<div class="spl rest"><span>Remise manager (PIN)</span><b>− 100 MRU</b></div></div>')
    right = ('<div class="pc" style="flex:1"><h4>Bankily · QR Marchand</h4>'
             f'{qr_html()}<div class="ar" style="text-align:center">Scanner pour payer 1 000 MRU</div>'
             '<div class="kp2"><div>1</div><div>2</div><div>3</div><div>4</div><div>5</div><div>6</div><div>7</div><div>8</div><div>9</div></div>'
             '<div class="cta" style="padding:10px;font-size:13px">VALIDER LE PAIEMENT</div></div>')
    mid = '<div class="mid-title">Encaissement</div>'
    return f'<div class="py">{left}{center}{right}</div>', mid


def s_dash(t):
    k = ('<div class="kpis"><div class="kp"><small>CA du jour (TTC)</small><b>148 500</b><span>▲ +14 % vs mardi dernier</span></div>'
         '<div class="kp"><small>Commandes</small><b>214</b><span>▲ +9 %</span></div>'
         '<div class="kp"><small>Panier moyen</small><b>694 MRU</b><span>▲ +4 %</span></div>'
         '<div class="kp"><small>Marge brute</small><b>65 %</b><span>Food cost 35 %</span></div></div>')
    vals = [18, 30, 52, 88, 70, 45, 38, 55, 80, 100, 72, 40]
    bars = "".join(f'<div class="{"pk" if v == 100 else ""}" style="height:{v}%"></div>' for v in vals)
    hrs = "".join(f"<span>{h}h</span>" for h in range(10, 22))
    chart = (f'<div class="card" style="flex:1"><h4>Chiffre d\'affaires par heure <span>Aujourd\'hui</span></h4>'
             f'<div class="bars">{bars}</div><div class="bl">{hrs}</div></div>')
    donut = ('<div class="card" style="width:300px"><h4>Modes de paiement <span>Temps réel</span></h4><div class="dnw">'
             '<div class="dn" style="background:conic-gradient(#10b981 0 42%,#3b82f6 42% 78%,#f59e0b 78% 91%,#94a3b8 91% 100%)">'
             '<i>148 500<small>MRU</small></i></div><div class="lgd">'
             '<div><i style="background:#10b981"></i>Cash 42 %</div><div><i style="background:#3b82f6"></i>Bankily 36 %</div>'
             '<div><i style="background:#f59e0b"></i>Masrivi 13 %</div><div><i style="background:#94a3b8"></i>Autres 9 %</div></div></div></div>')
    top = ('<div class="card" style="flex:1"><h4>Top plats <span>Ventes</span></h4><div class="lst">'
           '<div><span>🍖 Méchoui Royal</span><b>62</b></div><div><span>🌯 Chawarma Arabe</span><b>55</b></div>'
           '<div><span>🍔 Burger Smash</span><b>41</b></div><div><span>🍕 Pizza Reine</span><b>33</b></div></div></div>')
    alerts = ('<div class="card" style="flex:1"><h4>Alertes IA <span>2 nouvelles</span></h4>'
              '<div class="al r">⚠ 2 annulations après addition — Caissier #2</div>'
              '<div class="al">📈 Viande +12 % chez le fournisseur</div><div class="al g">✔ Écart de stock : 0 kg aujourd\'hui</div></div>')
    caisses = ('<div class="card" style="flex:1"><h4>Parc de caisses <span>LAN</span></h4><div class="lst">'
               '<div><span>🖥 Caisse 1 — Master</span><b style="color:var(--ok)">● En ligne</b></div>'
               '<div><span>🖥 Caisse 2 — Terrasse</span><b style="color:var(--ok)">● En ligne</b></div>'
               '<div><span>📱 3 tablettes serveurs</span><b style="color:var(--ok)">● OK</b></div>'
               '<div><span>🍳 KDS Cuisine</span><b style="color:var(--ok)">● OK</b></div></div></div>')
    mid = '<div class="mid-title">Tableau de bord</div>'
    return f'<div class="db">{k}<div class="rw">{chart}{donut}</div><div class="rw" style="flex:1">{top}{alerts}{caisses}</div></div>', mid


SCREENS = [
    ("Caisse tactile · vente en cours", None),
    ("Plan de salle interactif", s_floor),
    ("Écran cuisine KDS", s_kds),
    ("Paiement mixte · Bankily + Cash", s_pay),
    ("Tableau de bord propriétaire", s_dash),
]


def screen(t, idx):
    st = vars_style(t["v"])
    if idx == 0:
        body = s_pos(t)
        mid = MODES
    else:
        body, mid = SCREENS[idx][1](t)
    return f'<div class="scr" style="{st}">{topbar(mid, t)}{body}</div>'


def shot(t, idx, s):
    return f'<div class="shot" style="--s:{s}">{screen(t, idx)}</div>'


# ---------------------------------------------------------------- PAGES
def stars(n):
    return '<span class="stars">' + "★" * n + "☆" * (5 - n) + "</span>"


def page_cover():
    return f"""
<div class="pg cover">
  <div class="cv-top"><b>FULL-TEK POS · SUITE CLOUD &amp; EDGE (Resto · Market · Pharma — V3.0)</b><span>Réf. MAQ-UI-2026-V3 &nbsp;•&nbsp; Novembre 2026</span></div>
  <div>
    <span class="cv-tag">Catalogue intégral des interfaces &amp; écosystème 360°</span>
    <div class="cv-h">12 modèles de <span>caisse &amp; points de vente</span><br>+ 8 modules Pro (Investisseur, Market, Mobile &amp; Kiosk)</div>
    <div class="cv-p">Douze directions artistiques complètes (5 écrans par modèle = 60 écrans) couvrant Restauration, Khaima Mauritanienne, Supermarché/Pesée, Pâtisserie/Glacier, Street-Food/Pizzeria, iPad Minimal et Hôtel Resort + 8 écrans Écosystème 360° (Console Super-Admin MRR de M. Taha Chouaib, Kiosk, TV, App Serveur, Menu QR + WhatsApp, App Livreur GPS &amp; Ticket 80mm FR/AR).</div>
  </div>
  <div class="cv-shots">{shot(THEMES[0], 0, .30)}{shot(THEMES[6], 0, .30)}{shot(THEMES[7], 0, .30)}</div>
  <div class="cv-bot">
    <div class="cv-cl"><small>Préparé pour</small><b>M. Taha Chouaib</b></div>
    <div class="cv-stat"><div><b>12</b><span>Modèles</span></div><div><b>68</b><span>Écrans HD</span></div><div><b>FR / AR</b><span>Bilingue</span></div><div><b>Resto + Market + Hôtel</b><span>Multi-Secteurs 360°</span></div></div>
  </div>
</div>"""


def page_intro(subset, pageno, title_suffix):
    cards = ""
    for t in subset:
        cards += (f'<div class="mc"><div class="t"><b>{t["name"]}</b><span>MODÈLE {t["id"]:02d}</span></div>'
                  f'{shot(t, 0, .30)}<p>{t["tag"]}</p></div>')
    how = ("".join(f'<div><b>Écran {i + 1}</b>{n}</div>' for i, (n, _) in enumerate(SCREENS)))
    return f"""
<div class="pg">
  <div class="pt"><h2>Vue d'ensemble — {title_suffix}</h2><p>Chaque modèle possède sa propre identité visuelle et ses raccourcis métiers dédiés (3 clics maximum par encaissement).</p></div>
  <div class="mg">{cards}</div>
  <div class="how">{how}</div>
  <div class="pfoot"><span>CONFIDENTIEL — Catalogue 12 Modèles d'Interfaces SaaS POS (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def page_hero(t, pageno):
    sw = "".join(f'<div><i style="background:{h}"></i>{n}</div>' for n, h in t["palette"])
    pal = "".join(f'<div><i style="background:{h}"></i>{n}<code>{h}</code></div>' for n, h in t["palette"])
    return f"""
<div class="pg">
  <div class="ph"><div class="pn">MODÈLE {t["id"]:02d}</div><div><h2>{t["name"]}</h2><p>{t["tag"]}</p></div><div class="sw">{sw}</div></div>
  <div class="heroRow">
    <div>{shot(t, 0, .77)}<div class="cap"><span>●</span>Écran 1 — Caisse tactile · vente en cours ({t.get("brand_name", "Le Sultan")})</div></div>
    <div class="side">
      <div class="sd"><h5>Palette</h5><div class="pal">{pal}</div></div>
      <div class="sd"><h5>Typographie &amp; ambiance</h5><p><b>{t["typo"]}</b><br>{t["mood"]}</p></div>
      <div class="sd"><h5>Évaluation</h5><p>Rapidité caissier &nbsp;{stars(t["vitesse"])}<br>Effet premium &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;{stars(t["premium"])}<br>Mode d'affichage &nbsp;<b>{t["mode"]}</b></p></div>
    </div>
  </div>
  <div class="cards3">
    <div class="cd"><h5>Philosophie du design</h5><p>{t["philo"]}</p></div>
    <div class="cd"><h5>Idéal pour</h5><p>{t["ideal"]}</p></div>
    <div class="cd"><h5>Points forts</h5><p>{t["atouts"]}</p></div>
  </div>
  <div class="pfoot"><span>CONFIDENTIEL — Catalogue 12 Modèles d'Interfaces SaaS POS (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def page_screens(t, pageno):
    cells = ""
    for i in range(1, 5):
        cells += f'<div>{shot(t, i, .47)}<div class="cap"><span>●</span>Écran {i + 1} — {SCREENS[i][0]}</div></div>'
    return f"""
<div class="pg">
  <div class="ph" style="margin-bottom:8px"><div class="pn">MODÈLE {t["id"]:02d}</div><div><h2 style="font-size:20px">{t["name"]} — écrans 2 à 5</h2></div></div>
  <div class="g22">{cells}</div>
  <div class="pfoot"><span>CONFIDENTIEL — Catalogue 12 Modèles d'Interfaces SaaS POS (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def s_superadmin():
    st = vars_style(THEMES[0]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">FT</div><div><b>FULL-TEK CLOUD · CONSOLE INVESTISSEUR</b>'
           '<small>Portail Super-Admin SaaS — M. Taha Chouaib</small></div></div>'
           '<div class="mid-title">Gestion du Parc National &amp; Revenus Récurrents (MRR)</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>CLOUD + EDGE SYNC ACTIF</div>'
           '<div class="usr"><div class="av">TC</div><b>Taha Chouaib</b></div></div></div>')
    k = ('<div class="kpis">'
         '<div class="kp"><small>MRR (Revenu Mensuel Récurrent)</small><b>425 000 MRU</b><span>▲ +18 % ce mois · ARR : 5,1M MRU</span></div>'
         '<div class="kp"><small>Établissements Abonnés</small><b>54 actifs</b><span>38 Restaurants · 16 Markets</span></div>'
         '<div class="kp"><small>Terminaux &amp; Caisses déployés</small><b>186 caisses</b><span>Nouakchott · Nouadhibou · Atar</span></div>'
         '<div class="kp"><small>Taux de recouvrement</small><b>98,2 %</b><span>Licences Offline protégées</span></div></div>')
    rows = (
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:7px 10px;background:var(--sf2);border-radius:6px;font-weight:700;font-size:10px;color:var(--mu)">'
        '<span>ÉTABLISSEMENT CLIENT</span><span>SECTEUR / VILLE</span><span>FORMULE</span><span>MRR / MOIS</span><span>STATUT &amp; CONTRÔLE</span></div>'
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:8px 10px;border-bottom:1px solid var(--bd);font-size:11px;align-items:center">'
        '<b>🍖 Le Sultan Lounge &amp; Grill</b><span>Resto · Tevragh Zeina</span><span>Enterprise (4 caisses)</span><b>12 000 MRU</b><span style="color:var(--ok);font-weight:700">● Actif · Lease 28j</span></div>'
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:8px 10px;border-bottom:1px solid var(--bd);font-size:11px;align-items:center">'
        '<b>🛒 Supermarché Al-Baraka</b><span>Market · Ksar</span><span>Market Pro (3 caisses)</span><b>9 500 MRU</b><span style="color:var(--ok);font-weight:700">● Actif · Lease 24j</span></div>'
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:8px 10px;border-bottom:1px solid var(--bd);font-size:11px;align-items:center">'
        '<b>🍔 Sahara Smash Burger</b><span>Fast-Food · Ilot K</span><span>Pro + Kiosk (3 postes)</span><b>8 500 MRU</b><span style="color:var(--wa);font-weight:700">⏳ Échéance J-2 (Relance WA)</span></div>'
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:8px 10px;border-bottom:1px solid var(--bd);font-size:11px;align-items:center">'
        '<b>🥐 Boulangerie Pâtisserie Délice</b><span>Boulangerie · Nouadhibou</span><span>Pro (2 caisses + pesée)</span><b>6 500 MRU</b><span style="color:var(--ok);font-weight:700">● Actif · Lease 19j</span></div>'
        '<div style="display:grid;grid-template-columns:2fr 1.1fr 1fr 1fr 1.2fr;padding:8px 10px;font-size:11px;align-items:center">'
        '<b>☕ Café Oasis Marina</b><span>Café · Tevragh Zeina</span><span>Starter (1 caisse)</span><b>4 500 MRU</b><span style="color:var(--er);font-weight:700">🔒 Suspendu (Impayé) · Débloquer</span></div>'
    )
    body = (f'<div class="db">{k}<div class="rw" style="flex:1">'
            f'<div class="card" style="flex:2.2"><h4>Parc Clients SaaS en Mauritanie <span>Contrôle des licences à distance</span></h4>{rows}</div>'
            '<div class="card" style="flex:1"><h4>Sécurité &amp; Anti-Piratage <span>Mode Offline</span></h4>'
            '<div class="al g">🔐 <b>Jeton Cryptographique 30j</b> : chaque caisse locale vérifie sa signature matérielle.</div>'
            '<div class="al">📲 <b>Activation par Code SMS/WhatsApp</b> si le commerce est hors-ligne.</div>'
            '<div class="al r">⚡ <b>Nouvelle inscription</b> : +3 demandes de démo aujourd\'hui à Nouakchott.</div>'
            '<div class="cta" style="margin-top:8px;padding:9px;font-size:11px">+ CRÉER UN NOUVEAU RESTAURANT / MARKET</div></div></div></div>')
    return f'<div class="scr" style="{st}">{top}{body}</div>'


def s_market():
    st = vars_style(THEMES[5]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">M</div><div><b>AL-BARAKA MARKET · سوبرماركت البركة</b>'
           '<small>Caisse #01 · Mode Supermarché, Boucherie &amp; Pesée</small></div></div>'
           '<div class="modes"><span class="on">🛒 Détail</span><span>📦 Demi-Gros</span><span>⚖ Pesée Balance</span><span>📒 Crédit Karni</span></div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>SCANNER EAN + BALANCE COM1 OK</div></div></div>')
    scale_box = (
        '<div style="display:grid;grid-template-columns:1.2fr 1.2fr 1fr;gap:8px">'
        '<div class="card" style="background:#0f172a;color:#fff;border-color:#1e293b">'
        '<h4 style="color:#94a3b8">⚖ BALANCE ÉLECTRONIQUE (COM1) <span style="color:#22c55e">● STABLE</span></h4>'
        '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-top:4px">'
        '<div><div style="font-size:24px;font-weight:800;color:#38bdf8;font-family:\'JetBrains Mono\'">1,450 kg</div>'
        '<div style="font-size:10px;color:#cbd5e1">Viande Hachée Boeuf · لحم بقري مفروم</div></div>'
        '<div style="text-align:right"><div style="font-size:11px;color:#94a3b8">380 MRU / kg</div>'
        '<div style="font-size:18px;font-weight:800;color:#22c55e">551 MRU</div></div></div></div>'
        '<div class="card"><h4>🔍 LECTURE CODE-BARRES (EAN-13 / PLU)</h4>'
        '<div style="padding:7px 10px;background:var(--sf2);border:1.5px solid var(--ac);border-radius:7px;font-family:\'JetBrains Mono\';font-size:12px;font-weight:700">'
        '6291004582190 — Lait Nido Poudre 900g</div>'
        '<div style="display:flex;justify-content:space-between;margin-top:6px;font-size:10px;color:var(--mu)">'
        '<span>Stock rayon : <b>48 boîtes</b></span><span>Lot péremption : <b>11/2027 (FEFO OK)</b></span></div></div>'
        '<div class="card"><h4>📒 CARNET CRÉDIT CLIENT (KARNI)</h4>'
        '<div style="font-size:12px;font-weight:800">M. Sidi Ould Ahmed</div>'
        '<div style="font-size:10px;color:var(--mu);margin:3px 0">Plafond : 15 000 MRU · Solde dû : <b style="color:var(--wa)">3 200 MRU</b></div>'
        '<div style="font-size:10px;color:var(--ok);font-weight:700">✔ Autorisé à porter sur le carnet (+ SMS auto)</div></div></div>'
    )
    plu = (
        '<div class="card" style="flex:1"><h4>Raccourcis Tactiles Produits Non-Codés (Boulangerie, Fruits &amp; Légumes, Boucherie, Eau)</h4>'
        '<div style="display:grid;grid-template-columns:repeat(4,1fr);gap:7px;margin-top:4px">'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🥖 Baguette Tradition</b><div style="font-size:10px;color:var(--mu)">خبز فرنسي · Unité</div><b style="color:var(--ac)">10 MRU</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🌴 Dattes Atar (kg)</b><div style="font-size:10px;color:var(--mu)">تمر أطار · Pesée</div><b style="color:var(--ac)">250 MRU/kg</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🥩 Côtelettes Agneau</b><div style="font-size:10px;color:var(--mu)">ريش غنم · Pesée</div><b style="color:var(--ac)">420 MRU/kg</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>💧 Pack Eau Benichab x6</b><div style="font-size:10px;color:var(--mu)">مياه بنشاب · Demi-Gros</div><b style="color:var(--ac)">110 MRU</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🥔 Pommes de terre (kg)</b><div style="font-size:10px;color:var(--mu)">بطاطس · Pesée</div><b style="color:var(--ac)">45 MRU/kg</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🐪 Lait de Chamelle 1L</b><div style="font-size:10px;color:var(--mu)">لبن الإبل · Frais</div><b style="color:var(--ac)">90 MRU</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>🍃 Thé Vert Achoura 500g</b><div style="font-size:10px;color:var(--mu)">شاي أخضر · Boîte</div><b style="color:var(--ac)">180 MRU</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px"><b>⛽ Sac Riz 25 kg (Gros)</b><div style="font-size:10px;color:var(--mu)">أرز ٢٥ كغ · Gros</div><b style="color:var(--ac)">950 MRU</b></div>'
        '</div></div>'
    )
    tkt = (
        '<div class="tk" style="width:310px;border-left:1px solid var(--bd)">'
        '<div class="tkh"><div class="r"><b>Ticket Market #1084</b><span class="tag">CAISSE 1</span></div><small>Client : M. Sidi Ould Ahmed</small></div>'
        '<div class="tkl">'
        '<div class="ln"><div class="q">1</div><div class="n"><b>Viande Hachée (1,450 kg)</b><span class="ar">لحم مفروم</span></div><div class="pr">551</div></div>'
        '<div class="ln"><div class="q">2</div><div class="n"><b>Lait Nido 900g (EAN)</b><span class="ar">حليب نيدو</span></div><div class="pr">760</div></div>'
        '<div class="ln"><div class="q">5</div><div class="n"><b>Baguette Tradition</b><span class="ar">خبز</span></div><div class="pr">50</div></div>'
        '<div class="ln"><div class="q">1</div><div class="n"><b>Pack Eau Benichab x6</b><span class="ar">مياه</span></div><div class="pr">110</div></div>'
        '</div>'
        '<div class="tkf"><div class="tot"><span>TOTAL À PAYER</span><b>1 471 MRU</b></div>'
        '<div class="pb"><div class="cash">💵 Espèces</div><div class="bk">📲 Bankily</div><div class="ms">📒 Karni</div><div class="sp">⚡ Mixte</div></div>'
        '<div class="cta">ENCAISSER &amp; OUVRIR TIROIR (F12)</div></div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;flex:1;overflow:hidden"><div style="flex:1;padding:10px;display:flex;flex-direction:column;gap:8px">{scale_box}{plu}</div>{tkt}</div></div>'


def s_kiosk_cfd():
    st = vars_style(THEMES[4]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">S</div><div><b>BORNE KIOSK 27" &amp; AFFICHEUR CLIENT DOUBLE-ÉCRAN</b>'
           '<small>Expérience Libre-Service Fast-Food &amp; Écran Client Comptoir</small></div></div>'
           '<div class="mid-title">2 Interfaces Clients Synchronisées</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>PAIEMENT QR BANKILY DIRECT</div></div></div>')
    kiosk = (
        '<div class="card" style="flex:1.15;display:flex;flex-direction:column;justify-content:space-between;border:2px solid var(--ac)">'
        '<div><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">'
        '<span style="background:var(--ac);color:#fff;padding:3px 9px;border-radius:99px;font-size:10px;font-weight:800">BORNE TACTILE LIBRE-SERVICE (KIOSK)</span>'
        '<span style="font-size:11px;font-weight:700">🇫🇷 Français &nbsp;|&nbsp; 🇲🇷 العربية</span></div>'
        '<div style="font-size:15px;font-weight:800;margin-bottom:6px">Composez votre Menu · اختر وجبتك</div>'
        '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px">'
        '<div style="padding:8px;background:var(--sf2);border:1.5px solid var(--ac);border-radius:8px;text-align:center"><div style="font-size:22px">🍔</div><b style="font-size:11px">Menu Double Smash</b><div style="font-size:10px;color:var(--ac);font-weight:800">320 MRU</div></div>'
        '<div style="padding:8px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px;text-align:center"><div style="font-size:22px">🌯</div><b style="font-size:11px">Menu Tacos XL</b><div style="font-size:10px;color:var(--ac);font-weight:800">280 MRU</div></div>'
        '<div style="padding:8px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px;text-align:center"><div style="font-size:22px">🍗</div><b style="font-size:11px">Bucket Crispy x8</b><div style="font-size:10px;color:var(--ac);font-weight:800">450 MRU</div></div>'
        '</div>'
        '<div style="margin-top:8px;padding:8px;background:var(--sf2);border-radius:8px;font-size:11px">'
        '<b>Personnalisation :</b> ✔ Supplément Cheddar (+30 MRU) · ✔ Sans Oignon · ✔ Frites Maison · ✔ Jus Bissap Frais</div></div>'
        '<div style="display:flex;justify-content:space-between;align-items:center;padding-top:8px;border-top:1px solid var(--bd)">'
        '<div><small style="color:var(--mu);font-size:10px">Votre commande (Sur place)</small><div style="font-size:18px;font-weight:800">350 MRU</div></div>'
        '<div class="cta" style="padding:10px 16px;font-size:12px">PAYER PAR QR BANKILY → N° 148</div></div></div>'
    )
    cfd = (
        '<div class="card" style="flex:1;background:#0f172a;color:#f8fafc;border-color:#1e293b;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px">'
        '<span style="background:#10b981;color:#052e16;padding:3px 9px;border-radius:99px;font-size:10px;font-weight:800">ÉCRAN CLIENT COMPTOIR (2e ÉCRAN CAISSE)</span>'
        '<span style="font-size:11px;color:#94a3b8">مرحبا بكم · Bienvenue</span></div>'
        '<div style="display:flex;gap:10px;align-items:center">'
        '<div style="flex:1;font-size:11px">'
        '<div style="padding:5px 0;border-bottom:1px solid #1e293b;display:flex;justify-content:space-between"><span>1x Méchoui Royal</span><b>450 MRU</b></div>'
        '<div style="padding:5px 0;border-bottom:1px solid #1e293b;display:flex;justify-content:space-between"><span>2x Chawarma Arabe</span><b>360 MRU</b></div>'
        '<div style="padding:5px 0;border-bottom:1px solid #1e293b;display:flex;justify-content:space-between"><span>2x Jus Bissap</span><b>120 MRU</b></div>'
        '<div style="padding:8px 0;display:flex;justify-content:space-between;font-size:16px;font-weight:800;color:#22c55e"><span>NET À PAYER</span><span>930 MRU</span></div>'
        '</div>'
        f'<div style="width:130px;text-align:center">{qr_html()}<div style="font-size:9px;color:#94a3b8">Scannez avec Bankily / Masrivi</div></div>'
        '</div></div>'
        '<div style="padding:7px 10px;background:#1e293b;border-radius:7px;font-size:10px;display:flex;justify-content:space-between">'
        '<span>🎁 <b>Programme Fidélité :</b> +93 points gagnés</span><span style="color:#38bdf8">Merci de votre visite ! شكرا لزيارتكم</span></div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:10px;padding:10px;flex:1">{kiosk}{cfd}</div></div>'


def s_tv_queue():
    st = vars_style(THEMES[0]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">TV</div><div><b>ÉCRAN TV SALLE — SUIVI DES COMMANDES EN TEMPS RÉEL</b>'
           '<small>Affichage Dynamique Client &amp; Synthèse Vocale Bilingue (FR / AR)</small></div></div>'
           '<div class="mid-title">Synchronisé automatiquement avec l\'Écran Cuisine KDS</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>APPEL VOCAL AUTO ACTIF</div></div></div>')
    prep = (
        '<div class="card" style="flex:1;display:flex;flex-direction:column;gap:8px">'
        '<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 12px;background:rgba(245,158,11,.15);border-radius:8px;border:1px solid var(--wa)">'
        '<b style="font-size:15px;color:var(--wa)">👨‍🍳 EN PRÉPARATION · قيد التحضير</b><span style="font-size:11px;color:var(--mu)">5 commandes en cuisine</span></div>'
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">'
        '<div style="padding:14px;background:var(--sf2);border-radius:10px;display:flex;justify-content:space-between;align-items:center"><b style="font-size:26px;font-family:\'JetBrains Mono\'">N° 146</b><span style="font-size:11px;color:var(--wa)">⏳ ~3 min</span></div>'
        '<div style="padding:14px;background:var(--sf2);border-radius:10px;display:flex;justify-content:space-between;align-items:center"><b style="font-size:26px;font-family:\'JetBrains Mono\'">N° 147</b><span style="font-size:11px;color:var(--wa)">⏳ ~4 min</span></div>'
        '<div style="padding:14px;background:var(--sf2);border-radius:10px;display:flex;justify-content:space-between;align-items:center"><b style="font-size:26px;font-family:\'JetBrains Mono\'">N° 149</b><span style="font-size:11px;color:var(--mu)">⏳ ~6 min</span></div>'
        '<div style="padding:14px;background:var(--sf2);border-radius:10px;display:flex;justify-content:space-between;align-items:center"><b style="font-size:26px;font-family:\'JetBrains Mono\'">N° 150</b><span style="font-size:11px;color:var(--mu)">⏳ ~7 min</span></div>'
        '</div>'
        '<div style="padding:10px;background:var(--sf2);border-radius:8px;font-size:11px;color:var(--mu);margin-top:auto">'
        '🛵 <b>Livraison Express :</b> Commandes #W-882 et #W-885 remises aux livreurs motos.</div></div>'
    )
    ready = (
        '<div class="card" style="flex:1;display:flex;flex-direction:column;gap:8px;border:2px solid var(--ok)">'
        '<div style="display:flex;justify-content:space-between;align-items:center;padding:8px 12px;background:rgba(16,185,129,.18);border-radius:8px;border:1px solid var(--ok)">'
        '<b style="font-size:15px;color:var(--ok)">✅ PRÊT À RETIRER · جاهز للاستلام</b><span style="font-size:11px;color:var(--ok)">Présentez votre ticket au comptoir</span></div>'
        '<div style="padding:18px;background:rgba(16,185,129,.22);border:2px solid var(--ok);border-radius:12px;display:flex;justify-content:space-between;align-items:center">'
        '<div><span style="font-size:10px;font-weight:800;color:var(--ok)">🔔 NOUVEL APPEL AU COMPTOIR</span><div style="font-size:38px;font-weight:900;font-family:\'JetBrains Mono\';color:#fff">N° 148</div></div>'
        '<div style="text-align:right;font-size:13px;font-weight:700;color:var(--ok)">رقم ١٤٨ جاهز<br><small style="color:var(--tx)">Borne Kiosk · À emporter</small></div></div>'
        '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:8px">'
        '<div style="padding:12px;background:var(--sf2);border:1px solid var(--ok);border-radius:10px;text-align:center"><b style="font-size:24px;color:var(--ok);font-family:\'JetBrains Mono\'">N° 142</b></div>'
        '<div style="padding:12px;background:var(--sf2);border:1px solid var(--ok);border-radius:10px;text-align:center"><b style="font-size:24px;color:var(--ok);font-family:\'JetBrains Mono\'">N° 144</b></div>'
        '<div style="padding:12px;background:var(--sf2);border:1px solid var(--ok);border-radius:10px;text-align:center"><b style="font-size:24px;color:var(--ok);font-family:\'JetBrains Mono\'">N° 145</b></div>'
        '</div>'
        '<div style="padding:10px;background:var(--sf2);border-radius:8px;font-size:11px;margin-top:auto">'
        '🔊 <b>Synthèse vocale :</b> « Commande numéro 148 est prête — الطلب رقم ١٤٨ جاهز »</div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:10px;padding:10px;flex:1">{prep}{ready}</div></div>'


def s_waiter_app():
    st = vars_style(THEMES[0]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">📱</div><div><b>APPLICATION MOBILE SERVEUR (PDA ANDROID / iOS)</b>'
           '<small>Prise de Commande à Table en Wi-Fi Local (0,2 s · Fonctionne Sans Internet)</small></div></div>'
           '<div class="mid-title">3 Étapes sur Smartphone Serveur</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>SERVEUR : AMADOU · ZONE TERRASSE</div></div></div>')
    p1 = (
        '<div class="card" style="flex:1;border-radius:18px;border:2px solid var(--bd);display:flex;flex-direction:column;justify-content:space-between">'
        '<div><div style="display:flex;justify-content:space-between;font-size:10px;color:var(--mu);margin-bottom:6px"><span>9:41 · Wi-Fi LAN</span><span>🔋 96%</span></div>'
        '<div style="font-size:13px;font-weight:800;margin-bottom:6px">1. Mes Tables (Terrasse)</div>'
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">'
        '<div style="padding:9px;background:rgba(245,158,11,.15);border:1.5px solid var(--wa);border-radius:9px"><b>Table T-08</b><div style="font-size:10px">6 pers. · 24 min</div><b style="color:var(--wa);font-size:11px">1 600 MRU</b></div>'
        '<div style="padding:9px;background:rgba(16,185,129,.12);border:1px solid var(--ok);border-radius:9px"><b>Table T-09</b><div style="font-size:10px">4 pers. · Libre</div><b style="color:var(--ok);font-size:11px">Ouvrir +</b></div>'
        '<div style="padding:9px;background:rgba(239,68,68,.15);border:1px solid var(--er);border-radius:9px"><b>Table T-05</b><div style="font-size:10px">Addition demandée</div><b style="color:var(--er);font-size:11px">2 890 MRU</b></div>'
        '<div style="padding:9px;background:var(--sf2);border:1px solid var(--bd);border-radius:9px"><b>Salon VIP-1</b><div style="font-size:10px">8 pers. · 41 min</div><b style="font-size:11px">3 450 MRU</b></div>'
        '</div></div>'
        '<div class="cta" style="padding:8px;font-size:11px">OUVRIR TABLE T-08</div></div>'
    )
    p2 = (
        '<div class="card" style="flex:1;border-radius:18px;border:2px solid var(--ac);display:flex;flex-direction:column;justify-content:space-between">'
        '<div><div style="display:flex;justify-content:space-between;font-size:10px;color:var(--mu);margin-bottom:6px"><span>Table T-08 · Convive #3</span><span>⚡ Ajout rapide</span></div>'
        '<div style="font-size:13px;font-weight:800;margin-bottom:6px">2. Saisie &amp; Modificateurs</div>'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;margin-bottom:6px;font-size:11px"><b>🍖 Méchoui Royal (450 MRU)</b><div style="font-size:10px;color:var(--ac);margin-top:3px">✔ Bien cuit · ✔ Sans oignon · ✔ Sauce piment à part</div></div>'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;margin-bottom:6px;font-size:11px"><b>🍕 Pizza Reine (260 MRU)</b><div style="font-size:10px;color:var(--ac);margin-top:3px">✔ Supplément Olives · ✔ À suivre (2e service)</div></div>'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;font-size:11px"><b>🍵 2x Thé Mauritanien (120 MRU)</b><div style="font-size:10px;color:var(--ok);margin-top:3px">✔ Envoyer au Bar immédiatement</div></div></div>'
        '<div class="cta" style="padding:8px;font-size:11px">🔥 ENVOYER EN CUISINE KDS (0,2s)</div></div>'
    )
    p3 = (
        '<div class="card" style="flex:1;border-radius:18px;border:2px solid var(--bd);display:flex;flex-direction:column;justify-content:space-between">'
        '<div><div style="display:flex;justify-content:space-between;font-size:10px;color:var(--mu);margin-bottom:6px"><span>Table T-08 · Encaissement</span><span>🔔 Prêt</span></div>'
        '<div style="font-size:13px;font-weight:800;margin-bottom:6px">3. Paiement à Table</div>'
        '<div style="font-size:10px;color:var(--ok);margin-bottom:6px">✔ Notification Push : « Plats Table T-08 prêts au passe-plat ! »</div>'
        f'<div style="text-align:center;margin:4px 0">{qr_html()}<div style="font-size:10px;color:var(--mu)">Le client scanne sur le téléphone du serveur</div></div>'
        '<div style="display:flex;justify-content:space-between;font-size:12px;font-weight:800;padding:6px 8px;background:var(--sf2);border-radius:7px"><span>Total Table T-08</span><span>1 600 MRU</span></div></div>'
        '<div class="cta" style="padding:8px;font-size:11px">IMPRIMER L\'ADDITION BLUETOOTH</div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:12px;padding:10px;flex:1">{p1}{p2}{p3}</div></div>'


def s_qr_whatsapp():
    st = vars_style(THEMES[1]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">💬</div><div><b>MENU DIGITAL QR TABLE &amp; AUTOMATISATION WHATSAPP BUSINESS</b>'
           '<small>Commande Client Sans Attente &amp; Notifications Transactionnelles Bilingues</small></div></div>'
           '<div class="mid-title">Expérience Client Digitalisée</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>BOT WHATSAPP ACTIF 24/7</div></div></div>')
    qrm = (
        '<div class="card" style="flex:1;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><span style="background:var(--ac);color:#fff;padding:3px 9px;border-radius:99px;font-size:10px;font-weight:800">1. MENU QR SCANNÉ À LA TABLE T-08</span>'
        '<div style="font-size:14px;font-weight:800;margin:6px 0">Bienvenue chez Le Sultan · مرحبا بكم</div>'
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;border:1px solid var(--bd)"><b>🍖 Méchoui Royal</b><div style="font-size:10px;color:var(--mu)">مشوي ملكي · 450 MRU</div><div style="margin-top:4px;font-size:10px;color:var(--ac);font-weight:700">+ Ajouter au panier</div></div>'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;border:1px solid var(--bd)"><b>🍛 Thieboudienne</b><div style="font-size:10px;color:var(--mu)">تيبودين · 250 MRU</div><div style="margin-top:4px;font-size:10px;color:var(--ac);font-weight:700">+ Ajouter au panier</div></div>'
        '</div>'
        '<div style="display:flex;gap:6px;margin-top:8px">'
        '<div style="flex:1;padding:8px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px;text-align:center;font-size:11px;font-weight:700">🔔 Appeler le serveur</div>'
        '<div style="flex:1;padding:8px;background:var(--sf2);border:1px solid var(--bd);border-radius:8px;text-align:center;font-size:11px;font-weight:700">🧾 Demander l\'addition</div>'
        '</div></div>'
        '<div class="cta" style="padding:9px;font-size:11px">COMMANDER DIRECTEMENT DEPUIS MA TABLE</div></div>'
    )
    wa = (
        '<div class="card" style="flex:1.15;background:#0b141a;color:#e9edef;border-color:#1f2c34;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><div style="display:flex;justify-content:space-between;align-items:center;padding-bottom:6px;border-bottom:1px solid #1f2c34">'
        '<div><b style="color:#25d366;font-size:12px">● WhatsApp Business API Officiel</b><div style="font-size:10px;color:#8696a0">+222 45 25 •• •• · Le Sultan Restaurant</div></div>'
        '<span style="font-size:10px;background:#005c4b;padding:3px 8px;border-radius:99px">Automatisé</span></div>'
        '<div style="background:#005c4b;padding:8px 10px;border-radius:10px;font-size:10.5px;margin-top:8px;line-height:1.4">'
        '<b>Salam M. Ahmed 👋 ! Votre commande #W-884 est confirmée :</b><br>'
        '• 1x Méchoui Royal (450 MRU) + 2x Chawarma (360 MRU)<br>'
        '• Livraison Tevragh Zeina : 100 MRU · <b>Total : 910 MRU</b><br>'
        '📲 <b>Code Marchand Bankily : 884210</b></div>'
        '<div style="background:#1f2c34;padding:8px 10px;border-radius:10px;font-size:10.5px;margin-top:6px;line-height:1.4">'
        '🛵 <b>Suivi en direct :</b> Votre livreur <b>Moussa</b> est en route (arrivée estimée : 11 min).<br>'
        '📄 <i>Facture_Officielle_884.pdf (jointe automatiquement)</i></div></div>'
        '<div style="font-size:10px;color:#8696a0;display:flex;justify-content:space-between;padding-top:6px;border-top:1px solid #1f2c34">'
        '<span>✔ Rapport Z de clôture envoyé au propriétaire à 23h59</span><span style="color:#25d366">100% Automatique</span></div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:10px;padding:10px;flex:1">{qrm}{wa}</div></div>'


def s_delivery_app():
    st = vars_style(THEMES[5]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">🛵</div><div><b>CENTRALE DE DISPATCH &amp; APPLICATION MOBILE LIVREUR (GPS NOUAKCHOTT)</b>'
           '<small>Suivi Flotte Motos, Assignation par Quartier &amp; Encaissement à la Porte</small></div></div>'
           '<div class="mid-title">Logistique de Livraison Temps Réel</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>4 LIVREURS ACTIFS</div></div></div>')
    map_card = (
        '<div class="card" style="flex:1.3;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><h4>Carte de Dispatch — Nouakchott <span>Zones &amp; Tarifs Automatiques</span></h4>'
        '<div style="height:170px;background:linear-gradient(135deg,#e0f2fe,#dbeafe);border-radius:10px;border:1px solid #93c5fd;position:relative;padding:10px;color:#0f172a">'
        '<div style="position:absolute;top:14px;left:18px;background:#fff;padding:4px 8px;border-radius:6px;font-size:10px;font-weight:700;box-shadow:0 2px 6px rgba(0,0,0,.1)">📍 Tevragh Zeina (100 MRU) · 🛵 Moussa (#W-884)</div>'
        '<div style="position:absolute;top:68px;right:22px;background:#fff;padding:4px 8px;border-radius:6px;font-size:10px;font-weight:700;box-shadow:0 2px 6px rgba(0,0,0,.1)">📍 Ksar / Socogim (150 MRU) · 🛵 Brahim (#W-881)</div>'
        '<div style="position:absolute;bottom:16px;left:36px;background:#0f172a;color:#fff;padding:5px 10px;border-radius:6px;font-size:10px;font-weight:700">🏠 Restaurant Central (Ilot K) · 2 motos prêtes</div>'
        '</div></div>'
        '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:6px;font-size:10px">'
        '<div style="padding:7px;background:var(--sf2);border-radius:7px"><b>🛵 Moussa</b><br><span style="color:var(--ok)">En livraison (8 min)</span></div>'
        '<div style="padding:7px;background:var(--sf2);border-radius:7px"><b>🛵 Brahim</b><br><span style="color:var(--ok)">Livré · 2 450 MRU en caisse</span></div>'
        '<div style="padding:7px;background:var(--sf2);border-radius:7px"><b>🛵 Abdallahi</b><br><span style="color:var(--ac)">Disponible au resto</span></div>'
        '</div></div>'
    )
    driver = (
        '<div class="card" style="flex:1;border:2px solid var(--ac);border-radius:16px;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><span style="background:var(--ac);color:#fff;padding:3px 9px;border-radius:99px;font-size:10px;font-weight:800">APP MOBILE LIVREUR (MOUSSA)</span>'
        '<div style="font-size:14px;font-weight:800;margin:6px 0">Course #W-884 · M. Ahmed</div>'
        '<div style="font-size:11px;color:var(--mu);margin-bottom:6px">📍 Près Ambassade, Tevragh Zeina (Point GPS WhatsApp reçu)</div>'
        '<div style="display:flex;gap:6px;margin-bottom:8px">'
        '<div style="flex:1;padding:7px;background:var(--sf2);border-radius:7px;text-align:center;font-size:11px;font-weight:700">📞 Appeler Client</div>'
        '<div style="flex:1;padding:7px;background:var(--sf2);border-radius:7px;text-align:center;font-size:11px;font-weight:700">🗺 Ouvrir Waze/Maps</div>'
        '</div>'
        '<div style="padding:8px;background:var(--sf2);border-radius:8px;font-size:11px">'
        '<b>À encaisser à la porte : 910 MRU</b><br><span style="font-size:10px;color:var(--ok)">✔ Ou afficher mon QR Bankily Livreur</span></div></div>'
        '<div class="cta" style="padding:9px;font-size:11px">✔ CONFIRMER LA REMISE CLIENT</div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:10px;padding:10px;flex:1">{map_card}{driver}</div></div>'


def s_receipt_z():
    st = vars_style(THEMES[2]["v"])
    top = ('<div class="tb"><div class="br"><div class="lg">🧾</div><div><b>TICKET THERMIQUE 80MM BILINGUE (FR/AR) &amp; CLÔTURE Z AVEUGLE</b>'
           '<small>Impression ESC/POS Haute Vitesse &amp; Contrôle Anti-Fraude des Espèces</small></div></div>'
           '<div class="mid-title">Documents Officiels &amp; Audit de Caisse</div>'
           '<div class="tr"><div class="pill"><i class="dot"></i>SIGNATURE ANTI-FRAUDE</div></div></div>')
    rcp = (
        '<div style="width:320px;background:#fff;color:#0f172a;border-radius:10px;padding:12px 14px;font-family:\'JetBrains Mono\',monospace;font-size:10px;display:flex;flex-direction:column;justify-content:space-between;box-shadow:0 8px 24px rgba(0,0,0,.35)">'
        '<div><div style="text-align:center;border-bottom:1px dashed #94a3b8;padding-bottom:6px;margin-bottom:6px">'
        '<b style="font-size:13px">LE SULTAN · مطعم السلطان</b><br>'
        '<span>Tevragh Zeina, Nouakchott · NIF 048291</span><br>'
        '<span>Ticket #2026-0412 · Table T-08 · Serveur: Amadou</span></div>'
        '<div style="display:flex;justify-content:space-between"><span>2x Méchoui Royal / مشوي ملكي</span><b>900</b></div>'
        '<div style="display:flex;justify-content:space-between"><span>2x Chawarma Arabe / شاورما</span><b>360</b></div>'
        '<div style="display:flex;justify-content:space-between"><span>1x Pizza Reine / بيتزا</span><b>260</b></div>'
        '<div style="display:flex;justify-content:space-between"><span>3x Jus Bissap / كركديه</span><b>180</b></div>'
        '<div style="border-top:1px dashed #94a3b8;margin:6px 0;padding-top:6px">'
        '<div style="display:flex;justify-content:space-between"><span>Sous-total / المجموع</span><span>1 700 MRU</span></div>'
        '<div style="display:flex;justify-content:space-between"><span>Remise Manager / خصم</span><span>-100 MRU</span></div>'
        '<div style="display:flex;justify-content:space-between;font-size:13px;font-weight:800;margin-top:3px"><span>TOTAL TTC / الإجمالي</span><span>1 600 MRU</span></div></div>'
        '<div style="border-top:1px dashed #94a3b8;padding-top:5px;font-size:9.5px">'
        '<div>✔ Payé Bankily (Réf. 4821) : <b>1 000 MRU</b></div>'
        '<div>✔ Payé Espèces (Cash) : <b>600 MRU</b></div></div></div>'
        '<div style="text-align:center;border-top:1px dashed #94a3b8;padding-top:5px;font-size:9px;color:#475569">'
        'Merci de votre visite · شكرا لزيارتكم<br><b>HASH : 9F8A-44C1-FULLTEK</b></div></div>'
    )
    zrep = (
        '<div class="card" style="flex:1;display:flex;flex-direction:column;justify-content:space-between">'
        '<div><h4>Clôture de Caisse "Z" Aveugle &amp; Rapprochement Wallets <span>Fin de service · 23h45</span></h4>'
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:6px">'
        '<div style="padding:9px;background:var(--sf2);border-radius:8px;font-size:11px"><b>💵 Espèces en Tiroir (Comptage aveugle)</b><div style="margin-top:4px">Saisi par caissier : <b>62 350 MRU</b><br>Attendu théorique : <b>62 350 MRU</b><br><span style="color:var(--ok);font-weight:700">✔ Écart : 0 MRU (Parfait)</span></div></div>'
        '<div style="padding:9px;background:var(--sf2);border-radius:8px;font-size:11px"><b>📲 Wallets Mauritanie (Rapprochés)</b><div style="margin-top:4px">Bankily : <b>53 460 MRU</b> (84 trans.)<br>Masrivi + Sedad : <b>32 690 MRU</b><br><span style="color:var(--ok);font-weight:700">✔ 100 % vérifié par références</span></div></div>'
        '</div>'
        '<div style="padding:9px;background:var(--sf2);border-radius:8px;margin-top:8px;font-size:11px">'
        '<b>🛡 Journal de Sécurité &amp; Anti-Fraude :</b><br>'
        '• Ouvertures tiroir sans vente : <b>0</b> &nbsp;|&nbsp; Annulations après impression : <b>2 (Autorisées par PIN Manager)</b><br>'
        '• Consommation théorique viande : <b>28,4 kg</b> vs Pesée fin de soir : <b>28,3 kg</b> (Écart normal 0,3%)</div></div>'
        '<div class="cta" style="padding:9px;font-size:11px">CLÔTURER LA JOURNÉE &amp; ENVOYER LE PDF SUR WHATSAPP À M. TAHA CHOUAIB</div></div>'
    )
    return f'<div class="scr" style="{st}">{top}<div style="display:flex;gap:12px;padding:10px;flex:1">{rcp}{zrep}</div></div>'


def shot_raw(html_scr, s=.47):
    return f'<div class="shot" style="--s:{s}">{html_scr}</div>'


def page_eco1(pageno):
    cells = (
        f'<div>{shot_raw(s_superadmin(), .47)}<div class="cap"><span>★</span>Écran Pro A — Console Super-Admin SaaS &amp; Revenus MRR (Spécial Investisseur M. Taha Chouaib)</div></div>'
        f'<div>{shot_raw(s_market(), .47)}<div class="cap"><span>★</span>Écran Pro B — Mode Supermarché / Market / Boucherie (Code-barres EAN, Balance Poids kg &amp; Crédit Karni)</div></div>'
        f'<div>{shot_raw(s_kiosk_cfd(), .47)}<div class="cap"><span>★</span>Écran Pro C — Borne Tactile Libre-Service (Kiosk 27") &amp; Écran Client Comptoir Double-Affichage</div></div>'
        f'<div>{shot_raw(s_tv_queue(), .47)}<div class="cap"><span>★</span>Écran Pro D — Écran TV Salle « En préparation / Prêt à retirer » avec Appel Vocal Bilingue FR/AR</div></div>'
    )
    return f"""
<div class="pg">
  <div class="ph" style="margin-bottom:8px"><div class="pn">ÉCOSYSTÈME 360° · 1/2</div><div><h2 style="font-size:20px">Modules Premium : Console Investisseur MRR, Mode Market/Pesée, Borne Kiosk &amp; Écran TV</h2></div></div>
  <div class="g22">{cells}</div>
  <div class="pfoot"><span>CONFIDENTIEL — Modules Premium SaaS POS Restauration &amp; Market (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def page_eco2(pageno):
    cells = (
        f'<div>{shot_raw(s_waiter_app(), .47)}<div class="cap"><span>★</span>Écran Pro E — Application Mobile Serveur (Prise de commande à table en Wi-Fi local sans Internet)</div></div>'
        f'<div>{shot_raw(s_qr_whatsapp(), .47)}<div class="cap"><span>★</span>Écran Pro F — Menu Digital QR Table Client &amp; Automatisation WhatsApp Business (Facture PDF + Bankily)</div></div>'
        f'<div>{shot_raw(s_delivery_app(), .47)}<div class="cap"><span>★</span>Écran Pro G — Centrale Dispatch GPS Nouakchott &amp; Application Mobile Livreur Moto</div></div>'
        f'<div>{shot_raw(s_receipt_z(), .47)}<div class="cap"><span>★</span>Écran Pro H — Ticket Thermique 80mm Bilingue (FR/AR) &amp; Rapport de Clôture Z Aveugle Anti-Fraude</div></div>'
    )
    return f"""
<div class="pg">
  <div class="ph" style="margin-bottom:8px"><div class="pn">ÉCOSYSTÈME 360° · 2/2</div><div><h2 style="font-size:20px">Mobilité &amp; Contrôle : App Serveur, Menu QR + Bot WhatsApp, App Livreur GPS &amp; Ticket 80mm FR/AR</h2></div></div>
  <div class="g22">{cells}</div>
  <div class="pfoot"><span>CONFIDENTIEL — Modules Premium SaaS POS Restauration &amp; Market (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def page_compare(pageno):
    rows = ""
    for t in THEMES:
        sw = t["palette"][2][1]
        rows += (f'<tr><td style="padding:4px 8px"><span class="mb" style="background:{sw};width:11px;height:11px"></span><b>{t["id"]:02d} · {t["name"]}</b></td>'
                 f'<td style="padding:4px 8px">{t["mood"]}</td>'
                 f'<td style="padding:4px 8px">{t["mode"]}</td><td style="padding:4px 8px">{t["ideal"]}</td>'
                 f'<td style="padding:4px 8px">{stars(t["vitesse"])}</td><td style="padding:4px 8px">{stars(t["premium"])}</td>'
                 f'<td style="padding:4px 8px;text-align:center"><span class="box" style="width:13px;height:13px"></span></td></tr>')
    return f"""
<div class="pg">
  <div class="pt" style="margin-bottom:6px"><h2>Comparatif des 12 modèles &amp; bon pour accord</h2><p>Cochez le ou les modèles retenus. Possibilité d'activer plusieurs modèles selon le type d'établissement abonné.</p></div>
  <table class="cmp" style="font-size:9.8px"><thead><tr><th style="padding:6px 8px">MODÈLE</th><th style="padding:6px 8px">AMBIANCE</th><th style="padding:6px 8px">MODE</th><th style="padding:6px 8px">IDÉAL POUR</th><th style="padding:6px 8px">RAPIDITÉ</th><th style="padding:6px 8px">PREMIUM</th><th style="padding:6px 8px">CHOIX</th></tr></thead><tbody>{rows}</tbody></table>
  <div class="note" style="margin-top:8px">
    <div class="nb" style="padding:8px 12px;font-size:10px"><b>Personnalisation &amp; Multi-Thèmes inclus dans le SaaS de M. Taha Chouaib :</b><br>• Les <b>12 modèles</b> peuvent être intégrés au SaaS : chaque restaurant ou market abonné choisit le thème adapté à son secteur.<br>• Interface 100 % bilingue Français (LTR) / Arabe (RTL) avec bascule en 1 clic et personnalisation du logo.<br>• Changement de thème instantané (ex: thème clair le jour, thème sombre la nuit) sans aucune perte de données.</div>
    <div class="sg" style="padding:8px 12px;font-size:10px"><b style="margin-bottom:6px">Validation du client — M. Taha Chouaib</b>Modèle(s) retenu(s) : ………………………………………………<br><br>Date &amp; signature : ……………………………………………………</div>
  </div>
  <div class="pfoot"><span>Catalogue Intégral 12 Modèles (68 Écrans HD) — SaaS POS Restauration, Market &amp; Hôtel (M. Taha Chouaib)</span><span>Page {pageno}</span></div>
</div>"""


def build_html():
    pages = all_pages()
    return ('<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><title>Maquettes d\'interface POS — 12 Modèles</title>'
            f'<style>{CSS}</style></head><body>{"".join(pages)}</body></html>')


def all_pages():
    pages = [
        page_cover(),
        page_intro(THEMES[:6], 2, "Modèles 01 à 06 (Resto, Café, Luxe, Glass, Fast-Food & SaaS)"),
        page_intro(THEMES[6:], 3, "Modèles 07 à 12 (Mauritanie, Market, Pâtisserie, Street-Food, iPad & Hôtel)"),
    ]
    n = 4
    for t in THEMES:
        pages.append(page_hero(t, n)); n += 1
        pages.append(page_screens(t, n)); n += 1
    pages.append(page_eco1(n)); n += 1
    pages.append(page_eco2(n)); n += 1
    pages.append(page_compare(n))
    return pages


def _print_page(args):
    i, body, tmpdir = args
    hp = os.path.join(tmpdir, f"page_{i:02d}.html")
    pp = os.path.join(tmpdir, f"page_{i:02d}.pdf")
    with open(hp, "w", encoding="utf-8") as f:
        f.write(f'<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><style>{CSS}</style></head><body>{body}</body></html>')
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--force-device-scale-factor=1",
                    f"--user-data-dir={os.path.join(tmpdir, 'prof%02d' % i)}", f"--print-to-pdf={pp}", hp],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return pp


def build_pdf():
    import tempfile
    import fitz
    from concurrent.futures import ThreadPoolExecutor
    with open(HTML_PATH, "w", encoding="utf-8") as f:
        f.write(build_html())
    tmpdir = tempfile.mkdtemp(prefix="maq_")
    pages = all_pages()
    with ThreadPoolExecutor(max_workers=4) as ex:
        files = list(ex.map(_print_page, [(i, b, tmpdir) for i, b in enumerate(pages)]))
    out = fitz.open()
    for p in files:
        with fitz.open(p) as d:
            out.insert_pdf(d, from_page=0, to_page=0)
    out.save(PDF_PATH)
    print("PDF:", PDF_PATH, len(out), "pages")

def build_png():
    os.makedirs(PNG_DIR, exist_ok=True)
    tmp = os.path.join(PNG_DIR, "_tmp")
    os.makedirs(tmp, exist_ok=True)
    slugs = ["1_Caisse", "2_Plan_de_salle", "3_Cuisine_KDS", "4_Paiement", "5_Dashboard"]
    for t in THEMES:
        d = os.path.join(PNG_DIR, f"Modele_{t['id']}_{t['name'].replace(' ', '_').replace('é', 'e').replace('É', 'E')}")
        os.makedirs(d, exist_ok=True)
        for i in range(5):
            hp = os.path.join(tmp, f"m{t['id']}_{i}.html")
            with open(hp, "w", encoding="utf-8") as f:
                f.write(f'<!DOCTYPE html><html><head><meta charset="UTF-8"><style>body{{margin:0}}{CSS}</style></head>'
                        f'<body>{screen(t, i)}</body></html>')
            out = os.path.join(d, f"{slugs[i]}.png")
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--force-device-scale-factor=2", "--window-size=1024,640",
                            "--virtual-time-budget=4000", f"--screenshot={out}", hp], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("PNG ok:", d)


if __name__ == "__main__":
    if "--png" in sys.argv:
        build_png()
    else:
        build_pdf()



