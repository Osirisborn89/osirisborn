(() => {
  const $ = (sel) => document.querySelector(sel);

  async function get(url, opts = {}) {
    const r = await fetch(url, { cache: "no-store", ...opts });
    if (!r.ok) throw new Error(`GET ${url} → ${r.status}`);
    return r.json();
  }
  async function post(url, body) {
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body || {}),
    });
    const txt = await r.text();
    let json = null;
    try { json = JSON.parse(txt) } catch {}
    if (!r.ok) throw new Error(json?.error || txt || `POST ${url} failed`);
    return json ?? {};
  }

  function toast(msg) {
    const t = $("#toast");
    t.textContent = msg || "";
    if (msg) setTimeout(() => (t.textContent = ""), 4000);
  }

  function setRing(pct) {
    const ring = $("#ring"); const span = $("#pct");
    const clamped = Math.max(0, Math.min(100, pct|0));
    ring.style.setProperty("--pct", (clamped/100).toFixed(3));
    span.textContent = clamped + "%";
  }

  function drawChart(series) {
    const svg = $("#chart"), w = 600, h = 120, pad = 6;
    const pts = series.map(s => s.xp);
    const max = Math.max(1, ...pts);
    const step = (w - pad*2) / Math.max(1, series.length-1);
    let d = [];
    series.forEach((row, i) => {
      const x = pad + i*step;
      const y = h - pad - (row.xp / max) * (h - pad*2);
      d.push(`${x},${y}`);
    });
    $("#series").setAttribute("points", d.join(" "));
    $("#days").textContent = series.length;
  }

  async function renderSummary(days = 30) {
    const data = await get(`/xp.json?days=${days}`);
    const s = data.summary || {};
    $("#rank").textContent = `Rank: ${s.rank ?? "—"}`;
    $("#xp").textContent   = s.xp ?? 0;
    $("#goal").textContent = s.dailyGoal ?? "—";
    $("#today").textContent= s.xpToday ?? 0;
    $("#remain").textContent= s.remaining ?? "—";
    setRing(Number(s.progressPct || 0));
    drawChart(data.series || []);
  }

  function statusClass(v) {
    return v?.toLowerCase() === "completed" ? "status-completed" : "status-progress";
  }

  async function renderMissions() {
    const data = await get("/api/missions");
    const rows = (data.items || []).map(x => {
      const btn = x.status === "Completed"
        ? `<button disabled>Done</button>`
        : `<button data-complete="\${x.id}">Complete</button>`;
      return `<tr>
        <td class="mono">\${x.id}</td>
        <td>\${x.title}</td>
        <td class="mono">\${x.xp}</td>
        <td class="\${statusClass(x.status)}">\${x.status}</td>
        <td>\${btn}</td>
      </tr>`;
    });
    $("#missions").innerHTML = rows.join("") || `<tr><td colspan="5" class="muted">No missions yet.</td></tr>`;
  }

  async function addMissionFlow() {
    const id = prompt("Mission id (e.g. m07):");
    if (!id) return;
    const xp = Number(prompt("XP value (e.g. 200):") || "0");
    const title = prompt("Title:", "New Mission") || "New Mission";
    await post("/api/mission/add", { id, xp, title });
    await renderMissions();
    await renderSummary(30);
  }

  async function completeMission(id) {
    await post("/api/mission/complete", { id });
    await renderMissions();
    await renderSummary(30);
  }

  async function doBackup() {
    const res = await post("/api/backup", {});
    toast(`Backup saved: ${res.file || 'ok'}`);
  }

  async function doRestore() {
    if (!confirm("Restore MOST RECENT backup? Your current data will be overwritten.")) return;
    const res = await post("/api/restore", { file: "latest" });
    toast(`Restored: ${res.file || 'latest'}`);
    await renderSummary(30);
    await renderMissions();
  }

  function wire() {\r\n    const xp1 = document.getElementById('btn-xp1');
    if (xp1) xp1.addEventListener('click', () => addXp(1, 'Check-in').catch(err => alert(err.message)));

    const xpC = document.getElementById('btn-xpCustom');
    if (xpC) xpC.addEventListener('click', async () => {
      const v = Number(prompt('XP amount:', '25') || '0');
      if (!v) return;
      const why = prompt('Reason:', 'Manual XP') || 'Manual XP';
      await addXp(v, why).catch(err => alert(err.message));
    });
    $("#btn-refresh").addEventListener("click", () => { renderSummary(30); renderMissions(); });
    $("#btn-add").addEventListener("click", () => addMissionFlow());
    $("#btn-backup").addEventListener("click", () => doBackup().catch(e => toast(e.message)));
    $("#btn-restore").addEventListener("click", () => doRestore().catch(e => toast(e.message)));
    document.body.addEventListener("click", (e) => {
      const id = e.target?.getAttribute?.("data-complete");
      if (id) { completeMission(id).catch(err => alert(err.message)); }
    });
    document.addEventListener("keydown", (e) => { if (e.key.toLowerCase() === "r") { renderSummary(30); renderMissions(); }});

    renderSummary(30).catch(console.error);
    renderMissions().catch(console.error);
    setInterval(() => { renderSummary(30); renderMissions(); }, 30000);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire);
  else wire();
})();


