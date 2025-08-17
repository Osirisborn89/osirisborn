import { db } from "./db.js";

const KEY = "outbox";
const CMP_KEY = "completed";

function readJSON(k){ try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } }
function writeJSON(k,v){ try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }

function getCompleted(){ return readJSON(CMP_KEY) || {}; }
function setCompleted(obj){ writeJSON(CMP_KEY, obj); }

function extractLessonId(reason){
  if (!reason) return null;
  const s = String(reason);
  // Common pattern we use: "Lesson <id> complete"
  let m = s.match(/lesson\s+([A-Za-z0-9._-]+)\s+complete/i);
  if (m && m[1]) return m[1];
  // Fallback: try to catch tokens like py-xx-yy in reason
  m = s.match(/\b([A-Za-z]{2,5}-\d{2}-\d{2})\b/);
  if (m && m[1]) return m[1];
  return null;
}

async function loadQ(){
  const q = await db.get(KEY);
  return Array.isArray(q) ? q : [];
}
async function saveQ(q){ await db.set(KEY, q) }

function newId(){
  return (crypto.randomUUID?.() ?? (Date.now()+"-"+Math.random().toString(16).slice(2)));
}

export async function addXP(delta, reason="client"){
  const item = {
    id: newId(),
    type: "xp-add",
    delta: Number(delta)||0,
    reason,
    ts: new Date().toISOString()
  };

  // If this looks like lesson completion, prevent duplicate awards client-side.
  const lid = extractLessonId(reason);
  if (lid) item.lessonId = lid;

  if (item.lessonId){
    const cmp = getCompleted();
    if (cmp[item.lessonId]){
      try {
        window.dispatchEvent(new CustomEvent("osb:xp:skip", { detail: { lessonId:item.lessonId, reason:item.reason } }));
        // Also ping a "flushed" event so listeners refresh UI
        window.dispatchEvent(new CustomEvent("osb:outbox:flushed", { detail: { remaining: 0 } }));
      } catch {}
      return "skip:"+item.lessonId;
    }
  }

  const q = await loadQ(); q.push(item); await saveQ(q);
  tryFlush(); // fire-and-forget
  return item.id;
}

export async function tryFlush(){
  if (!navigator.onLine) return;
  const q = await loadQ(); if (q.length===0) return;

  const remain = [];
  for (const item of q){
    if (item.type !== "xp-add") { remain.push(item); continue; }
    try {
      const res = await fetch("/api/xp/add", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ delta: item.delta, reason: item.reason })
      });
      if (!res.ok) throw new Error(String(res.status));

      // Success → if it's a lesson, mark completed so future adds are ignored.
      if (item.lessonId){
        const cmp = getCompleted();
        cmp[item.lessonId] = true;
        setCompleted(cmp);
      }

      // Tell UI exactly what was awarded.
      try {
        window.dispatchEvent(new CustomEvent("osb:xp:awarded", {
          detail: { delta: item.delta, reason: item.reason, lessonId: item.lessonId || null }
        }));
      } catch {}
    } catch {
      remain.push(item); // keep for later
    }
  }

  await saveQ(remain);

  // announce that a flush cycle finished
  try {
    window.dispatchEvent(new CustomEvent("osb:outbox:flushed", { detail: { remaining: remain.length } }));
  } catch {}
}

export async function pending(){ return loadQ() }

window.addEventListener("online", tryFlush);

// expose for testing
window.osbOutbox = { addXP, tryFlush, pending };
