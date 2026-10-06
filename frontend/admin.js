"use strict";
// Admin / officer dashboard. Lazy-loaded on first open. All permissions are enforced by the backend; this UI only hides what a role can't use.
window.GSAdmin = (() => {
  const S = { tab: "ov", page: 1, status: "", type: "", q: "", open: null };
  const TYPES = ["healthcare", "agriculture", "government", "sos"], STAT = ["Received", "In Progress", "Completed", "Rejected"];
  const rs = s => t("rs_" + String(s).replace(" ", "_")), tyl = ty => t(ty === "sos" ? "ty_sos" : "ty_" + ty);
  let el;
  const TABS = () => [["ov", "📊", t("ad_ov")], ["req", "📋", t("ad_req")], ["emerg", "🚨", t("ad_emerg")], ["docs", "📄", t("ad_docs")], ["sync", "🔄", t("ad_sync")], ...(auth.user?.role === "ADMIN" ? [["users", "👥", t("ad_users")]] : [])];
  const head = () => `<h2>🛠 ${t("ad_title")}</h2><div class="subnav" role="tablist">${TABS().map(([k, i, l]) => `<button role="tab" data-ad="tab:${k}" aria-selected="${S.tab === k}">${i} ${l}</button>`).join("")}<button data-ad="refresh">⟳ ${t("ad_refresh")}</button></div>`;
  const put = html => { el.innerHTML = head() + `<div id="ad-body">${html}</div>`; };
  const fail = e => put(`<p class="err" role="alert">${t(e && e.status === 403 ? "msg_forbidden" : "ad_fail")}</p>`);
  const row = r => `<div class="item ${r.type === "sos" ? "sos" : r.status === "Completed" ? "synced" : "pending"}"><h3>${tyl(r.type)} · ${rs(r.status)}</h3><p>${esc(r.text || "")}</p>
    <dl class="kv"><dt>${t("name")}</dt><dd>${esc(r.name || "—")}</dd><dt>${t("village")}</dt><dd>${esc(r.village || "—")}</dd><dt>${t("q_created")}</dt><dd>${fmt(r.created_at)}</dd><dt>${t("q_id")}</dt><dd>${esc(r.id.slice(0, 8))}</dd></dl>
    <div class="row"><button class="btn sm ghost" data-ad="open:${esc(r.id)}">${t("ad_open")}</button></div><div id="d-${esc(r.id)}"></div></div>`;
  async function overview() {
    put(`<p>${t("ad_load")}</p>`);
    try {
      const s = await api("/api/admin/stats"), bt = s.by_type, max = Math.max(1, ...Object.values(bt)), dev = Q.filter(i => ["pending", "syncing"].includes(i.status)).length;
      const card = (k, v, c = "") => `<div class="stat ${c}"><b>${v}</b>${t(k)}</div>`;
      put(`<div class="stats">${card("ad_users_n", s.users)}${card("ad_total", s.total)}${card("ad_pending", s.pending)}${card("ad_completed", s.completed)}${card("ad_offline", dev)}
        ${card("ad_health", bt.healthcare || 0)}${card("ad_agri", bt.agriculture || 0)}${card("ad_gov", bt.government || 0)}${card("ad_sos", s.sos_open, "red")}${card("ad_docs_n", s.documents)}</div>
        <p class="note">${t("ad_device")}</p><h2>${t("ad_by_type")}</h2>${Object.entries(bt).map(([k, v]) => `<div class="bar"><span>${tyl(k)}</span><i style="width:${Math.round(v / max * 60)}%"></i> ${v}</div>`).join("")}
        <h2>${t("ad_recent")}</h2>${s.recent.length ? s.recent.map(row).join("") : `<p>${t("empty")}</p>`}`);
    } catch (e) { fail(e); }
  }
  async function requests(emerg) {
    const type = emerg ? "sos" : S.type, qs = new URLSearchParams({ page: S.page, page_size: 10, status: S.status, type, q: S.q });
    put(`<p>${t("ad_load")}</p>`);
    try {
      const d = await api("/api/admin/requests?" + qs), pages = Math.max(1, Math.ceil(d.total / d.page_size));
      put(`<form class="card" data-ad-filter novalidate><div class="row"><div style="flex:1 1 140px"><label for="f-status">${t("ad_status")}</label><select class="f" id="f-status"><option value="">${t("ad_all")}</option>${STAT.map(s => `<option value="${s}" ${S.status === s ? "selected" : ""}>${rs(s)}</option>`).join("")}</select></div>
        ${emerg ? "" : `<div style="flex:1 1 140px"><label for="f-type">${t("q_type")}</label><select class="f" id="f-type"><option value="">${t("ad_all")}</option>${TYPES.map(s => `<option value="${s}" ${S.type === s ? "selected" : ""}>${tyl(s)}</option>`).join("")}</select></div>`}
        <div style="flex:2 1 200px"><label for="f-q">${t("ad_search")}</label><input id="f-q" value="${esc(S.q)}"></div></div><div class="row"><button class="btn sm" type="submit">🔍</button></div></form>
        ${d.items.length ? d.items.map(row).join("") : `<p>${t("empty")}</p>`}
        <div class="pager"><button class="btn sm ghost" data-ad="page:-1" ${S.page <= 1 ? "disabled" : ""}>${t("ad_prev")}</button><span>${t("ad_page", { p: d.page, n: pages })}</span><button class="btn sm ghost" data-ad="page:1" ${S.page >= pages ? "disabled" : ""}>${t("ad_next")}</button></div>`);
    } catch (e) { fail(e); }
  }
  async function detail(id) {
    const box = document.getElementById("d-" + id); if (!box) return; if (box.innerHTML) { box.innerHTML = ""; return; } box.textContent = t("ad_load");
    try {
      const r = await api("/api/admin/requests/" + encodeURIComponent(id)), det = Object.entries(r.details || {}).filter(([, v]) => v !== "" && v != null);
      box.innerHTML = `<div class="card"><p>${esc(r.text)}</p><dl class="kv"><dt>${t("q_id")}</dt><dd>${esc(r.id)}</dd><dt>${t("q_created")}</dt><dd>${fmt(r.created_at)}</dd><dt>${t("synced")}</dt><dd>${fmt(r.synced_at)}</dd>${det.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl>
        <label for="s-${esc(id)}">${t("ad_status")}</label><select class="f" id="s-${esc(id)}">${STAT.map(s => `<option value="${s}" ${r.status === s ? "selected" : ""}>${rs(s)}</option>`).join("")}</select>
        ${auth.user.role === "ADMIN" ? `<label for="a-${esc(id)}">${t("ad_assign")}</label><input id="a-${esc(id)}" inputmode="numeric" value="${r.assigned_to || ""}">` : ""}
        <div class="row"><button class="btn sm" data-ad="save:${esc(id)}">${t("ad_save")}</button><button class="btn sm alt" data-ad="done:${esc(id)}">✔ ${rs("Completed")}</button></div><p class="msgarea" id="m-${esc(id)}" aria-live="polite"></p></div>`;
    } catch (e) { box.textContent = t("ad_fail"); }
  }
  async function save(id, status) {
    const body = { status: status || document.getElementById("s-" + id).value }, a = document.getElementById("a-" + id);
    if (a && a.value.trim()) body.assigned_to = parseInt(a.value, 10);
    try { await api("/api/admin/requests/" + encodeURIComponent(id), { method: "PATCH", body }); document.getElementById("m-" + id).textContent = t("ad_saved"); }
    catch (e) { document.getElementById("m-" + id).textContent = t(errKey(e)); }
  }
  async function documents() {
    put(`<p>${t("ad_load")}</p>`);
    try {
      const l = await api("/api/admin/documents");
      put(l.length ? l.map(d => `<div class="item ${d.status === "Verified" ? "synced" : d.status === "Rejected" ? "failed" : "pending"}"><h3>📄 ${esc(d.filename)} · ${rs(d.status)}</h3><p>${t("dc_cat_" + d.category)} · ${Math.ceil(d.size / 1024)} KB · ${t("ad_owner")}: ${esc(d.owner)} · ${fmt(d.created_at)}</p>
        <div class="row"><button class="btn sm ghost" data-act="dl" data-arg="${esc(d.id)}" data-name="${esc(d.filename)}">⬇ ${t("dc_view")}</button><button class="btn sm" data-ad="doc:${esc(d.id)}:Verified">✔ ${t("ad_verify")}</button><button class="btn sm danger" data-ad="doc:${esc(d.id)}:Rejected">✖ ${t("ad_reject")}</button></div></div>`).join("") : `<p>${t("dc_none")}</p>`);
    } catch (e) { fail(e); }
  }
  async function syncLog() {
    put(`<p>${t("ad_load")}</p>`);
    try { const l = await api("/api/admin/sync-history");
      put(l.length ? l.map(r => `<div class="item ${r.rejected ? "failed" : "synced"}"><p>${fmt(r.at)} — ${t("ad_received")}: ${r.received}, ${t("ad_created")}: ${r.created}, ${t("ad_dups")}: ${r.duplicates}, ${t("ad_rej")}: ${r.rejected}</p></div>`).join("") : `<p>${t("no_history")}</p>`);
    } catch (e) { fail(e); }
  }
  async function users() {
    put(`<p>${t("ad_load")}</p>`);
    try { const l = await api("/api/admin/users");
      put(l.map(u => `<div class="item"><h3>${esc(u.name || u.username)} <small>(${esc(u.username)} · #${u.id})</small></h3><div class="row"><label class="sr" for="r-${u.id}">${t("ad_role")}</label>
        <select class="f" id="r-${u.id}" ${u.id === auth.user.id ? "disabled" : ""}>${["CITIZEN", "OFFICER", "ADMIN"].map(r => `<option ${u.role === r ? "selected" : ""}>${r}</option>`).join("")}</select>
        <label class="chk"><input type="checkbox" id="x-${u.id}" ${u.active ? "checked" : ""} ${u.id === auth.user.id ? "disabled" : ""}> ${t("ad_active")}</label>
        <button class="btn sm" data-ad="user:${u.id}" ${u.id === auth.user.id ? "disabled" : ""}>${t("ad_save")}</button></div></div>`).join(""));
    } catch (e) { fail(e); }
  }
  const go = () => ({ ov: overview, req: () => requests(false), emerg: () => requests(true), docs: documents, sync: syncLog, users }[S.tab]());
  function open(target) {
    el = target;
    if (!isStaff()) { el.innerHTML = `<h2>🛠 ${t("ad_title")}</h2><p class="err">${t("ad_none")}</p><div class="row"><button class="btn" data-act="auth">${t("login")}</button></div>`; return; }
    if (!el._wired) { el._wired = true;
      el.addEventListener("click", async e => { const b = e.target.closest("[data-ad]"); if (!b) return; const [a, x, y] = b.dataset.ad.split(":");
        if (a === "tab") { S.tab = x; S.page = 1; S.status = S.type = S.q = ""; go(); } else if (a === "refresh") go();
        else if (a === "page") { S.page = Math.max(1, S.page + +x); go(); } else if (a === "open") detail(x);
        else if (a === "save") save(x); else if (a === "done") { document.getElementById("s-" + x).value = "Completed"; save(x, "Completed"); }
        else if (a === "doc") { try { await api("/api/admin/documents/" + encodeURIComponent(x), { method: "PATCH", body: { status: y } }); documents(); } catch (er) { toast(t(errKey(er))); } }
        else if (a === "user") { try { await api("/api/admin/users/" + x, { method: "PATCH", body: { role: document.getElementById("r-" + x).value, active: document.getElementById("x-" + x).checked } }); toast(t("ad_saved")); } catch (er) { toast(t(errKey(er))); } } });
      el.addEventListener("submit", e => { if (e.target.hasAttribute("data-ad-filter")) { e.preventDefault(); S.status = $("f-status").value; S.type = $("f-type")?.value || ""; S.q = $("f-q").value.trim(); S.page = 1; go(); } });
    }
    go();
  }
  return { open };
})();
