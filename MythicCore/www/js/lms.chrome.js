/* Black Pyramid — LMS Chrome v1 (overlay)
 * Scope: attaches to #/learn/<trackId> and #/learn/<trackId>/<module>/<lesson>
 * Guard-safe: no title/brand changes; CSS scoped under .bp-lms
 * State: localStorage: bp.progress, bp.resume
 */
(function () {
  'use strict';

  // -----------------------------
  // Config & Utilities
  // -----------------------------
  const LS_PROGRESS_KEY = 'bp.progress';
  const LS_RESUME_KEY   = 'bp.resume';

  const qs  = (sel, el=document) => el.querySelector(sel);
  const qsa = (sel, el=document) => Array.from(el.querySelectorAll(sel));
  const on  = (el, ev, fn, opts) => el.addEventListener(ev, fn, opts);

  const progress = {
    get() {
      try { return JSON.parse(localStorage.getItem(LS_PROGRESS_KEY) || '{}'); }
      catch { return {}; }
    },
    set(obj) {
      localStorage.setItem(LS_PROGRESS_KEY, JSON.stringify(obj||{}));
    },
    isDone(key) {
      const p = this.get();
      return p[key] === 'done';
    },
    mark(key, done) {
      const p = this.get();
      if (done) p[key] = 'done'; else delete p[key];
      this.set(p);
    }
  };

  const resume = {
    get() {
      try { return JSON.parse(localStorage.getItem(LS_RESUME_KEY) || '{}'); }
      catch { return {}; }
    },
    set(trackId, url) {
      const r = this.get();
      r[trackId] = url;
      localStorage.setItem(LS_RESUME_KEY, JSON.stringify(r));
    }
  };

  // Inject scoped styles once
  function ensureStyles() {
    if (qs('#bp-lms-style')) return;
    const css = `
    .bp-lms { font-family: system-ui, Segoe UI, Roboto, Helvetica, Arial, sans-serif; line-height: 1.45; color: #e6e6e6; }
    .bp-lms a { color: #9bd; text-decoration: none; }
    .bp-lms a:hover { text-decoration: underline; }
    .bp-wrap { display: grid; grid-template-columns: 280px 1fr 260px; gap: 16px; }
    .bp-left { background:#11151a; border:1px solid #25303a; border-radius:12px; padding:12px; max-height: calc(100vh - 140px); overflow:auto; }
    .bp-main { background:#0d1117; border:1px solid #25303a; border-radius:12px; padding:16px; }
    .bp-right { background:#11151a; border:1px solid #25303a; border-radius:12px; padding:12px; display:none; }
    .bp-breadcrumbs { font-size: 13px; margin: 0 0 8px 0; display:flex; gap:6px; flex-wrap:wrap; align-items:center; }
    .bp-breadcrumbs .bp-crumb::after { content: '›'; margin:0 4px; opacity:0.5; }
    .bp-breadcrumbs .bp-crumb:last-child::after { content:''; }
    .bp-header { display:flex; flex-wrap:wrap; gap:8px 12px; align-items:center; margin:6px 0 10px 0; }
    .bp-title { font-size: 22px; font-weight: 700; }
    .bp-badges { display:flex; gap:8px; }
    .bp-badge { font-size:12px; padding:4px 8px; border-radius:999px; border:1px solid #2b3845; background:#141b22; }
    .bp-prereqs { font-size: 12px; opacity:.85; }
    .bp-progressbar { height:8px; background:#1a2230; border:1px solid #2b3845; border-radius:999px; overflow:hidden; margin:8px 0 14px 0; }
    .bp-progressbar > div { height:100%; width:0%; background:linear-gradient(90deg, #7b5cff, #00d4ff); transition:width .25s ease; }
    .bp-body { display:grid; gap:16px; }
    .bp-actions { display:flex; gap:8px; margin-top:10px; }
    .bp-btn { padding:8px 12px; border-radius:8px; border:1px solid #2b3845; background:#141b22; color:#e6e6e6; cursor:pointer; user-select:none; }
    .bp-btn[disabled] { opacity:.5; cursor:not-allowed; }
    .bp-sidebar-title { font-weight:700; margin:2px 0 8px 0; font-size:14px; display:flex; justify-content:space-between; align-items:center;}
    .bp-side-toggle { cursor:pointer; font-size:12px; opacity:.8; }
    .bp-module { margin-bottom:10px; }
    .bp-module h4 { margin:8px 0 4px 0; font-size:13px; opacity:.9; }
    .bp-lessons { display:grid; gap:4px; }
    .bp-lesson { display:flex; align-items:center; gap:6px; font-size:13px; padding:6px 8px; border-radius:6px; }
    .bp-lesson.bp-current { background:#161d26; border:1px solid #2b3845; }
    .bp-lesson .bp-lock { opacity:.7; }
    .bp-lesson a { flex:1; }
    .bp-lesson .bp-tick { font-size:12px; opacity:.9; }
    .bp-lock { width:14px; height:14px; display:inline-grid; place-items:center; border:1px solid #2b3845; border-radius:3px; }
    .bp-callout { border:1px solid #2b3845; border-left:4px solid #7b5cff; background:#141b22; padding:10px; border-radius:6px; }
    .bp-callout.tip   { border-left-color:#4fdb8e; }
    .bp-callout.info  { border-left-color:#00d4ff; }
    .bp-callout.warn  { border-left-color:#ff8c42; }
    .bp-code { border:1px solid #2b3845; background:#0b0f14; padding:10px; border-radius:6px; overflow:auto; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-size: 13px;}
    .bp-out { border:1px dashed #2b3845; background:#0f141a; padding:8px; border-radius:6px; white-space:pre-wrap; }
    .bp-task { counter-increment: task; }
    .bp-task::before { content: "Task " counter(task) ": "; font-weight:700; }
    .bp-checkpoint { border:1px solid #2b3845; background:#0f141a; padding:10px; border-radius:8px; }
    .bp-hidden { display:none; }
    .bp-taglist { display:flex; gap:6px; flex-wrap:wrap; }
    .bp-tag { font-size:11px; padding:2px 6px; border-radius:999px; border:1px solid #2b3845; background:#141b22; }
    @media (max-width: 980px) {
      .bp-wrap { grid-template-columns: 1fr; }
      .bp-left { order:2; }
      .bp-right { order:3; display:none !important; }
    }`;
    const style = document.createElement('style');
    style.id = 'bp-lms-style';
    style.textContent = css;
    document.head.appendChild(style);
  }

  // Route helpers: #/learn/<trackId> or #/learn/<trackId>/<module>/<lesson>
  function parseRoute() {
    const hash = location.hash || '';
    const parts = hash.replace(/^#\//, '').split('/');
    if (parts[0] !== 'learn') return null;
    const trackId = parts[1];
    const moduleId = parts[2];
    const lessonId = parts[3];
    return { trackId, moduleId, lessonId };
  }

  // Fetch track JSON (MythicCore/www/api/lessons/<trackId>.json)
  async function getTrack(trackId) {
    if (!trackId) return null;
    const base = getBaseHref();
    const url  = `${base}api/lessons/${encodeURIComponent(trackId)}.json`;
    const res  = await fetch(url, { cache: 'no-store' });
    if (!res.ok) throw new Error('Track JSON not found: ' + url);
    return await res.json();
  }

  // Guess base href for /api (assumes we’re inside MythicCore/www/)
  function getBaseHref() {
    // If the portal or SPA sets a <base>, respect it. Otherwise assume ./ 
    const b = qs('base');
    return b ? b.getAttribute('href') : './';
  }

  // Build lesson key for progress
  function lessonKey(trackId, moduleId, lessonId) {
    return `${trackId}:${moduleId}:${lessonId}`;
  }

  // Gating rule: unlocked iff first lesson OR previous is done OR prereqs met
  function isUnlocked(track, modIdx, lesIdx, modulesMap, progressMap) {
    if (modIdx === 0 && lesIdx === 0) return true;
    // previous lesson in linear order:
    let prev = null;
    if (lesIdx > 0) {
      prev = { m: modIdx, l: lesIdx - 1 };
    } else if (modIdx > 0) {
      const prevMod = track.modules[modIdx-1];
      prev = { m: modIdx - 1, l: prevMod.lessons.length - 1 };
    }
    const prevKey = prev ? lessonKey(track.trackId, track.modules[prev.m].id, track.modules[prev.m].lessons[prev.l].id) : null;
    const prevDone = prevKey ? (progressMap[prevKey] === 'done') : false;

    // prereqs (optional)
    const m = track.modules[modIdx];
    const lesson = m.lessons[lesIdx];
    const prereqs = Array.isArray(lesson.prereqs) ? lesson.prereqs : [];
    const prereqsDone = prereqs.every(p => {
      // supports "<module>:<lesson>" or "<lesson>" (same module)
      let mk, lk;
      if (p.includes(':')) {
        const [pm, pl] = p.split(':');
        mk = pm; lk = pl;
      } else {
        mk = m.id; lk = p;
      }
      const key = lessonKey(track.trackId, mk, lk);
      return progressMap[key] === 'done';
    });

    return prevDone || prereqsDone;
  }

  // Shortcode renderer (lightweight, regex-based)
  function renderBody(html) {
    if (!html) return '';
    let out = html;

    // [[callout:type]]...[[/callout]]
    out = out.replace(/\[\[callout:(tip|info|warn)\]\]([\s\S]*?)\[\[\/callout\]\]/g, (_, t, body) =>
      `<div class="bp-callout ${t}">${body.trim()}</div>`);

    // [[code:py]]...[[/code]] (generic)
    out = out.replace(/\[\[code:([a-z0-9_+-]+)\]\]([\s\S]*?)\[\[\/code\]\]/gi, (_, lang, body) =>
      `<pre class="bp-code" data-lang="${lang.toLowerCase()}"><code>${escapeHtml(body)}</code></pre>`);

    // [[out]]...[[/out]]
    out = out.replace(/\[\[out\]\]([\s\S]*?)\[\[\/out\]\]/g, (_, body) =>
      `<div class="bp-out">${escapeHtml(body)}</div>`);

    // [[task]]...[[/task]]
    out = out.replace(/\[\[task\]\]([\s\S]*?)\[\[\/task\]\]/g, (_, body) =>
      `<div class="bp-task">${body.trim()}</div>`);

    // [[checkpoint]]...[[/checkpoint]]
    out = out.replace(/\[\[checkpoint\]\]([\s\S]*?)\[\[\/checkpoint\]\]/g, (_, body) =>
      `<details class="bp-checkpoint"><summary>Checkpoint</summary><div>${body.trim()}</div></details>`);

    // [[split]]...[[/split]] simple two-column stack on mobile
    out = out.replace(/\[\[split\]\]([\s\S]*?)\[\[\/split\]\]/g, (_, body) =>
      `<div class="bp-split" style="display:grid; gap:12px; grid-template-columns: 1fr; }
      @media(min-width:1000px){ .bp-split{ grid-template-columns: 1fr 1fr; } }">${body.trim()}</div>`);

    return out;
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  }

  // DOM builders
  function el(tag, attrs={}, children=[]) {
    const e = document.createElement(tag);
    Object.entries(attrs).forEach(([k,v]) => {
      if (k === 'class') e.className = v;
      else if (k === 'html') e.innerHTML = v;
      else if (k.startsWith('on') && typeof v === 'function') e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v);
    });
    (Array.isArray(children) ? children : [children]).forEach(c => {
      if (c==null) return;
      if (typeof c === 'string') e.appendChild(document.createTextNode(c));
      else e.appendChild(c);
    });
    return e;
  }

  // Main render
  async function render() {
    const route = parseRoute();
    // Only attach on learn routes
    if (!route || !route.trackId) { teardown(); return; }

    ensureStyles();

    let track;
    try {
      track = await getTrack(route.trackId);
    } catch (e) {
      teardown();
      return;
    }

    // Build container
    let host = qs('#bp-lms');
    if (!host) {
      host = el('div', { id: 'bp-lms', class: 'bp-lms' });
      // Attach close to main content root without touching title/brand nodes
      // Heuristic: inject after main app root if present, else at end of body
      const appRoot = qs('#app, main, .app, .container, body');
      (appRoot || document.body).appendChild(host);
    }
    host.innerHTML = '';

    // Build structure
    const wrap = el('div', { class: 'bp-wrap' });
    const left = el('aside', { class: 'bp-left' });
    const main = el('section', { class: 'bp-main' });
    const right = el('aside', { class: 'bp-right' }); // optional/hidden for now

    // Breadcrumbs
    const crumbs = buildBreadcrumbs(route, track);
    main.appendChild(crumbs);

    // Header block
    const header = buildHeader(route, track);
    main.appendChild(header.bar);
    main.appendChild(header.block);

    // Body
    const body = buildBody(route, track);
    main.appendChild(body);

    // Prev/Next + Mark done actions
    const actions = buildActions(route, track);
    main.appendChild(actions);

    // Sidebar
    const sidebar = buildSidebar(route, track);
    left.appendChild(sidebar);

    // Compose
    wrap.appendChild(left);
    wrap.appendChild(main);
    wrap.appendChild(right);
    host.appendChild(wrap);

    // Resume chip support
    resume.set(route.trackId, location.hash);

    // Accessibility: focus title
    const focusTitle = qs('.bp-title', host);
    if (focusTitle) focusTitle.setAttribute('tabindex', '-1'), focusTitle.focus();
  }

  function buildBreadcrumbs(route, track) {
    const bc = el('nav', { class: 'bp-breadcrumbs', 'aria-label': 'Breadcrumb' });
    const parts = [];
    parts.push(['Learning', '#/learn']);
    parts.push(['Coding',  '#/learn/coding']);
    if (track?.title) parts.push([track.title, `#/learn/${track.trackId}`]);
    if (route.moduleId) parts.push([route.moduleId, `#/learn/${route.trackId}/${route.moduleId}`]);
    if (route.lessonId) parts.push([route.lessonId, location.hash]);

    parts.forEach(([label, href], i) => {
      const a = el('a', { href, class: 'bp-crumb' }, label);
      bc.appendChild(a);
    });
    return bc;
  }

  function buildHeader(route, track) {
    const { moduleId, lessonId } = route;
    const { lesson, modIdx, lesIdx } = findLesson(track, moduleId, lessonId);

    // Progress across the track
    const { doneCount, totalCount } = computeTrackProgress(track);
    const pct = totalCount ? Math.round((doneCount/totalCount)*100) : 0;

    const bar = el('div', { class: 'bp-progressbar', role: 'progressbar', 'aria-valuenow': String(pct), 'aria-valuemin': '0', 'aria-valuemax': '100' },
      el('div', { style: `width:${pct}%` })
    );

    const header = el('div', { class: 'bp-header' }, [
      el('div', { class: 'bp-title' }, lesson?.title || lessonId || 'Lesson'),
      el('div', { class: 'bp-badges' }, [
        lesson?.difficulty ? el('span', { class: 'bp-badge' }, String(lesson.difficulty)) : null,
        Number.isFinite(lesson?.est) ? el('span', { class: 'bp-badge' }, `${lesson.est} min`) : null,
      ]),
    ]);

    // Prereqs
    const prereqs = Array.isArray(lesson?.prereqs) ? lesson.prereqs : [];
    const prereqWrap = prereqs.length ? el('div', { class: 'bp-prereqs' }, [
      'Prereqs: ',
      ...prereqs.map((p, idx) => {
        let href;
        if (p.includes(':')) {
          const [pm, pl] = p.split(':');
          href = `#/learn/${track.trackId}/${pm}/${pl}`;
        } else {
          href = `#/learn/${track.trackId}/${moduleId}/${p}`;
        }
        return [
          el('a', { href }, p),
          idx < prereqs.length-1 ? ', ' : ''
        ];
      }).flat()
    ]) : null;

    const block = el('div', {}, [header, prereqWrap].filter(Boolean));
    return { bar, block, modIdx, lesIdx };
  }

  function buildBody(route, track) {
    const { lesson } = findLesson(track, route.moduleId, route.lessonId);
    const wrap = el('div', { class: 'bp-body' });

    // Sections (Outcomes → Concept-in-5 → Walkthrough → Try it → Checkpoint → Cheatsheet → Next)
    if (Array.isArray(lesson?.outcomes) && lesson.outcomes.length) {
      const ul = el('ul', {}, lesson.outcomes.map(o => el('li', {}, o)));
      wrap.appendChild(el('section', {}, [el('h3', {}, 'Outcomes'), ul]));
    }

    if (lesson?.tags?.length) {
      const tags = el('div', { class: 'bp-taglist' }, lesson.tags.map(t => el('span', { class:'bp-tag' }, t)));
      wrap.appendChild(tags);
    }

    // Body supports shortcodes
    if (lesson?.body) {
      const bodyHtml = renderBody(lesson.body);
      const body = el('section', { html: bodyHtml });
      wrap.appendChild(body);
    }

    return wrap;
  }

  function buildActions(route, track) {
    const { moduleId, lessonId } = route;
    const { modIdx, lesIdx } = findLesson(track, moduleId, lessonId);
    const actions = el('div', { class: 'bp-actions' });

    // Prev
    const prevInfo = getPrev(track, modIdx, lesIdx);
    const btnPrev = el('button', { class: 'bp-btn', disabled: prevInfo ? null : true, onClick: () => { if(prevInfo) location.hash = prevInfo.hash; } }, '← Prev');

    // Mark done
    const key = lessonKey(track.trackId, moduleId, lessonId);
    const isDone = progress.isDone(key);
    const btnToggle = el('button', { class: 'bp-btn', onClick: () => {
      const now = !progress.isDone(key);
      progress.mark(key, now);
      render(); // refresh UI
    } }, isDone ? '✓ Marked Done' : 'Mark Done');

    // Next (respect gating)
    const nextInfo = getNext(track, modIdx, lesIdx);
    const pmap = progress.get();
    const nextUnlocked = nextInfo ? isUnlocked(track, nextInfo.m, nextInfo.l, null, pmap) : false;
    const btnNext = el('button', { class: 'bp-btn', disabled: nextInfo && nextUnlocked ? null : true, onClick: () => {
      if (nextInfo && nextUnlocked) location.hash = nextInfo.hash;
    } }, 'Next →');

    actions.append(btnPrev, btnToggle, btnNext);
    return actions;
  }

  function findLesson(track, moduleId, lessonId) {
    const modIdx = track.modules.findIndex(m => m.id === moduleId) ?? -1;
    const mod = track.modules[modIdx] || { lessons: [] };
    const lesIdx = (mod.lessons || []).findIndex(l => l.id === lessonId) ?? -1;
    const lesson = mod.lessons?.[lesIdx] || null;
    return { modIdx, lesIdx, lesson, module: mod };
  }

  function computeTrackProgress(track) {
    const p = progress.get();
    let done = 0, total = 0;
    track.modules.forEach(m => (m.lessons||[]).forEach(l => {
      total += 1;
      const key = lessonKey(track.trackId, m.id, l.id);
      if (p[key] === 'done') done += 1;
    }));
    return { doneCount: done, totalCount: total };
  }

  function getPrev(track, m, l) {
    if (m === 0 && l === 0) return null;
    if (l > 0) return { m, l: l-1, hash: `#/learn/${track.trackId}/${track.modules[m].id}/${track.modules[m].lessons[l-1].id}` };
    if (m > 0) {
      const pm = track.modules[m-1];
      return { m: m-1, l: pm.lessons.length-1, hash: `#/learn/${track.trackId}/${pm.id}/${pm.lessons[pm.lessons.length-1].id}` };
    }
    return null;
  }

  function getNext(track, m, l) {
    const mod = track.modules[m];
    if (!mod) return null;
    if (l < mod.lessons.length-1) return { m, l: l+1, hash: `#/learn/${track.trackId}/${mod.id}/${mod.lessons[l+1].id}` };
    if (m < track.modules.length-1) {
      const nm = track.modules[m+1];
      return { m: m+1, l: 0, hash: `#/learn/${track.trackId}/${nm.id}/${nm.lessons[0].id}` };
    }
    return null;
  }

  function buildSidebar(route, track) {
    const pmap = progress.get();
    const wrap = el('div', {});
    const title = el('div', { class: 'bp-sidebar-title' }, [
      el('span', {}, track.title || route.trackId || 'Track'),
      el('a', { class:'bp-side-toggle', href:'#', onClick: (e)=> {
        e.preventDefault();
        const left = wrap.closest('.bp-left');
        if (!left) return;
        const collapsed = left.style.display === 'none';
        left.style.display = collapsed ? '' : 'none';
      }}, 'Collapse')
    ]);
    wrap.appendChild(title);

    track.modules.forEach((m, mi) => {
      const mod = el('div', { class:'bp-module' });
      mod.appendChild(el('h4', {}, m.title || m.id));
      const list = el('div', { class:'bp-lessons' });

      m.lessons.forEach((l, li) => {
        const key = lessonKey(track.trackId, m.id, l.id);
        const unlocked = isUnlocked(track, mi, li, null, pmap);
        const current = route.moduleId === m.id && route.lessonId === l.id;

        const row = el('div', { class: 'bp-lesson' + (current ? ' bp-current' : '') });
        const icon = unlocked
          ? el('span', { class: 'bp-tick', title: progress.isDone(key) ? 'Done' : 'Not done' }, progress.isDone(key) ? '✓' : '•')
          : el('span', { class: 'bp-lock', title: 'Complete the previous lesson to unlock' }, '🔒');

        const link = el('a', { href: `#/learn/${track.trackId}/${m.id}/${l.id}` }, l.title || l.id);
        if (!unlocked) {
          link.addEventListener('click', (e)=> e.preventDefault());
        }
        row.append(icon, link);
        list.appendChild(row);
      });

      mod.appendChild(list);
      wrap.appendChild(mod);
    });

    return wrap;
  }

  function teardown() {
    const host = qs('#bp-lms');
    if (host) host.remove();
  }

  // Hash routing hooks
  let renderScheduled = false;
  function scheduleRender() {
    if (renderScheduled) return;
    renderScheduled = true;
    requestAnimationFrame(async () => {
      renderScheduled = false;
      try { await render(); } catch (e) { /* fail quiet */ }
    });
  }

  on(window, 'hashchange', scheduleRender);
  on(document, 'DOMContentLoaded', scheduleRender);
  scheduleRender();
})();
