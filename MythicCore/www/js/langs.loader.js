(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;

  // Collect languages from links
  var LANGS=(function(){
    var set=new Set(); try{
      document.querySelectorAll('a[href^=""#/learn/""]').forEach(function(a){
        var parts=(a.getAttribute('href')||'').split('/');
        if(parts.length>=3 && parts[2]) set.add(parts[2].toLowerCase());
      });
    }catch(_){}
    return Array.from(set);
  })();

  function parseRoute(){
    var h=(location.hash||'').replace(/^#/,''), parts=h.split('/').filter(Boolean);
    if (parts[0] !== 'learn') return {lang:null, lesson:null};
    return { lang:(parts[1]||'').toLowerCase(), lesson: (parts[2]||null) };
  }
  function titleCase(s){ try { return s.charAt(0).toUpperCase() + s.slice(1); } catch(_){ return s; } }

  function ensureRoot(){
    var root = document.getElementById('lang-root');
    if (!root) {
      root = document.createElement('div');
      root.id = 'lang-root';
      var footer=document.querySelector('.footer');
      if (footer && footer.parentNode) footer.parentNode.insertBefore(root, footer);
      else document.body.appendChild(root);
    }
    return root;
  }
  function setHasData(on){
    document.body.classList.toggle('route-lang-hasdata', !!on);
  }

  function renderSkeleton(lang){
    setHasData(true);
    var root=ensureRoot();
    var html='';
    html+='<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html+='<h1>'+ titleCase(lang||'') +'</h1>';
    html+='<div id="lang-content"><div class="empty">Loading lessons (or content coming soon)…</div></div>';
    root.innerHTML=html;
  }

  function renderManifest(lang, manifest, initialLesson){
    setHasData(true);
    var root=ensureRoot();
    var html='';
    html+='<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html+='<h1>' + (manifest.title || titleCase(lang)) + '</h1>';
    html+='<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';
    (manifest.modules||[]).forEach(function(m){
      html+='<div class="module" data-module-id="'+(m.id||'m')+'">';
      html+='<h2>'+ (m.title||'') +'</h2>';
      html+='<ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+' min') : '');
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||'')+'">';
        html+='<div class="title">'+(L.title||'')+'</div><div class="mins">'+mins+'</div></li>';
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
      if(found && found.html){ slot.innerHTML=found.html; } else { slot.innerHTML='<div class="empty">Content coming soon.</div>'; }
    }

    // Click + keyboard
    root.querySelectorAll('.lesson').forEach(function(el){
      el.addEventListener('click', function(){
        var id=el.getAttribute('data-lesson-id'); if(!id) return;
        if(history && history.replaceState){
          history.replaceState(null,'',"#/learn/"+lang+"/"+id);
          window.dispatchEvent(new HashChangeEvent('hashchange'));
        } else {
          location.hash="#/learn/"+lang+"/"+id;
        }
      });
      el.addEventListener('keydown', function(e){
        if(e.key==='Enter' || e.key===' '){ e.preventDefault(); el.click(); }
      });
    });

    if(initialLesson){ activateLesson(initialLesson); }
  }

  function loadManifest(lang, lessonId){
    // Show skeleton immediately so page is never empty
    renderSkeleton(lang);
    var url = "data/learn/" + lang + ".json?v=" + Date.now();
    fetch(url, { cache: 'no-store' })
      .then(function(r){ if(!r.ok) throw new Error('missing'); return r.json(); })
      .then(function(json){ renderManifest(lang, json, lessonId); })
      .catch(function(){ /* keep skeleton */ });
  }

  function onRoute(){
    var r=parseRoute();
    if (!r.lang || LANGS.indexOf(r.lang) < 0) {
      // Not a language route → remove class so rest of app shows
      setHasData(false);
      return;
    }
    loadManifest(r.lang, r.lesson);
  }

  window.addEventListener('hashchange', onRoute);
  document.addEventListener('DOMContentLoaded', onRoute);
  window.addEventListener('portal:ready', onRoute);
  onRoute();
})();
