const API_ORIGIN = 'https://api.full-tek.com';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // 1. Proxy public JSON APIs (/public/*) and /m/* directly to api.full-tek.com
    if (path.startsWith('/public/') || path.startsWith('/m/')) {
      const target = new URL(path + url.search, API_ORIGIN);
      return fetch(new Request(target.toString(), request));
    }

    // 2. Root landing page (menu.full-tek.com/)
    if (path === '/' || path === '') {
      return new Response(
        `<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8" /><meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Full·Tek Resto · Menu QR</title>
<style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0b1220;color:#f8fafc;font-family:-apple-system,Segoe UI,sans-serif;text-align:center;padding:24px;}
.box{max-width:420px;background:#131c2e;border:1px solid rgba(148,163,184,0.2);border-radius:20px;padding:28px;}
h1{margin:0 0 8px;color:#10b981;font-size:22px;}p{color:#94a3b8;font-size:14px;line-height:1.5;}</style></head>
<body><div class="box"><h1>🍽 Full·Tek Resto · Menu QR</h1>
<p>Scannez le QR code de votre table ou du restaurant pour consulter le menu et commander directement.</p>
<p dir="rtl">امسح رمز QR الموجود على طاولتك لتصفح القائمة والطلب مباشرة.</p></div></body></html>`,
        { status: 200, headers: { 'Content-Type': 'text/html; charset=utf-8' } }
      );
    }

    // 3. Pretty restaurant URL: menu.full-tek.com/<TENANT_CODE>?table=T1 -> api.full-tek.com/m/<TENANT_CODE>?table=T1
    const cleanSlug = path.replace(/^\/+|\/+$/g, '');
    const target = new URL(`/m/${encodeURIComponent(cleanSlug)}${url.search}`, API_ORIGIN);
    return fetch(new Request(target.toString(), request));
  },
};
