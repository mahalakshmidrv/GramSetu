"use strict";
// GramSetu front-end: offline-first PWA. Online: UI -> API -> SQLite. Offline: UI -> IndexedDB queue -> Sync Manager -> API.
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : "r-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 12));
let lang = localStorage.getItem("lang") || "en"; if (!T[lang]) lang = "en";
const t = (k, v) => { let s = (T[lang] && T[lang][k]) ?? T.en[k] ?? k; if (v) for (const x in v) s = s.replaceAll("{" + x + "}", v[x]); return s; };
const L10 = o => (o && (o[lang] || o.en)) || "";
const fmt = ts => ts ? new Date(ts).toLocaleString(T[lang].sp, { day: "2-digit", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" }) : "—";
const ls = { get: (k, d) => { try { return JSON.parse(localStorage.getItem(k)) ?? d; } catch { return d; } }, set: (k, v) => localStorage.setItem(k, JSON.stringify(v)) };

// ---------- IndexedDB (v2): "requests" = legacy store (kept), "queue" = offline sync queue, "files" = queued document blobs ----------
const legacyToItem = o => ({ client_request_id: o.id, kind: "request", created_at: o.created_at, status: o.synced ? "synced" : "pending", retry_count: 0, last_attempt: null, error: "", synced_at: o.synced ? o.created_at : null,
  payload: { id: o.id, name: o.name || "", village: o.village || "", text: o.text, lang: o.lang || "en", category: o.category || "other", type: "general", created_at: o.created_at, details: {} } });
const dbp = new Promise((res, rej) => {
  const r = indexedDB.open("gramsetu", 2);
  r.onupgradeneeded = e => {
    const d = r.result;
    if (!d.objectStoreNames.contains("requests")) d.createObjectStore("requests", { keyPath: "id" });
    if (!d.objectStoreNames.contains("queue")) d.createObjectStore("queue", { keyPath: "client_request_id" }).createIndex("status", "status");
    if (!d.objectStoreNames.contains("files")) d.createObjectStore("files", { keyPath: "id" });
    if (e.oldVersion === 1) {      // migrate v1 data: nothing is deleted
      const q = r.transaction.objectStore("queue");
      r.transaction.objectStore("requests").getAll().onsuccess = ev => (ev.target.result || []).forEach(o => q.put(legacyToItem(o)));
    }
  };
  r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error);
});
const idb = async (store, mode, fn) => { const d = await dbp; return new Promise((res, rej) => { const tx = d.transaction(store, mode), r = fn(tx.objectStore(store)); tx.oncomplete = () => res(r && r.result); tx.onerror = tx.onabort = () => rej(tx.error); }); };
const qAll = () => idb("queue", "readonly", s => s.getAll()).then(a => (a || []).sort((x, y) => y.created_at - x.created_at));
const qPut = i => idb("queue", "readwrite", s => s.put(i));
const qDel = id => idb("queue", "readwrite", s => s.delete(id));
const fGet = id => idb("files", "readonly", s => s.get(id));
const fDel = id => idb("files", "readwrite", s => s.delete(id));
let Q = [];
const refreshQ = async () => { Q = await qAll(); updateStatus(); };

// ---------- network layer ----------
let forced = sessionStorage.getItem("gs_forced") === "1";     // demo switch: behave as if internet is off
let serverUp = null, flushing = false;
class NetErr extends Error {}
const auth = { get token() { return localStorage.getItem("gs_token"); }, get user() { return ls.get("gs_user", null); } };
const isStaff = () => ["OFFICER", "ADMIN"].includes(auth.user?.role);
const isOnline = () => !forced && navigator.onLine && serverUp !== false;
async function api(path, o = {}) {
  if (forced) throw new NetErr("forced");
  const h = { ...(o.headers || {}) }; if (o.body) h["Content-Type"] = "application/json";
  if (auth.token && !o.noAuth) h.Authorization = "Bearer " + auth.token;
  const ctl = new AbortController(), to = setTimeout(() => ctl.abort(), o.timeout || 15000); let res;
  try { res = await fetch(path, { method: o.method || "GET", headers: h, signal: ctl.signal, body: o.body ? JSON.stringify(o.body) : undefined }); }
  catch { serverUp = false; throw new NetErr("net"); } finally { clearTimeout(to); }
  serverUp = true;
  if (o.raw && res.ok) return res;
  let data = null; try { data = await res.json(); } catch {}
  if (!res.ok) { const e = new Error("http"); e.status = res.status; e.code = typeof data?.detail === "string" ? data.detail : "validation"; throw e; }
  return data;
}
const ERRMAP = { login_required: "msg_login_req", forbidden: "msg_forbidden", rate_limited: "msg_rate", validation: "msg_validation", file_too_large: "msg_too_big", file_type: "msg_bad_file", bad_credentials: "bad_login", username_taken: "user_taken", not_found: "msg_generic" };
const errKey = e => e instanceof NetErr ? "msg_need_net" : (e.status >= 500 || e.status === 429 && !e.code) ? "msg_server_down" : (ERRMAP[e.code] || "msg_generic");
async function checkOnline() {
  if (forced || !navigator.onLine) return false;
  try { await api("/api/health", { timeout: 4000 }); return true; } catch { return false; }
}

// ---------- sync status UI ----------
const vis = i => i.owner == null ? !auth.user : i.owner === auth.user?.id;       // shared device: a user only sees/sends their own queued items (owner null = anonymous report)
const cnt = s => Q.filter(i => vis(i) && s.includes(i.status)).length;
const syncMeta = () => ({ last: ls.get("gs_lastsync", null), err: ls.get("gs_lasterr", ""), log: ls.get("gs_synclog", []) });
function updateStatus() {
  const n = $("net"), p = cnt(["pending", "syncing"]), f = cnt(["failed"]), m = syncMeta();
  let cls, ic, tx;
  if (!isOnline()) { cls = "off"; ic = "🔴"; tx = p ? t("st_offline_pending", { n: p }) : t("st_offline"); }
  else if (flushing) { cls = "sync"; ic = "🔄"; tx = t("st_syncing"); }
  else if (p) { cls = "pend"; ic = "🟡"; tx = t("st_pending", { n: p }); }
  else if (f) { cls = "fail"; ic = "⚠️"; tx = t("st_failed", { n: f }); }
  else if (m.last) { cls = "on"; ic = "✓"; tx = t("st_synced"); }
  else { cls = "on"; ic = "🟢"; tx = t("st_online"); }
  n.className = "pill " + cls; n.innerHTML = `<span aria-hidden="true">${ic}</span> ${esc(tx)}`;
  $("demo-banner").classList.toggle("hidden", !forced);
  document.querySelectorAll(".sync-card").forEach(el => el.innerHTML = syncCardHTML());
}
function syncCardHTML() {
  const m = syncMeta();
  return `<h2>${t("sync_title")}</h2><dl class="kv"><dt>${t("last_sync")}</dt><dd>${m.last ? fmt(m.last) : t("never")}</dd>
  <dt>${t("pending_n")}</dt><dd>${cnt(["pending", "syncing"])}</dd><dt>${t("synced_n")}</dt><dd>${cnt(["synced"])}</dd><dt>${t("failed_n")}</dt><dd>${cnt(["failed"])}</dd>
  ${m.err ? `<dt>${t("last_error")}</dt><dd>${esc(t(m.err))}</dd>` : ""}</dl>
  <div class="row"><button class="btn" data-act="sync" ${flushing ? "disabled" : ""}>${flushing ? t("syncing_btn") : "🔄 " + t("sync_now")}</button></div>`;
}
let toastT;
function toast(msg, speak) { const el = $("toast"); el.textContent = msg; el.classList.add("show"); clearTimeout(toastT); toastT = setTimeout(() => el.classList.remove("show"), 7000); if (speak) say(msg); }

// ---------- offline queue + sync manager (idempotent: server ignores an already-stored client_request_id) ----------
const MAX_RETRY = 5;
const typing = () => /^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement?.tagName || "") && !!document.activeElement.closest("main");
async function enqueue(kind, payload, blob) {
  const it = { client_request_id: payload.id, kind, created_at: payload.created_at, status: "pending", retry_count: 0, last_attempt: null, error: "", synced_at: null, owner: auth.user?.id ?? null, payload };
  if (blob) await idb("files", "readwrite", s => s.put({ id: payload.id, blob }));
  await qPut(it); await refreshQ(); queueSync();
  await flush();
  return Q.find(i => i.client_request_id === payload.id) || it;
}
function outcomeMsg(it, okKey) {
  if (it.status === "synced") return t(okKey || "sent");
  return isOnline() ? t("msg_sync_later") : t("msg_offline_saved");
}
const blobB64 = b => new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(String(r.result).split(",")[1]); r.onerror = rej; r.readAsDataURL(b); });
async function markDone(it, serverStatus) { it.status = "synced"; it.synced_at = Date.now(); it.error = ""; it.server = serverStatus || it.server; await qPut(it); if (it.kind === "document") await fDel(it.client_request_id); }
async function markFail(it, e) {            // network/5xx: stay pending and retry; after MAX_RETRY (or a hard 4xx) become "failed" until the user taps Retry
  it.retry_count++; it.error = it.kind === "document" && e.code === "login_required" ? "msg_login_req" : e instanceof NetErr || e.status >= 500 || e.status === 429 ? "msg_sync_later" : errKey(e);
  const hard = e.status && e.status < 500 && e.status !== 429;
  it.status = hard || it.retry_count >= MAX_RETRY ? "failed" : "pending"; await qPut(it);
}
async function flush(manual) {
  if (flushing) return;
  await refreshQ();
  const me = auth.user?.id ?? null;
  // Logged out: only anonymous items. Logged in: only that user's items. Exception: anonymous SOS is never held back (sent without any token).
  const todo = Q.filter(i => i.status === "pending" && (me == null ? i.owner == null : i.owner === me || (i.owner == null && i.kind === "sos")));
  if (!(await checkOnline())) { updateStatus(); return; }
  if (!todo.length) { if (manual) { localStorage.setItem("gs_lastsync", Date.now()); toast(t("sync_nothing")); } updateStatus(); refreshStatuses(); return; }
  flushing = true; updateStatus();
  let ok = 0, bad = 0, lastErr = "";
  try {
    const reqs = todo.filter(i => i.kind !== "document").sort((a, b) => (b.kind === "sos") - (a.kind === "sos") || a.created_at - b.created_at);
    for (const [anon, list] of [[true, reqs.filter(i => i.owner == null)], [false, reqs.filter(i => i.owner != null)]])
    for (let i = 0; i < list.length; i += 25) {
      const chunk = list.slice(i, i + 25);
      for (const it of chunk) { it.status = "syncing"; it.last_attempt = Date.now(); await qPut(it); }
      try {
        const data = await api("/api/sync", { method: "POST", noAuth: anon, body: { requests: chunk.map(x => x.payload) } });
        const by = Object.fromEntries((data.results || []).map(r => [r.id, r]));
        for (const it of chunk) {
          const r = by[it.client_request_id];
          if (r && r.status !== "rejected") { await markDone(it, "Received"); ok++; }
          else { it.status = "failed"; it.error = "msg_validation"; it.retry_count++; await qPut(it); bad++; lastErr = "msg_validation"; }
        }
      } catch (e) { for (const it of chunk) { await markFail(it, e); bad++; } lastErr = (e instanceof NetErr ? "msg_sync_later" : errKey(e)); if (e instanceof NetErr) break; }
    }
    for (const it of todo.filter(i => i.kind === "document")) {
      const cur = (await qAll()).find(x => x.client_request_id === it.client_request_id); if (!cur || cur.status !== "pending") continue;
      cur.status = "syncing"; cur.last_attempt = Date.now(); await qPut(cur);
      try {
        const f = await fGet(cur.client_request_id); if (!f) throw Object.assign(new Error("x"), { status: 400, code: "validation" });
        const r = await api("/api/documents", { method: "POST", body: { ...cur.payload, data: await blobB64(f.blob) }, timeout: 60000 });
        await markDone(cur, "Received"); ok++;
      } catch (e) { await markFail(cur, e); bad++; lastErr = cur.error; if (e instanceof NetErr) break; }
    }
  } catch (e) { lastErr = "msg_generic"; }
  finally {
    flushing = false;
    const m = syncMeta(), log = [{ at: Date.now(), ok, failed: bad, error: lastErr }, ...m.log].slice(0, 20);
    ls.set("gs_synclog", log); ls.set("gs_lasterr", lastErr);
    if (ok > 0 || (!bad && !todo.length)) localStorage.setItem("gs_lastsync", Date.now());
    await refreshQ(); if (!typing()) renderCurrent(); refreshStatuses();     // never wipe a form the user is typing in
    if (ok) toast(t("st_synced"));
  }
}
async function queueSync() { try { const reg = await navigator.serviceWorker?.ready; if (reg?.sync) reg.sync.register("gramsetu-sync").catch(() => {}); } catch {} }
async function refreshStatuses() {       // office-side status (Received / In progress / Completed) for items already synced
  if (!isOnline()) return;
  const ids = Q.filter(i => vis(i) && i.status === "synced" && i.kind !== "document").slice(0, 50).map(i => i.client_request_id); if (!ids.length) return;
  try { const rows = await api("/api/requests?ids=" + ids.join(",")); const map = ls.get("gs_srv", {}); rows.forEach(r => map[r.id] = r.status); ls.set("gs_srv", map); if (cur === "queue") renderQueue(); } catch {}
}

