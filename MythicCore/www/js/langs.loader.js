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

  function titleCase(s){
    try { return s.charAt(0).toUpperCase() + s.slice(1); } catch(_) { return s; }
  }

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
    // If we show data, remove the placeholder class so the rest of the page isn't hidden
    if (on) document.body.classList.remove("route-lang-placeholder");
  }

  function renderManifest(lang, manifest){
    var root = ensureRoot();
    // Basic structure: title + meta + content + module/lesson list
    var html = "";
    html += '<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html += '<h1>' + (manifest.title || titleCase(lang)) + '</h1>';
    html += '<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';

    // Modules + lessons
    (manifest.modules || []).forEach(function(m){
      html += '<div class="module">';
      html += '<h2>' + (m.title || "") + '</h2>';
      html += '<ul class="lessons">';
      (m.lessons || []).forEach(function(lesson){
        var mins = (lesson.mins != null ? lesson.mins + " min" : "");
        html += '<li class="lesson" data-lesson-id="' + (lesson.id || "") + '">';
        html += '<div class="title">' + (lesson.title || "") + '</div>';
        html += '<div class="mins">' + mins + '</div>';
        html += '</li>';
      });
      html += '</ul></div>';
    });

    root.innerHTML = html;

    // Click handler to display lesson HTML in #lang-content
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
        if (found && found.html) {
          slot.innerHTML = found.html;
        } else {
          slot.innerHTML = '<div class="empty">Content coming soon.</div>';
        }
      });
    });
  }

  function loadManifest(lang){
    // Fetch JSON with cache-bust; if missing → keep placeholder
    var url = "data/learn/" + lang + ".json?v=" + Date.now();
    return fetch(url, { cache: "no-store" })
      .then(function(r){
        if (!r.ok) throw new Error("not ok");
        return r.json();
      })
      .then(function(json){
        setHasData(true);
        renderManifest(lang, json);
      })
      .catch(function(){
        setHasData(false);
      });
  }

  function onRoute(){
    var lang = currentLang();
    if (lang) { loadManifest(lang); }
    else { setHasData(false); }
  }

  window.addEventListener("hashchange", onRoute);
  document.addEventListener("DOMContentLoaded", onRoute);
  window.addEventListener("portal:ready", onRoute);
  onRoute();
})();
