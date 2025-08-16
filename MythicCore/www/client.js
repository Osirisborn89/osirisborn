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
