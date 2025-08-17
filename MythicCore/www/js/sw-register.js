// sw-register v21
if ("serviceWorker" in navigator) {
  window.addEventListener("load", async () => {
    try {
      const reg = await navigator.serviceWorker.register("/sw.js?v=21");
      console.log("[SW] registered ok; scope=", reg.scope);
      try { await reg.update(); } catch {}
      if (reg.waiting) { reg.waiting.postMessage({ type:"SKIP_WAITING" }); }
      navigator.serviceWorker.addEventListener("controllerchange", () => {
        console.log("[SW] controller changed");
      });
    } catch (e) {
      console.warn("[SW] registration failed", e);
    }
  });
}
