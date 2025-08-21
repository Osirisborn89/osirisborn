/* Black Pyramid — LMS Chrome v1 (polished)
 * Fixed overlay mount outside #host + backdrop to hide native content
 * Debounced re-mount; converts \n to <br> in lesson bodies
 */
(function () {
  "use strict";
  const LOG=(...a)=>{ try{ console.debug("[LMS]", ...a);}catch{} };
  const LS_PROGRESS_KEY="bp.progress", LS_RESUME_KEY="bp.resume";
  const qs=(s,el=document)=>el.querySelector(s), on=(el,ev,fn,opts)=>el.addEventListener(ev,fn,opts);

  const progress={ get(){try{return JSON.parse(localStorage.getItem(LS_PROGRESS_KEY)||"{}")}catch{return{}}}, set(o){localStorage.setItem(LS_PROGRESS_KEY,JSON.stringify(o||{}))}, isDone(k){return this.get()[k]==="done"}, mark(k,d){const p=this.get(); if(d){p[k]="done"} else {delete p[k]} this.set(p)} };
  const resume  ={ get(){try{return JSON.parse(localStorage.getItem(LS_RESUME_KEY)||"{}")}catch{return{}}}, set(t,u){const r=this.get(); r[t]=u; localStorage.setItem(LS_RESUME_KEY,JSON.stringify(r))} };

  function ensureStyles(){
    if (qs("#bp-lms-style")) return;
    const css = `
    .bp-debug { position:fixed; bottom:8px; right:8px; z-index:2147483647; font:12px/1.4 system-ui; padding:6px 8px; border-radius:6px; background:#111a; color:#e6e6e6; border:1px solid #2b3845; opacity:.95 }
    /* Fixed overlay + backdrop so native content is visually hidden */
    #bp-lms-root { position:fixed; z-index:2147483600; inset:56px 16px 16px 16px; pointer-events:none; }
    #bp-lms-backdrop { position:fixed; inset:0; background:rgba(13,17,23,.96); z-index:-1; }
    #bp-lms { pointer-events:auto; max-width:1400px; margin:0 auto; }
    #bp-lms, #bp-lms * { box-sizing:border-box; }
    #bp-lms { font-family: system-ui, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height:1.45; color:#e6e6e6; }
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
    .bp-lesson a { flex:1; color:#9bd; text-decoration:none; }
    .bp-tick { font-size:12px; opacity:.9; }
    .bp-lock { width:14px; height:14px; display:inline-grid; place-items:center; border:1px solid #2b3845; border-radius:3px; opacity:.8; }
    .bp-callout { border:1px solid #2b3845; border-left:4px solid #7b5cff; background:#141b22; padding:10px; border-radius:6px; }
    .bp-callout.tip{border-left-color:#4fdb8e}.bp-callout.info{border-left-color:#00d4ff}.bp-callout.warn{border-left-color:#ff8c42}
    .bp-code { border:1px solid #2b3845; background:#0b0f14; padding:10px; border-radius:6px; overflow:auto; font-family: ui-monospace, Menlo, Consolas, monospace; font-size:13px; }
    .bp-out { border:1px dashed #2b3845; background:#0f141a; padding:8px; border-radius:6px; white-space:pre-wrap; }
    .bp-task { counter-increment: task; } .bp-task::before { content:"Task " counter(task) ": "; font-weight:700; }
    .bp-checkpoint { border:1px solid #2b3845; background:#0f141a; padding:10px; border-radius:8px; }
    @media (max-width:980px){ .bp-wrap { grid-template-columns: 1fr; } #bp-lms-root { inset:48px 8px 8px 8px; } }
    `;
    const st=document.createElement("style"); st.id="bp-lms-style"; st.textContent=css; document.head.appendChild(st);
  }

  function showDebug(txt){
    let d=qs("#bp-debug"); if(!d){ d=document.createElement("div"); d.id="bp-debug"; d.className="bp-debug"; (document.body||document.documentElement).appendChild(d); }
    d.textContent=txt;
  }

  function parseRoute(){
    const hash=location.hash||"", parts=hash.replace(/^#\//,"").split("/");
    if(parts[0]!=="learn") return {ok:false};
    return { ok:true, trackId:parts[1], moduleId:parts[2], lessonId:parts[3] };
  }

  function getBaseHref(){ const b=document.querySelector("base"); return b? b.getAttribute("href") : "./"; }
  async function getTrack(trackId){
    const url=getBaseHref()+"api/lessons/"+encodeURIComponent(trackId)+".json";
    LOG("fetch", url);
    const res=await fetch(url,{cache:"no-store"});
    if(!res.ok) throw new Error("Track JSON not found: "+url);
    return res.json();
  }

  function el(tag, attrs={}, kids=[]){ const e=document.createElement(tag);
    for(const [k,v] of Object.entries(attrs)){ if(k==="class") e.className=v; else if(k==="html") e.innerHTML=v; else if(k.startsWith("on")&&typeof v==="function") e.addEventListener(k.slice(2), v); else e.setAttribute(k,v); }
    (Array.isArray(kids)?kids:[kids]).forEach(c=>{ if(c==null) return; if(typeof c==="string") e.appendChild(document.createTextNode(c)); else e.appendChild(c); });
    return e;
  }
  function escapeHtml(s){ return String(s).replace(/[&<>\"']/g, c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
  function renderBody(html){
    if(!html) return "";
    let out=html;
    // Convert escaped line breaks to <br>
    out=out.replace(/\\n/g, "<br>");
    out=out.replace(/\[\[callout:(tip|info|warn)\]\]([\s\S]*?)\[\[\/callout\]\]/g,(_,t,b)=>`<div class="bp-callout ${t}">${b.trim()}</div>`);
    out=out.replace(/\[\[code:([a-z0-9_+-]+)\]\]([\s\S]*?)\[\[\/code\]\]/gi,(_,lang,b)=>`<pre class="bp-code" data-lang="${lang.toLowerCase()}"><code>${escapeHtml(b)}</code></pre>`);
    out=out.replace(/\[\[out\]\]([\s\S]*?)\[\[\/out\]\]/g,(_,b)=>`<div class="bp-out">${escapeHtml(b)}</div>`);
    out=out.replace(/\[\[task\]\]([\s\S]*?)\[\[\/task\]\]/g,(_,b)=>`<div class="bp-task">${b.trim()}</div>`);
    out=out.replace(/\[\[checkpoint\]\]([\s\S]*?)\[\[\/checkpoint\]\]/g,(_,b)=>`<details class="bp-checkpoint"><summary>Checkpoint</summary><div>${b.trim()}</div></details>`);
    return out;
  }

  function lessonKey(trackId,moduleId,lessonId){ return `${trackId}:${moduleId}:${lessonId}`; }
  function findLesson(track,moduleId,lessonId){
    const mIdx=track.modules.findIndex(m=>m.id===moduleId), mod=track.modules[mIdx]||{lessons:[]};
    const lIdx=(mod.lessons||[]).findIndex(l=>l.id===lessonId), les=mod.lessons?.[lIdx]||null;
    return { mIdx,lIdx,lesson:les,module:mod };
  }
  function computeTrackProgress(track){
    const p=progress.get(); let done=0,total=0;
    track.modules.forEach(m=>(m.lessons||[]).forEach(l=>{ total++; if(p[lessonKey(track.trackId,m.id,l.id)]==="done") done++; }));
    return { doneCount:done, totalCount:total, pct: total? Math.round(done*100/total):0 };
  }
  function isUnlocked(track,m,l){
    if(m===0&&l===0) return true;
    let prev=null;
    if(l>0) prev={m,l:l-1}; else if(m>0){ const pm=track.modules[m-1]; prev={m:m-1,l:pm.lessons.length-1}; }
    if(prev){ const k=lessonKey(track.trackId,track.modules[prev.m].id,track.modules[prev.m].lessons[prev.l].id); if(progress.isDone(k)) return true; }
    const cur=track.modules[m].lessons[l]; const prereqs=Array.isArray(cur?.prereqs)?cur.prereqs:[];
    return prereqs.every(p=>{ let mk,lk; if(p.includes(":")){[mk,lk]=p.split(":")} else {mk=track.modules[m].id; lk=p;} return progress.isDone(lessonKey(track.trackId,mk,lk)); });
  }
  function getPrev(track,m,l){
    if(m===0&&l===0) return null;
    if(l>0) return { m,l:l-1, hash:`#/learn/${track.trackId}/${track.modules[m].id}/${track.modules[m].lessons[l-1].id}` };
    if(m>0){ const pm=track.modules[m-1]; return { m:m-1,l:pm.lessons.length-1, hash:`#/learn/${track.trackId}/${pm.id}/${pm.lessons[pm.lessons.length-1].id}` }; }
    return null;
  }
  function getNext(track,m,l){
    const mod=track.modules[m]; if(!mod) return null;
    if(l<mod.lessons.length-1) return { m,l:l+1, hash:`#/learn/${track.trackId}/${mod.id}/${mod.lessons[l+1].id}` };
    if(m<track.modules.length-1){ const nm=track.modules[m+1]; return { m:m+1,l:0, hash:`#/learn/${track.trackId}/${nm.id}/${nm.lessons[0].id}` }; }
    return null;
  }

  function buildBreadcrumbs(r,track){
    const bc=el("nav",{class:"bp-breadcrumbs","aria-label":"Breadcrumb"});
    [
      ["Learning","#/learn"],["Coding","#/learn/coding"],
      [track?.title||r.trackId, `#/learn/${r.trackId}`],
      [r.moduleId, `#/learn/${r.trackId}/${r.moduleId}`],
      [r.lessonId, location.hash]
    ].filter(x=>x[0]).forEach(([t,h])=>bc.appendChild(el("a",{href:h,class:"bp-crumb"},t)));
    return bc;
  }
  function buildHeader(r,track){
    const { lesson }=findLesson(track,r.moduleId,r.lessonId);
    const { pct }=computeTrackProgress(track);
    const bar=el("div",{class:"bp-progressbar",role:"progressbar","aria-valuenow":String(pct),"aria-valuemin":"0","aria-valuemax":"100"}, el("div",{style:`width:${pct}%`}));
    const header=el("div",{class:"bp-header"},[
      el("div",{class:"bp-title"}, lesson?.title||r.lessonId||"Lesson"),
      el("div",{class:"bp-badges"},[
        lesson?.difficulty? el("span",{class:"bp-badge"}, String(lesson.difficulty)) : null,
        Number.isFinite(lesson?.est)? el("span",{class:"bp-badge"}, `${lesson.est} min`) : null
      ].filter(Boolean))
    ]);
    const prereqs=Array.isArray(lesson?.prereqs)?lesson.prereqs:[];
    const prereqWrap = prereqs.length? el("div",{class:"bp-prereqs"},[
      "Prereqs: ",
      ...prereqs.map((p,i)=>[el("a",{href: p.includes(":")? `#/learn/${r.trackId}/${p.split(":")[0]}/${p.split(":")[1]}` : `#/learn/${r.trackId}/${r.moduleId}/${p}`}, p), i<prereqs.length-1? ", ":""]).flat()
    ]) : null;
    const block=el("div",{},[header,prereqWrap].filter(Boolean));
    return { bar, block };
  }
  function buildBody(r,track){
    const { lesson }=findLesson(track,r.moduleId,r.lessonId);
    const wrap=el("div",{class:"bp-body"});
    if(Array.isArray(lesson?.outcomes)&&lesson.outcomes.length){
      const ul=el("ul",{},lesson.outcomes.map(o=>el("li",{},o)));
      wrap.appendChild(el("section",{},[el("h3",{},"Outcomes"), ul]));
    }
    if(lesson?.tags?.length){ wrap.appendChild(el("div",{class:"bp-badges"},lesson.tags.map(t=>el("span",{class:"bp-badge"},t)))); }
    if(lesson?.body){ wrap.appendChild(el("section",{html:renderBody(lesson.body)})); }
    return wrap;
  }
  function buildActions(r,track){
    const { mIdx,lIdx }=findLesson(track,r.moduleId,r.lessonId);
    const actions=el("div",{class:"bp-actions"});
    const prev=getPrev(track,mIdx,lIdx), next=getNext(track,mIdx,lIdx);
    const key=lessonKey(track.trackId,r.moduleId,r.lessonId);
    const bPrev=el("button",{class:"bp-btn",disabled:prev?null:true,onClick:()=>{ if(prev) location.hash=prev.hash; }},"← Prev");
    const bToggle=el("button",{class:"bp-btn",onClick:()=>{ const now=!progress.isDone(key); progress.mark(key,now); scheduleRender(); }}, progress.isDone(key)?"✓ Marked Done":"Mark Done");
    const unlockedNext=next? isUnlocked(track,next.m,next.l):false;
    const bNext=el("button",{class:"bp-btn",disabled:(next&&unlockedNext)?null:true,onClick:()=>{ if(next&&unlockedNext) location.hash=next.hash; }},"Next →");
    actions.append(bPrev,bToggle,bNext);
    return actions;
  }

  function mountRoot(){
    // Mount as sibling of #host so SPA wipes don't touch us.
    const portalHost=qs("#host");
    const parent=(portalHost && portalHost.parentNode) || document.body || document.documentElement;
    let root=qs("#bp-lms-root",parent);
    if(!root){ root=document.createElement("div"); root.id="bp-lms-root"; parent.appendChild(root); }
    if(!qs("#bp-lms-backdrop",root)){ const bd=document.createElement("div"); bd.id="bp-lms-backdrop"; root.appendChild(bd); }
    let host=qs("#bp-lms",root);
    if(!host){ host=document.createElement("div"); host.id="bp-lms"; root.appendChild(host); }
    return { root, host };
  }
  function teardown(){ const r=qs("#bp-lms-root"); if(r) r.remove(); }

  async function render(){
    const r=parseRoute();
    if(!r.ok){ teardown(); showDebug("LMS DEBUG — not a learn route"); return; }
    if(!r.moduleId || !r.lessonId){ teardown(); showDebug(\`LMS DEBUG — track=\${r.trackId||"-"} module=- lesson=-\`); return; }
    showDebug(\`LMS DEBUG — track=\${r.trackId} module=\${r.moduleId} lesson=\${r.lessonId}\`);
    ensureStyles();

    let track;
    try{ track=await getTrack(r.trackId); }
    catch(e){ LOG("fetch failed", e); teardown(); showDebug(\`LMS DEBUG — ERROR loading \${r.trackId}.json\`); return; }

    const { root, host }=mountRoot();
    host.innerHTML="";

    const wrap=el("div",{class:"bp-wrap"});
    const left=el("aside",{class:"bp-left"}); const main=el("section",{class:"bp-main"});

    // Sidebar
    track.modules.forEach((m,mi)=>{
      const mod=el("div",{class:"bp-module"});
      mod.appendChild(el("h4",{},m.title||m.id));
      const list=el("div",{class:"bp-lessons"});
      (m.lessons||[]).forEach((l,li)=>{
        const k=lessonKey(track.trackId,m.id,l.id);
        const unlocked=isUnlocked(track,mi,li);
        const current=r.moduleId===m.id && r.lessonId===l.id;
        const row=el("div",{class:"bp-lesson"+(current?" bp-current":"")});
        const icon=unlocked? el("span",{class:"bp-tick",title:progress.isDone(k)?"Done":"Not done"}, progress.isDone(k)?"✓":"•")
                           : el("span",{class:"bp-lock",title:"Complete the previous lesson to unlock"},"🔒");
        const link=el("a",{href:\`#/learn/\${track.trackId}/\${m.id}/\${l.id}\`}, l.title||l.id);
        if(!unlocked) link.addEventListener("click",(e)=>e.preventDefault());
        row.append(icon,link); list.appendChild(row);
      });
      mod.appendChild(list); left.appendChild(mod);
    });

    // Main
    const crumbs=buildBreadcrumbs(r,track);
    const header=buildHeader(r,track);
    const body=buildBody(r,track);
    const actions=buildActions(r,track);
    main.appendChild(crumbs);
    main.appendChild(header.bar);
    main.appendChild(header.block);
    main.appendChild(body);
    main.appendChild(actions);

    wrap.appendChild(left); wrap.appendChild(main); host.appendChild(wrap);

    resume.set(r.trackId, location.hash);
    const titleEl=host.querySelector(".bp-title"); if(titleEl){ titleEl.setAttribute("tabindex","-1"); titleEl.focus(); }
  }

  // Debounced re-render triggers
  let scheduled=false;
  function scheduleRender(){ if(scheduled) return; scheduled=true; requestAnimationFrame(async()=>{ scheduled=false; try{ await render(); }catch(e){ LOG("render error", e); } }); }
  on(window,"hashchange",()=>{ LOG("hashchange",location.hash); scheduleRender(); });
  on(window,"popstate",  ()=>{ LOG("popstate",location.hash); scheduleRender(); });
  on(document,"DOMContentLoaded",()=>{ LOG("domready"); scheduleRender(); });

  // Poll for silent SPA hash changes
  (function(){ let last=location.hash; setInterval(()=>{ if(location.hash!==last){ last=location.hash; LOG("hash-poll", last); scheduleRender(); } }, 400); })();

  // Watch for our root being removed; debounce re-mount to avoid log spam
  let remountTimer=null;
  const mo=new MutationObserver(()=>{ if(!qs("#bp-lms-root")){ if(remountTimer) return; remountTimer=setTimeout(()=>{ remountTimer=null; LOG("root removed → re-mount"); scheduleRender(); }, 150); } });
  mo.observe(document.documentElement,{childList:true,subtree:true});

  scheduleRender();
})();
