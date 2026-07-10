'use strict';

/**
 * Privat Sign Tester — крихітний локальний сервер (zero-dependency, лише вбудовані модулі Node).
 *
 * Що робить:
 *  1. Віддає статичний клієнт із ./public (форма + підпис через віджет ІІТ EU Sign).
 *  2. Має ендпоінт /callback для SmartID-cloud-скелета (сюди ПриватБанк слав би результат
 *     підпису після підтвердження в Приват24). Через ngrok цей URL стає публічним.
 *  3. Опційно піднімає ngrok-тунель, якщо в системі є бінарник `ngrok`.
 *
 * Запуск:  node server.js   (порт з env PORT або 3000)
 * Тунель:  в іншому терміналі  ->  ngrok http 3000   (на ТВОЇЙ машині, не в контейнері)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const PORT = Number(process.env.PORT) || 3000;
const PUBLIC_DIR = path.join(__dirname, 'public');

// Останній отриманий callback тримаємо в пам'яті, щоб UI міг його показати (демо циклу).
let lastCallback = null;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj, null, 2);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  });
  res.end(body);
}

function serveStatic(req, res) {
  // Захист від path traversal: беремо лише basename-складові в межах PUBLIC_DIR.
  const urlPath = req.url.split('?')[0];
  const rel = urlPath === '/' ? 'index.html' : urlPath.replace(/^\/+/, '');
  const filePath = path.normalize(path.join(PUBLIC_DIR, rel));
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      return res.end('Not found: ' + rel);
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
    res.end(data);
  });
}

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', () => resolve(''));
  });
}

const server = http.createServer(async (req, res) => {
  const urlPath = req.url.split('?')[0];

  if (req.method === 'OPTIONS') {
    return sendJson(res, 204, {});
  }

  // --- Callback від SmartID-cloud (скелет). Публічний через ngrok. ---
  if (urlPath === '/callback') {
    const body = req.method === 'POST' ? await readBody(req) : '';
    let parsed = body;
    try { parsed = body ? JSON.parse(body) : ''; } catch (_) { /* лишаємо як текст */ }
    lastCallback = {
      receivedAt: new Date().toISOString(),
      method: req.method,
      query: req.url.includes('?') ? req.url.split('?')[1] : '',
      headers: req.headers,
      body: parsed,
    };
    console.log('\n[callback] отримано:', JSON.stringify(lastCallback, null, 2));
    return sendJson(res, 200, { ok: true, message: 'callback отримано сервером' });
  }

  // --- UI опитує цей ендпоінт, щоб показати останній callback. ---
  if (urlPath === '/api/last-callback') {
    return sendJson(res, 200, { lastCallback });
  }

  // --- Мок SmartID-підпису для скелета (доки нема партнерського API). ---
  if (urlPath === '/api/mock-smartid-sign' && req.method === 'POST') {
    const body = await readBody(req);
    let payload = {};
    try { payload = body ? JSON.parse(body) : {}; } catch (_) {}
    // Симулюємо асинхронний результат: за 2с самі б'ємо у власний /callback,
    // ніби ПриватБанк повернув підпис. Це ЛИШЕ демо циклу, не справжній .p7s.
    setTimeout(() => {
      const fakeSign = Buffer.from('MOCK-CAdES-P7S::' + (payload.fileName || 'contract') +
        '::' + new Date().toISOString()).toString('base64');
      lastCallback = {
        receivedAt: new Date().toISOString(),
        method: 'POST',
        source: 'mock-smartid',
        body: { status: 'SIGNED', format: 'CAdES/.p7s (МОК)', signBase64: fakeSign },
      };
      console.log('[mock-smartid] згенеровано мок-підпис і покладено в lastCallback');
    }, 2000);
    return sendJson(res, 200, {
      ok: true,
      note: 'Це МОК. Справжній SmartID підпис вимагає партнерського API ПриватБанку.',
    });
  }

  return serveStatic(req, res);
});

server.listen(PORT, () => {
  console.log('────────────────────────────────────────────────────────');
  console.log(`  Privat Sign Tester слухає:  http://localhost:${PORT}`);
  console.log('────────────────────────────────────────────────────────');
  maybeStartNgrok();
});

/** Піднімає ngrok, якщо бінарник є в PATH; інакше друкує інструкцію. */
function maybeStartNgrok() {
  const wantNgrok = process.env.START_NGROK !== '0';
  if (!wantNgrok) return;
  const probe = spawn('ngrok', ['version']);
  probe.on('error', () => {
    console.log('\n[ngrok] не знайдено в PATH. Щоб отримати публічний callback-URL:');
    console.log('  1) встанови ngrok (https://ngrok.com/download) і авторизуйся:');
    console.log('     ngrok config add-authtoken <ТВІЙ_ТОКЕН>');
    console.log(`  2) в іншому терміналі:  ngrok http ${PORT}`);
    console.log('  3) публічний https-URL із ngrok + "/callback" встав у форму.\n');
  });
  probe.on('exit', (code) => {
    if (code !== 0) return;
    console.log('\n[ngrok] знайдено — піднімаю тунель...');
    const tun = spawn('ngrok', ['http', String(PORT)], { stdio: 'inherit' });
    tun.on('error', (e) => console.log('[ngrok] не вдалося запустити:', e.message));
  });
}
