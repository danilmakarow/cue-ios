'use strict';

/*
 * Клієнтська логіка тесту підпису.
 *
 * ФАЙЛОВИЙ РЕЖИМ використовує SDK ІІТ "EndUser" з віджета EU Sign
 * (eu.iit.com.ua/sign-widget). SDK вантажиться динамічно з URI, вказаного у формі,
 * бо версія може змінюватися. Підпис виконується у браузері: ключ і пароль
 * вводяться у ЗАХИЩЕНОМУ iframe віджета й на нашу сторінку не потрапляють.
 *
 * ⚠️ Точні назви методів SDK ІІТ можуть відрізнятися між версіями віджета.
 * Якщо бачиш помилку "EndUser is not defined" або "... is not a function" —
 * онови URI віджета у формі й звір методи з докою ІІТ:
 *   https://eu.iit.com.ua/  →  «Бібліотека підпису (JS)» / sign-widget.
 * Місця, які найімовірніше треба підправити під свою версію, позначені  // ADJUST.
 */

const $ = (id) => document.getElementById(id);
document.getElementById('origin').textContent = location.origin;

let euSign = null;          // екземпляр EndUser
let keyLoaded = false;
let contractBytes = null;   // Uint8Array договору
let contractName = '';

// ── Перемикання режимів ──
document.querySelectorAll('input[name="mode"]').forEach((r) => {
  r.addEventListener('change', () => {
    const mode = document.querySelector('input[name="mode"]:checked').value;
    $('fileMode').hidden = mode !== 'file';
    $('smartidMode').hidden = mode !== 'smartid';
  });
});

// ── Завантаження договору ──
$('contractFile').addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;
  contractName = file.name;
  contractBytes = new Uint8Array(await file.arrayBuffer());
  $('contractInfo').textContent =
    `Обрано: ${file.name} · ${contractBytes.length.toLocaleString('uk')} байт · ${file.type || 'невідомий тип'}`;
  refreshSignBtn();
});

function refreshSignBtn() {
  $('signBtn').disabled = !(keyLoaded && contractBytes);
}

// ── Динамічне підвантаження SDK ІІТ ──
function loadScript(src) {
  return new Promise((resolve, reject) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = resolve;
    s.onerror = () => reject(new Error('Не вдалося завантажити ' + src));
    document.head.appendChild(s);
  });
}

async function ensureEndUser() {
  if (window.EndUser && euSign) return euSign;
  const widgetUrl = $('widgetUrl').value.replace(/\/+$/, '');
  if (!window.EndUser) {
    // euscp.js містить клас EndUser. // ADJUST: у деяких версіях файл зветься eusw.js
    await loadScript(widgetUrl + '/euscp.js');
  }
  if (!window.EndUser) throw new Error('SDK ІІТ завантажився, але EndUser не знайдено — звір назву файла/версію віджета.');

  // Ініціалізація віджета в контейнері #sign-widget-parent.
  // Сигнатура: new EndUser(parentElem, iframeId, widgetUri, formType)  // ADJUST під версію
  euSign = new window.EndUser(
    $('sign-widget-parent'),
    'sign-widget-iframe',
    widgetUrl,
    window.EndUser.FormType ? window.EndUser.FormType.ReadPKey : 1,
  );
  return euSign;
}

// ── Крок 1: зчитати ключ ──
$('readKeyBtn').addEventListener('click', async () => {
  $('keyInfo').textContent = 'Ініціалізація віджета ІІТ…';
  try {
    const eu = await ensureEndUser();
    // Відкриває захищену форму: вибір файлу ключа + пароль (усе в iframe ІІТ).
    const cert = await eu.ReadPrivateKey();           // ADJUST: назва методу за версією
    keyLoaded = true;
    const info = (cert && (cert.infoEx || cert.info)) || {};
    const subj = info.subjCN || info.subject || info.ownerName || 'ключ зчитано';
    $('keyInfo').innerHTML = `✅ Ключ зчитано: <b>${escapeHtml(String(subj))}</b>`;
    refreshSignBtn();
  } catch (err) {
    keyLoaded = false;
    $('keyInfo').innerHTML = `❌ ${escapeHtml(err.message || String(err))}`;
    refreshSignBtn();
  }
});

