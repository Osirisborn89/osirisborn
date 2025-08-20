/* MythicCore/www/js/backup.js */
function read(k){ try { return JSON.parse(localStorage.getItem(k)); } catch { return null } }
function write(k,v){ localStorage.setItem(k, JSON.stringify(v)); }
function nowStamp(){
  const d=new Date();
  const p=n=>String(n).padStart(2,"0");
  return d.getFullYear()+p(d.getMonth()+1)+p(d.getDate())+"-"+p(d.getHours())+p(d.getMinutes())+p(d.getSeconds());
}
function notify(msg){
  try{
    const el = document.getElementById("toast");
    if (!el) return alert(msg);
    el.textContent = msg;
    el.style.opacity = "1";
    setTimeout(()=>{ el.style.opacity = ".85"; }, 1800);
  }catch{}
}
async function snapshot(){
  const local = {
    xp:       read("xp")       ?? { totalXP:0, xpToday:0, series:[], updatedAt:new Date().toISOString() },
    settings: read("settings") ?? { dailyGoal:100, theme:"neon-purple", soundscape:true, updatedAt:new Date().toISOString() },
    notes:    read("notes")    ?? { items:[] },
    outbox:   read("outbox")   ?? []
  };
  const server = {};
  try { const r = await fetch("/xp.json?days=14",{cache:"no-store"}); if(r.ok) server.xp = await r.json(); } catch {}
  try { const r = await fetch("/diag",{cache:"no-store"}); if(r.ok) server.diag = await r.json(); } catch {}
  return {
    version: "0.1",
    createdAt: new Date().toISOString(),
    local, server
  };
}
function download(text, filename){
  const blob = new Blob([text], { type:"application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(()=>{ URL.revokeObjectURL(a.href); try{document.body.removeChild(a)}catch{} }, 800);
}
export async function backupNow(){
  const data = await snapshot();
  const text = JSON.stringify(data, null, 2);
  try { localStorage.setItem("osb:lastBackup", text); } catch {}
  download(text, `osb-backup-${nowStamp()}.json`);
  notify("Backup saved.");
}
async function pickBackupFile(){
  if ("showOpenFilePicker" in window){
    const [h] = await window.showOpenFilePicker({
      types:[{ description:"JSON backup", accept:{ "application/json":[".json"] } }],
      excludeAcceptAllOption:false, multiple:false
    });
    return await h.getFile();
  }
  return await new Promise((resolve, reject)=>{
    const inp=document.createElement("input");
    inp.type="file"; inp.accept=".json,application/json"; inp.style.display="none";
    inp.onchange=()=> resolve(inp.files?.[0]);
    inp.oncancel=()=> reject(new Error("cancel"));
    document.body.appendChild(inp); inp.click();
    setTimeout(()=>{ try{document.body.removeChild(inp)}catch{} }, 0);
  });
}
function applyLocal(local){
  if (local?.xp)       write("xp", local.xp);
  if (local?.settings) write("settings", local.settings);
  if (local?.notes)    write("notes", local.notes);
  if (Array.isArray(local?.outbox)) write("outbox", local.outbox);
}
export async function restoreLatest(){
  let text = localStorage.getItem("osb:lastBackup");
  if (!text) {
    try { const file = await pickBackupFile(); text = await file.text(); }
    catch { notify("No backup found to restore."); return; }
  }
  let data = null;
  try { data = JSON.parse(text); } catch { notify("Backup parse failed."); return; }
  try { applyLocal(data.local); } catch {}
  notify("Restore applied — reloading…");
  try { location.reload(); } catch {}
}
function wire(){
  document.getElementById("btn-backup")?.addEventListener("click", ()=>backupNow());
  document.getElementById("btn-restore")?.addEventListener("click", ()=>restoreLatest());
}
if (document.readyState==="loading") document.addEventListener("DOMContentLoaded", wire, { once:true });
else wire();
