(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;
feature/learn-mvp-harden

  var RESERVED = { "":1,'coding':1,"languages":1,"all":1,"tracks":1,"hub":1,"index":1,"home":1 };

  function parseRoute(){
    var h=(location.hash||"").replace(/^#/,""), parts=h.split("/").filter(Boolean);
    if(parts[0]!=="learn") return { lang:null, lesson:null };
    return { lang:(parts[1]||"").toLowerCase(), lesson:(parts[2]||null) };
  }
  function titleCase(s){ try{return s.charAt(0).toUpperCase()+s.slice(1);}catch(_){return s;} }
  function ensureRoot(){
    var r=document.getElementById("lang-root");
    if(!r){ r=document.createElement("div"); r.id="lang-root";
      var f=document.querySelector(".footer"); if(f&&f.parentNode) f.parentNode.insertBefore(r,f); else document.body.appendChild(r);
    }
    return r;
  }
  function setHasData(on){ document.body.classList.toggle("route-lang-hasdata", !!on); }

  function sum(arr, fn){ var t=0; for(var i=0;i<arr.length;i++){ t += +fn(arr[i])||0; } return t; }

  function renderSkeleton(lang){
    setHasData(true);
    var r=ensureRoot();
    r.innerHTML = '<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>'
                + '<h1>'+titleCase(lang||"")+'</h1>'
                + '<div class="lang-stats">Loading…</div>'
                + '<div id="lang-content"><div class="empty">Loading lessons (or content coming soon)…</div></div>';
  }

  function renderManifest(lang, manifest, initialLesson){
    setHasData(true);
    var root=ensureRoot();
    var modules=(manifest.modules||[]);
    var lessonCount = sum(modules, function(m){ return (m.lessons||[]).length; });
    var minuteCount = sum(modules, function(m){ return sum(m.lessons||[], function(L){ return L.mins||0; }); });

    var html='';
    html+='<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html+='<h1>'+(manifest.title||titleCase(lang))+'</h1>';
    html+='<div class="lang-stats">'+modules.length+' modules • '+lessonCount+' lessons • '+minuteCount+' min</div>';
    html+='<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';

    modules.forEach(function(m){
      var mid=m.id||Math.random().toString(36).slice(2);
      html+='<div class="module" data-module-id="'+mid+'">';
      html+='<h2>'+(m.title||"")+'</h2>';
      html+='<ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+" min") : "");
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||"")+'"><div class="title">'+(L.title||"")+'</div><div class="mins">'+mins+'</div></li>';
      });
      html+='</ul></div>';
    });

    root.innerHTML=html;

    // Accordion toggle
    root.querySelectorAll(".module h2").forEach(function(h2){
      h2.addEventListener("click", function(){
        var mod=h2.parentElement;
        mod.classList.toggle("collapsed");
      });
    });

    function activateLesson(id){
      root.querySelectorAll(".lesson.active").forEach(function(n){ n.classList.remove("active"); });
      var item=root.querySelector('.lesson[data-lesson-id="'+CSS.escape(id||"")+'"]');
      if(item){ item.classList.add("active"); try{ item.scrollIntoView({block:"nearest"});}catch(_){ } }
      var slot=document.getElementById("lang-content");
      var found=null;
      modules.some(function(m){ return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L; return true; } return false; }); });
      slot.innerHTML = (found && found.html) ? found.html : '<div class="empty">Content coming soon.</div>';
    }

    // Click + keyboard + deep-links
    root.querySelectorAll(".lesson").forEach(function(el){
      el.addEventListener("click", function(){
        var id=el.getAttribute("data-lesson-id"); if(!id) return;
        if(history&&history.replaceState){ history.replaceState(null,"","#/learn/"+lang+"/"+id); window.dispatchEvent(new HashChangeEvent("hashchange")); }
        else { location.hash="#/learn/"+lang+"/"+id; }
      });
      el.addEventListener("keydown", function(e){
        if(e.key==="Enter"||e.key===" "){ e.preventDefault(); el.click(); return; }
        var items=Array.from(root.querySelectorAll(".lesson")); var idx=items.indexOf(el);
        if(e.key==="ArrowDown" && idx<items.length-1){ items[idx+1].focus(); e.preventDefault(); }
        if(e.key==="ArrowUp" && idx>0){ items[idx-1].focus(); e.preventDefault(); }
      });
    });

    if(initialLesson){ activateLesson(initialLesson); }
  }

  function loadManifest(lang, lessonId){
    renderSkeleton(lang);
    fetch("data/learn/"+lang+".json?v="+Date.now(), {cache:"no-store"})
      .then(function(r){ if(!r.ok) throw new Error("missing"); return r.json(); })
      .then(function(json){ renderManifest(lang, json, lessonId); })
      .catch(function(){ /* keep skeleton */ });
  }

  function onRoute(){
    var r=parseRoute();
    if(!r.lang || RESERVED[r.lang]){ document.body.classList.remove("route-lang-hasdata"); return; }
    loadManifest(r.lang, r.lesson);

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
main
  }

  window.addEventListener("hashchange", onRoute);
  document.addEventListener("DOMContentLoaded", onRoute);
  window.addEventListener("portal:ready", onRoute);
  onRoute();
})();
