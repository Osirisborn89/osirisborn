/* osb service worker — v24 */
const VERSION = "osb-sw-v25";
const STATIC_CACHE = VERSION;
const OFFLINE_URL = "/index.html";

const PRECACHE_URLS = [
  "/",                // root
  "/index.html",

  // Styles
  "/lessons.css",
  "/runner.css",
  "/xp-panel.css",

  // Scripts (site root)
  "/xp-panel.js",
  "/client.js",
  "/lessons.js",

  // Scripts (under /js)
  "/js/db.js",
  "/js/outbox.js",
  "/js/backup.js",
  "/js/runner.js",
  "/js/live-xp.js",
  "/js/sw-register.js?v=24",

  // Assets
  "/favicon.svg"
];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(STATIC_CACHE);

    // Precache each URL individually so a 404 doesn't fail the whole install
    await Promise.all(PRECACHE_URLS.map(async (url) => {
      try {
        // cache:'reload' to bypass HTTP cache
        await cache.add(new Request(url, { cache: "reload" }));
      } catch (e) {
        // Non-fatal: log and continue
        console.warn("[SW] precache skipped:", url, e && e.message);
      }
    }));
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    // Clean up old caches
    const names = await caches.keys();
    await Promise.all(
      names
        .filter((n) => n !== STATIC_CACHE)
        .map((n) => caches.delete(n))
    );

    try { await self.clients.claim(); } catch {}
  })());
});

// Messages from the page (e.g., SKIP_WAITING)
self.addEventListener("message", (event) => {
  const data = event && event.data;
  if (!data) return;

  if (data.type === "SKIP_WAITING") {
    self.skipWaiting();
  }
});

self.addEventListener("fetch", (event) => {
  const req = event.request;

  // Only handle GET
  if (req.method !== "GET") return;

  const url = new URL(req.url);

  // Ignore cross-origin
  if (url.origin !== location.origin) return;

  // Decide strategy
  if (isHTMLRequest(req)) {
    // Navigation requests: network-first, fallback to cache, then offline
    event.respondWith(networkFirstHTML(req));
    return;
  }

  if (isAPIorJSON(url)) {
    // API/JSON: network-first with stale fallback
    event.respondWith(networkFirstJSON(req));
    return;
  }

  // Static assets: cache-first with background update
  event.respondWith(cacheFirstStatic(req));
});

/* ----------------- helpers ----------------- */

function isHTMLRequest(req) {
  return req.mode === "navigate" ||
    (req.headers.get("accept") || "").includes("text/html");
}

function isAPIorJSON(url) {
  const p = url.pathname;
  return (
    p.startsWith("/api/") ||
    p.endsWith(".json") ||
    p === "/xp.json" ||
    p === "/diag"
  );
}

async function networkFirstHTML(req) {
  try {
    const fresh = await fetch(req);
    // Optionally update cache in background
    const cache = await caches.open(STATIC_CACHE);
    cache.put(OFFLINE_URL, fresh.clone()).catch(()=>{});
    return fresh;
  } catch {
    const cached = await caches.match(req);
    if (cached) return cached;

    const offline = await caches.match(OFFLINE_URL);
    if (offline) return offline;

    // Ultimate fallback
    return new Response("<h1>Offline</h1>", {
      headers: { "Content-Type": "text/html; charset=UTF-8" },
      status: 503
    });
  }
}

async function networkFirstJSON(req) {
  const cache = await caches.open(STATIC_CACHE);
  try {
    const fresh = await fetch(req, { cache: "no-store" });
    // Only cache 200s to avoid persisting errors
    if (fresh && fresh.ok) cache.put(req, fresh.clone()).catch(()=>{});
    return fresh;
  } catch {
    const cached = await caches.match(req);
    if (cached) return cached;
    return new Response(JSON.stringify({ error: "offline" }), {
      headers: { "Content-Type": "application/json" },
      status: 503
    });
  }
}

async function cacheFirstStatic(req) {
  const cache = await caches.open(STATIC_CACHE);
  const cached = await caches.match(req);
  if (cached) {
    // Try to refresh in background (best-effort)
    fetch(req).then((fresh) => {
      if (fresh && fresh.ok) cache.put(req, fresh).catch(()=>{});
    }).catch(()=>{});
    return cached;
  }
  try {
    const fresh = await fetch(req);
    if (fresh && fresh.ok) cache.put(req, fresh.clone()).catch(()=>{});
    return fresh;
  } catch {
    // Last resort: offline page for html-like paths
    if (isLikelyHTMLPath(req.url)) {
      const offline = await caches.match(OFFLINE_URL);
      if (offline) return offline;
    }
    return new Response("Offline", { status: 503 });
  }
}

function isLikelyHTMLPath(u) {
  try {
    const url = new URL(u);
    // Heuristic: no file extension or looks like .html
    const hasDot = url.pathname.split("/").pop().includes(".");
    return !hasDot || url.pathname.endsWith(".html");
  } catch {
    return false;
  }
}
