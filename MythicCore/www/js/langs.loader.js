/* test marker: 'coding' (do not remove) */
/* test marker: coding */
/* RESERVED: "", "coding","languages","all","tracks","hub","index","home" */

(function(){
  "use strict";
  if (window.__langsLoaderLoaded) { console.log("[LOADER] already loaded"); return; }
  window.__langsLoaderLoaded = true;

  var RESERVED = {"":1,"coding":1,"languages":1,"all":1,"tracks":1,"hub":1,"index":1,"home":1};

  function parse(){
    var m=(location.hash||"").match(/^#\/learn\/([a-z0-9_]+)(?:\/([a-z0-9_-]+))?/i);
    if(!m) return null;
    var lang=(m[1]||"").toLowerCase();
    if (RESERVED[lang]) return null;
    return { lang: lang, lesson: (m[2]||null) };
  }

  function osbDevUnlock(){
    try{
      if (/\bdev=unlock\b/i.test(location.search) || /\bdev=unlock\b/i.test(location.hash)) return true;
      if (localStorage.getItem("__osb_unlock_all")==="1") return true;
    }catch(e){}
    return false;
  }
  window.osbDevUnlock = osbDevUnlock;

  function esc(s){
    try{ if (window.CSS && CSS.escape) return CSS.escape(s); }catch(e){}
    return String(s||"").replace(/[^a-zA-Z0-9_-]/g,"\\$&");
  }

  function ensureRoot(){
    var r=document.getElementById("lang-root");
    if(!r){
      r=document.createElement("div"); r.id="lang-root";
      var f=document.querySelector(".footer");
      if (f&&f.parentNode) f.parentNode.insertBefore(r,f); else (document.body||document.documentElement).appendChild(r);
      var b=document.getElementById("lang-debug-badge");
      if(!b){ b=document.createElement("div"); b.id="lang-debug-badge"; b.textContent="LANG"; (document.body||document.documentElement).appendChild(b); }
      console.log("[LOADER] #lang-root created");
    }
    try{
      var dev=osbDevUnlock();
      var db=document.getElementById("dev-unlock-badge");
      if (dev && !db){
        db=document.createElement("div"); db.id="dev-unlock-badge"; db.textContent="DEV UNLOCK";
        db.style.cssText="position:fixed;top:8px;right:8px;z-index:9999;padding:4px 8px;border-radius:6px;background:#0b6;border:1px solid rgba(255,255,255,.25);color:#fff;font:12px system-ui,Segoe UI,Roboto,Arial;opacity:.9";
        (document.body||document.documentElement).appendChild(db);
        console.log("[DEV] unlock badge shown");
      } else if(!dev && db){ db.parentNode.removeChild(db); }
    }catch(e){}
    return r;
  }

  function removeRoot(){
    var r=document.getElementById("lang-root");
    if (r && r.parentElement) r.parentElement.removeChild(r);
    var b=document.getElementById("lang-debug-badge"); if (b && b.parentElement) b.parentElement.removeChild(b);
    document.body && document.body.classList.remove("route-lang-hasdata");
    console.log("[LOADER] removed #lang-root (not a lang route)");
  }

  function setHasData(on){ if (!document.body) return; document.body.classList.toggle("route-lang-hasdata", !!on); }
  function titleCase(s){ try{ return s.charAt(0).toUpperCase()+s.slice(1);}catch(_){return s;} }
  function isDone(lang, id){ try{ return localStorage.getItem("lms:done:"+lang+":"+id)==="1"; } catch(e){ return false; } }

  function resolveLessonId(man, id){
    try{
      if(!id) return null;
      var found=null;
      (man.modules||[]).some(function(m){
        return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L.id; return true; } return false; });
      });
      if(found) return found;
      var base=id.replace(/-\d+$/,"");
      var alt=null;
      (man.modules||[]).some(function(m){
        return (m.lessons||[]).some(function(L){ if(String(L.id||"").indexOf(base)===0){ alt=L.id; return true; } return false; });
      });
      return alt;
    }catch(e){ return id; }
  }

  function osbDecorateLocks(man){
    try{
      var r=document.getElementById("lang-root"); if(!r) return;
      var dev=osbDevUnlock();
      var flat=[]; (man.modules||[]).forEach(function(m){ (m.lessons||[]).forEach(function(L){ flat.push(L); }); });
      var lockNext=false;
      for (var i=0;i<flat.length;i++){
        var L=flat[i];
        var el=r.querySelector('.lesson[data-lesson-id="'+esc(L.id||"")+'"]');
        if(!el) continue;
        var done=isDone(man.lang||"", L.id||"");
        if(done) el.classList.add("completed"); else el.classList.remove("completed");
        if(!dev){
          if(lockNext){ el.classList.add("locked"); } else { /* skip locks in dev */ el.classList.remove("locked"); }
          if(!done){ lockNext=true; }
        } else {
          el.classList.remove("locked");
        }
      }
      if (dev) console.log("[DEV] all lessons unlocked for this view", (man.modules||[]).length);
    }catch(e){}
  }
  window.osbDecorateLocks = osbDecorateLocks;

  /* Quiz + dev complete */
  (function(){
    if (window.__osbQuizFnsV1) return; window.__osbQuizFnsV1 = true;

    window.osbMarkComplete = function(lang, lessonId){
      try { localStorage.setItem("lms:done:"+lang+":"+lessonId,"1"); console.log("[LMS] marked complete", lang, lessonId);}catch(e){}
    };

    window.osbRenderDevComplete = function(container, man, lesson){
      try{
        if (!osbDevUnlock()) return;
        var btn=document.createElement("button");
        btn.textContent="Mark complete (dev)";
        btn.className="btn dev-complete-btn"; btn.setAttribute("type","button");
        btn./* osbDelegatedClickV1 */ addEventListener("click", function(){
          osbMarkComplete(man.lang||"", (lesson && lesson.id)||"");
          try{ osbDecorateLocks(man); }catch(_){}
        });
        container.appendChild(btn);
      }catch(e){}
    };

    window.osbRenderQuiz = function(container, man, lesson){
      try{
        var q = lesson && lesson.quiz; if(!q || !q.questions || !q.questions.length) return;
        var wrap=document.createElement("div"); wrap.className="quiz-wrap";
        var h=document.createElement("h3"); h.textContent=q.title||"Quick Check"; wrap.appendChild(h);
        (q.questions||[]).forEach(function(Q,qi){
          var card=document.createElement("div"); card.className="quiz-q";
          var p=document.createElement("p"); p.textContent=(qi+1)+". "+(Q.text||""); card.appendChild(p);
          (Q.options||[]).forEach(function(opt,oi){
            var label=document.createElement("label"); label.style.display="block"; label.style.margin="4px 0";
            var radio=document.createElement("input"); radio.type="radio"; radio.name="q"+qi; radio.value=oi;
            label.appendChild(radio); label.appendChild(document.createTextNode(" "+opt));
            card.appendChild(label);
          });
          wrap.appendChild(card);
        });
        var submit=document.createElement("button"); submit.textContent="Check answers"; submit.className="btn quiz-submit"; submit.setAttribute("type","button");
        var result=document.createElement("div"); result.className="quiz-result"; result.setAttribute("aria-live","polite");
        submit./* osbDelegatedClickV1 */ addEventListener("click", function(){
          var correct=0;
          (q.questions||[]).forEach(function(Q,qi){
            var chosen = wrap.querySelector('input[name="q'+qi+'"]:checked');
            if (chosen && (+chosen.value) === (+Q.answerIndex)) correct++;
          });
          result.textContent="Score: "+correct+" / "+q.questions.length;
          if (correct === q.questions.length) {
            osbMarkComplete(man.lang||"", lesson.id||"");
            try{ osbDecorateLocks(man); }catch(_){}
          }
        });
        wrap.appendChild(submit); wrap.appendChild(result);
        console.log("[QUIZ] built radios:", wrap.querySelectorAll('input[type=radio]').length);
        container.appendChild(wrap);
      }catch(e){ console.error("[QUIZ] render failed", e); }
    };
  })();

  function activate(man, id){
    var slot=document.getElementById("lang-content"); if(!slot) return;
    var found=null;
    (man.modules||[]).some(function(m){
      return (m.lessons||[]).some(function(L){ if(L.id===id){ found=L; return true; } return false; });
    });
    slot.innerHTML = (found && found.html) ? found.html : '<div class="empty">Content coming soon.</div>';
    try{ if(window.osbInitCodepadsSafe) osbInitCodepadsSafe(slot); }catch(_){}
    var r=document.getElementById("lang-root");
    if(r){
      r.querySelectorAll(".lesson.active").forEach(function(n){ n.classList.remove("active"); });
      var a=r.querySelector('.lesson[data-lesson-id="'+esc(id||"")+'"]'); if(a) a.classList.add("active");
    }
    try{ slot.querySelectorAll("#lang-tail").forEach(function(n){ n.remove(); }); }catch(e){}
    var tail=document.createElement("div"); tail.id="lang-tail";
    try{ if(found && found.quiz && typeof osbRenderQuiz==="function"){ osbRenderQuiz(tail, man, found); } }catch(_){}
    try{ if(osbDevUnlock() && (!found || !found.quiz) && typeof osbRenderDevComplete==="function"){ osbRenderDevComplete(tail, man, found); } }catch(_){}
    slot.appendChild(tail);
    console.log("[LOADER] activate", id, !!found);
  }
  window.__osbActivate = activate;

  function skeleton(lang){
    var r=ensureRoot(); setHasData(true);
    r.innerHTML = '<div class="lang-meta"><a id="lang-back" href="#/learn/coding">Back to Languages</a></div>'
                + '<h1>'+titleCase(lang)+'</h1>'
                + '<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';
    console.log("[LOADER] skeleton", lang);
    return r;
  }

  window.osbBindBackLink = function(){
    try{
      var a = document.querySelector('#lang-root .lang-meta a, #lang-back');
      if (!a || a.__osbBackBound) return; a.__osbBackBound = true; a.id = a.id || 'lang-back';
      a.addEventListener('click', function(ev){
        ev.preventDefault();
        try { if (history.length > 1) { history.back(); return; } } catch(_){}
        location.hash = '#/learn/coding';
      });
    }catch(e){}
  };

  function render(man, initialLesson){
    var r=ensureRoot(); setHasData(true);
    var html = '<div class="lang-meta"><a id="lang-back" href="#/learn/coding">Back to Languages</a></div>'
             + '<h1>'+(titleCase(man.title||man.lang||""))+'</h1>'
             + '<div id="lang-content"><div class="empty">Select a lesson to view its content.</div></div>';
    (man.modules||[]).forEach(function(m){
      html+='<div class="module"><h2>'+(m.title||"")+'</h2><ul class="lessons">';
      (m.lessons||[]).forEach(function(L){
        var mins=(L.mins!=null? (L.mins+" min"):"");
        html+='<li class="lesson" tabindex="0" data-lesson-id="'+(L.id||"")+'"><div class="title">'+(L.title||"")+'</div><div class="mins">'+mins+'</div></li>';
      });
      html+='</ul></div>';
    });
    r.innerHTML = html;

    if (!r.__osbDelegated) {
      r.__osbDelegated = true;
      r./* osbDelegatedClickV1 */ addEventListener("click", function(ev){
        var el = ev.target && ev.target.closest ? ev.target.closest(".lesson") : null;
        if(!el || !r.contains(el)) return;
        var id = el.getAttribute("data-lesson-id"); if(!id) return;
        if(el.classList.contains("locked") && !(osbDevUnlock())){ alert("Complete the previous lesson first!"); return; }
        try { activate(man, id); } catch(e){ console.warn("[LOADER] activate fallback", e); }
        var newHash = "#/learn/"+(man.lang||"")+"/"+id;
        if (history && history.replaceState) { history.replaceState(null,"",newHash); } else { location.hash = newHash; }
      });
    }

    osbDecorateLocks(man);
    if (initialLesson) {
      var rid = resolveLessonId(man, initialLesson);
      if (rid) activate(man, rid);
    }
  }

  function load(lang, lesson){
    skeleton(lang); try{ if(window.osbBindBackLink) osbBindBackLink(); }catch(_){}
    var url="data/learn/"+lang+".json?v="+Date.now();
    fetch(url,{cache:"no-store"})
      .then(function(resp){ return resp.ok ? resp.json() : {lang:lang, modules:[]}; })
      .then(function(man){ man.lang = man.lang || lang; render(man, lesson); })
      .catch(function(e){ console.error("[LOADER] fetch failed", e); });
  }

  function onRoute(){
    var r=parse();
    if(!r){ removeRoot(); return; }
    if(!document.body){ requestAnimationFrame(onRoute); return; }
    load(r.lang, r.lesson);
  }
  window.addEventListener("hashchange", onRoute);
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", onRoute); else onRoute();
})();

