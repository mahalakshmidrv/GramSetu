# GramSetu – offline-first, multilingual rural services platform

Citizens speak or type a need in English, Hindi or Tamil. It is saved on the phone (IndexedDB) and uploaded to the
FastAPI/SQLite backend whenever real connectivity exists. Modules: problem reports, healthcare, farmer services,
documents, SOS, schemes, rule-based assistant, officer/admin dashboard.

## Run
    python -m venv venv && source venv/bin/activate     # Windows: venv\Scripts\activate
    pip install -r requirements.txt                     # no new packages were added
    uvicorn backend.main:app --reload
Open http://localhost:8000 (Chrome/Edge for voice input). API docs: /docs

### Accounts (no passwords are in the source code)
On first start an ADMIN is created and its generated password is printed **once** in the server console.
To choose your own, set env vars before the first start:

    GRAMSETU_ADMIN_USER=admin GRAMSETU_ADMIN_PASSWORD='choose-a-strong-one'
    GRAMSETU_OFFICER_USER=officer1 GRAMSETU_OFFICER_PASSWORD='another-one'     # optional
Citizens self-register in the app (always role CITIZEN). Other optional env vars: `GRAMSETU_CORS_ORIGINS` (comma list,
default same-origin only), `GRAMSETU_MAX_FILE_BYTES` (default 2 MB), `GRAMSETU_DB`, `GRAMSETU_UPLOADS`.
Behind a public host use HTTPS (service workers, geolocation and secure uuid need it; localhost is exempt).

## Offline demo (also on the Home page, "Offline demo")
1. Open GramSetu online (log in once if you want to demo documents) – the shell and schemes are cached.
2. Tap **Simulate offline** on Home (or use DevTools > Network > Offline / airplane mode). Header shows 🔴 Offline Mode.
3. Reload – the app still opens. Create a report / healthcare / farmer request. It says it was saved offline.
4. Open **Offline Queue**: item is *Pending*, retries 0.
5. Tap **Go back online** (or reconnect). It syncs automatically (🔄 → ✓ All data synchronized).
6. Log in as admin → **Admin** tab: the request is listed; change its status.

## How synchronisation works
`UI → IndexedDB queue (status: pending) → Sync Manager → POST /api/sync | /api/documents → SQLite`
* Each item has a client-generated unique id (`client_request_id`), status pending/syncing/synced/failed, retry count, last attempt, error key.
* Sync triggers: browser `online` event, Background Sync (Chromium; wakes an open page), a 30 s timer, **Sync Now**, successful login.
* A real reachability check (`/api/health`) is used, because `navigator.onLine` can be true without internet.
* Idempotent: server does `INSERT OR IGNORE` on the id, so retries/double sends never create duplicates.
* Network/5xx errors keep the item pending (max 5 automatic retries, then *failed*); validation errors fail immediately. **Retry** re-queues.
* Items interrupted by a refresh while "syncing" are reset to pending on start. Nothing is deleted unless the user deletes it.
* SOS items are sent first.

## Limits – read before claiming anything
* The service worker does **not** itself upload while the app is closed; Background Sync only wakes an open page.
* SOS is an internet request to the GramSetu server. It does not send SMS/calls and does not reach authorities; the UI says so and offers `tel:112` / `tel:108` links.
* No LLM: the assistant is rule-based keyword intent matching (en/hi/ta) plus bundled content, offline and online. It never diagnoses.
* Facility finder is a list of facility *types* + helpline numbers, not a live "near me" directory (no data source). Verify helpline numbers for your state.
* Not implemented: notifications table, push notifications, image compression, rate limiting beyond in-memory per-IP limits (resets on restart; per-IP behind a proxy), CSRF tokens (not needed: bearer-token auth).
* Auth token is kept in `localStorage` (XSS would expose it – all dynamic text is HTML-escaped).

## Files
backend/main.py (API, auth, migration) · frontend/index.html, style.css, app.js (core), i18n.js (all en/hi/ta text),
content.js (offline health/farm content), admin.js (lazy-loaded dashboard), sw.js (cache v2), manifest.json

## Shared phones
Every queued item stores the `owner` (user id, or null for anonymous reports/SOS). The sync manager only sends items whose owner matches the
logged-in user; anonymous items are sent without any token, so they are never attached to someone else's account. Other users' items stay on the
device, are hidden from the queue view (a note shows how many exist) and sync when that account logs in again. Logging out does not delete queued data.
Anonymous (not logged-in) reports are still sent without any token, but they are visible in the queue only while nobody is logged in, and the
name/village form fields are remembered only per logged-in account (cleared on logout). Queued data stays in the browser's IndexedDB until synced:
on a truly shared phone, finish syncing before handing it over.
Sync rule: logged out → only anonymous items sync; logged in → only that user's items sync. Exception: an anonymous SOS item is still sent (without any token)
so an emergency is never held back because someone else is logged in.
