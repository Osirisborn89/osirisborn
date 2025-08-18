/* MythicCore/www/lessons.js */
import { addXP, tryFlush } from "./js/outbox.js";

const FALLBACK = [
  { id:"py-01-01", title:"Hello, Pyramid", xp:10, track:"python" },
  { id:"py-01-02", title:"Variables 101", xp:15, track:"python" },
  { id:"py-01-03", title:"Control Flow Basics", xp:20, track:"python" },
];

async function loadCurriculum(){
  const candidates = ["/api/lessons", "/api/lessons/list", "/curriculum.json"];
  for (const url of candidates){
    try {
      const r = await fetch(url, { cache:"no-store" });
      if (!r.ok) continue;
      const j = await r.json();
      if (Array.isArray(j)) return j;
      if (j && Array.isArray(j.lessons)) return j.lessons;
      if (j && j.result && Array.isArray(j.result.lessons)) return j.result.lessons;
    } catch {}
  }
  return FALLBACK;
}

function h(tag, attrs={}, ...children){
  const el = document.createElement(tag);
  for (const [k,v] of Object.entries(attrs||{})){
    if (k === "class") el.className = v;
    else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v);
    else el.setAttribute(k, v);
  }
  for (const c of children){
    if (c == null) continue;
    if (typeof c === "string") el.appendChild(document.createTextNode(c));
    else el.appendChild(c);
  }
  return el;
}

function render(list){
  const host = document.getElementById("bp-lessons-view") || document.body;
  let root = document.getElementById("lessons-list");
  if (!root){
    root = h("div", { id:"lessons-list" });
    (host).appendChild(root);
  }
  root.innerHTML = "";
  list.forEach(lesson => {
    const card = h("div", { class:"lesson-card" },
      h("div", { class:"lesson-title" }, lesson.title || lesson.id),
      h("div", { class:"lesson-meta" }, `XP: ${lesson.xp ?? 10}`),
      h("div", { class:"lesson-actions" },
        h("button", { id:`btn-${lesson.id}` }, "Complete")
      )
    );
    root.appendChild(card);
    const btn = card.querySelector("button");
    btn?.addEventListener("click", () => completeLesson(lesson, btn));
  });
}

async function completeLesson(lesson, btn){
  btn.disabled = true; const label = btn.textContent; btn.textContent = "Completing…";
  let awarded = 0;
  try {
    const r = await fetch("/api/lessons/complete", {
      method:"POST",
      headers:{ "Content-Type":"application/json" },
      body: JSON.stringify({ trackId: lesson.track || "python", lessonId: lesson.id })
    });
    const j = await r.json().catch(()=>({}));
    if (r.ok && j && j.status === "ok" && Number.isFinite(j.awarded) && j.awarded > 0) {
      awarded = j.awarded;
    }
  } catch {}
  try {
    if (awarded <= 0) {
      const xp = Number(lesson.xp ?? 10) || 0;
      if (xp > 0) await addXP(xp, `Lesson ${lesson.id} complete`);
    }
    tryFlush();
    toast(`Completed "${lesson.title || lesson.id}" +${awarded>0?awarded:(lesson.xp ?? 10)} XP`);
  } finally {
    setTimeout(()=>{ btn.disabled=false; btn.textContent=label; }, 600);
  }
}

function toast(msg){
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = msg;
  el.style.opacity = "1";
  setTimeout(()=>{ el.style.opacity = ".85"; }, 2000);
}

async function init(){
  const list = await loadCurriculum();
  render(list);
}
document.addEventListener("DOMContentLoaded", init);
if (document.readyState === "complete" || document.readyState === "interactive") init();
