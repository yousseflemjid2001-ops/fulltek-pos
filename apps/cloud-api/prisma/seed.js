require('dotenv').config();
const bcrypt = require('bcryptjs');
const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient();

async function main() {
  const count = await prisma.tenant.count();
  if (count > 0) {
    console.log(`Database already seeded (${count} tenants).`);
    return;
  }

  const demoPass = 'FullTek@2026';
  const passHash = await bcrypt.hash(demoPass, 10);

  const seedTenants = [
    {
      tenantCode: 'FT-1041',
      name: 'Dar El-Karam Resto',
      module: 'resto',
      subType: 'Salon Khaima VIP',
      city: 'Tevragh Zeina',
      district: 'Îlot C · Nouakchott',
      phone: '+222 46 11 22 33',
      manager: 'Ahmed Ould Salem',
      plan: 'Pro',
      mrr: 3000,
      tills: 3,
      daysLeft: 2,
      status: 'warn',
      online: true,
      pendingSync: 0,
      enabledThemes: JSON.stringify(['01', '04', '06', '07', '11']),
      features: JSON.stringify(['kds', 'khaima', 'tablet', 'split', 'boss', 'offline', 'lan', 'printer']),
      payMethods: JSON.stringify(['Cash', 'Bankily', 'Masrivi', 'Sedad', 'Bimbank', 'Click', 'Karni']),
      deliveryZonesJson: JSON.stringify([
        { id: 'zone-centre', nameFr: 'Centre / Ilot K', nameAr: 'المركز / إيلو ك', nameEn: 'Center / Ilot K', feeMru: 50 },
        { id: 'zone-tz', nameFr: 'Tevragh Zeina', nameAr: 'تفرغ زينة', nameEn: 'Tevragh Zeina', feeMru: 100 },
        { id: 'zone-ksar', nameFr: 'Ksar / Socogim', nameAr: 'لكصر / سوكوجيم', nameEn: 'Ksar / Socogim', feeMru: 150 },
        { id: 'zone-arafat', nameFr: 'Arafat / Dar Naim', nameAr: 'عرفات / دار النعيم', nameEn: 'Arafat / Dar Naim', feeMru: 150 },
      ]),
      freeDeliveryAboveMru: 1500,
      hardware: JSON.stringify(['printer', 'kds_screen', 'tablet']),
      username: 'darelkram41',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '7410',
    },
    {
      tenantCode: 'FT-2088',
      name: 'Al-Baraka Market',
      module: 'market',
      subType: 'Supermarché',
      city: 'Ksar',
      district: 'Carrefour Madrid',
      phone: '+222 44 88 19 02',
      manager: 'Mohamed Ould Sidi',
      plan: 'Pro',
      mrr: 3000,
      tills: 4,
      daysLeft: 24,
      status: 'active',
      online: true,
      pendingSync: 0,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['scale', 'barcode', 'wholesale', 'karni', 'boss', 'offline', 'lan', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Masrivi', 'Cash', 'Karni']),
      hardware: JSON.stringify(['printer', 'scanner', 'scale', 'drawer']),
      username: 'albaraka88',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '5920',
    },
    {
      tenantCode: 'FT-3019',
      name: 'Pharmacie Chinguetti',
      module: 'pharma',
      subType: "Pharmacie d'officine",
      city: 'Tevragh Zeina',
      nif: '00419284',
      rc: 'RC-NKC-9921',
      phone: '+222 42 33 77 10',
      manager: 'Dr. Mariem Mint Cheikh',
      plan: 'Entreprise',
      mrr: 5500,
      tills: 5,
      daysLeft: 18,
      status: 'active',
      online: false,
      pendingSync: 42,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['fefo', 'cnam', 'cold', 'generic', 'boss', 'offline', 'lan', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Masrivi', 'Sedad', 'Cash']),
      hardware: JSON.stringify(['printer', 'scanner', 'drawer']),
      username: 'chinguetti19',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '8831',
    },
    {
      tenantCode: 'FT-4012',
      name: 'Boucherie El-Wiam',
      module: 'market',
      subType: 'Boucherie',
      city: 'Arafat',
      phone: '+222 36 55 41 12',
      manager: 'Brahim Fall',
      plan: 'Start',
      mrr: 1500,
      tills: 1,
      daysLeft: 0,
      status: 'expired',
      online: true,
      pendingSync: 0,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['scale', 'karni', 'offline', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Cash', 'Karni']),
      hardware: JSON.stringify(['printer', 'scale']),
      username: 'elwiam12',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '3019',
    },
    {
      tenantCode: 'FT-5090',
      name: 'Café Khaima Nouadhibou',
      module: 'resto',
      subType: 'Café / Salon de thé',
      city: 'Nouadhibou',
      phone: '+222 48 90 14 25',
      manager: 'Sidi Mohamed',
      plan: 'Essai 15j',
      mrr: 0,
      tills: 2,
      daysLeft: 9,
      status: 'trial',
      online: true,
      pendingSync: 0,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['kds', 'khaima', 'tablet', 'boss', 'offline', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Masrivi', 'Cash']),
      hardware: JSON.stringify(['printer', 'tablet']),
      username: 'khaimandb90',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '1540',
    },
    {
      tenantCode: 'FT-6031',
      name: 'Pharmacie Atar Centre',
      module: 'pharma',
      subType: "Pharmacie d'officine",
      city: 'Atar',
      phone: '+222 45 64 31 09',
      manager: 'Dr. Abdallahi',
      plan: 'Pro',
      mrr: 3000,
      tills: 2,
      daysLeft: 4,
      status: 'warn',
      online: false,
      pendingSync: 19,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['fefo', 'cnam', 'cold', 'offline', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Cash']),
      hardware: JSON.stringify(['printer', 'scanner']),
      username: 'pharmaatar31',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '6604',
    },
    {
      tenantCode: 'FT-7089',
      name: 'Épicerie Rosso Express',
      module: 'market',
      subType: 'Épicerie / Alimentation',
      city: 'Rosso',
      phone: '+222 33 21 89 44',
      manager: 'Oumar Diop',
      plan: 'Start',
      mrr: 1500,
      tills: 1,
      daysLeft: 27,
      status: 'active',
      online: true,
      pendingSync: 0,
      enabledThemes: JSON.stringify(['01', '06', '07', '11']),
      features: JSON.stringify(['barcode', 'karni', 'offline', 'printer']),
      payMethods: JSON.stringify(['Bankily', 'Sedad', 'Cash', 'Karni']),
      hardware: JSON.stringify(['printer', 'scanner']),
      username: 'rosso89',
      passwordHash: passHash,
      accountPassword: demoPass,
      ownerPin: '9218',
    },
  ];

  const created = {};
  for (const t of seedTenants) {
    const row = await prisma.tenant.create({ data: t });
    await prisma.user.create({
      data: {
        tenantId: row.id,
        fullName: t.manager || t.name,
        username: t.username,
        passHash,
        pinCode: t.ownerPin,
        role: 'OWNER',
      },
    });
    created[t.tenantCode] = row;
  }

  // Seed FEFO demo batches for Pharmacie Chinguetti
  const pharma = created['FT-3019'];
  if (pharma) {
    const amox = await prisma.product.create({
      data: {
        tenantId: pharma.id,
        sku: 'MED-AMX-500',
        barcode: '3400930001122',
        nameFr: 'Amoxicilline 500mg',
        nameAr: 'أموكسيسيلين 500 ملغ',
        priceRetail: 185,
        trackFefo: true,
        requiresCnam: true,
      },
    });
    await prisma.stockBatch.create({
      data: {
        tenantId: pharma.id,
        productId: amox.id,
        lotNumber: 'LOT-A892',
        qty: 40,
        expiresAt: new Date('2027-08-30T00:00:00Z'),
      },
    });
  }

  await prisma.saaSPayment.createMany({
    data: [
      { payCode: 'P-901', tenantId: created['FT-1041'].id, method: 'Bankily', ref: 'BK-884210', amount: 3000, status: 'pending', timeLabel: '14:12' },
      { payCode: 'P-902', tenantId: created['FT-4012'].id, method: 'Masrivi', ref: 'MS-190442', amount: 1500, status: 'pending', timeLabel: '11:45' },
      { payCode: 'P-903', tenantId: created['FT-6031'].id, method: 'Sedad', ref: 'SD-773105', amount: 3000, status: 'pending', timeLabel: '09:30' },
    ],
  });

  await prisma.auditLog.createMany({
    data: [
      { tenantId: created['FT-2088'].id, title: 'Validation Bankily +30j · Al-Baraka Market', subtitle: 'M. Taha · Réf. BK-77310 · +3 000 MRU', timeLabel: '13:20' },
      { tenantId: created['FT-6031'].id, title: 'Code Offline 8 chiffres · Pharmacie Atar', subtitle: 'M. Taha · Lease +30j généré', timeLabel: 'Hier 19:05' },
      { tenantId: created['FT-5090'].id, title: 'Provisioning · Café Khaima Nouadhibou', subtitle: 'M. Taha · Essai gratuit 15j · 2 caisses', timeLabel: 'Hier 16:40' },
    ],
  });

  console.log('Seed completed: 7 tenants, 3 pending payments, 3 audit logs.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