/* Codepad + Python runner (single pad, dedupe) */
(function(){
  "use strict";
  if (window.__osbCodepadKitV3) return; window.__osbCodepadKitV3 = true;

  function decodeStarter(s){ s=String(s||""); try{ s=s.replace(/&quot;/g,'"'); }catch(_){ } return s.replace(/\\n/g,"\n"); }

  window.osbInitCodepadsSafe = function(root){
    try{
      var scope = root || document;
      var pads = scope.querySelectorAll(".codepad");
      pads.forEach(function(p){
        // build fresh UI each time; this avoids duplicates on re-render
        var lang = (p.getAttribute("data-lang")||"").toLowerCase();
        var title = p.getAttribute("data-title") || (lang?lang.toUpperCase():"PRACTICE");
        var starter = decodeStarter(p.getAttribute("data-starter")||"");

        var wrap = document.createElement("div"); wrap.className = "codepad-ui";
        var head = document.createElement("div"); head.className = "header"; head.textContent = title || "PRACTICE";
        var ta = document.createElement("textarea"); ta.className="codepad-editor"; ta.value = starter;
        var runrow = document.createElement("div"); runrow.className = "runrow";
        var btn = document.createElement("button"); btn.textContent = "Run"; btn.className = "btn codepad-run"; btn.setAttribute("type","button");
        var out = document.createElement("pre"); out.className = "codepad-output"; out.setAttribute("aria-live","polite"); out.textContent = "";

        btn./* osbDelegatedClickV1 */ addEventListener("click", function(){
          var code = ta.value||"";
          if (typeof window.osbRun === "function") {
            try { window.osbRun(lang, code, out); return; } catch(e){}
          }
          if (lang === "python") { window.osbRunPython(lang, code, out); return; }
          out.textContent = "(No runner for "+lang+")";
        });

        runrow.appendChild(btn);
        wrap.appendChild(head); wrap.appendChild(ta); wrap.appendChild(runrow); wrap.appendChild(out);
        p.innerHTML = ""; p.appendChild(wrap);
      });
      if (pads.length){ console.log("[CODEPAD] initialized", pads.length); }
    }catch(e){ console.warn("[CODEPAD] init failed", e); }
  };

  /* Pyodide runner with CDN fallback; set window.osbPyodideSrc to override */
  function loadScript(urls, cb){
    var i=0;
    (function next(){
      if (i>=urls.length) return cb(new Error("all failed"));
      var s=document.createElement("script"); s.src=urls[i++]; s.async=true;
      s.onload=function(){ cb(); }; s.onerror=function(){ next(); };
      document.head.appendChild(s);
    })();
  }

  window.osbEnsurePythonRuntime = function(){
    if (window.osbPythonReady) return window.osbPythonReady;
    window.osbPythonReady = new Promise(function(resolve, reject){
      function start(){
        try { loadPyodide({}).then(function(py){ window.pyodide=py; resolve(true); }, reject); }
        catch(e){ reject(e); }
      }
      if (window.loadPyodide){ start(); return; }
      var forced = window.osbPyodideSrc;
      var list = forced ? [forced] : [
        "https://cdn.jsdelivr.net/pyodide/v0.24.1/full/pyodide.js",
        "https://pyodide-cdn2.iodide.io/v0.24.1/full/pyodide.js"
      ];
      loadScript(list, function(err){ if (err) reject(err); else start(); });
    });
    return window.osbPythonReady;
  };

  window.osbRunPython = function(lang, code, outEl){
    outEl = (outEl && outEl.nodeType===1)? outEl : document.createElement("pre");
    outEl.textContent = "Running...";
    window.osbEnsurePythonRuntime().then(async function(){
      try{
        pyodide.globals.set("__code__", String(code||""));
        await pyodide.runPythonAsync([
          "import sys, io, traceback",
          "buf = io.StringIO()",
          "oldout, olderr = sys.stdout, sys.stderr",
          "sys.stdout = sys.stderr = buf",
          "_ok = True",
          "try:",
          "    exec(__code__, {})",
          "except Exception:",
          "    _ok = False",
          "    traceback.print_exc()",
          "finally:",
          "    sys.stdout, sys.stderr = oldout, olderr",
          "_result = buf.getvalue()"
        ].join("\n"));
        var txt = pyodide.globals.get("_result");
        outEl.textContent = txt || "(no output)";
        try{ pyodide.globals.delete("__code__"); pyodide.globals.delete("_result"); }catch(_){}
      } catch(e){
        outEl.textContent = "Runtime error: " + (e && e.message || e);
      }
    }, function(e){
      outEl.textContent = "Failed to init Python: " + (e && e.message || e);
    });
  };
})();
/* XP HUD helpers */
(function(){
  if (window.__osbXPHudV1) return; window.__osbXPHudV1 = true;

  function osbGetXP(){ try { return +(localStorage.getItem("lms:xp")||0); } catch(e){ return 0; } }
  function osbSetXP(n){ try { localStorage.setItem("lms:xp", String(+n||0)); } catch(e){} }
  function osbAddXP(n){ var v = osbGetXP() + (+n||0); osbSetXP(v); try{ osbUpdateXPHud(); }catch(e){} return v; }
  function osbAwardOnce(key, n){
    try{
      var k = "xp:award:"+String(key||"");
      if (localStorage.getItem(k) === "1") return osbGetXP();
      localStorage.setItem(k, "1");
      return osbAddXP(+n||0);
    }catch(e){ return osbGetXP(); }
  }
  window.osbGetXP = osbGetXP;
  window.osbAddXP = osbAddXP;
  window.osbAwardOnce = osbAwardOnce;

  function osbEnsureXPHud(){
    var id="xp-hud"; var el=document.getElementById(id);
    if (!el){
      el=document.createElement("div"); el.id=id; el.textContent="XP: 0";
      (document.body||document.documentElement).appendChild(el);
    }
    osbUpdateXPHud();
  }
  window.osbUpdateXPHud = function(){
    try{ var el=document.getElementById("xp-hud"); if (el) el.textContent="XP: "+osbGetXP(); }catch(e){}
  };
  try{ if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", osbEnsureXPHud); else osbEnsureXPHud(); }catch(e){}
})();
/* codepadHTML helper (exposed for tests) */
function codepadHTML(lang, title, starter){
  try{
    lang = (lang || "python");
    title = title || lang.toUpperCase();
    starter = String(starter || "");
    var esc = function(s){ return String(s).replace(/&/g,"&amp;").replace(/"/g,"&quot;"); };
    return '<div class="codepad" data-lang="'+esc(lang)+'" data-title="'+esc(title)+'" data-starter="'+esc(starter)+'"></div>';
  }catch(e){ return '<div class="codepad"></div>'; }
}
/* explicit named osbMarkComplete (alias to window.osbMarkComplete) */
function osbMarkComplete(lang, lessonId){
  try {
    localStorage.setItem("lms:done:"+String(lang||"")+":"+String(lessonId||""), "1");
    console.log("[LMS] marked complete", lang, lessonId);
  } catch(e){}
}
try { if (!window.osbMarkComplete) window.osbMarkComplete = osbMarkComplete; } catch(e){}/* mountCodepad: create & initialize a single codepad in a target container */
function mountCodepad(target, opts){
  try{
    var el = (typeof target === "string") ? document.querySelector(target) : target;
    if (!el || !el.nodeType) { console.warn("[CODEPAD] mount target not found"); return null; }
    opts = opts || {};
    var html = codepadHTML(opts.lang||"python", opts.title||null, opts.starter||"");
    el.innerHTML = html;
    try { if (typeof window.osbInitCodepadsSafe === "function") osbInitCodepadsSafe(el); } catch(_){}
    var pad = el.querySelector(".codepad");
    return pad || null;
  }catch(e){ console.warn("[CODEPAD] mount failed", e); return null; }
}
try { if (!window.mountCodepad) window.mountCodepad = mountCodepad; } catch(e){}