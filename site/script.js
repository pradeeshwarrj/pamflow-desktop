/*
  pamflow Desktop website - small script (no libraries).
  1. Light / dark switch (remembers the choice, otherwise follows the system).
  2. Screenshot tabs.
  3. Download buttons: look up the newest GitHub release and point each button
     at the right file. If that fails, the buttons keep their fallback link to
     the Releases page, so the page always works.
*/

const REPO = 'pradeeshwarrj/pamflow-desktop';

// Which release file belongs to which button (matched on the file name).
const FILES = {
  windows: /x64-setup\.exe$/i,
  'mac-arm': /aarch64\.dmg$/i,
  'mac-intel': /x64\.dmg$/i,
  appimage: /\.AppImage$/i,
  deb: /\.deb$/i
};

// ---- 1. Theme ----
const root = document.documentElement;
const themeButton = document.getElementById('theme');
function applyTheme(mode) {
  root.dataset.theme = mode;
  themeButton.textContent = mode === 'dark' ? '☀' : '☾';
  themeButton.setAttribute('aria-label', mode === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
}
let saved = null;
try { saved = localStorage.getItem('pamflow-site-theme'); } catch { /* storage can be blocked */ }
applyTheme(saved || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'));
themeButton.addEventListener('click', () => {
  const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
  applyTheme(next);
  try { localStorage.setItem('pamflow-site-theme', next); } catch { /* ignore */ }
});

// ---- 2. Screenshot tabs ----
const tabs = [...document.querySelectorAll('.tab')];
const panels = [...document.querySelectorAll('.panel')];
tabs.forEach((tab) =>
  tab.addEventListener('click', () => {
    tabs.forEach((t) => t.setAttribute('aria-selected', String(t === tab)));
    panels.forEach((p) => (p.hidden = p.id !== tab.dataset.panel));
  })
);

// ---- 3. Downloads ----
function detectSystem() {
  const text = (navigator.userAgentData?.platform || navigator.platform || '') + ' ' + navigator.userAgent;
  if (/win/i.test(text)) return 'windows';
  if (/mac/i.test(text) && !/iphone|ipad/i.test(text)) return 'mac';
  if (/linux|x11/i.test(text) && !/android/i.test(text)) return 'linux';
  return null;
}
const system = detectSystem();

function megabytes(bytes) {
  return bytes >= 1e9 ? (bytes / 1e9).toFixed(1) + ' GB' : Math.round(bytes / 1e6) + ' MB';
}

document.querySelectorAll('.dl').forEach((card) => {
  if (card.dataset.system === system) card.classList.add('mine');
});

const heroButton = document.getElementById('hero-download');
const heroNames = { windows: 'Windows', mac: 'macOS', linux: 'Linux' };
if (system) heroButton.textContent = 'Download for ' + heroNames[system];

// Newest published release. The list is used instead of /releases/latest because that one
// skips pre-releases, and the first releases are marked as pre-release.
fetch(`https://api.github.com/repos/${REPO}/releases?per_page=5`, { headers: { Accept: 'application/vnd.github+json' } })
  .then((response) => (response.ok ? response.json() : Promise.reject(new Error(response.status))))
  .then((releases) => {
    const release = releases.find((r) => !r.draft);
    if (!release) return;
    const version = (release.tag_name || '').replace(/^v/, '');
    document.querySelectorAll('[data-version]').forEach((el) => (el.textContent = version ? 'Version ' + version : ''));
    for (const link of document.querySelectorAll('[data-file]')) {
      const asset = release.assets.find((a) => FILES[link.dataset.file]?.test(a.name));
      if (!asset) continue;
      link.href = asset.browser_download_url;
      const size = link.querySelector('.size');
      if (size) size.textContent = ' · ' + megabytes(asset.size);
    }
    // The big button in the hero goes straight to the file for this system.
    const wanted = { windows: 'windows', mac: 'mac-arm', linux: 'appimage' }[system];
    const asset = wanted && release.assets.find((a) => FILES[wanted].test(a.name));
    if (asset && system !== 'mac') heroButton.href = asset.browser_download_url;
  })
  .catch(() => { /* keep the fallback links to the Releases page */ });
