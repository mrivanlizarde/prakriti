// Prakriti roadmap page: reading progress, section navigation, the "What's needed from" filter,
// one person's own list, and phases that open. Written 2026-10-08; rounds 2 and 3 the same day.
//
// Rules this file keeps, each for a reason:
// - Same-origin file, no inline code: the Worker's Content-Security-Policy allows only scripts
//   from this origin, so a script injected into the page cannot run.
// - Styles change only through classes and CSSOM properties (element.style.transform), never a
//   style attribute string, which the same policy blocks. New elements are built with
//   createElement and textContent, never from HTML strings.
// - The page works without this file. Phases are native <details>; the filter, the person's
//   list and the Open All button stay hidden until this script shows them, so no control
//   appears that does nothing.
// - Nothing waits on an animation frame. A hidden preview pane stops requestAnimationFrame, and a
//   probe that waits on it never returns, so every state is computed directly.
// - The filter's choice lives in the address (?for=serenity), so Ivan can send each person a link
//   that opens on their own asks. Writing the address can throw on file:// pages, so it is
//   wrapped and the page carries on without it.
// - Choosing a name hides everyone else's rows behind one "Show everyone's (N)" button per phase
//   and per decision group, rather than only dimming them: dimmed rows made ?for=gabriel 42
//   screens long on a phone (round 2, G7 and H9).
// - Rows for "the account holder" (data-who="holder") are nobody's count until Serenity confirms
//   on Mon 12 Oct that she holds the school's Google account. Only Serenity sees them, under that
//   label: Gabriel was taken off that question in round 3 (G12).
// - A person's count is only the things that person must do. Rows marked data-default (Gabriel's
//   "Unless you say otherwise", Serenity's "Each has a safe setting") and rows decided by both
//   teachers together (#for-both) never count and never sit in the dated list; each has its own
//   collapsed group, with its suggestion or safe setting beside it. Round 2's filter counted every
//   row, which printed "10 asks" for Gabriel and 39 for Serenity, and undid the safe settings
//   (round 3, G8, S12, B9, H13). Ivan's own rows are never treated as defaults.
// - The word on the page is "things", not "asks" (round 3, B9: "asks" is office jargon).
// - Weekdays are computed from the ISO date, never typed into this file.
(function () {
  'use strict';

  var doc = document;
  var root = doc.documentElement;
  var NAMES = { gabriel: 'Gabriel', serenity: 'Serenity', ivan: 'Ivan' };
  var SEES_HOLDER = { serenity: true };
  // The collapsed group of rows that need no reply, named as each person's decisions name it, and
  // which line each row shows beside it: Gabriel's suggestion, Serenity's safe setting.
  var DEFAULT_GROUP = {
    gabriel: { title: 'Unless you say otherwise', prefer: '.dec-a' },
    serenity: { title: 'Each has a safe setting until you answer', prefer: '.dec-if' }
  };
  var DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  var MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function toArray(list) { return Array.prototype.slice.call(list); }
  function owns(el, who) {
    return (' ' + (el.getAttribute('data-who') || '') + ' ').indexOf(' ' + who + ' ') > -1;
  }
  function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }
  function el(tag, cls, text) {
    var e = doc.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function squash(s) { return (s || '').replace(/\s+/g, ' ').trim(); }
  // "2026-10-09" -> "Fri 9 Oct". The weekday comes from the calendar, not from memory.
  function label(iso) {
    var p = iso.split('-');
    var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2]));
    return DAYS[d.getUTCDay()] + ' ' + d.getUTCDate() + ' ' + MONTHS[d.getUTCMonth()];
  }
  function isoOf(d) {
    function two(n) { return (n < 10 ? '0' : '') + n; }
    return d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate());
  }
  var now = new Date();
  var today = isoOf(now);
  // The end of this week is the coming Sunday (today, if today is Sunday).
  var weekEnd = isoOf(new Date(now.getFullYear(), now.getMonth(), now.getDate() + ((7 - now.getDay()) % 7)));

  // ── Reading progress and the current section ────────────────────────────────────────────
  var bar = doc.querySelector('.progress span');
  var tocLinks = toArray(doc.querySelectorAll('.toc > ol > li > a[href^="#"]'));
  var sections = tocLinks.map(function (a) { return doc.getElementById(a.getAttribute('href').slice(1)); });

  function onScroll() {
    var max = root.scrollHeight - window.innerHeight;
    var y = window.scrollY || window.pageYOffset || 0;
    var p = max > 0 ? Math.min(1, Math.max(0, y / max)) : 0;
    if (bar) bar.style.transform = 'scaleX(' + p.toFixed(4) + ')';

    // The current section is the last one whose top has passed a line a third of the way down.
    // At the very bottom, the last section is current even if it is too short to reach the line.
    var line = window.innerHeight * 0.34;
    var current = -1;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i] && sections[i].getBoundingClientRect().top <= line) current = i;
    }
    if (max > 0 && y >= max - 2) current = sections.length - 1;
    tocLinks.forEach(function (a, i) {
      if (i === current) a.setAttribute('aria-current', 'location');
      else a.removeAttribute('aria-current');
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);

  // ── Phases ──────────────────────────────────────────────────────────────────────────────
  var phases = toArray(doc.querySelectorAll('details.phase'));
  var toggleAll = doc.getElementById('phases-toggle');

  function syncToggle() {
    if (!toggleAll) return;
    var allOpen = phases.every(function (p) { return p.open; });
    toggleAll.textContent = allOpen ? 'Close All Phases' : 'Open All Phases';
  }
  if (toggleAll) {
    toggleAll.hidden = false;
    toggleAll.addEventListener('click', function () {
      var open = !phases.every(function (p) { return p.open; });
      phases.forEach(function (p) { p.open = open; });
      syncToggle();
      onScroll();
    });
  }
  phases.forEach(function (p) { p.addEventListener('toggle', function () { syncToggle(); onScroll(); }); });

  // A link to a phase or to one row (the strip at the top, the table of contents, a person's
  // own list) opens every <details> around its target, so the browser can scroll to it.
  function openFromHash(hash) {
    if (!hash || hash.length < 2) return null;
    var target = null;
    try { target = doc.getElementById(decodeURIComponent(hash.slice(1))); } catch (e) { return null; }
    if (!target) return null;
    if (target.tagName === 'DETAILS') target.open = true;
    for (var n = target.parentElement; n; n = n.parentElement) {
      if (n.tagName === 'DETAILS') n.open = true;
    }
    // A link to someone else's row while a name is chosen unfolds that row's group, so the
    // link never lands on nothing.
    if (target.classList.contains('is-other')) {
      var g = target.closest('.ph-part, .dec-group');
      if (g && g._toggle) {
        g.classList.add('show-others');
        g._toggle.setAttribute('aria-expanded', 'true');
      }
    }
    return target;
  }
  // When the address changes or the page opens on a row, the browser has already tried to
  // scroll to it, possibly while it was folded away; scroll again now that it is open.
  function goToHash() {
    var t = openFromHash(location.hash);
    if (t && t.scrollIntoView) t.scrollIntoView();
  }
  doc.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a[href^="#"]') : null;
    if (a) openFromHash(a.getAttribute('href'));
  });
  window.addEventListener('hashchange', goToHash);

  // Printing or saving as PDF shows every phase.
  window.addEventListener('beforeprint', function () { phases.forEach(function (p) { p.open = true; }); });

  // ── "What's needed from" ────────────────────────────────────────────────────────────────
  var scope = doc.getElementById('who-scope');
  var whoBar = doc.getElementById('who');
  var summary = doc.getElementById('who-sum');
  var mineBox = doc.getElementById('mine');
  var radios = whoBar ? toArray(whoBar.querySelectorAll('input[name="who"]')) : [];
  var items = scope ? toArray(scope.querySelectorAll('[data-who]')) : [];
  // The phase marked Now carries the date its asks are due by (data-end, ISO, so plain string
  // comparison orders it) and the same date as people read it (data-end-label).
  var nowPhase = doc.querySelector('details.phase.is-now');
  var cutoff = nowPhase ? nowPhase.getAttribute('data-end') : null;
  var cutoffLabel = nowPhase ? (nowPhase.getAttribute('data-end-label') || label(cutoff)) : null;

  // Every row gets an id, so a person's list can link to it. The first row of an ask is the
  // one the list points at.
  var seenKey = {};
  items.forEach(function (row, i) {
    if (row.id) return;
    var key = row.getAttribute('data-ask') || ('row-' + i);
    seenKey[key] = (seenKey[key] || 0) + 1;
    row.id = 'ask-' + key + (seenKey[key] > 1 ? '-' + seenKey[key] : '');
  });

  function isInfo(row) { return row.hasAttribute('data-info'); }
  function isHolder(row) { return owns(row, 'holder'); }
  function isDefault(row, who) { return who !== 'ivan' && row.hasAttribute('data-default'); }
  function isJoint(row) { return !!row.closest('#for-both'); }
  function where(row) {
    var ph = row.closest('details.phase');
    if (ph) {
      var n = ph.querySelector('.ph-n');
      var nm = ph.querySelector('.ph-name');
      return 'Phase ' + (n ? squash(n.textContent) : '') + (nm ? ' · ' + squash(nm.textContent).replace(/^Phase \d+: /, '') : '');
    }
    var g = row.closest('.dec-group');
    var t = g ? g.querySelector('.dec-group-title') : null;
    return t ? 'Decisions ' + squash(t.textContent).replace(/^For /, 'for ').replace(/^Ivan’s to decide$/, 'for Ivan') : '';
  }
  // A line break inside a "when" ("Mon 26 Oct to<br>Thu 5 Nov") reads as a space, not as nothing.
  function textOf(node) {
    var out = '';
    toArray(node.childNodes).forEach(function (c) {
      out += c.nodeName === 'BR' ? ' ' : c.nodeType === 3 ? c.nodeValue : textOf(c);
    });
    return out;
  }
  function whenText(row) {
    var w = row.querySelector('.when, .dec-when');
    return w ? squash(textOf(w)) : '';
  }
  function shortOf(row) {
    var s = row.getAttribute('data-short');
    if (s) return s;
    var q = row.querySelector('.act, .dec-q');
    return q ? squash(q.textContent).split(/[.?]\s/)[0] : '';
  }

  function byKeyPrev(order, key) {
    for (var i = 0; i < order.length; i++) if (order[i].key === key) return order[i];
    return null;
  }

  // One entry per ask: the first row of each data-ask key, with the earliest due date any of
  // its rows carries.
  function asksFor(rows) {
    var byKey = {};
    var order = [];
    rows.forEach(function (row, i) {
      var key = row.getAttribute('data-ask') || ('row-' + i + '-' + row.id);
      var due = row.getAttribute('data-due');
      if (!byKey[key]) {
        byKey[key] = { key: key, row: row, rows: [row], due: due || null, when: whenText(row), short: shortOf(row), where: where(row) };
        order.push(byKey[key]);
      } else if (due && (!byKey[key].due || due < byKey[key].due)) {
        // A later row with an earlier date (the Sunday session: an undated Phase 3 row, then a
        // decision due Sun 18 Oct) becomes the one the list points at.
        var all = byKey[key].rows.concat([row]);
        byKey[key] = { key: key, row: row, rows: all, due: due, when: whenText(row), short: shortOf(row), where: where(row) };
        order[order.indexOf(byKeyPrev(order, key))] = byKey[key];
      } else {
        byKey[key].rows.push(row);
      }
    });
    return order;
  }

  // What kind of thing an ask is, for one person: "default" when every one of its rows is a
  // suggestion or safe setting, "joint" when it is decided with the other teacher, else "own".
  // One action row is enough to make it the person's own: the intro is a suggestion in the
  // decisions but a recording Gabriel makes at the visit.
  function kindOf(ask, who) {
    if (ask.rows.every(function (r) { return isDefault(r, who); })) return 'default';
    if (ask.rows.some(isJoint)) return 'joint';
    return 'own';
  }
  // The line shown beside a row in a collapsed group: the person's preferred line (Gabriel's
  // suggestion, Serenity's safe setting), else the other, else the row's own text.
  function besideOf(ask, who) {
    var pref = DEFAULT_GROUP[who] ? DEFAULT_GROUP[who].prefer : '.dec-if';
    var other = pref === '.dec-a' ? '.dec-if' : '.dec-a';
    var picks = [pref, other];
    for (var p = 0; p < picks.length; p++) {
      for (var i = 0; i < ask.rows.length; i++) {
        var n = ask.rows[i].querySelector(picks[p]);
        if (n) return squash(n.textContent);
      }
    }
    return '';
  }

  // The containers that collapse other people's rows: each phase's list of asks, and each
  // decision group. Each gets one toggle button, made once.
  var groups = [];
  if (scope) {
    toArray(scope.querySelectorAll('.ph-part')).forEach(function (part) {
      if (part.querySelector('.needs')) groups.push(part);
    });
    toArray(scope.querySelectorAll('.dec-group')).forEach(function (g) { groups.push(g); });
  }
  groups.forEach(function (g, i) {
    var list = g.querySelector('.needs, .decs');
    if (list && !list.id) list.id = 'list-' + i;
    var btn = el('button', 'btn btn-quiet others-toggle');
    btn.type = 'button';
    btn.hidden = true;
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-controls', toArray(g.querySelectorAll('.needs, .decs')).map(function (l, j) {
      if (!l.id) l.id = 'list-' + i + '-' + j;
      return l.id;
    }).join(' '));
    var txt = el('span', 'others-label');
    var mark = el('span', 'faq-toggle');
    mark.setAttribute('aria-hidden', 'true');
    btn.appendChild(txt);
    btn.appendChild(mark);
    btn.addEventListener('click', function () {
      var open = !g.classList.contains('show-others');
      g.classList.toggle('show-others', open);
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      // The label says what the button will do next (round 3, H10).
      txt.textContent = (open ? 'Hide' : 'Show') + ' everyone’s (' + (g._others || 0) + ')';
      syncSubs(g);
      onScroll();
    });
    g.appendChild(btn);
    if (g.classList.contains('dec-group')) {
      var empty = el('p', 'dec-empty');
      empty.hidden = true;
      g.insertBefore(empty, g.querySelector('.dec-group-title').nextSibling);
    }
    g._toggle = btn;
    g._label = txt;
  });

  // A sub-heading inside a decision group ("Needs your answer", "For information") hides when a
  // name is chosen and none of the rows under it are shown, so no heading sits over nothing.
  function syncSubs(g) {
    toArray(g.querySelectorAll('.dec-sub')).forEach(function (h) {
      var list = h.nextElementSibling;
      while (list && !list.classList.contains('decs')) list = list.nextElementSibling;
      if (!list) return;
      var rows = toArray(list.querySelectorAll('[data-who]'));
      var shown = rows.filter(function (r) { return !r.classList.contains('is-other'); }).length;
      h.hidden = shown === 0 && !g.classList.contains('show-others') && rows.length > 0 &&
        scope.getAttribute('data-for') !== 'everyone';
    });
  }

  // The date shown in a person's list, so it never states a day that has not been set:
  //   "Thu 22 Oct target" shows Thu 22 Oct; "Mon 26 Oct to Thu 5 Nov" shows From Mon 26 Oct;
  //   "From Mon 26 Oct" and "By Mon 26 Oct" show as written;
  //   a row timed by an event or a span ("Same visit", "Week of Mon 12 Oct", "Wed 21 to Thu 22
  //   Oct") shows "By" and the latest date it can be.
  function whenLabel(a) {
    if (!a.due) return a.when;
    var d = label(a.due);
    var at = a.when.indexOf(d);
    if (at === 0) return a.when.slice(d.length).indexOf(' to ') === 0 ? 'From ' + d : d;
    if (at > 0 && /^(From|By) /.test(a.when)) return a.when.slice(0, at + d.length);
    return 'By ' + d;
  }
  function entry(a, beside) {
    var li = el('li');
    li.appendChild(el('span', 'meta mine-when', whenLabel(a)));
    var cell = el('div', 'mine-ask-cell');
    var link = el('a', 'mine-ask', a.short);
    link.href = '#' + a.row.id;
    cell.appendChild(link);
    if (beside) cell.appendChild(el('p', 'mine-safe', beside));
    li.appendChild(cell);
    li.appendChild(el('span', 'meta mine-where', a.where));
    return li;
  }
  function byDue(a, b) { return (a.due || '9') < (b.due || '9') ? -1 : (a.due || '9') > (b.due || '9') ? 1 : 0; }

  function renderMine(who, own, joint, defaults, holderRows) {
    if (!mineBox) return;
    while (mineBox.firstChild) mineBox.removeChild(mineBox.firstChild);
    var name = NAMES[who];
    if (!name) { mineBox.hidden = true; return; }

    var dated = own.filter(function (a) { return a.due; }).sort(byDue);
    var undated = own.filter(function (a) { return !a.due; });

    mineBox.appendChild(el('h2', 'mine-title', 'What is needed from ' + name)).id = 'mine-title';
    mineBox.appendChild(el('p', 'mine-lead', 'In date order, the next one first. Each links to its row below.'));

    function list(title, entries, note) {
      if (!entries.length) return;
      mineBox.appendChild(el('h3', 'mine-group', title));
      if (note) mineBox.appendChild(el('p', 'mine-note', note));
      var ol = el('ol', 'mine-list');
      ol.setAttribute('role', 'list');
      entries.forEach(function (a) { ol.appendChild(entry(a)); });
      mineBox.appendChild(ol);
    }
    // A collapsed group: native <details>, so it opens without this script's help.
    function folded(title, entries, withBeside) {
      if (!entries.length) return;
      var d = el('details', 'dec-more mine-more');
      var sum = el('summary');
      var t = el('span', 'dec-more-q', title + ' ');
      t.appendChild(el('span', 'dec-more-n', '(' + entries.length + ')'));
      sum.appendChild(t);
      var mark = el('span', 'faq-toggle');
      mark.setAttribute('aria-hidden', 'true');
      sum.appendChild(mark);
      d.appendChild(sum);
      var ol = el('ol', 'mine-list');
      ol.setAttribute('role', 'list');
      entries.forEach(function (a) { ol.appendChild(entry(a, withBeside ? besideOf(a, who) : '')); });
      d.appendChild(ol);
      mineBox.appendChild(d);
    }
    list('This week', dated.filter(function (a) { return a.due <= weekEnd; }));
    list('Later', dated.filter(function (a) { return a.due > weekEnd; }));
    list('No date yet', undated);
    if (holderRows.length) {
      list('If you hold the school’s Google account', asksFor(holderRows),
        'Counted for no one until you confirm on Mon 12 Oct that you hold it. Ivan sits beside you.');
    }
    folded('For you both', joint.slice().sort(byDue), false);
    if (DEFAULT_GROUP[who]) folded(DEFAULT_GROUP[who].title, defaults.slice().sort(byDue), true);
    mineBox.hidden = false;
  }

  function apply(who) {
    var name = NAMES[who];
    if (scope) scope.setAttribute('data-for', name ? who : 'everyone');

    var mine = [];
    var holderRows = [];
    items.forEach(function (row) {
      var holderShown = !!name && isHolder(row) && !!SEES_HOLDER[who];
      var isMine = !!name && owns(row, who) && !isInfo(row);
      var isOther = !!name && !owns(row, who) && !holderShown;
      row.classList.toggle('is-mine', isMine);
      row.classList.toggle('is-holder', holderShown);
      row.classList.toggle('is-other', isOther);
      if (isMine) mine.push(row);
      if (holderShown) holderRows.push(row);
    });

    groups.forEach(function (g) {
      g.classList.remove('show-others');
      var rows = toArray(g.querySelectorAll('[data-who]'));
      var others = rows.filter(function (r) { return r.classList.contains('is-other'); }).length;
      var shown = rows.length - others;
      g._others = others;
      g.classList.toggle('all-others', !!name && shown === 0);
      if (g._toggle) {
        g._toggle.hidden = !name || others === 0;
        g._toggle.setAttribute('aria-expanded', 'false');
        g._label.textContent = 'Show everyone’s (' + others + ')';
      }
      syncSubs(g);
      var empty = g.querySelector('.dec-empty');
      if (empty) {
        empty.hidden = !name || shown > 0;
        empty.textContent = name ? 'Nothing here is for ' + name + '.' : '';
      }
    });

    phases.forEach(function (p) {
      var chip = p.querySelector('.ph-count');
      var empty = p.querySelector('.ph-empty');
      // The chip counts the things this person must do in the phase; a suggestion that stands
      // without a reply is shown, but not counted.
      var n = name ? toArray(p.querySelectorAll('.need.is-mine')).filter(function (r) { return !isDefault(r, who); })
        .reduce(function (keys, r) { var k = r.getAttribute('data-ask') || r.id; if (keys.indexOf(k) < 0) keys.push(k); return keys; }, []).length : 0;
      var visible = name ? p.querySelectorAll('.need.is-mine, .need.is-holder').length : 0;
      if (chip) {
        chip.hidden = !name;
        chip.classList.toggle('has-asks', n > 0);
        chip.textContent = name ? (n ? n + ' for ' + name : 'Nothing for ' + name) : '';
      }
      if (empty) {
        empty.hidden = !name || visible > 0;
        empty.textContent = name ? 'Nothing is needed from ' + name + ' in this phase.' : '';
      }
    });

    // One thing can appear twice, as a phase row and as a decision (the "podcast first" yes, for
    // example). Rows that share a data-ask key count once, so the number matches what the person
    // actually has to do.
    var asks = name ? asksFor(mine) : [];
    var own = asks.filter(function (a) { return kindOf(a, who) === 'own'; });
    var joint = asks.filter(function (a) { return kindOf(a, who) === 'joint'; });
    var defaults = asks.filter(function (a) { return kindOf(a, who) === 'default'; });

    if (summary) {
      if (name) {
        // "Needed by" counts the person's own things with a date on or before the end of the
        // phase marked Now. "Next" is the first of them due today or later.
        var soon = own.filter(function (a) { return cutoff && a.due && a.due <= cutoff; }).length;
        var next = own.filter(function (a) { return a.due && a.due >= today; }).sort(byDue)[0];
        var text = name + ': ' + plural(soon, 'thing', 'things') + ' needed by ' + cutoffLabel + '.';
        if (next) text += ' Next: ' + next.short + ', ' + label(next.due) + '.';
        summary.textContent = text;
      } else {
        summary.textContent = 'Choose a name to see what is needed from that person first.';
      }
    }
    renderMine(who, own, joint, defaults, holderRows);
    syncToggle();
    onScroll();
  }

  function remember(who) {
    try {
      var url = new URL(location.href);
      if (NAMES[who]) url.searchParams.set('for', who); else url.searchParams.delete('for');
      history.replaceState(null, '', url.pathname + url.search + url.hash);
    } catch (e) { /* file:// and some private modes refuse; the filter still works. */ }
  }

  if (whoBar && scope) {
    whoBar.hidden = false;
    radios.forEach(function (r) {
      r.addEventListener('change', function () {
        if (!r.checked) return;
        apply(r.value);
        remember(r.value);
      });
    });

    var start = 'everyone';
    try { start = (new URLSearchParams(location.search).get('for') || 'everyone').toLowerCase(); } catch (e) {}
    if (!NAMES[start]) start = 'everyone';
    radios.forEach(function (r) { r.checked = r.value === start; });
    apply(start);
  }

  if (location.hash) goToHash();
  syncToggle();
  onScroll();
})();
