export const db = (() => {
  // Simple localStorage-backed KV with sane defaults
  function read(k){ try { return JSON.parse(localStorage.getItem(k)) } catch { return null } }
  function write(k,v){ localStorage.setItem(k, JSON.stringify(v)) }

  return {
    async get(k){ return read(k); },
    async set(k,v){ write(k,v); },
    async all(){
      const now = new Date().toISOString();
      return {
        xp:       read("xp")       ?? { totalXP:0, xpToday:0, series:[], updatedAt: now },
        settings: read("settings") ?? { dailyGoal:100, theme:"neon-purple", soundscape:true, updatedAt: now },
        notes:    read("notes")    ?? { items:[] }
      };
    }
  };
})();
