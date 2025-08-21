/* Black Pyramid — LMS Chrome v1 (overlay, lesson-only)
 * Scope: attaches to #/learn/<trackId>/<module>/<lesson>
 * Guard-safe: no title/brand changes; CSS scoped under .bp-lms
 * State: localStorage: bp.progress, bp.resume
 */
(function () {
  "use strict";
  const LOG = (...args)=>{ try{ console.debug("[LMS]", ...args);}catch{} };

  const LS_PROGRESS_KEY = "bp.progress";
  const LS_RESUME_KEY   = "bp.resume";
  const qs  = (sel, el=document) => el.querySelector(sel);
  const on  = (el, ev, fn, opts) => el.addEventListener(ev, fn, opts);

  const progress = {
    get(){ try { return JSON.parse(localStorage.getItem(LS_PROGRESS_KEY)||"{}"); } catch { return {}; } },
    set(o){ localStorage.setItem(LS_PROGRESS_KEY, JSON.stringify(o||{})); },
    isDone(k){ return this.get()[k] === "done"; },
    mark(k, done){ const p=this.get(); if(done){p[k]="done"} else {delete p[k]} this.set(p); }
  };
  const resume = {
    get(){ try { return JSON.parse(localStorage.getItem(LS_RESUME_KEY)||"{}"); } catch { return {}; } },
    set(trackId, url){ const r=this.get(); r[trackId]=url; localStorage.setItem(LS_RESUME_KEY, JSON.stringify(r)); }
  };

  function ensureStyles(){
    if (qs("#bp-lms-style")) return;
    const style = document.createElement("style");
    style.id = "bp-lms-style";
    style.textContent = `
    .bp-lms { font-family: system-ui, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height:1.45; color:#e6e6e6; }
    .bp-lms a { color:#9bd; text-decoration:none; } .bp-lms a:hover{ text-decoration:underline; }
    .bp-wrap { display:grid; grid-template-columns: 280px 1fr; gap:16px; }
    .bp-left { background:#11151a; border:1px solid #25303a; border-radius:12px; padding:12px; max-height: calc(100vh - 140px); overflow:auto; }
    .bp-main { background:#0d1117; border:1px solid #25303a; border-radius:12px; padding:16px; }
    .bp-breadcrumbs { font-size:13px; margin:0 0 8px 0; display:flex; gap:6px; flex-wrap:wrap; align-items:center; }
    .bp-breadcrumbs .bp-crumb::after { content:"›"; margin:0 4px; opacity:.5; } .bp-breadcrumbs .bp-crumb:last-child::after{ content:""; }
    .bp-header { display:flex; flex-wrap:wrap; gap:8px 12px; align-items:center; margin:6px 0 10px 0; }
    .bp-title { font-size:22px; font-weight:700; }
    .bp-badges { display:flex; gap:8px; }
    .bp-badge { font-size:12px; padding:4px 8px; border-radius:999px; border:1px solid #2b3845; background:#141b22; }
    .bp-prereqs { font-size:12px; opacity:.85; }
    .bp-progressbar { height:8px; background:#1a2230; border:1px solid #2b3845; border-radius:999px; overflow:hidden; margin:8px 0 14px 0; }
    .bp-progressbar > div { height:100%; width:0%; background:linear-gradient(90deg,#7b5cff,#00d4ff); transition:width .25s ease; }
    .bp-body { display:grid; gap:16px; }
    .bp-actions { display:flex; gap:8px; margin-top:10px; }
    .bp-btn { padding:8px 12px; border-radius:8px; border:1px solid #2b3845; background:#141b22; color:#e6e6e6; cursor:pointer; user-select:none; }
    .bp-btn[disabled]{ opacity:.5; cursor:not-allowed; }
    .bp-module { margin-bottom:10px; }
    .bp-lessons { display:grid; gap:4px; }
    .bp-lesson { display:flex; align-items:center; gap:6px; font-size:13px; padding:6px 8px; border-radius:6px; }
    .bp-lesson.bp-current { background:#161d26; border:1px solid #2b3845; }
    .bp-lesson a { flex:1; }
    .bp-tick { font-size:12px; opacity:.9; }
    .bp-lock { width:14px; height:14px; display:inline-grid; place-items:center; border:1px solid #2b3845; border-radius:3px; opacity:.8; }
    .bp-callout { border:1px solid #2b3845; border-left:4px solid #7b5cff; background:#141b22; padding:10px; border-radius:6px; }
    .bp-callout.tip{border-left-color:#4fdb8e}.bp-callout.info{border-left-color:#00d4ff}.bp-callout.warn{border-left-color:#ff8c42}
    .bp-code { border:1px solid #2b3845; background:#0b0f14; padding:10px; border-radius:6px; overflow:auto; font-family: ui-monospace, Menlo, Consolas, monospace; font-size:13px; }
    .bp-out { border:1px dashed #2b3845; background:#0f141a; padding:8px; border-radius:6px; white-space:pre-wrap; }
    .bp-task { counter-increment: task; } .bp-task::before { content:"Task " counter(task) ": "; font-weight:700; }
    .bp-checkpoint { border:1px solid #2b3845; background:#0f141a; padding:10px; border-radius:8px; }
    @media (max-width:980px){ .bp-wrap { grid-template-columns: 1fr; } }
    `;
    document.head.appendChild(style);
  }

  function parseRoute(){
    const hash = location.hash || "";
    const parts = hash.replace(/^#\//, "").split("/");
    if (parts[0] !== "learn") return null;
    const trackId = parts[1];
    const moduleId = parts[2];
    const lessonId = parts[3];
    return { trackId, moduleId, lessonId };
  }

  function getBaseHref(){ const b=document.querySelector("base"); return b ? b.getAttribute("href") : "./"; }
  async function getTrack(trackId){
    const url = getBaseHref() + "api/lessons/" + encodeURIComponent(trackId) + ".json";
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error("Track JSON not found: " + url);
    return res.json();
  }
  function lessonKey(trackId, moduleId, lessonId){ return `${trackId}:${moduleId}:${lessonId}`; }
  function escapeHtml(s){ return String(s).replace(/[&<>\"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  function el(tag, attrs={}, kids=[]){ const e=document.createElement(tag); for (const [k,v] of Object.entries(attrs)){ if(k==="class") e.className=v; else if(k==="html") e.innerHTML=v; else if(k.startsWith("on")&&typeof v==="function") e.addEventListener(k.slice(2), v); else e.setAttribute(k,v); } (Array.isArray(kids)?kids:[kids]).forEach(c=>{ if(c==null) return; if(typeof c==="string") e.appendChild(document.createTextNode(c)); else e.appendChild(c);}); return e; }

  function renderBody(html){
    if (!html) return "";
    let out = html;
    out = out.replace(/\[\[callout:(tip|info|warn)\]\]([\s\S]*?)\[\[\/callout\]\]/g, (_, t, b)=>`<div class="bp-callout ${t}">${b.trim()}</div>`);
    out = out.replace(/\[\[code:([a-z0-9_+-]+)\]\]([\s\S]*?)\[\[\/code\]\]/gi, (_, lang, b)=>`<pre class="bp-code" data-lang="${lang.toLowerCase()}"><code>${escapeHtml(b)}</code></pre>`);
    out = out.replace(/\[\[out\]\]([\s\S]*?)\[\[\/out\]\]/g, (_, b)=>`<div class="bp-out">${escapeHtml(b)}</div>`);
    out = out.replace(/\[\[task\]\]([\s\S]*?)\[\[\/task\]\]/g, (_, b)=>`<div class="bp-task">${b.trim()}</div>`);
    out = out.replace(/\[\[checkpoint\]\]([\s\S]*?)\[\[\/checkpoint\]\]/g, (_, b)=>`<details class="bp-checkpoint"><summary>Checkpoint</summary><div>${b.trim()}</div></details>`);
    return out;
  }

  function findLesson(track, moduleId, lessonId){
    const mIdx = track.modules.findIndex(m=>m.id===moduleId);
    const mod  = track.modules[mIdx] || { lessons: [] };
    const lIdx = (mod.lessons||[]).findIndex(l=>l.id===lessonId);
    const les  = mod.lessons?.[lIdx] || null;
    return { mIdx, lIdx, lesson: les, module: mod };
  }
  function computeTrackProgress(track){
    const p=progress.get(); let done=0,total=0;
    track.modules.forEach(m => (m.lessons||[]).forEach(l => { total++; if (p[lessonKey(track.trackId, m.id, l.id)]==="done") done++; }));
    return { doneCount: done, totalCount: total, pct: total? Math.round((done/total)*100):0 };
  }
  function isUnlocked(track, m, l){
    if (m===0 && l===0) return true;
    let prev=null;
    if (l>0) prev={m, l:l-1}; else if (m>0){ const pm=track.modules[m-1]; prev={m:m-1, l: pm.lessons.length-1}; }
    if (prev){ const k=lessonKey(track.trackId, track.modules[prev.m].id, track.modules[prev.m].lessons[prev.l].id); if(progress.isDone(k)) return true; }
    const cur=track.modules[m].lessons[l]; const prereqs=Array.isArray(cur?.prereqs)?cur.prereqs:[];
    return prereqs.every(p=>{ let mk,lk; if(p.includes(":")){[mk,lk]=p.split(":")} else {mk=track.modules[m].id; lk=p;} return progress.isDone(lessonKey(track.trackId,mk,lk)); });
  }

  function buildBreadcrumbs(route, track){
    const bc = el("nav", { class:"bp-breadcrumbs", "aria-label":"Breadcrumb" });
    const items = [
      ["Learning", "#/learn"],
      ["Coding", "#/learn/coding"],
      [track?.title || route.trackId, `#/learn/${route.trackId}`],
      [route.moduleId, `#/learn/${route.trackId}/${route.moduleId}`],
      [route.lessonId, location.hash]
    ].filter(x=>x[0]);
    items.forEach(([label, href]) => bc.appendChild(el("a", { href, class:"bp-crumb" }, label)));
    return bc;
  }
  function buildHeader(route, track){
    const { lesson } = findLesson(track, route.moduleId, route.lessonId);
    const { pct } = computeTrackProgress(track);
    const bar = el("div", { class:"bp-progressbar", role:"progressbar", "aria-valuenow":String(pct), "aria-valuemin":"0","aria-valuemax":"100" },
      el("div", { style:`width:${pct}%` })
    );
    const header = el("div", { class:"bp-header" }, [
      el("div", { class:"bp-title" }, lesson?.title || route.lessonId || "Lesson"),
      el("div", { class:"bp-badges" }, [
        lesson?.difficulty ? el("span", { class:"bp-badge" }, String(lesson.difficulty)) : null,
        Number.isFinite(lesson?.est) ? el("span", { class:"bp-badge" }, `${lesson.est} min`) : null
      ].filter(Boolean))
    ]);
    const prereqs = Array.isArray(lesson?.prereqs) ? lesson.prereqs : [];
    const prereqWrap = prereqs.length ? el("div", { class:"bp-prereqs" }, [
      "Prereqs: ",
      ...prereqs.map((p,i)=>[ el("a", { href: p.includes(":") ? `#/learn/${route.trackId}/${p.split(":")[0]}/${p.split(":")[1]}` : `#/learn/${route.trackId}/${route.moduleId}/${p}` }, p), i<prereqs.length-1 ? ", " : "" ]).flat()
    ]) : null;
    const block = el("div", {}, [header, prereqWrap].filter(Boolean));
    return { bar, block };
  }
  function buildBody(route, track){
    const { lesson } = findLesson(track, route.moduleId, route.lessonId);
    const wrap = el("div", { class:"bp-body" });
    if (Array.isArray(lesson?.outcomes) && lesson.outcomes.length){
      const ul = el("ul", {}, lesson.outcomes.map(o=>el("li",{},o)));
      wrap.appendChild(el("section", {}, [el("h3", {}, "Outcomes"), ul]));
    }
    if (lesson?.tags?.length){
      const tags = el("div", { class:"bp-taglist" }, lesson.tags.map(t=>el("span",{class:"bp-badge"},t)));
      wrap.appendChild(tags);
    }
    if (lesson?.body){
      wrap.appendChild(el("section", { html: renderBody(lesson.body) }));
    }
    return wrap;
  }
  function getPrev(track, m, l){
    if (m===0 && l===0) return null;
    if (l>0) return { m, l:l-1, hash:`#/learn/${track.trackId}/${track.modules[m].id}/${track.modules[m].lessons[l-1].id}` };
    if (m>0){ const pm=track.modules[m-1]; return { m:m-1, l: pm.lessons.length-1, hash:`#/learn/${track.trackId}/${pm.id}/${pm.lessons[pm.lessons.length-1].id}` }; }
    return null;
  }
  function getNext(track, m, l){
    const mod=track.modules[m]; if(!mod) return null;
    if (l < mod.lessons.length-1) return { m, l:l+1, hash:`#/learn/${track.trackId}/${mod.id}/${mod.lessons[l+1].id}` };
    if (m < track.modules.length-1){
      const nm=track.modules[m+1];
      return { m:m+1, l:0, hash:`#/learn/${track.trackId}/${nm.id}/${nm.lessons[0].id}` };
    }
    return null;
  }

  function buildActions(route, track){
    const { mIdx, lIdx } = findLesson(track, route.moduleId, route.lessonId);
    const actions = el("div", { class:"bp-actions" });
    const prev = getPrev(track, mIdx, lIdx);
    const next = getNext(track, mIdx, lIdx);
    const key  = lessonKey(track.trackId, route.moduleId, route.lessonId);
    const btnPrev = el("button", { class:"bp-btn", disabled: prev? null : true, onClick: ()=>{ if(prev) location.hash=prev.hash; } }, "← Prev");
    const btnToggle = el("button", { class:"bp-btn", onClick: ()=>{ const now=!progress.isDone(key); progress.mark(key, now); scheduleRender(); } }, progress.isDone(key) ? "✓ Marked Done" : "Mark Done");
    const unlockedNext = next ? isUnlocked(track, next.m, next.l) : false;
    const btnNext = el("button", { class:"bp-btn", disabled: (next && unlockedNext) ? null : true, onClick: ()=>{ if(next && unlockedNext) location.hash=next.hash; } }, "Next →");
    actions.append(btnPrev, btnToggle, btnNext);
    return actions;
  }

  function teardown(){ const host = qs("#bp-lms"); if (host) host.remove(); }

  async function render(){
    const route = parseRoute();
    if (!route || !route.trackId){ teardown(); return; }

    // LESSON-ONLY GUARD
    if (!route.moduleId || !route.lessonId){
      LOG("Skipping (not a lesson page)", route);
      teardown();
      return;
    }

    LOG("Render lesson", route);
    ensureStyles();

    let track;
    try{
      LOG("Fetch track JSON", route.trackId);
      track = await getTrack(route.trackId);
    }catch(e){
      LOG("Track JSON fetch failed", String(e));
      teardown(); return;
    }

    let host = qs("#bp-lms");
    if (!host){ host = document.createElement("div"); host.id="bp-lms"; host.className="bp-lms"; (document.body || document.documentElement).appendChild(host); }
    host.innerHTML = "";

    const wrap   = el("div", { class:"bp-wrap" });
    const left   = el("aside", { class:"bp-left" });
    const main   = el("section", { class:"bp-main" });

    // Sidebar (modules/lessons with ✓/locks)
    track.modules.forEach((m, mi)=>{
      const mod = el("div", { class:"bp-module" });
      mod.appendChild(el("h4", {}, m.title || m.id));
      const list = el("div", { class:"bp-lessons" });
      (m.lessons||[]).forEach((l, li)=>{
        const k = lessonKey(track.trackId, m.id, l.id);
        const unlocked = isUnlocked(track, mi, li);
        const current  = route.moduleId===m.id && route.lessonId===l.id;
        const row = el("div", { class: "bp-lesson" + (current ? " bp-current" : "") });
        const icon = unlocked ? el("span",{class:"bp-tick", title: progress.isDone(k) ? "Done":"Not done"}, progress.isDone(k) ? "✓":"•") : el("span",{class:"bp-lock", title:"Complete the previous lesson to unlock"},"🔒");
        const link = el("a", { href:`#/learn/${track.trackId}/${m.id}/${l.id}` }, l.title || l.id);
        if (!unlocked) link.addEventListener("click",(e)=>e.preventDefault());
        row.append(icon, link);
        list.appendChild(row);
      });
      mod.appendChild(list);
      left.appendChild(mod);
    });

    // Main
    const crumbs = buildBreadcrumbs(route, track);
    const header = buildHeader(route, track);
    const body   = buildBody(route, track);
    const actions= buildActions(route, track);

    main.appendChild(crumbs);
    main.appendChild(header.bar);
    main.appendChild(header.block);
    main.appendChild(body);
    main.appendChild(actions);

    wrap.appendChild(left);
    wrap.appendChild(main);
    if (!qs("#bp-lms")) (document.body || document.documentElement).appendChild(host);
    host.appendChild(wrap);

    resume.set(route.trackId, location.hash);
    const titleEl = host.querySelector(".bp-title"); if (titleEl) { titleEl.setAttribute("tabindex","-1"); titleEl.focus(); }
  }

  let scheduled=false;
  function scheduleRender(){
  if(scheduled) return;
  scheduled = true;
  requestAnimationFrame(async()=>{
    scheduled = false;
    try {
      LOG("scheduleRender", location.hash);
      await render();
      showDebug();
    } catch(e){
      LOG("render error", e);
    }
  });
}
function showDebug(){
  try{
    const hash = location.hash || "";
    const parts = hash.replace(/^#\//, "").split("/");
    const dbg = document.querySelector("#bp-debug") || (()=>{
      const d = document.createElement("div");
      d.id = "bp-debug";
      d.style.cssText = "position:fixed;bottom:8px;right:8px;font:12px/1.4 system-ui;padding:6px 8px;border-radius:6px;background:#111a;color:#e6e6e6;border:1px solid #2b3845;z-index:99999;opacity:.9";
      document.body.appendChild(d);
      return d;
    })();
    let txt = "LMS DEBUG — ";
    if (parts[0] !== "learn") {
      txt += "Not a learn route";
    } else {
      const trackId = parts[1], moduleId = parts[2], lessonId = parts[3];
      txt += `track=${trackId||"-"}  module=${moduleId||"-"}  lesson=${lessonId||"-"}`;
    }
    document.querySelector("#bp-debug").textContent = txt;
  }catch(_){}
}
  on(window, "hashchange", ()=>{ LOG("hashchange", location.hash); scheduleRender(); });
  on(document, "DOMContentLoaded", ()=>{ LOG("domready"); scheduleRender(); showDebug(); });
  scheduleRender();
})();


