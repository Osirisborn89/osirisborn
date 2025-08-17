import { db } from "./db.js";

const KEY = "outbox";

async function loadQ(){
  const q = await db.get(KEY);
  return Array.isArray(q) ? q : [];
}
async function saveQ(q){ await db.set(KEY, q) }

function newId(){
  return (crypto.randomUUID?.() ?? (Date.now()+"-"+Math.random().toString(16).slice(2)));
}

export async function addXP(delta, reason="client"){
  const item = { id:newId(), type:"xp-add", delta:Number(delta)||0, reason, ts:new Date().toISOString() };
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
      // success → drop from queue
    } catch {
      remain.push(item); // keep for later
    }
  }
  await saveQ(remain);
}

export async function pending(){ return loadQ() }

window.addEventListener("online", tryFlush);

// expose for dev testing
window.osbOutbox = { addXP, tryFlush, pending };
