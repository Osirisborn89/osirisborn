(function(){
  if (window.__langsPlaceholderLoaded) return; window.__langsPlaceholderLoaded = true;
  var LANGS = ["bash","c","cpp","csharp","ctf","cyber","dart","go","haskell","htmlcss","java","javascript","js","kotlin","lua","matlab","php","python","r","ruby","rust","scala","sql","swift","typescript"];

  function currentLang(){
    var h = (location.hash || "").toLowerCase();
    for (var i=0;i<LANGS.length;i++){
      var id = LANGS[i];
      if (h === "#/learn/" + id || h.indexOf("#/learn/" + id + "/") === 0) return id;
    }
    return null;
  }

  function ensurePlaceholder(){
    try {
      var id = currentLang();
      var on = !!id;
      document.body.classList.toggle("route-lang-placeholder", on);
      var host = document.getElementById("lang-placeholder");

      if (on) {
        if (!host) {
          host = document.createElement("div");
          host.id = "lang-placeholder";
          var footer = document.querySelector(".footer");
          if (footer && footer.parentNode) { footer.parentNode.insertBefore(host, footer); }
          else { document.body.appendChild(host); }
        }
        // Minimal placeholder (empty canvas). You can add copy later if you want.
        host.innerHTML = "";
      } else {
        if (host) host.parentNode && host.parentNode.removeChild(host);
      }
    } catch(e) { /* no-op */ }
  }

  window.addEventListener("hashchange", ensurePlaceholder);
  document.addEventListener("DOMContentLoaded", ensurePlaceholder);
  window.addEventListener("portal:ready", ensurePlaceholder);
  ensurePlaceholder();
})();