// ── Крок 2: підписати ──
$('signBtn').addEventListener('click', async () => {
  $('signResult').textContent = 'Підписання…';
  $('downloadLink').style.display = 'none';
  try {
    const eu = await ensureEndUser();
    const detached = $('signType').value === 'detached';
    const withTsp = $('withTsp').checked;

    // Вибір алгоритму та рівня. // ADJUST: константи можуть зватися інакше у твоїй версії SDK.
    const asBase64 = true;

    let signB64;
    if (typeof eu.SignData === 'function') {
      // Поширена сигнатура EndUser.SignData(data, external, asBase64, signAlgo, ...)
      // external=true → detached; false → attached/enveloped.
      signB64 = await eu.SignData(contractBytes, detached, asBase64);   // ADJUST
    } else if (typeof eu.SignDataInternal === 'function') {
      signB64 = await eu.SignDataInternal(false, contractBytes, asBase64); // ADJUST
    } else {
      throw new Error('Не знайдено метод підпису (SignData/SignDataInternal) у SDK.');
    }

    // Готуємо файл .p7s до завантаження.
    const bytes = base64ToBytes(typeof signB64 === 'string' ? signB64 : bytesToBase64(signB64));
    const blob = new Blob([bytes], { type: 'application/pkcs7-signature' });
    const url = URL.createObjectURL(blob);
    const link = $('downloadLink');
    link.href = url;
    link.download = contractName + '.p7s';
    link.style.display = 'inline-block';

    $('signResult').innerHTML =
      `✅ Підписано. Формат: <b>CAdES ${detached ? 'detached' : 'attached'}${withTsp ? ' + TSP' : ''}</b>. ` +
      `Розмір підпису: ${bytes.length.toLocaleString('uk')} байт.` +
      (detached ? ' <i>(detached — зберігай разом з оригіналом договору)</i>' : '');

    // Демо циклу: якщо задано callback URL — надсилаємо туди підпис (base64).
    const cb = $('callbackUrl').value.trim();
    if (cb) {
      fetch(cb, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fileName: contractName, format: 'CAdES', signBase64: bytesToBase64(bytes) }),
      }).then(() => console.log('Підпис надіслано на callback'))
        .catch((e) => console.log('callback недоступний:', e.message));
    }
  } catch (err) {
    $('signResult').innerHTML = `❌ ${escapeHtml(err.message || String(err))}`;
  }
});

// ── SmartID скелет ──
$('smartidStartBtn').addEventListener('click', async () => {
  $('qrBox').hidden = false;
  $('callbackBox').hidden = false;
  const cb = $('callbackUrl').value.trim() || (location.origin + '/callback');
  // QR лише ілюстративний: у реальному потоці його генерує ПриватБанк.
  const demoData = 'smartid-demo:' + cb;
  $('qrImg').src = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=' + encodeURIComponent(demoData);

  // Запускаємо мок-підпис на сервері (він за 2с покладе результат у lastCallback).
  await fetch('/api/mock-smartid-sign', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fileName: contractName || 'contract.pdf' }),
  }).catch(() => {});

  pollCallback();
});

let pollTimer = null;
function pollCallback() {
  clearInterval(pollTimer);
  let ticks = 0;
  pollTimer = setInterval(async () => {
    ticks++;
    try {
      const r = await fetch('/api/last-callback');
      const j = await r.json();
      $('callbackOut').textContent = j.lastCallback
        ? JSON.stringify(j.lastCallback, null, 2)
        : 'очікування callback…';
      if (j.lastCallback) clearInterval(pollTimer);
    } catch (e) {
      $('callbackOut').textContent = 'сервер недоступний: ' + e.message;
    }
    if (ticks > 30) clearInterval(pollTimer);
  }, 1000);
}

// ── утиліти ──
function base64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToBase64(bytes) {
  let bin = '';
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
  return btoa(bin);
}
function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
