/* MythicCore/www/sw.js */
const CACHE = "osb-v3-2025-08-17-03";
const ORIGIN = self.location.origin;

const PRECACHE = [
  "/",
  "/client.js",
  "/lessons.js",
  "/js/outbox.js",
  "/js/backup.js",
  "/js/sw-register.js",
  "/xp-panel.css",
  "/xp-panel.js",
  "/lessons.css",
  "/favicon.svg",
];

self.addEventListener("install", (event) => {
  self.skipWaiting();
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    for (const url of PRECACHE) {
      try { await cache.add(new Request(url, { cache: "reload" })); } catch {}
    }
  })());
});

self.addEventListener("activate", (event) => {
  clients.claim();
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(n => n.startsWith("osb-") && n !== CACHE).map(n => caches.delete(n)));
  })());
});

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  // Navigations -> network-first, fallback to cached "/"
  if (req.mode === "navigate") {
    event.respondWith((async () => {
      try { return await fetch(req); }
      catch {
        const cache = await caches.open(CACHE);
        return (await cache.match("/")) || Response.error();
      }
    })());
    return;
  }

  if (url.origin !== ORIGIN) return;

  // API -> network-first; Outbox handles offline writes
  const isAPI = url.pathname.startsWith("/api/") || url.pathname === "/xp.json";
  if (isAPI) {
    event.respondWith(fetch(req).catch(() => Response.error()));
    return;
  }

  // Static -> cache-first
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(req);
    if (hit) return hit;
    try {
      const res = await fetch(req);
      if (res && res.ok && res.type === "basic") cache.put(req, res.clone());
      return res;
    } catch { return Response.error(); }
  })());
});
