// GramSetu service worker. Bump VERSION on every release: old caches are deleted on activate.
const VERSION = "v3", SHELL = "gramsetu-shell-" + VERSION, DATA = "gramsetu-data-" + VERSION;
const FILES = ["/", "/index.html", "/app.js", "/i18n.js", "/content.js", "/style.css", "/manifest.json", "/icon.svg"];
const PUBLIC_API = ["/api/schemes"];          // only non-private API answers may be cached
self.addEventListener("install", e => {
  e.waitUntil(caches.open(SHELL).then(c => c.addAll(FILES)).then(() => caches.open(DATA)).then(c => c.add("/api/schemes").catch(() => {})));
  self.skipWaiting();
});
self.addEventListener("activate", e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => ![SHELL, DATA].includes(k)).map(k => caches.delete(k)))));
  self.clients.claim();
});
self.addEventListener("fetch", e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== "GET" || u.origin !== location.origin) return;
  if (u.pathname.startsWith("/api/")) {
    if (!PUBLIC_API.includes(u.pathname)) return;               // private/auth data: network only, never cached
    e.respondWith(fetch(r).then(res => { if (res.ok) { const c = res.clone(); caches.open(DATA).then(x => x.put(r, c)); } return res; })
      .catch(() => caches.match(r).then(m => m || new Response("[]", { headers: { "Content-Type": "application/json" }, status: 503 }))));
    return;
  }
  // app shell: cache first, refresh in the background (stale-while-revalidate)
  e.respondWith(caches.match(r, { ignoreSearch: true }).then(hit => {
    const net = fetch(r).then(res => { if (res.ok && res.type === "basic") { const c = res.clone(); caches.open(SHELL).then(x => x.put(r, c)); } return res; }).catch(() => hit);
    return hit || net.then(res => res || caches.match("/index.html"));
  }));
});
// Background Sync: wake an open page so it flushes its IndexedDB queue
self.addEventListener("sync", e => {
  if (e.tag === "gramsetu-sync") e.waitUntil(self.clients.matchAll().then(cs => cs.forEach(c => c.postMessage("flush"))));
});
