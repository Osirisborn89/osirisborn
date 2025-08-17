import { db } from "./db.js";

const LATEST_KEY = "osb.backup.latest";

function toast(msg){
  const el = document.getElementById("toast");
  if (!el) return;
  el.textContent = msg;
  el.style.opacity = "1";
  setTimeout(()=>{ el.style.opacity = ".85"; }, 2000);
}

async function collect(){
  const all = await db.all();
  const outbox = await db.get("outbox") ?? [];
  return {
    meta: {
      app: "Osirisborn / Black Pyramid",
      version: 1,
      ts: new Date().toISOString()
    },
    data: {
      xp: all.xp,
      settings: all.settings,
      notes: all.notes,
      outbox
    }
  };
}

function downloadBundle(bundle){
  const pretty = JSON.stringify(bundle, null, 2);
  const blob = new Blob([pretty], { type: "application/json" });
  const ts = new Date().toISOString().replace(/[:.]/g, "").slice(0, 15);
  const name = `osb-bundle-${ts}.json`;
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  setTimeout(()=>URL.revokeObjectURL(a.href), 1500);
  a.remove();
  localStorage.setItem(LATEST_KEY, pretty);
}

async function restoreBundle(bundle){
  if (!bundle || !bundle.data) throw new Error("Invalid bundle");
  const d = bundle.data;

  if (d.xp)       await db.set("xp", d.xp);
  if (d.settings) await db.set("settings", d.settings);
  if (d.notes)    await db.set("notes", d.notes);
  if ("outbox" in d) await db.set("outbox", Array.isArray(d.outbox) ? d.outbox : []);

  try {
    window.dispatchEvent(new CustomEvent("osb:data:restored"));
  } catch {}
  toast("Restore complete — reloading…");
  setTimeout(()=>location.reload(), 400);
}

async function restoreFromLatest(){
  const raw = localStorage.getItem(LATEST_KEY);
  if (!raw) {
    toast("No saved backup found. Hold Shift and click Restore to choose a file.");
    return;
  }
  const parsed = JSON.parse(raw);
  await restoreBundle(parsed);
}

function pickFileAndRestore(){
  const input = document.createElement("input");
  input.type = "file";
  input.accept = "application/json";
  input.style.display = "none";
  document.body.appendChild(input);
  input.addEventListener("change", async () => {
    const file = input.files?.[0];
    if (!file) return;
    const text = await file.text().catch(()=>null);
    if (!text) { toast("Could not read file."); return; }
    try {
      const parsed = JSON.parse(text);
      localStorage.setItem(LATEST_KEY, JSON.stringify(parsed));
      await restoreBundle(parsed);
    } catch {
      toast("Invalid JSON bundle.");
    } finally {
      input.remove();
    }
  });
  input.click();
}

async function onBackup(){
  try {
    const bundle = await collect();
    downloadBundle(bundle);
    toast("Backup downloaded and saved as latest.");
  } catch {
    toast("Backup failed.");
  }
}

async function onRestore(ev){
  if (ev && ev.shiftKey) {
    pickFileAndRestore();
  } else {
    restoreFromLatest();
  }
}

function wire(){
  const b = document.getElementById("btn-backup");
  const r = document.getElementById("btn-restore");
  if (b) b.addEventListener("click", onBackup);
  if (r) r.addEventListener("click", onRestore);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", wire);
} else {
  wire();
}
