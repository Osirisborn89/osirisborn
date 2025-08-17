// osb-sw v21
const CACHE = "osb-sw-v21";

self.addEventListener("install", (e) => {
  self.skipWaiting();
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(["/", "/index.html"]).catch(()=>{})));
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("message", (e) => {
  if (e?.data?.type === "SKIP_WAITING") self.skipWaiting();
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  const url = new URL(req.url);

  if (req.method !== "GET") return;

  // Only handle same-origin
  if (url.origin !== location.origin) return;

  // HTML/doc navigations: network-first (fall back to cache)
  const isHTML = req.mode === "navigate" || req.destination === "document" || url.pathname.endsWith("/");
  if (isHTML) {
    e.respondWith(
      fetch(req).then(r => {
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(req, copy)).catch(()=>{});
        return r;
      }).catch(() => caches.match(req))
    );
    return;
  }

  // Always-fresh modules that change often
  const path = url.pathname;
  const alwaysFresh = (
    path.startsWith("/js/runner") ||
    path === "/lessons.js" ||
    path === "/client.js"
  );
  if (alwaysFresh) {
    e.respondWith(fetch(req).catch(() => caches.match(req)));
    return;
  }

  // Static assets: cache-first, then update in background
  e.respondWith(
    caches.match(req).then(cached => {
      const fetchPromise = fetch(req).then(r => {
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(req, copy)).catch(()=>{});
        return r;
      }).catch(()=>cached || Promise.reject("offline"));
      return cached || fetchPromise;
    })
  );
});
