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
    const d = series.map((row, i) => {
      const x = pad + i*step;
      const y = h - pad - (row.xp / max) * (h - pad*2);
      return `${x},${y}`;
    }).join(" ");
    $("#series").setAttribute("points", d);
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
        : `<button data-complete="${x.id}">Complete</button>`;
      return `<tr>
        <td class="mono">${x.id}</td>
        <td>${x.title}</td>
        <td class="mono">${x.xp}</td>
        <td class="${statusClass(x.status)}">${x.status}</td>
        <td>${btn}</td>
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

  function wire() {
    $("#btn-refresh").addEventListener("click", () => { renderSummary(30); renderMissions(); });
    $("#btn-add").addEventListener("click", () => addMissionFlow());
    document.body.addEventListener("click", (e) => {
      const id = e.target?.getAttribute?.("data-complete");
      if (id) { completeMission(id).catch(err => alert(err.message)); }
    });
    document.addEventListener("keydown", (e) => {
      if (e.key.toLowerCase() === "r") { renderSummary(30); renderMissions(); }
    });

    // initial
    renderSummary(30).catch(console.error);
    renderMissions().catch(console.error);

    // auto-refresh every 30s
    setInterval(() => { renderSummary(30); renderMissions(); }, 30000);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire);
  else wire();
})();
