/* MythicCore/www/js/sw-register.js */
(function(){
  if (!("serviceWorker" in navigator)) {
    console.warn("[SW] not supported in this browser/env");
    return;
  }
  // Try immediately (DOMContentLoaded happens before load)
  const doRegister = async () => {
    try {
      const reg = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
      console.log("[SW] registered ok; scope=", reg.scope);
      // Ask the browser to check for updates shortly after
      setTimeout(() => reg.update?.(), 1500);
    } catch (err) {
      console.warn("[SW] register failed:", err);
    }
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", doRegister, { once:true });
  } else {
    doRegister();
  }

  // Debug: list existing registrations
  navigator.serviceWorker.getRegistrations?.().then(rs => {
    console.log("[SW] existing registrations:", rs.map(r => r.scope));
  }).catch(()=>{});
})();
