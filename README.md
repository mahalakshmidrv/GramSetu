# 🌾 GramSetu 2.0 — Offline-First Village Communication Network

GramSetu 2.0 is an offline-first rural communication and essential public services application built for Indian villages where internet connectivity and mobile cellular coverage are intermittent, weak, or completely unavailable.

Inspired by the offline download mechanism of **Spotify Premium**, GramSetu enables citizens to save critical emergency contacts, healthcare centres, crop advisories, welfare schemes, and panchayat announcements on-device so they remain instantly accessible anywhere, anytime — with zero internet required.

---

## 🏗️ Architecture Overview

GramSetu 2.0 features a dual-layer architecture backed by a lightweight server:

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           GramSetu 2.0 Rural Ecosystem                          │
├──────────────────────────────────────┬──────────────────────────────────────────┤
│    Native Flutter / Android App      │       Web PWA / Browser Companion        │
│          (gramsetu_mobile/)          │             (gramsetu/frontend/)         │
├──────────────────────────────────────┼──────────────────────────────────────────┤
│ • On-device SQLite (sqflite WAL)     │ • IndexedDB (gramsetu-vault-v2)          │
│ • Native BLE Advertising & Discovery │ • Service Worker Cache v6                │
│ • Direct RFCOMM Socket Transfer      │ • Web Share / JSON Backup Export         │
│ • Mode C Store-and-Forward Mesh      │ • REST Background Sync with Backend      │
│ • Multi-Channel SOS Rapid Countdown  │ • Responsive Rural Touch UI (WCAG AAA)   │
│ • Bilingual (English & தமிழ்)        │ • Bilingual (English, தமிழ், हिन्दी)     │
└──────────────────────────────────────┴──────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    FastAPI + SQLite WAL Backend (gramsetu/backend/)             │
├─────────────────────────────────────────────────────────────────────────────────┤
│ • /api/vault/resources — HTTP ETag / 304 Not Modified incremental cache syncing │
│ • /api/announcements — Broadcast panchayat circulars and seasonal warnings     │
│ • /api/messages/send, inbox, ack — Internet fallback messaging (Mode A)         │
│ • /api/sos, /api/sos/{id} — Multi-channel emergency triage & false alarm cancel │
│ • /api/sync — Idempotent batch sync for citizen problem reports and documents   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📡 Multi-Mode Transport Matrix

GramSetu 2.0 routes messages and requests through three dynamic transport tiers:

| Feature / Mode | Mode A: Internet Available | Mode B: Zero-Internet Nearby (P2P) | Mode C: Community Relay (Mesh) |
|---|---|---|---|
| **Underlying Radio** | Cellular 4G/5G, Wi-Fi | Bluetooth LE Discovery + RFCOMM | BLE / Wi-Fi Direct Peer-to-Peer |
| **Backend Sync** | Direct FastAPI REST calls | Not available | Synced when any relay peer hits internet |
| **Emergency Calling** | Device dialer (`tel:112`, `tel:108`) | Device dialer (`tel:`) | Device dialer (`tel:`) |
| **Peer Messaging** | Central server delivery | Direct device-to-device transfer | Multi-hop store-and-forward |
| **SOS Broadcasting** | Central triage + server alert | Local BLE beacon broadcast | Hop-limited community relay |
| **Hop Limit & TTL** | Direct (0 hops) | Single direct hop (1 hop) | Configurable max hops (1–5), 24h TTL |
| **Truthful Status** | `"transmitted_server"` | `"delivered_device"` | `"relayed"` (Hop X of Y) |

> [!IMPORTANT]
> **Truth in Technology Policy**: GramSetu 2.0 never fabricates delivery receipts or claims emergency dispatch when data is stored locally. Records remain labeled `"saved_locally"` until positively confirmed by network ack or nearby RFCOMM delivery.

---

## 📱 Modules & Core Capabilities

### 1. Spotify-Inspired Offline Vault
* **Pre-cached Village Resources**: Emergency First Aid, Village Health Centres & Directory, Crop Care & Pest Advisory, and Government Welfare Schemes.
* **Persistent Storage**: Survives device reboots, airplane mode, and app updates.
* **Incremental Synchronization**: Uses `ETag` / `If-None-Match` caching so users only download bytes when guides are updated.

### 2. My Village Contacts Directory
* **Categorized Directory**: Neighbours, Health Workers (ASHA/ANM/Doctors), Farmers, Family, and Emergency.
* **Priority 1 Emergency Contacts**: Pinned to the top of the contacts list and embedded in the Emergency SOS trigger screen.
* **One-Tap Calling**: Direct dialer invocation via `tel:` with automated number sanitization.
* **Instant Offline Search**: Multi-field matching across contact name, phone, and location notes.

### 3. Nearby Connect (Zero-Internet Communication)
* **Native Android BLE Advertiser**: Custom Service UUID `0000FE28-0000-1000-8000-00805F9B34FB` broadcasting device ID and signal strength (RSSI).
* **BLE Continuous Scanner**: Discovers active nearby villagers within radio range without cellular data or SIM cards.
* **Mode C Store-and-Forward Mesh**: Deduplication cache prevents broadcast storms; packets expire automatically after TTL.

### 4. Emergency SOS & Neighbour Assistance
* **Rapid 3-Second Trigger**: Large emergency button with live countdown and one-tap cancellation to prevent false alarms.
* **Manual Location Description Fallback**: Enables clear dispatch in rural hamlets without reliable GPS satellites (e.g. *"Near North Hamlet temple water tank"*).
* **Bilingual SMS & Share Templates**: Instant English and Tamil dispatches for village elders.
* **Direct Emergency Lines**: One-tap dialing for National Emergency (`112`), Medical Ambulance (`108`), and Mother-Child Ambulance (`102`).