// ---------- speech ----------
const SR = window.SpeechRecognition || window.webkitSpeechRecognition; let rec = null;
function setSpeaking(b) { document.body.classList.toggle("speaking", b); }
function say(text) {
  if (!("speechSynthesis" in window) || !text) return; speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(String(text).slice(0, 1200)); u.lang = T[lang].sp; u.onstart = () => setSpeaking(true); u.onend = u.onerror = () => setSpeaking(false); speechSynthesis.speak(u);
}
function stopSpeaking() { if ("speechSynthesis" in window) speechSynthesis.cancel(); setSpeaking(false); }
function stopListening() { try { rec && rec.stop(); } catch {} }
const voiceErr = c => ({ "not-allowed": "v_denied", "service-not-allowed": "v_denied", "no-speech": "v_nospeech", "audio-capture": "v_nodev", network: "v_network" }[c] || "v_err");
function listen({ btn, indicator, onText, onDone }) {
  if (!SR) return toast(t("nomic"));
  if (rec) return stopListening();
  stopSpeaking();                                   // a new voice query stops any speech
  rec = new SR(); rec.lang = T[lang].sp; rec.interimResults = true; let heard = "";
  const off = () => { rec = null; btn.classList.remove("rec"); btn.textContent = btn.dataset.label; indicator.classList.add("hidden"); };
  btn.dataset.label = btn.textContent; btn.classList.add("rec"); btn.textContent = t("v_stop"); indicator.classList.remove("hidden");
  rec.onresult = e => { heard = [...e.results].map(r => r[0].transcript).join(" "); onText(heard); };
  rec.onerror = e => toast(t(voiceErr(e.error)));
  rec.onend = () => { off(); onDone && onDone(heard); };
  try { rec.start(); } catch { off(); toast(t("v_err")); }
}