async function addXp(delta, reason) {
  await post('/api/xp', { delta, reason });
  await renderSummary(30);
}
/* ==== BEGIN LESS-001: lightweight router for /lessons ==== */
(function () {
  const lessonsView = document.getElementById('bp-lessons-view');
  const lessonsTileSection = document.getElementById('bp-lessons-tile-section');

  if (!lessonsTileSection || !lessonsView) return;

  document.addEventListener('click', (e) => {
    const a = e.target.closest('a[data-nav]');
    if (!a) return;
    const href = a.getAttribute('href');
    try {
      const sameOrigin = new URL(href, window.location.origin).origin === window.location.origin;
      if (sameOrigin && href && href.startsWith('/')) {
        e.preventDefault();
        if (href !== window.location.pathname) {
          window.history.pushState({}, '', href);
        }
        renderRoute();
      }
    } catch (_) { /* noop */ }
  });

  window.addEventListener('popstate', renderRoute);

  function renderRoute() {
    const path = window.location.pathname;
    const showLessons = (path === '/lessons');
    lessonsView.hidden = !showLessons;
    if (lessonsTileSection) lessonsTileSection.hidden = showLessons;
    if (showLessons) {
      const firstCard = document.querySelector('#bp-tracks .bp-tile');
      if (firstCard) firstCard.focus({ preventScroll: true });
    }
  }

  renderRoute();
})();
 /* ==== END LESS-001 ==== */

/* ==== LESSONS FALLBACK INIT (static baton support) ==== */
(function () {
  try {
    var baton = sessionStorage.getItem("bp-route");
    if (baton && typeof window !== "undefined" && window.history && window.location.pathname !== baton) {
      sessionStorage.removeItem("bp-route");
      window.history.replaceState({}, "", baton);
    }
  } catch (e) { /* no-op */ }
})();


/* ==== BEGIN LESS-001 HASH ROUTER (safe, no-server) ==== */
(function () {
  function getRoute() {
    // Prefer hash route (e.g., "#/lessons"); fall back to path ("/lessons")
    var hash = (typeof window !== "undefined" ? window.location.hash : "") || "";
    if (hash.replace(/\/+$/,"") === "#/lessons") return "lessons";
    var path = (typeof window !== "undefined" ? window.location.pathname : "") || "";
    if (path.replace(/\/+$/,"") === "/lessons") return "lessons"; // supports old path, too
    return "home";
  }

  function renderRoute() {
    var route = getRoute();
    var showLessons = (route === "lessons");
    var lessonsView = document.getElementById("bp-lessons-view");
    var lessonsTileSection = document.getElementById("bp-lessons-tile-section");
    if (lessonsView) lessonsView.hidden = !showLessons;
    if (lessonsTileSection) lessonsTileSection.hidden = showLessons;
    if (showLessons) {
      var firstCard = document.querySelector("#bp-tracks .bp-tile");
      if (firstCard && firstCard.focus) firstCard.focus({ preventScroll: true });
    }
  }

  // Intercept internal nav clicks that use data-nav and have hrefs starting with "#"
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[data-nav]');
    if (!a) return;
    var href = a.getAttribute("href") || "";
    if (href.startsWith("#/")) {
      e.preventDefault();
      // set the hash; hashchange will render
      if (window.location.hash !== href) window.location.hash = href;
      else renderRoute();
    }
  });

  window.addEventListener("hashchange", renderRoute);
  // First paint
  renderRoute();
})();
 /* ==== END LESS-001 HASH ROUTER ==== */


