// sw-register.js (no await; SW v26)
(function () {
  if (!('serviceWorker' in navigator)) return;
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('/sw.js?v=27').then(
      function (reg) { console.log('[SW] registered ok; scope=', reg.scope); },
      function (err) { console.warn('[SW] register failed', err); }
    );
  });
})();