// ---------- rule-based intent classification (works offline) ----------
const KW = {
 water:["water","tap","well","पानी","नल","कुआं","தண்ணீர்","குடிநீர்","கிணறு"],
 health:["health","doctor","hospital","medicine","fever","स्वास्थ्य","डॉक्टर","अस्पताल","दवा","மருத்துவ","மருந்து","காய்ச்சல்"],
 farming:["farm","crop","seed","fertilizer","खेत","फसल","बीज","किसान","खेती","விவசாய","பயிர்","விதை"],
 road:["road","bridge","pothole","bus","सड़क","पुल","बस","சாலை","பாலம்"],
 electricity:["electric","power","light","current","बिजली","மின்"],
 pension:["pension","widow","old age","पेंशन","विधवा","ஓய்வூதியம்","முதியோர்"],
 job:["job","work","wage","रोजगार","काम","मजदूरी","வேலை","கூலி"]};
const INTENT_KW = {
 emergency:["emergency","ambulance","accident","sos","snake","poison","unconscious","chest pain","bleeding","can't breathe","cannot breathe","आपात","एम्बुलेंस","दुर्घटना","बचाओ","सांप","जहर","बेहोश","सीने में दर्द","खून बह","அவசர","ஆம்புலன்ஸ்","விபத்து","பாம்பு","விஷம்","மயக்கம்","நெஞ்சு வலி"],
 documents:["document","upload","aadhaar","aadhar","pdf","दस्तावेज","अपलोड","आधार","ஆவண","பதிவேற்ற","ஆதார்"],
 offline:["offline","internet","network","sync","no signal","ऑफलाइन","इंटरनेट","सिंक","ஆஃப்லைன்","இணையம்","ஒத்திசை"],
 government:["government","scheme","yojana","certificate","ration","सरकारी","योजना","प्रमाणपत्र","राशन","அரசு","திட்டம்","சான்றிதழ்","ரேஷன்"],
 nav:["help","how to use","menu","navigate","मदद","कैसे उपयोग","உதவி","எப்படி பயன்படுத்த"]};
const has = (txt, list) => list.some(w => txt.includes(w));
function classify(text) { const x = text.toLowerCase(); let best = "other", n = 0; for (const k in KW) { const s = KW[k].filter(w => x.includes(w)).length; if (s > n) { n = s; best = k; } } return best; }
function detectIntent(text) {
  const x = text.toLowerCase().trim(), cat = classify(x);
  if (has(x, INTENT_KW.emergency)) return { intent: "emergency", cat };
  if (has(x, INTENT_KW.documents)) return { intent: "documents", cat };
  if (has(x, INTENT_KW.offline)) return { intent: "offline", cat };
  if (cat === "health") return { intent: "healthcare", cat };
  if (cat === "farming") return { intent: "agriculture", cat };
  if (cat !== "other" || has(x, INTENT_KW.government)) return { intent: "government", cat };
  if (has(x, INTENT_KW.nav)) return { intent: "nav", cat };
  if (/^(hi|hello|hey|namaste)\b/.test(x) || has(x, ["नमस्ते", "வணக்கம்"])) return { intent: "hi", cat };
  return { intent: "unknown", cat };
}

// ---------- schemes (cached by the service worker + localStorage fallback) ----------
let SCHEMES = ls.get("schemes", []);
async function loadSchemes() {
  try { const l = await api("/api/schemes"); if (Array.isArray(l) && l.length) { SCHEMES = l; ls.set("schemes", l); } } catch {}
  return SCHEMES;
}
const schemeCards = cats => { const l = SCHEMES.filter(s => !cats || cats.includes(s.cat));
  return l.length ? l.map(s => `<div class="item"><h3>${esc(L10(s.name))}</h3><span class="tag">${t("cat_" + s.cat)}</span><p>${esc(L10(s.desc))}</p></div>`).join("") : `<p>${t("empty")}</p>`; };
const infoCards = list => list.map(i => `<details><summary>${i.icon} ${esc(L10(i.title))}</summary><p>${esc(L10(i.body))}</p></details>`).join("");
const helpCards = list => list.map(h => `<a class="call" href="tel:${h.num.replace(/\D/g, "")}">📞 ${esc(h.num)} <small>${esc(L10(h.name))}</small></a>`).join("");

