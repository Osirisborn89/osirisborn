(function () {
  const STATE = {
    data: null,
    completed: JSON.parse(localStorage.getItem("completed") || "{}") // { [lessonId]: true }
  };

  async function loadCurriculum() {
    const res = await fetch("/data/curriculum.json", { cache: "no-store" });
    if (!res.ok) throw new Error("curriculum.json failed to load");
    STATE.data = await res.json();
  }

  function el(tag, attrs = {}, ...children) {
    const node = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === "class") node.className = v; else node.setAttribute(k, v);
    }
    children.flat().forEach(c => node.append(c && c.nodeType ? c : String(c ?? "")));
    return node;
  }

  function lessonRow(lesson) {
    const done = !!STATE.completed[lesson.id];
    const row = el("div", { class: `lesson-row ${done ? "done" : ""}` });

    const title = el("div", { class: "lesson-title" },
      `${lesson.title} `,
      el("span", { class: "lesson-id" }, `(${lesson.id})`)
    );
    const meta = el("div", { class: "lesson-meta" }, lesson.brief || "");

    const actions = el("div", { class: "lesson-actions" });
    const btnRun = el("button", { class: "btn-run", "data-id": lesson.id }, "Run / Check");
    btnRun.addEventListener("click", async () => {
      try {
        // Delegate to your runner (symbolic check name or fallback to lesson.id)
        const symbol = lesson.runner?.check || lesson.id;
        const result = await window.runner?.runCheck?.(symbol);

        // Normalize toast + XP via events (live-xp.js will format if it sees a lessonId)
        const reason = `Lesson ${lesson.id} complete`;
        window.dispatchEvent(new CustomEvent("osb:xp:awarded", {
          detail: { delta: lesson.xp, reason, lessonId: lesson.id }
        }));

        // Mirror client dedupe (UI state)
        STATE.completed[lesson.id] = true;
        localStorage.setItem("completed", JSON.stringify(STATE.completed));
        row.classList.add("done");

        // Optional toast if runner didn't: still gets normalized
        window.toast?.(`✓ +${lesson.xp} XP — ${reason}`);
      } catch (e) {
        window.toast?.(`Runner error: ${e?.message || e}`, { level: "error" });
      }
    });

    actions.append(btnRun);
    row.append(title, meta, actions);
    return row;
  }

  function moduleCard(mod) {
    const card = el("div", { class: "module-card" });
    const header = el("div", { class: "module-header" },
      el("h3", {}, mod.title),
      el("div", { class: "module-brief" }, mod.brief || "")
    );
    const list = el("div", { class: "lesson-list" });
    mod.lessons.forEach(lsn => list.append(lessonRow(lsn)));
    card.append(header, list);
    return card;
  }

  function trackSection(track) {
    const section = el("section", { class: "track-section" });
    const lessons = track.modules.flatMap(m => m.lessons);
    const total = lessons.reduce((a, l) => a + (l.xp || 0), 0);
    const earned = lessons.filter(l => STATE.completed[l.id]).reduce((a, l) => a + (l.xp || 0), 0);
    const pct = total ? Math.round((earned / total) * 100) : 0;

    const header = el("header", { class: "track-header" },
      el("h2", {}, `${track.icon || ""} ${track.title}`),
      el("div", { class: "track-progress" }, `${earned}/${total} XP (${pct}%)`)
    );

    const grid = el("div", { class: "module-grid" });
    track.modules.forEach(m => grid.append(moduleCard(m)));
    section.append(header, grid);
    return section;
  }

  async function render() {
    await loadCurriculum();
    const root = document.getElementById("lessons-root") || document.getElementById("bp-lessons-root");
    if (!root) return;
    root.innerHTML = "";
    (STATE.data.tracks || []).forEach(t => root.append(trackSection(t)));
    document.body.classList.add("route-lessons"); // keep lessons-tile safety net hidden
  }

  // route hook
  window.addEventListener("hashchange", () => {
    if (location.hash.startsWith("#/lessons")) render();
  });
  if (location.hash.startsWith("#/lessons")) render();
})();
// === OSB LESS-011 BEGIN ===
(function(){
  if (window.__OSB_LESSON_UX__) return; 
  window.__OSB_LESSON_UX__ = true;

  const state = {
    trackId: 'python-beginner',
    toastLock: new Set(),
  };

  async function getCurriculum() {
    try {
      if (window.CURRICULUM?.getTrack) {
        return { getTrack: window.CURRICULUM.getTrack.bind(window.CURRICULUM) };
      }
      const res = await fetch("/data/curriculum.json", { cache: "no-store" }).catch(()=>null);
      if (!res || !res.ok) return null;
      const data = await res.json();
      return {
        getTrack: (id)=> (data.tracks || []).find(t=>t.id===id)
      };
    } catch(e){ return null; }
  }

  function xpPill(xp) { return `<span class="xp-pill">${xp} XP</span>`; }
  function actionButtons(lesson){
    const acts = lesson.actions || [];
    const btns = [];
    if (acts.includes('run')) btns.push(`<button class="btn small btn-run" data-lesson="${lesson.id}">Run</button>`);
    if (acts.includes('check')) btns.push(`<button class="btn small btn-check" data-lesson="${lesson.id}">Check</button>`);
    return btns.join('');
  }

  function lessonRow(lesson, completedSet) {
    const completed = completedSet.has(lesson.id);
    const completedClass = completed ? 'completed' : '';
    const statusBadge = completed ? `<span class="badge-ok">✓ Completed</span>` : '';
    return `
      <div class="lesson-row ${completedClass}" data-lesson="${lesson.id}">
        <div class="lesson-main">
          <div class="lesson-title">${lesson.title}</div>
          <div class="lesson-brief">${lesson.brief || ''}</div>
        </div>
        <div class="lesson-side">
          ${xpPill(lesson.xp || 0)}
          ${statusBadge}
          <div class="lesson-actions">${actionButtons(lesson)}</div>
        </div>
      </div>
    `;
  }

  async function fetchTrackProgress(trackId) {
    try {
      const res = await fetch(`/api/lessons/track/${trackId}`, { cache: 'no-store' });
      if (!res.ok) return { completed: new Set(), totals: { done:0, total:0, pct:0 } };
      const data = await res.json();
      return { completed: new Set(data.completed || []), totals: data.totals || { done:0, total:0, pct:0 } };
    } catch(e){
      return { completed: new Set(), totals: { done:0, total:0, pct:0 } };
    }
  }

  function setTrackBadgeProgress(totals) {
    const badge = document.querySelector(`[data-track="${state.trackId}"] .track-progress`);
    if (badge) {
      badge.textContent = `${totals.pct || 0}%`;
      badge.setAttribute('data-done', totals.done || 0);
      badge.setAttribute('data-total', totals.total || 0);
    }
  }

  async function renderLessons(track, container) {
    const { completed, totals } = await fetchTrackProgress(state.trackId);
    setTrackBadgeProgress(totals);
    const rows = [];
    if (track?.modules) {
      for (const m of track.modules) {
        rows.push(`<div class="module-title">${m.title}</div>`);
        for (const lesson of m.lessons) rows.push(lessonRow(lesson, completed));
      }
    }
    container.innerHTML = rows.join('');
    container.addEventListener('click', async (ev) => {
      const btn = ev.target.closest('button');
      if (!btn) return;
      const lessonId = btn.getAttribute('data-lesson');
      if (btn.classList.contains('btn-run')) await onRun(lessonId);
      if (btn.classList.contains('btn-check')) await onCheck(lessonId);
    }, { once: true });
  }

  async function onRun(lessonId) {
    const result = await window.runSample?.(lessonId);
    if (result?.ok && result?.awarded) {
      singleToast(result.lessonId, `✓ +${result.xp} XP — Lesson ${result.lessonId} complete`);
      await refreshAfterChange();
    }
  }

  async function onCheck(lessonId) {
    const payload = { trackId: state.trackId, lessonId };
    const res = await fetch('/api/lessons/complete', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload),
    });
    if (res.ok) {
      singleToast(lessonId, `✓ Lesson ${lessonId} marked complete`);
      await refreshAfterChange();
    }
  }

  async function refreshAfterChange() {
    const container = document.querySelector('#lessons-container');
    const cur = await getCurriculum();
    const track = cur?.getTrack(state.trackId);
    if (container && track) await renderLessons(track, container);
  }

  function singleToast(key, msg) {
    if (state.toastLock.has(key)) return;
    state.toastLock.add(key);
    (window.toast && typeof window.toast === 'function') && window.toast(msg);
    setTimeout(()=>state.toastLock.delete(key), 1500);
  }

  async function bootIfLessonsRoute(){
    const isLessons = (location.hash || '').includes('/lessons');
    if (!isLessons) return;
    const container = document.querySelector('#lessons-container');
    const cur = await getCurriculum();
    const track = cur?.getTrack(state.trackId);
    if (container && track) {
      await renderLessons(track, container);
    } else {
      // fallback: decorate any existing rows if present
      const rows = document.querySelectorAll('.lesson-row[data-lesson]');
      if (rows.length && cur) {
        // minimal decoration
        rows.forEach(r=>{
          const id = r.getAttribute('data-lesson');
          const trackObj = cur.getTrack(state.trackId);
          const allLessons = trackObj?.modules?.flatMap(m=>m.lessons)||[];
          const meta = allLessons.find(l=>l.id===id);
          if (!meta) return;
          const side = r.querySelector('.lesson-side') || r.appendChild(Object.assign(document.createElement('div'),{className:'lesson-side'}));
          if (!side.querySelector('.xp-pill')) side.insertAdjacentHTML('afterbegin', xpPill(meta.xp||0));
          const act = side.querySelector('.lesson-actions') || side.appendChild(Object.assign(document.createElement('div'),{className:'lesson-actions'}));
          if (!act.querySelector('.btn-run') && (meta.actions||[]).includes('run')) act.insertAdjacentHTML('beforeend', `<button class="btn small btn-run" data-lesson="${id}">Run</button>`);
          if (!act.querySelector('.btn-check') && (meta.actions||[]).includes('check')) act.insertAdjacentHTML('beforeend', `<button class="btn small btn-check" data-lesson="${id}">Check</button>`);
        });
        // attach one-time click handler at container level if exists
        (rows[0]?.parentElement||document).addEventListener('click', async (ev)=>{
          const btn = ev.target.closest('button[data-lesson]');
          if (!btn) return;
          if (btn.classList.contains('btn-run')) await onRun(btn.getAttribute('data-lesson'));
          if (btn.classList.contains('btn-check')) await onCheck(btn.getAttribute('data-lesson'));
        }, { once:true });
      }
    }
  }

  window.addEventListener('DOMContentLoaded', bootIfLessonsRoute);
  window.addEventListener('hashchange', bootIfLessonsRoute);
})();
// === OSB LESS-011 END ===


