(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;
  var LANGS = ["bash","c","cpp","csharp","ctf","cyber","dart","go","haskell","htmlcss","java","javascript","js","kotlin","lua","matlab","php","python","r","ruby","rust","scala","sql","swift","typescript"];

  function currentLang(){
    var h = (location.hash || "").toLowerCase();
    for (var i=0;i<LANGS.length;i++){
      var id = LANGS[i];
      if (h === "#/learn/" + id || h.indexOf("#/learn/" + id + "/") === 0) return id;
    }
    return null;
  }

  function titleCase(s){ try { return s.charAt(0).toUpperCase() + s.slice(1); } catch(_){ return s; } }

  function ensureRoot(){
    var root = document.getElementById("lang-root");
    if (!root) {
      root = document.createElement("div");
      root.id = "lang-root";
      var footer = document.querySelector(".footer");
      if (footer && footer.parentNode) footer.parentNode.insertBefore(root, footer); else document.body.appendChild(root);
    }
    return root;
  }

  function setHasData(on){
    document.body.classList.toggle("route-lang-hasdata", !!on);
    if (on) document.body.classList.remove("route-lang-placeholder");
  }

  function render(manifest){
    var root = ensureRoot();
    var html = "";
    html += '<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html += '<h1>' + (manifest.title || titleCase(manifest.lang || "")) + '</h1>';
    html += '<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';
    (manifest.modules || []).forEach(function(m){
      html += '<div class="module">';
      html += '<h2>' + (m.title || "") + '</h2>';
      html += '<ul class="lessons">';
      (m.lessons || []).forEach(function(L){
        var mins = (L.mins != null ? L.mins + " min" : "");
        html += '<li class="lesson" data-lesson-id="' + (L.id || "") + '">';
        html +=   '<div class="title">' + (L.title || "") + '</div>';
        html +=   '<div class="mins">' + mins + '</div>';
        html += '</li>';
      });
      html += '</ul></div>';
    });
    root.innerHTML = html;

    root.querySelectorAll(".lesson").forEach(function(el){
      el.addEventListener("click", function(){
        var id = el.getAttribute("data-lesson-id");
        var found;
        (manifest.modules || []).some(function(m){
          return (m.lessons || []).some(function(L){
            if (L.id === id) { found = L; return true; }
            return false;
          });
        });
        var slot = document.getElementById("lang-content");
        if (!slot) return;
        slot.innerHTML = (found && found.html) ? found.html : '<div class="empty">Content coming soon.</div>';
      });
    });
  }

  function loadManifest(lang){
    var url = "data/learn/" + lang + ".json?v=" + Date.now();
    return fetch(url, { cache: "no-store" })
      .then(function(r){ if (!r.ok) throw new Error("missing"); return r.json(); })
      .then(function(json){ setHasData(true); render(json); })
      .catch(function(){ setHasData(false); });
  }

  function onRoute(){
    var lang = currentLang();
    if (lang) loadManifest(lang); else setHasData(false);
  }

  window.addEventListener("hashchange", onRoute);
  document.addEventListener("DOMContentLoaded", onRoute);
  window.addEventListener("portal:ready", onRoute);
  onRoute();
})();