// ---------- views ----------
let cur = "home"; const sub = { health: "main", farm: "main" };
let dashboardStats = { total: 0, by_category: {} };
const profile = () => { const u = auth.user; if (!u) return { name: "", village: "" }; const p = ls.get("gs_profile_" + u.id, {}); return { name: p.name || u.name || "", village: p.village || u.village || "" }; };
const saveProfile = (name, village) => { if (auth.user) ls.set("gs_profile_" + auth.user.id, { name, village }); };
const resetForms = () => { const p = profile(); $("name").value = p.name; $("village").value = p.village; $("text").value = ""; $("hint").textContent = ""; };
const tile = (ic, label, desc, act, arg, cls = "") => `<button class="tile ${cls}" data-act="${act}" data-arg="${arg}"><span class="ic" aria-hidden="true">${ic}</span><b>${label}</b>${desc ? `<span>${desc}</span>` : ""}</button>`;
const statCard = (label, value) => `<div class="stat-box"><strong>${esc(String(value))}</strong><span>${esc(label)}</span></div>`;
async function loadDashboardStats() {
  try { dashboardStats = await api("/api/stats"); }
  catch { dashboardStats = { total: 0, by_category: {} }; }
}
function renderHome() {
  const pendingSync = Q.filter(i => vis(i) && ["pending", "syncing"].includes(i.status)).length;
  const totalRequests = Number(dashboardStats.total || 0);
  const healthRequests = Number(dashboardStats.by_category?.health || 0);
  const farmingRequests = Number(dashboardStats.by_category?.farming || 0);
  const otherRequests = Math.max(0, totalRequests - healthRequests - farmingRequests);
  const offlineText = pendingSync ? t("pending_sync", { n: pendingSync }) : t("no_pending_sync");
  $("home").innerHTML = `
    <div class="hero-panel">
      <div class="hero-copy">
        <p class="eyebrow">GRAMSETU</p>
        <h2>${t("service_home_hero")}</h2>
        <p>${t("service_home_subtitle")}</p>
        <div class="hero-actions">
          <button class="btn" data-act="tab" data-arg="schemes">${t("service_explore")}</button>
          <button class="btn alt" data-act="tab" data-arg="sos">${t("service_emergency")}</button>
        </div>
      </div>
      <div class="hero-stats">
        <div class="stat"><b>${esc(String(totalRequests))}</b><span>${t("stats_total")}</span></div>
        <div class="stat"><b>${esc(String(healthRequests))}</b><span>${t("stats_health")}</span></div>
        <div class="stat"><b>${esc(String(farmingRequests))}</b><span>${t("stats_farming")}</span></div>
        <div class="stat"><b>${esc(String(otherRequests))}</b><span>${t("stats_other")}</span></div>
      </div>
    </div>
    <div class="service-grid">
      <div class="service-card"><div class="service-icon">🏛</div><h3>${t("service_gov")}</h3><p>${t("service_gov_desc")}</p><button class="btn ghost" data-act="tab" data-arg="schemes">${t("service_explore_btn")}</button></div>
      <div class="service-card"><div class="service-icon">🌾</div><h3>${t("service_farm")}</h3><p>${t("service_farm_desc")}</p><button class="btn ghost" data-act="tab" data-arg="farm">${t("service_explore_btn")}</button></div>
      <div class="service-card"><div class="service-icon">🏥</div><h3>${t("service_health")}</h3><p>${t("service_health_desc")}</p><button class="btn ghost" data-act="tab" data-arg="health">${t("service_support_btn")}</button></div>
      <div class="service-card"><div class="service-icon">📄</div><h3>${t("service_docs")}</h3><p>${t("service_docs_desc")}</p><button class="btn ghost" data-act="tab" data-arg="docs">${t("service_docs_btn")}</button></div>
      <div class="service-card danger-card"><div class="service-icon">🚨</div><h3>${t("service_sos")}</h3><p>${t("service_sos_desc")}</p><button class="btn danger" data-act="tab" data-arg="sos">${t("service_sos_btn")}</button></div>
      <div class="service-card"><div class="service-icon">🤖</div><h3>${t("service_offline")}</h3><p>${t("service_offline_desc")}</p><button class="btn ghost" data-act="chat">${t("service_assistant_btn")}</button></div>
    </div>
    <div class="card status-card">
      <div class="status-head">
        <div>
          <div class="status-marker">●</div>
          <span>${t("offline_ready")}</span>
        </div>
      </div>
      <p>${t("offline_ready_desc")}</p>
      <div class="offline-queue">${esc(offlineText)}</div>
    </div>
    <div class="stats-grid">
      ${statCard(t("stats_total"), totalRequests)}
      ${statCard(t("stats_health"), healthRequests)}
      ${statCard(t("stats_farming"), farmingRequests)}
      ${statCard(t("stats_other"), otherRequests)}
    </div>
    <div class="card sos-card">
      <h3>${t("urgent_help")}</h3>
      <p>${t("sos_benefit")}</p>
      <button class="sos-btn" data-act="tab" data-arg="sos">${t("service_sos_btn")}</button>
    </div>
    <div class="card sync-card"></div>
    <details><summary>🎬 ${t("demo_title")}</summary><p>${t("demo_steps")}</p>
    <div class="row"><button class="btn ${forced ? "" : "alt"}" data-act="demo">${forced ? t("demo_on") : t("demo_off")}</button></div></details>`;
  updateStatus();
}
function subnav(sec, items) {
  return `<div class="subnav" role="tablist">${items.map(([k, ic, lab]) => `<button role="tab" data-act="sub" data-arg="${sec}:${k}" aria-selected="${sub[sec] === k}">${ic} ${lab}</button>`).join("")}</div>`;
}
function reqForm(kind, services, extra, submitKey, descKey) {
  const p = profile();
  return `<form class="card" data-form="${kind}" novalidate>
   <label for="${kind}-svc">${t("form_service")}</label><select class="f" id="${kind}-svc">${services.map(k => `<option value="${k}">${t(k)}</option>`).join("")}</select>${extra}
   <label for="${kind}-name">${t("name")}</label><input id="${kind}-name" value="${esc(p.name)}" autocomplete="name">
   <label for="${kind}-village">${t("village")}</label><input id="${kind}-village" value="${esc(p.village)}">
   <label for="${kind}-text">${t(descKey)}</label><textarea id="${kind}-text" required></textarea>
   <div class="row"><button class="btn" type="submit">${t(submitKey)}</button></div><p class="msgarea" aria-live="polite"></p></form>`;
}
const HEALTH_NAV = () => [["main", "🏥", t("n_health")], ["services", "🏥", t("hl_find")], ["schemes", "📋", t("hl_schemes")], ["info", "🩺", t("hl_info")], ["fac", "📍", t("hl_fac")], ["emerg", "🚨", t("hl_emerg")]];
function renderHealth() {
  const s = sub.health, warn = `<div class="warn">${t("hl_disclaimer")}</div>`; let h = "";
  if (s === "main") h = `<h2>🏥 ${t("hl_title")}</h2>${warn}<div class="tiles">${tile("🏥", t("hl_find"), "", "sub", "health:services")}${tile("📋", t("hl_schemes"), "", "sub", "health:schemes")}${tile("🩺", t("hl_info"), "", "sub", "health:info")}${tile("📍", t("hl_fac"), "", "sub", "health:fac")}${tile("🚨", t("hl_emerg"), "", "sub", "health:emerg", "red")}</div>`;
  else {
    h = subnav("health", HEALTH_NAV()) + warn;
    if (s === "services") h += reqForm("healthcare", ["hl_svc_general", "hl_svc_vaccine", "hl_svc_maternal", "hl_svc_medicine", "hl_svc_elderly", "hl_svc_scheme"], "", "hl_submit", "hl_describe");
    if (s === "schemes") h += schemeCards(["health"]);
    if (s === "info") h += `<div class="warn red"><b>${t("red_title")}</b><br>${t("red_text")}</div>` + infoCards(HEALTH_INFO);
    if (s === "fac") h += `<p>${t("hl_fac_note")}</p>` + ["sc", "phc", "chc", "dh", "aw"].map(k => `<div class="item"><h3>${t("fac_" + k)}</h3><p>${t("fac_" + k + "_d")}</p></div>`).join("") + `<h2>${t("helplines")}</h2>${helpCards(HELPLINES)}<p class="note">${t("helpline_note")}</p>`;
    if (s === "emerg") h += `<div class="warn red">${t("hl_emerg_text")}</div>${helpCards(HELPLINES.slice(0, 3))}<div class="row"><button class="btn danger" data-act="tab" data-arg="sos">🚨 ${t("hl_emerg_btn")}</button></div><p class="note">${t("sos_warn")}</p>`;
  }
  $("health").innerHTML = h;
}
const FARM_NAV = () => [["main", "🌾", t("fm_title")], ["schemes", "🌾", t("fm_schemes")], ["crops", "🌱", t("fm_crops")], ["assist", "🧑‍🌾", t("fm_assist")], ["apply", "📋", t("fm_apply")], ["offline", "📡", t("fm_offline")]];
function renderFarm() {
  const s = sub.farm; let h = "";
  if (s === "main") h = `<h2>🌾 ${t("fm_title")}</h2><div class="tiles">${tile("🌾", t("fm_schemes"), "", "sub", "farm:schemes")}${tile("🌱", t("fm_crops"), "", "sub", "farm:crops")}${tile("🧑‍🌾", t("fm_assist"), "", "sub", "farm:assist")}${tile("📋", t("fm_apply"), "", "sub", "farm:apply")}${tile("📄", t("fm_docs"), "", "tab", "docs")}${tile("📡", t("fm_offline"), "", "sub", "farm:offline")}</div><p class="note">${t("fm_note")}</p>`;
  else {
    h = subnav("farm", FARM_NAV());
    if (s === "schemes") h += schemeCards(["farming"]) + `<h2>${t("helplines")}</h2>${helpCards(FARM_HELPLINES)}<p class="note">${t("helpline_note")}</p>`;
    if (s === "crops") h += infoCards(CROPS) + `<p class="note">${t("fm_note")}</p>`;
    if (s === "assist") h += infoCards(FARM_GUIDE) + `<p class="note">${t("fm_note")}</p>${helpCards(FARM_HELPLINES)}`;
    if (s === "apply") h += reqForm("agriculture", ["fm_svc_pmkisan", "fm_svc_insurance", "fm_svc_seed", "fm_svc_fert", "fm_svc_soil", "fm_svc_loan", "fm_svc_equip"],
      `<label for="agriculture-crop">${t("fm_crop")}</label><input id="agriculture-crop" maxlength="60"><label for="agriculture-land">${t("fm_land")}</label><input id="agriculture-land" inputmode="decimal" maxlength="8">`, "fm_submit", "fm_ask")
      + `<div class="card">${t("fm_docs_d")}<div class="row"><button class="btn ghost" data-act="tab" data-arg="docs">📄 ${t("fm_docs_btn")}</button></div></div>`;
    if (s === "offline") h += `<div class="card"><h3>✅ ${t("fm_off_yes")}</h3><p>${t("fm_off_yes_l")}</p></div><div class="card"><h3>🌐 ${t("fm_off_no")}</h3><p>${t("fm_off_no_l")}</p></div>`;
  }
  $("farm").innerHTML = h;
}
const sLabel = it => t("s_" + it.status), tLabel = it => it.kind === "document" ? t("ty_document") : it.kind === "sos" || it.payload.type === "sos" ? t("ty_sos") : it.payload.type && it.payload.type !== "general" ? t("ty_" + it.payload.type) : t("ty_request");
const preview = it => it.kind === "document" ? it.payload.filename : it.payload.text;
function queueItemHTML(it, full) {
  const srv = ls.get("gs_srv", {})[it.client_request_id];
  return `<div class="item ${it.status} ${it.kind === "sos" ? "sos" : ""}"><h3>${tLabel(it)} · ${sLabel(it)}${it.status === "pending" && !isOnline() ? " · " + t("saved_offline_tag") : ""}</h3><p>${esc(String(preview(it)).slice(0, 140))}</p>
  <dl class="kv"><dt>${t("q_id")}</dt><dd title="${esc(it.client_request_id)}">${esc(it.client_request_id.slice(0, 8))}</dd><dt>${t("q_created")}</dt><dd>${fmt(it.created_at)}</dd>
  <dt>${t("q_status")}</dt><dd>${sLabel(it)}</dd><dt>${t("q_retries")}</dt><dd>${it.retry_count}</dd><dt>${t("q_attempt")}</dt><dd>${fmt(it.last_attempt)}</dd>
  ${it.error ? `<dt>${t("q_error")}</dt><dd>${esc(t(it.error))}</dd>` : ""}${srv ? `<dt>${t("q_server")}</dt><dd>${esc(t("rs_" + srv.replace(" ", "_")))}</dd>` : ""}</dl>
  ${["pending", "failed"].includes(it.status) ? `<div class="row"><button class="btn sm" data-act="retry" data-arg="${esc(it.client_request_id)}">🔄 ${t("retry")}</button><button class="btn sm ghost" data-act="del" data-arg="${esc(it.client_request_id)}">🗑 ${t("del")}</button></div>` : ""}</div>`;
}
function renderQueue() {
  const mineQ = Q.filter(vis), other = Q.filter(i => i.owner != null && !vis(i)).length, wait = mineQ.filter(i => i.status !== "synced"), done = mineQ.filter(i => i.status === "synced").slice(0, 30), log = syncMeta().log;
  $("queue").innerHTML = `<div class="card sync-card"></div>${other ? `<div class="warn">${t("q_other", { n: other })}</div>` : ""}
   ${cnt(["failed"]) ? `<div class="row"><button class="btn ghost" data-act="retryall">${t("retry_all")}</button></div>` : ""}
   <h2>${t("q_waiting")}</h2>${wait.length ? wait.map(i => queueItemHTML(i)).join("") : `<p>${t("empty")}</p>`}
   <h2>${t("q_done")}</h2>${done.length ? done.map(i => queueItemHTML(i)).join("") : `<p>${t("empty")}</p>`}
   <h2>${t("history")}</h2>${log.length ? log.map(l => `<div class="item ${l.failed ? "failed" : "synced"}"><p>${fmt(l.at)} — ${t("synced_n")}: ${l.ok}, ${t("failed_n")}: ${l.failed}${l.error ? " · " + esc(t(l.error)) : ""}</p></div>`).join("") : `<p>${t("no_history")}</p>`}`;
  updateStatus();
}
function renderSchemesTab() {
  const cats = [...new Set(SCHEMES.map(s => s.cat))], sel = $("schemes").dataset.f || "";
  $("schemes").innerHTML = `<label for="sch-f">${t("form_service")}</label><select class="f" id="sch-f"><option value="">${t("ad_all")}</option>${cats.map(c => `<option value="${c}" ${c === sel ? "selected" : ""}>${t("cat_" + c)}</option>`).join("")}</select>${schemeCards(sel ? [sel] : null)}`;
}
// documents
const DOC_EXT = { pdf: "application/pdf", png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg" };
async function renderDocs() {
  const u = auth.user; if (!u) { $("docs").innerHTML = `<h2>📄 ${t("dc_title")}</h2><div class="warn">${t("dc_login")}</div><div class="row"><button class="btn" data-act="auth">${t("login")}</button></div><p class="note">${t("dc_rules")}</p>`; return; }
  const local = Q.filter(i => i.kind === "document" && i.payload.owner === u.id), key = "gs_docs_" + u.id; let server = ls.get(key, []);
  $("docs").innerHTML = `<h2>📄 ${t("dc_title")}</h2><form class="card" data-form="document" novalidate><label for="d-cat">${t("dc_cat")}</label><select class="f" id="d-cat">${["id", "land", "health", "cert", "other"].map(c => `<option value="${c}">${t("dc_cat_" + c)}</option>`).join("")}</select>
   <label for="d-file">${t("dc_file")}</label><input id="d-file" type="file" accept=".pdf,.png,.jpg,.jpeg,application/pdf,image/png,image/jpeg"><p class="note">${t("dc_rules")}</p>
   <div class="row"><button class="btn" type="submit">${t("dc_save")}</button></div><p class="msgarea" aria-live="polite"></p></form><div id="doc-list"></div>`;
  const paint = () => { const ids = new Set(local.map(i => i.client_request_id)), rest = server.filter(d => !ids.has(d.id));
    $("doc-list").innerHTML = local.length + rest.length === 0 ? `<p>${t("dc_none")}</p>` :
      local.map(i => `<div class="item ${i.status}"><h3>📄 ${esc(i.payload.filename)} · ${sLabel(i)}</h3><p>${t("dc_cat_" + i.payload.category)} · ${Math.ceil(i.payload.size / 1024)} KB · ${fmt(i.created_at)}</p>${i.error ? `<p class="err">${esc(t(i.error))}</p>` : ""}
        <div class="row">${i.status === "synced" ? `<button class="btn sm ghost" data-act="dl" data-arg="${esc(i.client_request_id)}" data-name="${esc(i.payload.filename)}">⬇ ${t("dc_view")}</button>` : `<button class="btn sm" data-act="retry" data-arg="${esc(i.client_request_id)}">🔄 ${t("retry")}</button><button class="btn sm ghost" data-act="del" data-arg="${esc(i.client_request_id)}">🗑 ${t("del")}</button>`}</div></div>`).join("")
      + rest.map(d => `<div class="item synced"><h3>📄 ${esc(d.filename)} · ${t("rs_" + d.status)}</h3><p>${t("dc_cat_" + d.category)} · ${Math.ceil(d.size / 1024)} KB · ${fmt(d.created_at)}</p><div class="row"><button class="btn sm ghost" data-act="dl" data-arg="${esc(d.id)}" data-name="${esc(d.filename)}">⬇ ${t("dc_view")}</button></div></div>`).join(""); };
  paint();
  if (isOnline()) try { server = await api("/api/my/documents"); ls.set(key, server); if (cur === "docs") paint(); } catch {}
}
async function downloadDoc(id, name) {
  try { const res = await api("/api/documents/" + encodeURIComponent(id) + "/download", { raw: true }); const url = URL.createObjectURL(await res.blob());
    const a = Object.assign(document.createElement("a"), { href: url, download: name || "document" }); document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 5000);
  } catch (e) { toast(t(errKey(e))); }
}
// SOS
function renderSos() {
  const mine = Q.filter(i => vis(i) && i.payload.type === "sos").slice(0, 10);
  $("sos").innerHTML = `<h2>🚨 ${t("sos_title")}</h2><div class="warn red">${t("sos_warn")}</div><div class="row"><a class="call" href="tel:112">${t("sos_call112")}</a><a class="call" href="tel:108">${t("sos_call108")}</a></div>
   <button class="sos-btn" data-act="sos">🚨 ${t("sos_btn")}</button><div id="sos-result" aria-live="assertive"></div>
   <h2>${t("sos_list")}</h2>${mine.length ? mine.map(i => `<div class="item sos"><h3>${t("sos_id")}: ${esc(i.client_request_id.slice(0, 8))} · ${sLabel(i)}</h3><p>${t("sos_time")}: ${fmt(i.created_at)}</p><p>${i.status === "synced" ? t("sos_received") : t("sos_saved_local")}</p></div>`).join("") : `<p>${t("empty")}</p>`}`;
}
const getPos = () => new Promise(res => { if (!navigator.geolocation) return res(null); navigator.geolocation.getCurrentPosition(p => res({ lat: +p.coords.latitude.toFixed(5), lng: +p.coords.longitude.toFixed(5), accuracy: Math.round(p.coords.accuracy) }), () => res(null), { timeout: 6000, maximumAge: 60000 }); });
let sosBusy = false;
async function sendSos() {
  if (sosBusy) return; sosBusy = true; $("sos-yes").disabled = true;
  try {
    const note = $("sos-note").value.trim(), pos = $("sos-loc").checked ? await getPos() : null, p = profile();
    const payload = { id: uid(), name: p.name, village: p.village, text: note || t("sos_default"), lang, category: "other", type: "sos", created_at: Date.now(), details: { note, ...(pos || {}) } };
    $("sos-dlg").close(); $("sos-note").value = "";
    const it = await enqueue("sos", payload);
    if (cur !== "sos") showTab("sos"); renderSos();
    $("sos-result").innerHTML = `<div class="card"><h3>${t("sos_id")}: ${esc(it.client_request_id.slice(0, 8))}</h3><p>${t("sos_time")}: ${fmt(it.created_at)} · ${sLabel(it)}</p><p><b>${it.status === "synced" ? t("sos_received") : t("sos_saved_local")}</b></p></div>`;
    say(it.status === "synced" ? t("sos_received") : t("sos_saved_local"));
  } finally { sosBusy = false; $("sos-yes").disabled = false; }
}
// ---------- navigation / rendering ----------
const VIEWS = { home: renderHome, report: () => {}, health: renderHealth, farm: renderFarm, docs: renderDocs, sos: renderSos, schemes: renderSchemesTab, queue: renderQueue };
async function showTab(tab) {
  stopSpeaking();
  if (tab === "admin" && !isStaff()) tab = "home";
  cur = tab;
  document.querySelectorAll("main > section").forEach(s => s.classList.toggle("hidden", s.id !== tab));
  document.querySelectorAll("#tabs button").forEach(b => b.setAttribute("aria-selected", b.dataset.arg === tab));
  if (tab === "admin") { await loadAdmin(); window.GSAdmin.open($("admin")); }
  else VIEWS[tab] && VIEWS[tab]();
  if (tab === "home") loadDashboardStats().then(() => cur === tab && renderHome());
  if (tab === "schemes" || tab === "health" || tab === "farm") loadSchemes().then(() => cur === tab && VIEWS[tab]());
  if (tab === "queue") refreshStatuses();
  renderAuthBtn();
  scrollTo(0, 0);
}
let adminLoad; const loadAdmin = () => adminLoad ||= new Promise((res, rej) => { const s = document.createElement("script"); s.src = "admin.js"; s.onload = res; s.onerror = () => { adminLoad = null; rej(); }; document.head.appendChild(s); });
function renderCurrent() { if (cur === "admin") window.GSAdmin?.open($("admin")); else VIEWS[cur] && VIEWS[cur](); }
function applyI18n() {
  document.documentElement.lang = lang; $("lang").value = lang; document.title = "GramSetu – " + t("tagline");
  document.querySelectorAll("[data-i18n]").forEach(e => e.textContent = t(e.dataset.i18n));
  document.querySelectorAll("[data-i18n-ph]").forEach(e => e.placeholder = t(e.dataset.i18nPh));
  document.querySelectorAll("[data-i18n-aria]").forEach(e => e.setAttribute("aria-label", t(e.dataset.i18nAria)));
  document.querySelectorAll("[data-i18n-title]").forEach(e => e.title = t(e.dataset.i18nTitle));
  if (!rec) { $("mic").textContent = t("mic"); } $("speak").textContent = t("speak"); $("send").textContent = t("send");
  $("chat-mic").setAttribute("aria-label", t("mic")); $("lang").setAttribute("aria-label", t("lang_label"));
  renderAuthBtn(); renderChips(); showCat();
}
function renderAuthBtn() {
  updateStatus();
  const u = auth.user;
  const b = $("auth-btn");
  b.textContent = u ? t("logout") : t("login");
  b.title = u ? t("logged_as", { n: u.name || u.username }) : "";
  const profileBtn = $("profile-btn");
  if (profileBtn) profileBtn.textContent = u ? (u.name || u.username) : "Profile";
  const pageTitle = $("page-title");
  if (pageTitle) pageTitle.textContent = { home: "Dashboard", report: "Report", health: "Healthcare", farm: "Farmer Support", docs: "Documents", sos: "Emergency", schemes: "Schemes", queue: "Offline Queue" }[cur] || "Dashboard";
  $("tab-admin").classList.toggle("hidden", !isStaff());
}
const showCat = () => { const v = $("text").value; $("hint").textContent = v ? `${t("detected")} ${t("cat_" + classify(v))}` : ""; };

