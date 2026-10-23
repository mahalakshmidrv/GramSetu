# GramSetu offline-first implementation and acceptance checklist

## Phase 1 — Offline foundation (implemented in this package)
- [x] Existing PWA shell cache and IndexedDB request/SOS queue retained.
- [x] Contacts, local message outbox and saved guides stored persistently in a separate IndexedDB database.
- [x] Messages retain a truthful local-only status after refresh/reopen.
- [x] JSON backup export.
- [ ] Browser storage durability varies by device/browser; test on target devices and encourage backups.

## Phase 2 — Trusted contacts and emergency UX (partially implemented)
- [x] Manual trusted-neighbour contacts and optional phone number/location note.
- [x] `tel:` link for the device's available phone service.
- [x] Existing SOS stays in the original persistent sync queue; the existing UI distinguishes saved locally from server receipt.
- [x] Offline emergency, first-aid and farming guides can be saved locally.
- [ ] Permissioned contact import and device permission UX are not included yet.

## Phase 3 — Native nearby messaging (not implemented; required before claiming offline delivery)
1. Create/maintain a native Android companion using a supported Bluetooth LE discovery + authenticated data-transfer design or Wi-Fi Direct. Browser Bluetooth APIs are not a reliable universal substitute.
2. Add Android runtime permission flows and explain discovery/visibility to the user. Avoid collecting or advertising identifiers without consent.
3. Define a versioned message envelope with unique ID, sender/recipient device IDs, creation/expiry time, payload length and integrity protection.
4. Use an established cryptographic protocol/library; do not invent encryption. Pair/verify peers, encrypt message content, and reject malformed/oversized payloads.
5. Implement explicit send/receive acknowledgements, deduplication, expiry, retry and bounded queue sizes. A message is delivered only after a recipient acknowledgement.
6. Add optional store-and-forward only with explicit user consent, short expiry, hop limits, dedupe and no exposure of plaintext to relaying devices.
7. Test two physical Android phones with Wi-Fi/mobile data disabled, then test interruptions, app restart, duplicates, permission denial and low battery. Do not rely on emulator-only tests.

## Phase 4 — Reliability/performance
- Measure cold start, local DB operations, queue flush duration, storage size and battery impact on low-end Android devices.
- Verify no duplicate messages after retries or connection interruptions; verify expiry and conflict rules.
- Test no network, weak network, server unavailable, force-stop/restart and browser cache update.

## Phase 5 — Final validation and honest claims
- Publish a device/OS compatibility table and actual test results.
- Label each status as local, queued, transferring, acknowledged/delivered, expired or failed.
- Keep ordinary phone calls distinct from app messages: calls to telephone numbers require cellular service or another supported voice service.
- SOS delivery is not guaranteed by offline storage. Clearly show whether it is only saved, sent to the server, or acknowledged by a responder.
