async function fetchJSON(url){
  const r = await fetch(url, { cache: "no-store" });
  try { return await r.json(); } catch { return null; }
}
function norm(x){
  if (Array.isArray(x)) { const o = x.find(v => v && typeof v === "object"); if (o) x = o; }
  if (x && x.result) x = x.result;
  return x;
}
function showToast(msg){
  const t = document.getElementById("toast");
  if (t){ t.textContent = msg; t.style.opacity = "1"; setTimeout(()=>t.style.opacity=".85", 1800); }
  console.log("[toast]", msg);
}
async function refreshXP(note){
  try {
    const raw = await fetchJSON("/xp.json?days=7");
    const data = norm(raw);
    if (!data || !data.summary) return;

    const today = Number(data.summary.xpToday ?? 0) || 0;

    const elToday = document.getElementById("xp-today");
    if (elToday) elToday.textContent = String(today);

    const goalInput = document.getElementById("daily-goal");
    const goal = Number(goalInput?.value ?? 100) || 100;
    const pct = Math.max(0, Math.min(100, goal ? (today/goal)*100 : 0));
    const bar = document.getElementById("xp-bar-fill");
    if (bar) bar.style.width = pct.toFixed(1) + "%";

    if (note) showToast(note);
  } catch {}
}

window.addEventListener("osb:outbox:flushed", () => refreshXP());
window.addEventListener("osb:xp:awarded", (e)=>{
  const d = (e && e.detail) || {};
  refreshXP(`✓ +${Number(d.delta||0)} XP — ${d.reason||"Progress"}`);
});
window.addEventListener("osb:xp:skip", ()=>{
  refreshXP("✓ Already completed — no XP");
});

// Expose
window.osbRefreshXP = refreshXP;

// Initial kick
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => refreshXP(), { once:true });
} else {
  setTimeout(()=>refreshXP(), 0);
}