// ---------- forms ----------
const invalid = (el, bad) => { el.setAttribute("aria-invalid", bad ? "true" : "false"); return bad; };
async function submitForm(form) {
  const kind = form.dataset.form, msg = form.querySelector(".msgarea"), btn = form.querySelector("button[type=submit]"); if (btn.disabled) return;
  const say_ = (m, sp) => { const el = document.querySelector(`[data-form="${kind}"] .msgarea`); if (el) el.textContent = m; toast(m, sp); };   // re-query: the view may have re-rendered after sync
  if (kind === "document") return submitDoc(form, btn, say_);
  const text = form.querySelector("textarea").value.trim(), svc = form.querySelector("select")?.value;
  if (invalid(form.querySelector("textarea"), !text)) return say_(t("msg_validation") + " " + t("needtext"));
  btn.disabled = true;
  try {
    const g = s => (form.querySelector(s)?.value || "").trim(), name = g("[id$=-name]"), village = g("[id$=-village]"); saveProfile(name, village);
    const details = { service: svc }; let category = "other";
    if (kind === "healthcare") category = "health";
    if (kind === "agriculture") { category = "farming"; details.crop = g("#agriculture-crop"); details.land_acres = g("#agriculture-land"); }
    const payload = { id: uid(), name, village, text, lang, category, type: kind, created_at: Date.now(), details };
    const it = await enqueue("request", payload); form.querySelector("textarea").value = "";
    say_(outcomeMsg(it), true);
  } finally { btn.disabled = false; }
}
async function submitDoc(form, btn, say_) {
  const f = $("d-file").files[0], u = auth.user; if (!u) return say_(t("msg_login_req"));
  if (invalid($("d-file"), !f)) return say_(t("dc_choose"));
  const ext = f.name.split(".").pop().toLowerCase();
  if (!DOC_EXT[ext]) return say_(t("msg_bad_file")); if (f.size > 2 * 1024 * 1024) return say_(t("msg_too_big")); if (!f.size) return say_(t("msg_validation"));
  btn.disabled = true;
  try {
    let sha = ""; try { sha = [...new Uint8Array(await crypto.subtle.digest("SHA-256", await f.arrayBuffer()))].map(b => b.toString(16).padStart(2, "0")).join(""); } catch { sha = `${f.size}-${f.lastModified}-${f.name}`; }
    if (Q.some(i => i.kind === "document" && i.payload.owner === u.id && i.payload.sha256 === sha)) return say_(t("dc_local_dup"));
    const payload = { id: uid(), category: $("d-cat").value, filename: f.name, mime: DOC_EXT[ext], size: f.size, sha256: sha, created_at: Date.now(), owner: u.id };
    const it = await enqueue("document", payload, f); renderDocs();
    say_(it.status === "synced" ? t("dc_uploaded") : isOnline() ? t("msg_sync_later") : t("dc_saved_off"), true);
  } finally { btn.disabled = false; }
}

