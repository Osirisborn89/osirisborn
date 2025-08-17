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
