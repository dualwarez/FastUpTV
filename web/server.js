#!/usr/bin/env node
/**
 * FastUpTV web UI - run the cleaner from your phone's browser.
 *
 *   node web/server.js            -> http://<pc-ip>:8080/?t=<token>
 *
 * The browser cannot speak ADB, so this tiny server does the talking and the phone just shows
 * buttons and the log. Binds to the LAN; every request needs the token printed at startup.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { execFile } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const ADB = path.join(ROOT, 'tools', 'platform-tools', 'adb.exe');
const PORT = Number(process.env.PORT || 8080);
const TOKEN = process.env.TOKEN || crypto.randomBytes(6).toString('hex');

// ---------------------------------------------------------------- helpers

function adb(args, timeout = 60000) {
  return new Promise((resolve) => {
    execFile(ADB, args, { timeout, windowsHide: true, maxBuffer: 8 * 1024 * 1024 }, (err, stdout, stderr) => {
      resolve({ ok: !err, out: (stdout || '').toString(), err: (stderr || '').toString() });
    });
  });
}

function sh(serial, cmd, timeout) {
  return adb(['-s', serial, 'shell', cmd], timeout).then((r) => (r.out + r.err).trim());
}

function readList(file) {
  if (!fs.existsSync(file)) return [];
  return fs.readFileSync(file, 'utf8')
    .split(/\r?\n/)
    .map((l) => l.replace(/#.*$/, '').trim())
    .filter(Boolean)
    .map((l) => l.split(/\s+/)[0]);
}

const CORE_RE = /^(android|com\.android\.systemui|com\.android\.shell|com\.android\.phone|com\.android\.settings|com\.android\.tv\.settings|com\.(google\.)?android\.(permissioncontroller|packageinstaller|ext\.services|ext\.shared|modulemetadata)|com\.google\.android\.overlay\.modules.*|com\.android\.providers\..*)$/;
const CORE_OK = /^com\.android\.providers\.(calendar|contacts|userdictionary|blockednumber)$/;

function lanIp() {
  const nets = os.networkInterfaces();
  for (const name of Object.keys(nets)) {
    for (const n of nets[name] || []) {
      if (n.family === 'IPv4' && !n.internal) return n.address;
    }
  }
  return '127.0.0.1';
}

async function findTv(hint) {
  const dev = await adb(['devices']);
  const line = dev.out.split(/\r?\n/).find((l) => /\tdevice$/.test(l));
  if (line) return line.split('\t')[0];

  if (hint) {
    await adb(['connect', hint]);
    const again = await adb(['devices']);
    if (again.out.includes(hint) && /\tdevice/.test(again.out)) return hint;
  }

  const base = lanIp().split('.').slice(0, 3).join('.');
  const tries = [];
  for (let i = 1; i <= 254; i++) tries.push(`${base}.${i}`);
  const open = [];
  await Promise.all(tries.map((ip) => new Promise((resolve) => {
    const s = new (require('net').Socket)();
    s.setTimeout(220);
    s.once('connect', () => { open.push(ip); s.destroy(); resolve(); });
    s.once('timeout', () => { s.destroy(); resolve(); });
    s.once('error', () => { s.destroy(); resolve(); });
    s.connect(5555, ip);
  })));
  for (const ip of open) await adb(['connect', `${ip}:5555`]);
  const after = await adb(['devices']);
  const hits = after.out.split(/\r?\n/).filter((l) => /:5555\tdevice/.test(l));
  return hits.length ? hits[0].split('\t')[0] : null;
}

async function inspect(serial) {
  const brand = await sh(serial, 'getprop ro.product.brand');
  const model = await sh(serial, 'getprop ro.product.model');
  const sdk = await sh(serial, 'getprop ro.build.version.sdk');
  const homeLine = await sh(serial, 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME');
  const home = (homeLine.split(/\r?\n/).filter((l) => l.includes('/')).pop() || '').split('/')[0];
  const installedRaw = await sh(serial, 'pm list packages');
  const installed = installedRaw.split(/\r?\n/).map((l) => l.replace(/^package:/, '').trim()).filter(Boolean);

  const core = readList(path.join(ROOT, 'lists', 'core.txt'));
  const keys = ['xiaomi', 'tcl', 'sony', 'hisense', 'philips', 'oneplus', 'nokia', 'google'];
  const brandKey = `${brand} ${model}`.toLowerCase();
  let brandList = null;
  let brandFile = null;
  for (const k of keys) {
    if (brandKey.includes(k)) {
      const f = path.join(ROOT, 'lists', `${k}.txt`);
      if (fs.existsSync(f)) { brandList = readList(f); brandFile = `lists/${k}.txt`; }
      break;
    }
  }

  const wanted = [...new Set([...(core || []), ...(brandList || [])])];
  const proposed = [];
  const skipped = [];
  for (const pkg of wanted) {
    if (installed.indexOf(pkg) === -1) { skipped.push({ pkg, why: 'not installed' }); continue; }
    if (CORE_RE.test(pkg) && !CORE_OK.test(pkg)) { skipped.push({ pkg, why: 'core Android' }); continue; }
    if (pkg === home) { skipped.push({ pkg, why: 'owns Home' }); continue; }
    if (/inputmethod|\.input$|gboard/.test(pkg)) { skipped.push({ pkg, why: 'keyboard' }); continue; }
    if (/setupwraith|setupwizard/.test(pkg)) { skipped.push({ pkg, why: 'setup wizard' }); continue; }
    proposed.push(pkg);
  }

  return { serial, brand, model, sdk, home, installed: installed.length, brandFile, proposed, skipped };
}

async function apply(serial, list, dryRun) {
  const log = [];
  const disabled = [];
  const failed = [];
  const stamp = new Date().toISOString().replace(/[:T]/g, '-').slice(0, 19);
  const dir = path.join(ROOT, 'backups', stamp);
  log.push(`backup -> backups/${stamp}`);

  if (!dryRun) {
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'packages-all.txt'), await sh(serial, 'pm list packages -f'));
    fs.writeFileSync(path.join(dir, 'packages-disabled.txt'), await sh(serial, 'pm list packages -d'));
    fs.writeFileSync(path.join(dir, 'props.txt'), await sh(serial, 'getprop'));
    fs.writeFileSync(path.join(dir, 'home-owner.txt'), await sh(serial, 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME'));
  }

  for (const pkg of list) {
    if (dryRun) { log.push(`would disable ${pkg}`); continue; }
    const out = await sh(serial, `pm disable-user --user 0 ${pkg}`);
    const disabledNow = await sh(serial, 'pm list packages -d');
    if (disabledNow.split(/\r?\n/).some((l) => l.trim() === `package:${pkg}`)) {
      log.push(`disabled ${pkg}`);
      disabled.push(pkg);
      fs.appendFileSync(path.join(dir, 'disabled.txt'), pkg + '\n');
    } else {
      log.push(`FAILED ${pkg} ${out}`.trim());
      failed.push(pkg);
    }
    await new Promise((r) => setTimeout(r, 200));
  }

  if (!dryRun) {
    for (const k of ['window_animation_scale', 'transition_animation_scale', 'animator_duration_scale']) {
      await sh(serial, `settings put global ${k} 0.5`);
    }
    await sh(serial, 'pm trim-caches 32G');
    log.push('animations 0.5x, cache trimmed');
  }

  return { log, disabled: disabled.length, failed: failed.length, backup: dryRun ? null : `backups/${stamp}` };
}

async function restoreLatest(serial) {
  const base = path.join(ROOT, 'backups');
  if (!fs.existsSync(base)) return { log: ['no backups found'], restored: 0 };
  const dirs = fs.readdirSync(base).filter((d) => fs.existsSync(path.join(base, d, 'disabled.txt'))).sort();
  if (!dirs.length) return { log: ['no backups with disabled.txt'], restored: 0 };
  const dir = path.join(base, dirs[dirs.length - 1]);
  const list = fs.readFileSync(path.join(dir, 'disabled.txt'), 'utf8').split(/\r?\n/).filter(Boolean);
  const log = [`backup: backups/${dirs[dirs.length - 1]}`];
  let ok = 0;
  for (const pkg of list) {
    const out = await sh(serial, `pm enable --user 0 ${pkg}`);
    if (out.includes('enabled')) { log.push(`enabled ${pkg}`); ok++; } else { log.push(`skip ${pkg}`); }
  }
  for (const k of ['window_animation_scale', 'transition_animation_scale', 'animator_duration_scale']) {
    await sh(serial, `settings put global ${k} 1.0`);
  }
  const stock = (fs.readFileSync(path.join(dir, 'home-owner.txt'), 'utf8').split(/\r?\n/).find((l) => l.includes('/')) || '').split('/')[0];
  if (stock) {
    await sh(serial, `pm enable --user 0 ${stock}`);
    await sh(serial, `cmd package set-home-activity --user 0 ${stock}/.MainActivity`);
    log.push(`stock home: ${stock}`);
  }
  await sh(serial, 'pm disable-user --user 0 com.gathin.tvhome');
  log.push('animations 1x');
  return { log, restored: ok };
}

// ---------------------------------------------------------------- page

const PAGE = `<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>FastUpTV</title>
<style>
 :root { color-scheme: dark; }
 * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
 body { margin:0; font:16px/1.45 system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
        background:#0d1014; color:#e8edf5; padding:20px 16px 40px; }
 h1 { font-size:22px; margin:0 0 2px; letter-spacing:.5px; }
 .sub { color:#8f9aa8; font-size:13px; margin-bottom:20px; }
 .card { background:#151a21; border:1px solid #222a34; border-radius:14px; padding:14px; margin-bottom:12px; }
 .row { display:flex; justify-content:space-between; font-size:14px; padding:2px 0; }
 .row b { font-weight:600; }
 button { width:100%; padding:16px; font-size:16px; font-weight:600; border-radius:12px; border:0;
          background:#1f6feb; color:#fff; margin-top:10px; }
 button.ghost { background:#1c232c; color:#c9d4e3; border:1px solid #2b3643; }
 button.warn { background:#8b2c2c; }
 button:disabled { opacity:.5; }
 pre { background:#0b0e12; border:1px solid #1d242d; border-radius:10px; padding:12px; font-size:12px;
       line-height:1.5; max-height:46vh; overflow:auto; white-space:pre-wrap; word-break:break-word; }
 .pill { display:inline-block; font-size:12px; padding:2px 8px; border-radius:999px; background:#1d2530; color:#9fb0c4; }
 .ok { color:#5ec27a; } .bad { color:#e06c75; }
</style></head>
<body>
<h1>FastUpTV</h1>
<div class="sub">Phone se TV clean karo - PC par chalta hai, phone sirf button dabata hai</div>

<div class="card" id="status"><div class="row"><span>TV</span><b id="tv">-</b></div>
  <div class="row"><span>Model</span><b id="model">-</b></div>
  <div class="row"><span>Android</span><b id="sdk">-</b></div>
  <div class="row"><span>Packages band honge</span><b id="count">-</b></div></div>

<button id="scan">1. TV dhoondo</button>
<button id="analyse" class="ghost">2. Plan dekho (kuch change nahi)</button>
<button id="clean">3. Clean karo</button>
<button id="restore" class="warn">Restore (sab wapas)</button>

<pre id="log">ready.</pre>

<script>
const T = new URLSearchParams(location.search).get('t') || '';
const $ = (id) => document.getElementById(id);
function log(s) { $('log').textContent += (s.endsWith('\\n') ? s : s + '\\n'); $('log').scrollTop = 1e9; }
function busy(b) { for (const id of ['scan','analyse','clean','restore']) $(id).disabled = b; }
async function api(pathname, body) {
  const r = await fetch(pathname + (pathname.includes('?') ? '&' : '?') + 't=' + encodeURIComponent(T), {
    method: body ? 'POST' : 'GET',
    headers: { 'content-type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
function show(s) {
  if (s.serial) $('tv').textContent = s.serial;
  if (s.model) $('model').textContent = s.brand + ' ' + s.model;
  if (s.sdk) $('sdk').textContent = s.sdk;
  if (s.proposed) $('count').textContent = s.proposed.length;
}
$('scan').onclick = async () => { busy(1); log('scanning ...'); try { const s = await api('/api/connect', {}); show(s); log('found ' + s.serial); } catch (e) { log('! ' + e.message); } busy(0); };
$('analyse').onclick = async () => { busy(1); log('reading the TV ...'); try { const s = await api('/api/analyse', {}); show(s); log(s.proposed.join('\\n')); log('-- ' + s.proposed.length + ' packages, kuch change nahi hua'); } catch (e) { log('! ' + e.message); } busy(0); };
$('clean').onclick = async () => {
  if (!confirm('TV par ' + ($('count').textContent || '?') + ' packages band honge. Aage badhein?')) return;
  busy(1); log('cleaning ...'); try { const r = await api('/api/clean', {}); log(r.log.join('\\n')); log('done: ' + r.disabled + ' disabled, ' + r.failed + ' failed'); } catch (e) { log('! ' + e.message); } busy(0);
};
$('restore').onclick = async () => {
  if (!confirm('Sab kuch wapas chalu ho jayega. Pakka?')) return;
  busy(1); log('restoring ...'); try { const r = await api('/api/restore', {}); log(r.log.join('\\n')); log('restored: ' + r.restored); } catch (e) { log('! ' + e.message); } busy(0);
};
</script>
</body></html>`;

// ---------------------------------------------------------------- server

function send(res, code, body, type = 'application/json') {
  res.writeHead(code, { 'content-type': type, 'cache-control': 'no-store' });
  res.end(body);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/' || url.pathname === '/index.html') {
    if (url.searchParams.get('t') !== TOKEN) return send(res, 401, 'bad token', 'text/plain');
    return send(res, 200, PAGE, 'text/html; charset=utf-8');
  }
  if (!url.pathname.startsWith('/api/')) return send(res, 404, 'not found', 'text/plain');
  if (url.searchParams.get('t') !== TOKEN) return send(res, 401, 'bad token', 'text/plain');

  try {
    if (url.pathname === '/api/connect') {
      const serial = await findTv();
      if (!serial) return send(res, 200, JSON.stringify({ error: 'TV nahi mila - USB debugging ON hai?' }));
      const info = await inspect(serial);
      return send(res, 200, JSON.stringify(info));
    }
    if (url.pathname === '/api/analyse') {
      const serial = await findTv();
      if (!serial) return send(res, 200, JSON.stringify({ error: 'TV nahi mila' }));
      return send(res, 200, JSON.stringify(await inspect(serial)));
    }
    if (url.pathname === '/api/clean') {
      const serial = await findTv();
      if (!serial) return send(res, 200, JSON.stringify({ error: 'TV nahi mila' }));
      const info = await inspect(serial);
      const result = await apply(serial, info.proposed, false);
      return send(res, 200, JSON.stringify(result));
    }
    if (url.pathname === '/api/restore') {
      const serial = await findTv();
      if (!serial) return send(res, 200, JSON.stringify({ error: 'TV nahi mila' }));
      return send(res, 200, JSON.stringify(await restoreLatest(serial)));
    }
    return send(res, 404, 'unknown api', 'text/plain');
  } catch (e) {
    return send(res, 500, JSON.stringify({ error: String(e && e.message || e) }));
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('');
  console.log('  FastUpTV web UI');
  console.log('  ---------------------------------------------');
  console.log(`  phone par kholo:  http://${lanIp()}:${PORT}/?t=${TOKEN}`);
  console.log('  (PC aur phone ek hi Wi-Fi par)');
  console.log('  band karne ke liye Ctrl+C');
  console.log('');
});