### 5. Healthcare & Farmer Support
* **Healthcare Directory**: Detailed schedules and services for Sub-Centres, PHCs, and CHCs.
* **Crop Care & Pest Management**: Organic pest control, seasonal Kharif/Rabi advisories, and PM-KISAN support.
* **Toll-Free Helplines**: Direct one-tap access to Kisan Call Centre (`1800-180-1551`).

---

## 🌐 Deploy to Render (Cloud Hosting)

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/mahalakshmidrv/GramSetu)

GramSetu 2.0 can be deployed instantly to **Render**:
1. Go to [Render Dashboard](https://dashboard.render.com) → **New +** → **Blueprint**.
2. Connect `https://github.com/mahalakshmidrv/GramSetu` (branch `main`).
3. Render automatically picks up [`render.yaml`](render.yaml) and provisions the web service.
4. Detailed guide: [`docs/RENDER_DEPLOYMENT.md`](docs/RENDER_DEPLOYMENT.md).

---

## 🚀 How to Run Locally

### Prerequisites
* **Python**: 3.10+ (tested on Python 3.14)
* **Flutter SDK**: 3.27+ (tested on Flutter 3.44.6, Dart 3.12.2)
* **Android SDK**: API 34+ (compileSdkVersion 36, minSdkVersion 21)

---

### A. Run Backend Server (FastAPI)

```powershell
# In d:\Mahalakshmi\Gramsetu\gramsetu
.\venv\Scripts\activate
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

* **Web Application**: Open [http://localhost:8000](http://localhost:8000)
* **Interactive OpenAPI Docs**: [http://localhost:8000/docs](http://localhost:8000/docs)
* **Run Backend Test Suite**:
  ```powershell
  .\venv\Scripts\python -m unittest discover tests
  # Ran 12 tests in 0.87s — OK (100% pass)
  ```

---

### B. Run Flutter Android Mobile App

```powershell
# In d:\Mahalakshmi\Gramsetu\gramsetu_mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

* To target a physical device:
  ```powershell
  flutter run -d <device-id>
  ```

---

## 📲 Two-Phone Android Testing Guide

Follow these steps to demonstrate real-world zero-internet peer discovery and messaging:

1. **Install GramSetu APK on Phone A and Phone B**:
   ```powershell
   flutter build apk --debug
   adb -s <phone-A-serial> install build/app/outputs/flutter-apk/app-debug.apk
   adb -s <phone-B-serial> install build/app/outputs/flutter-apk/app-debug.apk
   ```

2. **Simulate Total Grid Outage**:
   - Turn **ON Airplane Mode** on both phones.
   - Manually turn **ON Bluetooth** and **Location** (required by Android for BLE beacon scanning).

3. **Start Advertising on Phone A**:
   - Open GramSetu 2.0 → Tap **Nearby Connect (P2P)** tab.
   - Toggle **"Advertise Device Presence"** to ON. Phone A is now broadcasting its presence.

4. **Discover Peer on Phone B**:
   - Open GramSetu 2.0 on Phone B → Tap **Nearby Connect (P2P)**.
   - Tap **"Scan for Nearby Devices"**.
   - Phone A will appear in Phone B's Discovered Peers list with its unique ID and real-time RSSI signal bar.

5. **Send Direct Offline Message**:
   - On Phone B, tap **"Send Message"** on Phone A's tile.
   - Enter a message (e.g., *"Need tractor assistance at East plot"*).
   - Tap **"Save to Outbox & Send"**.
   - Notice the status immediately updates to `"delivered_device"` once acknowledged.

6. **Trigger Emergency SOS**:
   - On Phone A, tap **Emergency SOS**.
   - Press the SOS button; observe the 3-second countdown.
   - The alert is recorded in the local SQLite vault as `"saved_locally"` with GPS and landmark note, and broadcast over BLE.

7. **Reconnection & Mode A Sync**:
   - Turn Airplane Mode OFF on Phone A and connect to Wi-Fi.
   - Open **Sync & Settings** → Tap **"Sync Now"**.
   - The outbox messages and SOS alerts are uploaded to the FastAPI backend, and status shifts to `"transmitted_server"`.

---

## 🧪 Verification & Test Results

| Test Category | Suite / File | Tests | Status |
|---|---|---|---|
| **Backend API & Migrations** | `gramsetu/tests/test_backend.py` | 7 tests | ✅ 100% Passed (0.52s) |
| **Offline Vault & Protocols** | `gramsetu/tests/test_offline_vault.py` | 5 tests | ✅ 100% Passed (0.35s) |
| **Flutter Models & Serializers** | `gramsetu_mobile/test/models_test.dart` | 4 tests | ✅ 100% Passed (0.05s) |
| **Transport & Hop/TTL Logic** | `gramsetu_mobile/test/transport_test.dart` | 3 tests | ✅ 100% Passed (0.04s) |
| **Bilingual UI Smoke Tests** | `gramsetu_mobile/test/widget_test.dart` | 3 tests | ✅ 100% Passed (1.20s) |
| **Static Code Analysis** | `flutter analyze` | 0 issues | ✅ Clean (0 errors, 0 warnings) |

---

## 👥 Contributors & Rural Impact
GramSetu 2.0 is developed as a production-minded digital public infrastructure project adhering to WCAG AAA accessibility, open web standards, and decentralized village resilience.
