/* sw-register v24 */
(() => {
  if (!("serviceWorker" in navigator)) return;

  const SW_URL = "/sw.js?v=24";
  let hasHandledControllerChange = false;

  async function registerSW() {
    try {
      const reg = await navigator.serviceWorker.register(SW_URL, { scope: "/" });
      console.log("[SW] registered ok; scope=", reg.scope);

      // Pull the latest SW immediately.
      try { await reg.update(); } catch {}

      // If a new worker is waiting, activate it now.
      if (reg.waiting) {
        try { reg.waiting.postMessage({ type: "SKIP_WAITING" }); } catch {}
      }

      // Watch for updates being found.
      reg.addEventListener("updatefound", () => {
        const sw = reg.installing;
        if (!sw) return;
        sw.addEventListener("statechange", () => {
          if (sw.state === "installed" && navigator.serviceWorker.controller) {
            // New content available.
            try { window.dispatchEvent(new CustomEvent("osb:sw:update-available")); } catch {}
            try { if (typeof window.toast === "function") window.toast("Update ready"); } catch {}
          }
        });
      });

      // Log when the controller changes (updated SW takes control).
      navigator.serviceWorker.addEventListener("controllerchange", () => {
        if (hasHandledControllerChange) return;
        hasHandledControllerChange = true;
        console.log("[SW] controller changed");
        // Intentionally NOT auto-reloading to avoid disrupting the session.
      });

      // Expose a helper to trigger update/activation manually if needed.
      window.osbSW = {
        async updateNow() {
          const r = await navigator.serviceWorker.getRegistration("/");
          if (!r) return false;
          try { await r.update(); } catch {}
          if (r.waiting) {
            try { r.waiting.postMessage({ type: "SKIP_WAITING" }); } catch {}
          }
          return true;
        }
      };
    } catch (e) {
      console.warn("[SW] registration failed", e);
    }
  }

  window.addEventListener("load", registerSW, { once: true });
})();
