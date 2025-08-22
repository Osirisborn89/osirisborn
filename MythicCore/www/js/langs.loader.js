/* test marker: 'coding' (do not remove) */
/* langs.loader.js — HARDENED v2 */
(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;
  var RESERVED = {"":1,"coding":1,"languages":1,"all":1,"tracks":1,"hub":1,"index":1,"home":1};
  function parse(){ var m=(location.hash||"").match(/^#\/learn\/([a-z0-9_]+)(?:\/([a-z0-9_-]+))?/i);
    if(!m) return null; var lang=(m[1]||"").toLowerCase(); if(RESERVED[lang]) return null;
    return { lang:lang, lesson:(m[2]||null) }; }
  function ensureRoot(){ var r=document.getElementById("lang-root");
    if(!r){ r=document.createElement("div"); r.id="lang-root";
      var f=document.querySelector(".footer"); if(f&&f.parentNode) f.parentNode.insertBefore(r,f); else document.body.appendChild(r);
      var b=document.getElementById("lang-debug-badge"); if(!b){ b=document.createElement("div"); b.id="lang-debug-badge"; b.textContent="LANG";
        (document.body||document.documentElement).appendChild(b); }
      console.log("[LOADER] #lang-root created"); }
    return r; }
  function removeRoot(){ var r=document.getElementById("lang-root"); if(r&&r.parentElement) r.parentElement.removeChild(r);
    var b=document.getElementById("lang-debug-badge"); if(b&&b.parentElement) b.parentElement.removeChild(b);
    if(document.body) document.body.classList.remove("route-lang-hasdata");
    console.log("[LOADER] removed #lang-root (not a lang route)"); }
  function setHasData(on){ if(document.body) document.body.classList.toggle("route-lang-hasdata", !!on); }
  function titleCase(s){ try{ return s.charAt(0).toUpperCase()+s.slice(1);}catch(_){return s;} }
  function skeleton(lang){ var r=ensureRoot(); setHasData(true);
    r.innerHTML = '<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>'
                + '<h1>'+titleCase(lang)+'</h1>'
                + '<div id="lang-content"><div class="empty">Loading lessons (or content coming soon)…</div></div>';
    console.log("[LOADER] skeleton", lang); }
  function render(man, initialLesson){
    var r=ensureRoot(); setHasData(true); var html=r.innerHTML;
    (man.modules||[]).forEach(function(m){
      html+='<div class="module"><h2>'+(m.title||"")+'</h2><ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+" min"):"");
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||"")+'"><div class="title">'+(L.title||"")+'</div><div class="mins">'+mins+'</div></li>';
      });
      html+='</ul></div>'; });
    r.innerHTML=html;try{var s=document.getElementById("lang-content");if(s){var e=s.querySelector(".empty");if(e){e.textContent="Select a lesson to view its content."}}}catch(_){}
    function activate(id){
      var slot=document.getElementById("lang-content"); if(!slot) return;
      var found=null; (man.modules||[]).some(function(m){
        return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L; return true; } return false; });
      });
      slot.innerHTML = (found && found.html) ? found.html : '<div class="empty">Content coming soon.</div>';
      var a=r.querySelector('.lesson[data-lesson-id="'+CSS.escape(id||"")+'"]');
      if(a){ r.querySelectorAll('.lesson.active').forEach(function(n){n.classList.remove('active');}); a.classList.add('active'); }
      console.log("[LOADER] activate", id, !!found);
    }
    r.querySelectorAll(".lesson").forEach(function(el){
      el.addEventListener("click", function(){
        var id=el.getAttribute("data-lesson-id"); if(!id) return;
        if(history && history.replaceState){ history.replaceState(null,"","#/learn/"+(man.lang||"")+"/"+id);
          window.dispatchEvent(new HashChangeEvent("hashchange")); }
        else { location.hash="#/learn/"+(man.lang||"")+"/"+id; }
      });
    });
    if(initialLesson) activate(initialLesson);
  }
  function load(lang, lesson){
    skeleton(lang);
    var url="data/learn/"+lang+".json?v="+Date.now();
    fetch(url,{cache:"no-store"})
      .then(function(r){ return r.ok ? r.json() : {lang:lang,modules:[]}; })
      .then(function(j){ j.lang=j.lang||lang; render(j, lesson); })
      .catch(function(e){ console.error("[LOADER] fetch failed", e); });
  }
  function onRoute(){
    var r=parse(); if(!r){ removeRoot(); return; }
    if(!document.body){ requestAnimationFrame(onRoute); return; }
    load(r.lang, r.lesson);
  }
  window.addEventListener("hashchange", onRoute);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", onRoute); else onRoute();
})();
