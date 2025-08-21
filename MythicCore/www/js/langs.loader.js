(function(){
  if (window.__langsLoaderLoaded) return; window.__langsLoaderLoaded = true;

  // Lang list (from existing includes in portal)
  var LANGS=(function(){
    var set=new Set(); try{
      document.querySelectorAll('a[href^=""#/learn/""]').forEach(function(a){
        var id=a.getAttribute('href').split('/')[2]; if(id) set.add(id.toLowerCase());
      });
    }catch(_){}
    return Array.from(set);
  })();

  function parseRoute(){
    var h=(location.hash||'').replace(/^#/,''), parts=h.split('/').filter(Boolean);
    // Expect: ["learn", "<lang>", "<lessonId>?"]
    if(parts[0]!=='learn') return { lang:null, lesson:null };
    var lang=(parts[1]||'').toLowerCase();
    var lesson=(parts[2]||'')||null;
    return { lang:lang, lesson:lesson };
  }
  function titleCase(s){ try{return s.charAt(0).toUpperCase()+s.slice(1);}catch(_){return s;} }

  function ensureRoot(){
    var root=document.getElementById('lang-root');
    if(!root){
      root=document.createElement('div'); root.id='lang-root';
      var footer=document.querySelector('.footer');
      if(footer&&footer.parentNode) footer.parentNode.insertBefore(root,footer); else document.body.appendChild(root);
    }
    return root;
  }
  function setHasData(on){
    document.body.classList.toggle('route-lang-hasdata',!!on);
    if(on) document.body.classList.remove('route-lang-placeholder');
  }

  function saveExpanded(lang, ids){
    try{ sessionStorage.setItem('lms:'+lang+':expanded', JSON.stringify(ids||[])); }catch(_){}
  }
  function loadExpanded(lang){
    try{ return JSON.parse(sessionStorage.getItem('lms:'+lang+':expanded')||'[]'); }catch(_){ return []; }
  }

  function renderManifest(lang, manifest, initialLesson){
    var root=ensureRoot();
    var expanded=new Set(loadExpanded(lang));

    var html='';
    html+='<div class="lang-meta"><a href="#/learn/coding">← Back to Languages</a></div>';
    html+='<h1>'+(manifest.title||titleCase(lang))+'</h1>';
    html+='<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';

    (manifest.modules||[]).forEach(function(m){
      var mid=m.id||Math.random().toString(36).slice(2);
      var isOpen=!expanded.size || expanded.has(mid); // if none saved, default open
      html+='<div class="module'+(isOpen?'':' collapsed')+'" data-module-id="'+mid+'">';
      html+='<h2>'+ (m.title||'') +'</h2>';
      html+='<ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+' min') : '');
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||'')+'"><div class="title">'+(L.title||'')+'</div><div class="mins">'+mins+'</div></li>';
      });
      html+='</ul></div>';
    });

    root.innerHTML=html;

    // Accordion toggle
    root.querySelectorAll('.module h2').forEach(function(h2){
      h2.addEventListener('click', function(){
        var mod=h2.parentElement;
        var id=mod.getAttribute('data-module-id');
        mod.classList.toggle('collapsed');
        var ids=new Set(loadExpanded(lang));
        if(mod.classList.contains('collapsed')) ids.delete(id); else ids.add(id);
        saveExpanded(lang, Array.from(ids));
      });
    });

    function activateLesson(id){
      // set active state
      root.querySelectorAll('.lesson.active').forEach(function(n){ n.classList.remove('active'); });
      var item=root.querySelector('.lesson[data-lesson-id="'+CSS.escape(id||'')+'"]');
      if(item){ item.classList.add('active'); try{ item.scrollIntoView({block:'nearest'}); }catch(_){ } }
      // render content
      var slot=document.getElementById('lang-content');
      var found=null;
      (manifest.modules||[]).some(function(m){
        return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L; return true; } return false; });
      });
      if(found && found.html){ slot.innerHTML=found.html; } else { slot.innerHTML='<div class="empty">Content coming soon.</div>'; }
    }

    // Click/keyboard handlers + deep-link update
    root.querySelectorAll('.lesson').forEach(function(el){
      el.addEventListener('click', function(){
        var id=el.getAttribute('data-lesson-id');
        if(!id) return;
        if(history && history.replaceState){
          history.replaceState(null,'',"#/learn/"+lang+"/"+id);
          window.dispatchEvent(new HashChangeEvent('hashchange'));
        } else {
          location.hash="#/learn/"+lang+"/"+id;
        }
      });
      el.addEventListener('keydown', function(e){
        if(e.key==='Enter' || e.key===' '){ e.preventDefault(); el.click(); return; }
        var items=Array.from(root.querySelectorAll('.lesson'));
        var idx=items.indexOf(el);
        if(e.key==='ArrowDown' && idx<items.length-1){ items[idx+1].focus(); e.preventDefault(); }
        if(e.key==='ArrowUp' && idx>0){ items[idx-1].focus(); e.preventDefault(); }
      });
    });

    // Auto-open module containing initial lesson
    if(initialLesson){
      var host=root.querySelector('.lesson[data-lesson-id="'+CSS.escape(initialLesson)+'"]');
      if(host){
        var mod=host.closest('.module'); if(mod && mod.classList.contains('collapsed')){
          mod.classList.remove('collapsed');
          var id=mod.getAttribute('data-module-id'); var ids=new Set(loadExpanded(lang)); ids.add(id); saveExpanded(lang,Array.from(ids));
        }
        activateLesson(initialLesson);
      }
    }
  }

  function loadManifest(lang, lessonId){
    var url="data/learn/"+lang+".json?v="+Date.now();
    return fetch(url,{cache:'no-store'}).then(function(r){ if(!r.ok) throw new Error('missing'); return r.json(); })
      .then(function(json){ setHasData(true); renderManifest(lang, json, lessonId); })
      .catch(function(){ setHasData(false); });
  }

  function onRoute(){
    var r=parseRoute();
    if(!r.lang || LANGS.indexOf(r.lang)<0){ setHasData(false); return; }
    loadManifest(r.lang, r.lesson);
  }

  window.addEventListener('hashchange', onRoute);
  document.addEventListener('DOMContentLoaded', onRoute);
  window.addEventListener('portal:ready', onRoute);
  onRoute();
})();