/* ==== BEGIN LESS-001 HASH ROUTER V2 (capture + hash, no server deps) ==== */
(function () {
  function currentRoute() {
    var h = (typeof window!=="undefined" ? window.location.hash : "") || "";
    if (h.replace(/\/+$/,"") === "#/lessons") return "lessons";
    var p = (typeof window!=="undefined" ? window.location.pathname : "") || "";
    if (p.replace(/\/+$/,"") === "/lessons") return "lessons"; // supports old path too
    return "home";
  }

  function render() {
    var route = currentRoute();
    var showLessons = (route === "lessons");
    var v = document.getElementById("bp-lessons-view");
    var t = document.getElementById("bp-lessons-tile-section");
    if (v) v.hidden = !showLessons;
    if (t) t.hidden = showLessons;
    if (showLessons) {
      var first = document.querySelector("#bp-tracks .bp-tile");
      if (first && first.focus) first.focus({ preventScroll: true });
    }
  }

  // Capture-phase click so no other handler can swallow it
  document.addEventListener("click", function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[data-nav]') : null;
    if (!a) return;
    var href = a.getAttribute("href") || "";
    if (href.startsWith("#/")) {
      e.preventDefault();
      if (window.location.hash !== href) window.location.hash = href;
      render();
    }
  }, true);

  window.addEventListener("hashchange", render);

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", render);
  } else {
    render();
  }
})();
 /* ==== END LESS-001 HASH ROUTER V2 ==== */


/* ==== BEGIN LESS-001 HASH ROUTER V3 (force styles; no server deps) ==== */
(function () {
  function routeIsLessons() {
    try {
      var h = window.location.hash || "";
      if (h.replace(/\/+$/,"") === "#/lessons") return true;
      var p = window.location.pathname || "";
      if (p.replace(/\/+$/,"") === "/lessons") return true; // legacy path support
    } catch (e) {}
    return false;
  }

  function showLessons() {
    var v = document.getElementById("bp-lessons-view");
    var t = document.getElementById("bp-lessons-tile-section");
    if (v) {
      // remove "hidden" and force visible
      v.hidden = false;
      try { v.removeAttribute("hidden"); } catch(e){}
      v.style.removeProperty("display");
      v.style.setProperty("display","block","important");
      v.style.setProperty("visibility","visible","important");
      v.style.setProperty("opacity","1","important");
    }
    if (t) {
      // force hide tile section
      t.hidden = true;
      try { t.setAttribute("hidden",""); } catch(e){}
      t.style.setProperty("display","none","important");
      t.style.setProperty("visibility","hidden","important");
      t.style.setProperty("opacity","0","important");
    }
    // a11y focus
    var first = document.querySelector("#bp-tracks .bp-tile");
    if (first && first.focus) { try { first.focus({ preventScroll:true }); } catch(e){} }
  }

  function showHome() {
    var v = document.getElementById("bp-lessons-view");
    var t = document.getElementById("bp-lessons-tile-section");
    if (v) {
      v.hidden = true;
      try { v.setAttribute("hidden",""); } catch(e){}
      v.style.setProperty("display","none","important");
      v.style.setProperty("visibility","hidden","important");
      v.style.setProperty("opacity","0","important");
    }
    if (t) {
      t.hidden = false;
      try { t.removeAttribute("hidden"); } catch(e){}
      t.style.removeProperty("display");
      t.style.setProperty("display","block","important");
      t.style.setProperty("visibility","visible","important");
      t.style.setProperty("opacity","1","important");
    }
  }

  function renderV3() {
    if (routeIsLessons()) showLessons(); else showHome();
  }

  // Capture-phase click so other handlers can't swallow it
  document.addEventListener("click", function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a[data-nav]') : null;
    if (!a) return;
    var href = a.getAttribute("href") || "";
    if (href.startsWith("#/")) {
      e.preventDefault();
      if (window.location.hash !== href) window.location.hash = href;
      // Run after hash mutation and layout
      requestAnimationFrame(renderV3);
    }
  }, true);

  window.addEventListener("hashchange", function(){ requestAnimationFrame(renderV3); });

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function(){ requestAnimationFrame(renderV3); });
  } else {
    requestAnimationFrame(renderV3);
  }
})();
 /* ==== END LESS-001 HASH ROUTER V3 ==== */


/* ==== BEGIN LESSONS ROUTE FLAG (sets html[data-route]) ==== */
(function () {
  function setRouteFlag() {
    try {
      var h = window.location.hash || "";
      var r = (h.replace(/\/+$/,"") === "#/lessons") ? "lessons" : "home";
      document.documentElement.setAttribute("data-route", r);
    } catch (e) {}
  }
  // Run on load and whenever hash changes
  window.addEventListener("hashchange", function(){ requestAnimationFrame(setRouteFlag); });
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function(){ requestAnimationFrame(setRouteFlag); });
  } else {
    requestAnimationFrame(setRouteFlag);
  }
})();
 /* ==== END LESSONS ROUTE FLAG ==== */


