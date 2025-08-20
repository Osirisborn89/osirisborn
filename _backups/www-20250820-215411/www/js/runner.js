(function () {
  // Minimal, deterministic runner. No UI side-effects here.
  // Return a structured result; lessons.js will award XP + toast.

  function ok(id, xp, note) { return { ok: true, id, xp, note }; }
  function fail(id, note)   { return { ok: false, id, note }; }

  // Demo "checks" you can expand later.
  async function checkFirstPrint() {
    // In a real check you might run code in a sandbox or inspect state.
    // For now we just pass.
    return ok("py-01-01", 10, "Printed hello world");
  }

  async function checkVariables() {
    // Placeholder; later parse a snippet or query saved state.
    return ok("py-01-02", 20, "Basic vars & types ok");
  }

  const checks = {
    "python:first-print": checkFirstPrint,
    "python:variables":   checkVariables,
  };

  // Public API
  window.runner = {
    async runCheck(symbolOrId) {
      const key = String(symbolOrId || "").trim();
      const fn  = checks[key] || null;
      if (!fn) return fail(key || "unknown", "No such check");
      try {
        const res = await fn();
        return res && res.ok ? res : fail(res?.id || key, res?.note || "Unknown failure");
      } catch (e) {
        return fail(key, e?.message || String(e));
      }
    }
  };
})();
// === OSB LESS-011 BEGIN ===
(function(){
  if (window.__OSB_RUNNER_UX__) return;
  window.__OSB_RUNNER_UX__ = true;

  async function runSample(lessonId) {
    try {
      // Adjust endpoint mapping if your runner differs
      const res = await fetch(`/api/runner/run?lessonId=${encodeURIComponent(lessonId)}`, { method: 'POST' });
      if (!res.ok) return { ok:false, lessonId, xp:0, awarded:false };
      const data = await res.json(); // expect { ok:true, pass:true, xp:10 }

      const ok = !!data.ok && !!data.pass;
      let awarded = false;
      let xp = Number(data.xp || 0);

      if (ok) {
        const award = await fetch('/api/xp/add', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ lessonId, xp })
        });
        awarded = award.ok;
      }
      return { ok, lessonId, xp, awarded };
    } catch(e){
      return { ok:false, lessonId, xp:0, awarded:false };
    }
  }

  window.runSample = runSample;
})();
// === OSB LESS-011 END ===
