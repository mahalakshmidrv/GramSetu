"""Unit and integration tests for GramSetu 2.0 backend."""
import os
import unittest
from fastapi.testclient import TestClient

# Use temporary database file for tests
TEST_DB = os.path.join(os.path.dirname(__file__), "test_gramsetu.db")
if os.path.exists(TEST_DB):
    try: os.remove(TEST_DB)
    except Exception: pass
os.environ["GRAMSETU_DB"] = TEST_DB
os.environ["GRAMSETU_ADMIN_USER"] = "testadmin"
os.environ["GRAMSETU_ADMIN_PASSWORD"] = "testadminpassword123"
from backend.main import app, init_db, seed_staff, seed_vault

class TestGramSetuBackend(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        init_db()
        seed_staff()
        seed_vault()
        cls.client = TestClient(app)

    @classmethod
    def tearDownClass(cls):
        if os.path.exists(TEST_DB):
            try: os.remove(TEST_DB)
            except Exception: pass

    def test_01_health_and_schemes(self):
        res = self.client.get("/api/health")
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.json()["ok"])

        res = self.client.get("/api/schemes")
        self.assertEqual(res.status_code, 200)
        schemes = res.json()
        self.assertGreaterEqual(len(schemes), 5)
        self.assertTrue(any(s["id"] == "pmkisan" for s in schemes))

    def test_02_vault_resources(self):
        res = self.client.get("/api/vault/resources")
        self.assertEqual(res.status_code, 200)
        self.assertIn("etag", res.headers)
        resources = res.json()
        self.assertGreaterEqual(len(resources), 4)
        keys = [r["key"] for r in resources]
        self.assertIn("first-aid", keys)
        self.assertIn("health-centres", keys)
        self.assertIn("crop-care", keys)

        # Test If-None-Match ETag caching
        etag = res.headers["etag"]
        res_cached = self.client.get("/api/vault/resources", headers={"If-None-Match": etag})
        self.assertEqual(res_cached.status_code, 304)

    def test_03_announcements(self):
        res = self.client.get("/api/announcements")
        self.assertEqual(res.status_code, 200)
        anns = res.json()
        self.assertGreaterEqual(len(anns), 3)

    def test_04_user_registration_and_login(self):
        # Register new citizen
        user_payload = {
            "username": "farmer_ramesh",
            "password": "strongPassword123",
            "name": "Ramesh Kumar",
            "village": "Rampur"
        }
        res = self.client.post("/api/auth/register", json=user_payload)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("token", data)
        self.assertEqual(data["user"]["username"], "farmer_ramesh")
        self.assertEqual(data["user"]["role"], "CITIZEN")

        # Login with correct credentials
        res_login = self.client.post("/api/auth/login", json={"username": "farmer_ramesh", "password": "strongPassword123"})
        self.assertEqual(res_login.status_code, 200)
        token = res_login.json()["token"]

        # Verify /api/auth/me
        res_me = self.client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(res_me.status_code, 200)
        self.assertEqual(res_me.json()["name"], "Ramesh Kumar")

        # Reject bad password
        res_bad = self.client.post("/api/auth/login", json={"username": "farmer_ramesh", "password": "wrongPassword"})
        self.assertEqual(res_bad.status_code, 401)

    def test_05_sync_idempotency_and_duplicates(self):
        # Register a second user to test sync
        token_res = self.client.post("/api/auth/register", json={
            "username": "sarpanch_sita",
            "password": "sitaPassword123",
            "name": "Sita Devi",
            "village": "Rampur"
        })
        token = token_res.json()["token"]

        req_id = "test-req-uuid-1001"
        sync_payload = {
            "requests": [
                {
                    "id": req_id,
                    "name": "Sita Devi",
                    "village": "Rampur",
                    "category": "water",
                    "type": "general",
                    "text": "Hand pump near community hall needs repair.",
                    "lang": "en",
                    "created_at": 1729000000000,
                    "details": {}
                }
            ]
        }

        # First sync attempt -> created
        res1 = self.client.post("/api/sync", json=sync_payload, headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(res1.status_code, 200)
        data1 = res1.json()
        self.assertIn(req_id, data1["synced"])
        self.assertEqual(data1["results"][0]["status"], "created")

        # Second sync attempt with identical client_request_id -> duplicate ignored safely
        res2 = self.client.post("/api/sync", json=sync_payload, headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(res2.status_code, 200)
        data2 = res2.json()
        self.assertIn(req_id, data2["synced"])
        self.assertEqual(data2["results"][0]["status"], "duplicate")

    def test_06_offline_messages_mode_a(self):
        # Sender: Ramesh
        login1 = self.client.post("/api/auth/login", json={"username": "farmer_ramesh", "password": "strongPassword123"})
        token1 = login1.json()["token"]
        ramesh_id = login1.json()["user"]["id"]

        # Recipient: Sita
        login2 = self.client.post("/api/auth/login", json={"username": "sarpanch_sita", "password": "sitaPassword123"})
        token2 = login2.json()["token"]

        msg_id = "msg-offline-101"
        msg_payload = {
            "id": msg_id,
            "recipient_id": "sarpanch_sita",
            "recipient_name": "Sita Devi",
            "body": "Namaste Sarpanch ji, when is the next Gram Sabha?",
            "transport": "backend",
            "created_at": 1729000100000
        }

        # Send message
        res_send = self.client.post("/api/messages/send", json=msg_payload, headers={"Authorization": f"Bearer {token1}"})
        self.assertEqual(res_send.status_code, 200)
        self.assertEqual(res_send.json()["status"], "sent")

        # Duplicate send should report duplicate
        res_dup = self.client.post("/api/messages/send", json=msg_payload, headers={"Authorization": f"Bearer {token1}"})
        self.assertEqual(res_dup.status_code, 200)
        self.assertEqual(res_dup.json()["status"], "duplicate")

        # Sita checks inbox
        res_inbox = self.client.get("/api/messages/inbox", headers={"Authorization": f"Bearer {token2}"})
        self.assertEqual(res_inbox.status_code, 200)
        inbox = res_inbox.json()
        self.assertTrue(any(m["id"] == msg_id for m in inbox))

        # Acknowledge message
        res_ack = self.client.post("/api/messages/ack", json={"message_id": msg_id, "status": "acknowledged"}, headers={"Authorization": f"Bearer {token2}"})
        self.assertEqual(res_ack.status_code, 200)
        self.assertTrue(res_ack.json()["ok"])

    def test_07_emergency_sos_flow(self):
        sos_id = "sos-alert-9999"
        sos_payload = {
            "id": sos_id,
            "name": "Ramesh Kumar",
            "village": "Rampur",
            "phone": "+919876543210",
            "latitude": 13.0827,
            "longitude": 80.2707,
            "location_note": "Near North Canal Gate",
            "text": "Medical emergency, fever and unconsciousness",
            "lang": "ta",
            "created_at": 1729000200000
        }

        # Submit SOS
        res = self.client.post("/api/sos", json=sos_payload)
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.json()["status"], "created")

        # Duplicate SOS safely recognized
        res_dup = self.client.post("/api/sos", json=sos_payload)
        self.assertEqual(res_dup.status_code, 200)
        self.assertEqual(res_dup.json()["status"], "duplicate")

        # False alarm cancellation
        res_cancel = self.client.patch(f"/api/sos/{sos_id}", json={"status": "Cancelled", "note": "False alarm, patient recovered"})
        self.assertEqual(res_cancel.status_code, 200)
        self.assertEqual(res_cancel.json()["status"], "Cancelled")

if __name__ == "__main__":
    unittest.main()