// ---------- auth ----------
let authMode = "login";
function setAuthMode(m) { authMode = m; $("auth-reg").classList.toggle("hidden", m !== "register"); $("auth-go").textContent = t(m === "login" ? "login" : "register"); $("auth-sw").textContent = t(m === "login" ? "auth_to_reg" : "auth_to_login"); $("a-pass").autocomplete = m === "login" ? "current-password" : "new-password"; $("auth-err").textContent = ""; }
async function submitAuth() {
  const body = { username: $("a-user").value.trim(), password: $("a-pass").value }, err = $("auth-err");
  if (authMode === "register") { body.name = $("a-name").value.trim(); body.village = $("a-village").value.trim(); }
  if (invalid($("a-user"), !body.username) | invalid($("a-pass"), authMode === "register" ? body.password.length < 8 : !body.password) | (authMode === "register" && invalid($("a-name"), !body.name))) return err.textContent = t("msg_validation");
  $("auth-go").disabled = true;
  try {
    const r = await api("/api/auth/" + authMode, { method: "POST", body });
    localStorage.setItem("gs_token", r.token); ls.set("gs_user", r.user); $("auth-dlg").close(); $("a-pass").value = "";
    toast(t(authMode === "login" ? "login_ok" : "reg_ok")); resetForms(); renderAuthBtn(); renderCurrent(); flush();
  } catch (e) { err.textContent = t(errKey(e)); } finally { $("auth-go").disabled = false; }
}
async function logout() { try { await api("/api/auth/logout", { method: "POST" }); } catch {} localStorage.removeItem("gs_token"); localStorage.removeItem("gs_user"); Object.keys(localStorage).filter(k => k.startsWith("gs_docs_")).forEach(k => localStorage.removeItem(k)); resetForms(); renderAuthBtn(); if (cur === "admin") showTab("home"); else renderCurrent(); }