/* ==== BEGIN LESS-002: lessons summary wiring ==== */
(function(){
  async function updateLessonsSummary(){
    try{
      const res = await fetch("/api/lessons/summary",{cache:"no-store"});
      if(!res.ok) throw new Error("summary bad");
      const data = await res.json();
      if(!data || !Array.isArray(data.tracks)) return;
      const t = data.tracks.find(x => x.id === "python") || data.tracks[0];
      if(!t) return;
      const pct = Number.isFinite(t.progress) ? t.progress : 0;

      const tile = document.getElementById("bp-lessons-tile-progress");
      if (tile) tile.textContent = `${t.title} • ${pct}%`;

      const pv = document.getElementById("bp-lessons-progress");
      if (pv)  pv.textContent = `${pct}%`;
    }catch(e){ /* silent for MVP */ }
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updateLessonsSummary);
  } else {
    updateLessonsSummary();
  }
})();
 /* ==== END LESS-002 ==== */


/* ==== BEGIN LESS-003: lessons completion wiring ==== */
(function(){
  function ensureCompleteButton(){
    var host = document.querySelector("#bp-lessons-view .bp-grid");
    if (!host || document.getElementById("bp-complete-py-01-01")) return;

    var btn = document.createElement("button");
    btn.id = "bp-complete-py-01-01";
    btn.textContent = "Complete: Hello, Pyramid";
    btn.style.marginTop = "8px";
    btn.className = "bp-btn";
    // minimal button styling
    btn.style.padding = "8px 12px";
    btn.style.border = "1px solid rgba(255,255,255,.2)";
    btn.style.borderRadius = "8px";
    btn.style.background = "transparent";
    btn.style.cursor = "pointer";

    // Put it inside the first track card
    var firstCard = document.querySelector("#bp-tracks .bp-tile");
    (firstCard || host).appendChild(btn);

    btn.addEventListener("click", async function(){
      btn.disabled = true; btn.textContent = "Completing…";
      try{
        // 1) Mark lesson complete
        let r = await fetch("/api/lessons/complete", {
          method:"POST",
          headers:{ "Content-Type":"application/json" },
          body: JSON.stringify({ trackId:"python", lessonId:"py-01-01" })
        });
        let c = await r.json();
        if (!r.ok || !c || (c.error && c.error.length)) throw new Error(c.error || "complete failed");

        // 2) If just completed, award XP via the existing endpoint
        if (c.status === "ok" && Number.isFinite(c.awarded) && c.awarded > 0) {
          let xp = await fetch("/api/xp/add", {
            method:"POST",
            headers:{ "Content-Type":"application/json" },
            body: JSON.stringify({ delta: c.awarded, reason: `Lesson ${c.lessonId} complete` })
          });
          if (!xp.ok) console.warn("XP add failed");
        }

        // 3) Update the visible counts quickly
        try{
          const res = await fetch("/api/lessons/summary",{cache:"no-store"});
          const data = await res.json();
          const t = data.tracks.find(x => x.id === "python") || data.tracks[0];
          const pct = Number.isFinite(t.progress) ? t.progress : 0;
          const tile = document.getElementById("bp-lessons-tile-progress");
          if (tile) tile.textContent = `${t.title} • ${pct}%`;
          const pv = document.getElementById("bp-lessons-progress");
          if (pv)  pv.textContent = `${pct}%`;
        }catch(_){}

        // 4) Nudge the XP ring to refresh: quick reload (keeps the #/lessons hash)
        setTimeout(function(){ location.reload(); }, 600);
      }catch(err){
        console.error(err);
        btn.textContent = "Try again";
        btn.disabled = false;
      }
    });
  }

  // Run when Lessons view is shown
  function maybeAttach(){
    var showLessons = (location.hash.replace(/\/+$/,"") === "#/lessons") ||
                      (location.pathname.replace(/\/+$/,"") === "/lessons");
    if (showLessons) ensureCompleteButton();
  }

  window.addEventListener("hashchange", function(){ setTimeout(maybeAttach, 0); });
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function(){ setTimeout(maybeAttach, 0); });
  } else {
    setTimeout(maybeAttach, 0);
  }
})();
 /* ==== END LESS-003 ==== */

