(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;

  function parseRoute(){
    var h=(location.hash||'').replace(/^#/,''), parts=h.split('/').filter(Boolean);
    if(parts[0]!=='learn') return { lang:null, lesson:null };
    return { lang:(parts[1]||'').toLowerCase(), lesson:(parts[2]||null) };
  }
  var RESERVED = { '':1, 'coding':1, 'languages':1, 'all':1, 'tracks':1, 'hub':1, 'index':1, 'home':1 };

  function titleCase(s){ try{return s.charAt(0).toUpperCase()+s.slice(1);}catch(_){return s;} }
  function ensureRoot(){
    var r=document.getElementById('lang-root');
    if(!r){
      r=document.createElement('div'); r.id='lang-root';
      var f=document.querySelector('.footer'); if(f&&f.parentNode) f.parentNode.insertBefore(r,f); else document.body.appendChild(r);
    }
    return r;
  }
  function setHasData(on){ document.body.classList.toggle('route-lang-hasdata', !!on); }

  function renderSkeleton(lang){
    setHasData(true);
    var r=ensureRoot();
    r.innerHTML = '<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>'
                + '<h1>'+ titleCase(lang||'') +'</h1>'
                + '<div id="lang-content"><div class="empty">Loading lessons (or content coming soon)…</div></div>';
  }

  function renderManifest(lang, manifest, initialLesson){
    setHasData(true);
    var root=ensureRoot(), html='';
    html+='<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html+='<h1>'+(manifest.title||titleCase(lang))+'</h1>';
    html+='<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';
    (manifest.modules||[]).forEach(function(m){
      html+='<div class="module" data-module-id="'+(m.id||'m')+'"><h2>'+(m.title||'')+'</h2><ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+' min') : '');
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||'')+'"><div class="title">'+(L.title||'')+'</div><div class="mins">'+mins+'</div></li>';
      });
      html+='</ul></div>';
    });
    root.innerHTML=html;

    function activateLesson(id){
      root.querySelectorAll('.lesson.active').forEach(function(n){ n.classList.remove('active'); });
      var item=root.querySelector('.lesson[data-lesson-id="'+CSS.escape(id||'')+'"]');
      if(item){ item.classList.add('active'); try{ item.scrollIntoView({block:'nearest'});}catch(_){ } }
      var slot=document.getElementById('lang-content');
      var found=null;
      (manifest.modules||[]).some(function(m){
        return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L; return true; } return false; });
      });
      slot.innerHTML=(found&&found.html)?found.html:'<div class="empty">Content coming soon.</div>';
    }

    // deep-links
    root.querySelectorAll('.lesson').forEach(function(el){
      el.addEventListener('click', function(){
        var id=el.getAttribute('data-lesson-id'); if(!id) return;
        if(history&&history.replaceState){ history.replaceState(null,'',"#/learn/"+lang+"/"+id); window.dispatchEvent(new HashChangeEvent('hashchange')); }
        else { location.hash="#/learn/"+lang+"/"+id; }
      });
    });

    if(initialLesson){ activateLesson(initialLesson); }
  }

  function loadManifest(lang, lessonId){
    renderSkeleton(lang);
    fetch("data/learn/"+lang+".json?v="+Date.now(), {cache:'no-store'})
      .then(function(r){ if(!r.ok) throw new Error('missing'); return r.json(); })
      .then(function(json){ renderManifest(lang, json, lessonId); })
      .catch(function(){ /* keep skeleton */ });
  }

  function onRoute(){
    var r=parseRoute();
    if(!r.lang || RESERVED[r.lang]) { document.body.classList.remove('route-lang-hasdata'); return; }
    loadManifest(r.lang, r.lesson);
  }

  window.addEventListener('hashchange', onRoute);
  document.addEventListener('DOMContentLoaded', onRoute);
  window.addEventListener('portal:ready', onRoute);
  onRoute();
})();