// ---------- chatbot (rule-based, offline-capable) ----------
const chatOpen = () => !$("chat").classList.contains("hidden");
function renderChips() { $("chat-chips").innerHTML = ["chat_q1", "chat_q2", "chat_q3", "chat_q4"].map(k => `<button type="button" data-act="chip" data-arg="${k}">${esc(t(k))}</button>`).join(""); }
function addMsg(cls, text, actions) {
  const d = document.createElement("div"); d.className = "msg " + cls; d.textContent = text;
  if (actions?.length) { const r = document.createElement("div"); r.className = "row"; r.innerHTML = actions.map(a => a.href ? `<a class="btn sm alt" href="${a.href}">${esc(a.label)}</a>` : `<button type="button" class="btn sm" data-act="botnav" data-arg="${a.arg}">${esc(a.label)}</button>`).join(""); d.appendChild(r); }
  $("chat-log").appendChild(d); $("chat-log").scrollTop = $("chat-log").scrollHeight; return d;
}
function botReply(q) {
  const { intent, cat } = detectIntent(q); let text = t("bot_" + (intent === "nav" ? "nav" : intent)), acts = [];
  const go = (k, a) => ({ label: t(k), arg: a });
  if (intent === "government") { const l = SCHEMES.filter(s => s.cat === cat && cat !== "other").concat(cat === "other" ? SCHEMES.filter(s => !["health", "farming"].includes(s.cat)).slice(0, 3) : []).slice(0, 3);
    if (l.length) text += "\n" + l.map(s => `• ${L10(s.name)} – ${L10(s.desc)}`).join("\n"); acts = [go("schemes", "schemes"), go("report", "report")]; }
  if (intent === "agriculture") acts = [go("fm_schemes", "farm:schemes"), go("fm_crops", "farm:crops"), go("fm_apply", "farm:apply")];
  if (intent === "healthcare") { acts = [go("hl_schemes", "health:schemes"), go("hl_info", "health:info"), go("hl_find", "health:services")]; text += "\n" + t("hl_disclaimer"); }
  if (intent === "documents") acts = [go("n_docs", "docs")];
  if (intent === "emergency") acts = [go("n_sos", "sos"), { label: t("sos_call112"), href: "tel:112" }, { label: t("sos_call108"), href: "tel:108" }];
  if (intent === "offline") acts = [go("n_queue", "queue")];
  if (intent === "nav" || intent === "unknown") acts = [go("report", "report"), go("n_health", "health"), go("n_farm", "farm"), go("n_docs", "docs")];
  return { text, acts, intent };
}
function ask(q, byVoice) {
  q = q.trim(); if (!q) return; addMsg("me", q); const r = botReply(q); addMsg("bot", r.text, r.acts); $("chat-in").value = "";
  if (byVoice) say(r.text);
}
function openChat() { $("chat").classList.remove("hidden"); if (!$("chat-log").children.length) addMsg("bot", t("chat_hello")); $("chat-in").focus(); loadSchemes(); }
function closeChat() { $("chat").classList.add("hidden"); stopSpeaking(); stopListening(); }     // closing the chatbot stops speech and the microphone

// ---------- events ----------
async function setForced(v) { forced = v; sessionStorage.setItem("gs_forced", v ? "1" : "0"); serverUp = null; updateStatus(); renderCurrent(); if (!v) { await flush(true); } }
document.addEventListener("click", async e => {
  const b = e.target.closest("[data-act]"); if (!b) return; const a = b.dataset.act, arg = b.dataset.arg;
  switch (a) {
    case "tab": if (chatOpen() && b.closest("#chat")) closeChat(); return showTab(arg);
    case "sub": { const [s, k] = arg.split(":"); sub[s] = k; return VIEWS[s](); }
    case "sync": return flush(true);
    case "retry": { const it = Q.find(i => i.client_request_id === arg); if (it) { it.status = "pending"; it.error = ""; await qPut(it); toast(t("msg_retry")); await refreshQ(); renderCurrent(); flush(); } return; }
    case "retryall": for (const it of Q.filter(i => i.status === "failed")) { it.status = "pending"; it.error = ""; await qPut(it); } await refreshQ(); renderCurrent(); return flush();
    case "del": if (confirm(t("confirm_del"))) { await qDel(arg); await fDel(arg); await refreshQ(); toast(t("msg_deleted")); renderCurrent(); } return;
    case "dl": return downloadDoc(arg, b.dataset.name);
    case "demo": return setForced(!forced);
    case "auth": return auth.user && b.id === "auth-btn" ? logout() : (setAuthMode("login"), $("auth-dlg").showModal(), $("a-user").focus());
    case "authclose": return $("auth-dlg").close();
    case "authswitch": return setAuthMode(authMode === "login" ? "register" : "login");
    case "sos": return $("sos-dlg").showModal();
    case "sosclose": return $("sos-dlg").close();
    case "chat": return chatOpen() ? closeChat() : openChat();
    case "chatclose": return closeChat();
    case "chip": return ask(t(arg));
    case "botnav": closeChat(); if (arg.includes(":")) { const [s, k] = arg.split(":"); sub[s] = k; showTab(s); } else showTab(arg); return;
    case "stopspeak": return stopSpeaking();
    case "readpage": if (document.body.classList.contains("speaking")) return stopSpeaking(); return say(document.querySelector("main > section:not(.hidden)")?.innerText);
  }
});
document.addEventListener("submit", e => { const f = e.target; if (f.dataset?.form) { e.preventDefault(); submitForm(f); } });
document.addEventListener("change", e => { if (e.target.id === "sch-f") { $("schemes").dataset.f = e.target.value; renderSchemesTab(); } });
$("auth-form").onsubmit = e => { e.preventDefault(); submitAuth(); };
$("sos-yes").onclick = sendSos;
$("chat-form").onsubmit = e => { e.preventDefault(); ask($("chat-in").value); };
$("chat-mic").onclick = () => listen({ btn: $("chat-mic"), indicator: $("chat-listening"), onText: v => $("chat-in").value = v, onDone: v => v && ask(v, true) });
$("mic").onclick = () => listen({ btn: $("mic"), indicator: $("listening"), onText: v => { $("text").value = v; showCat(); } });
$("speak").onclick = () => say($("text").value || t("needtext"));
$("text").oninput = showCat;
$("report-form").onsubmit = async e => {      // existing "report a problem" flow, now through the offline queue
  e.preventDefault(); const text = $("text").value.trim(), btn = $("send"); if (btn.disabled) return;
  if (invalid($("text"), !text)) return toast(t("needtext"), true);
  btn.disabled = true;
  try { saveProfile($("name").value, $("village").value);
    const it = await enqueue("request", { id: uid(), name: $("name").value, village: $("village").value, text, lang, category: classify(text), type: "general", created_at: Date.now(), details: {} });
    $("text").value = ""; $("hint").textContent = ""; toast(outcomeMsg(it), true); $("hint").textContent = outcomeMsg(it);
  } finally { btn.disabled = false; }
};
$("lang").onchange = e => { lang = e.target.value; localStorage.setItem("lang", lang); stopSpeaking(); applyI18n(); renderCurrent(); updateStatus(); };
addEventListener("online", () => { serverUp = null; updateStatus(); flush(); loadSchemes(); });
addEventListener("offline", updateStatus);
addEventListener("pagehide", () => { stopSpeaking(); stopListening(); });
document.addEventListener("keydown", e => { if (e.key === "Escape" && chatOpen()) closeChat(); });
setInterval(() => { if (!document.hidden) flush(); }, 30000);        // retry pending items, notice reconnection (navigator.onLine can be wrong)
if ("serviceWorker" in navigator) { navigator.serviceWorker.register("/sw.js"); navigator.serviceWorker.addEventListener("message", e => e.data === "flush" && flush()); }

// ---------- boot ----------
(async () => {
  applyI18n(); await refreshQ();
  for (const it of Q.filter(i => i.status === "syncing")) { it.status = "pending"; await qPut(it); }     // interrupted by a refresh/crash: nothing is lost
  await refreshQ(); const p = profile(); $("name").value = p.name; $("village").value = p.village;
  showTab("home"); flush(); queueSync();
  if (auth.token && navigator.onLine && !forced) api("/api/auth/me").then(u => { ls.set("gs_user", u); renderAuthBtn(); }).catch(e => { if (e.status === 401) { localStorage.removeItem("gs_token"); localStorage.removeItem("gs_user"); renderAuthBtn(); } });
})();
