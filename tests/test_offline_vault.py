"""Protocol, encryption, store-and-forward relay, and conflict resolution tests for GramSetu Offline Vault."""
import base64
import hashlib
import hmac
import json
import os
import time
import unittest

def mock_encrypt(plaintext: str, key: bytes) -> dict:
    """Simulates authenticated AES-GCM envelope using HMAC-SHA256 for integrity and XOR keystream."""
    iv = os.urandom(12)
    # Generate keystream from key + iv
    h = hashlib.sha256(key + iv).digest()
    while len(h) < len(plaintext.encode()):
        h += hashlib.sha256(h + key).digest()
    raw = plaintext.encode("utf-8")
    cipher = bytes(b ^ h[i] for i, b in enumerate(raw))
    tag = hmac.new(key, iv + cipher, hashlib.sha256).digest()[:16]
    return {
        "iv": base64.b64encode(iv).decode(),
        "cipher": base64.b64encode(cipher).decode(),
        "tag": base64.b64encode(tag).decode()
    }

def mock_decrypt(encrypted: dict, key: bytes) -> str:
    iv = base64.b64decode(encrypted["iv"])
    cipher = base64.b64decode(encrypted["cipher"])
    tag = base64.b64decode(encrypted["tag"])
    expected_tag = hmac.new(key, iv + cipher, hashlib.sha256).digest()[:16]
    if not hmac.compare_digest(tag, expected_tag):
        raise ValueError("Authentication tag mismatch: data corrupted or tampered")
    h = hashlib.sha256(key + iv).digest()
    while len(h) < len(cipher):
        h += hashlib.sha256(h + key).digest()
    decrypted = bytes(b ^ h[i] for i, b in enumerate(cipher))
    return decrypted.decode("utf-8")

class RelayEngine:
    """Store-and-forward relay engine with hop limits, TTL, and deduplication."""
    def __init__(self, device_id: str, max_hops: int = 3, allow_relay: bool = True):
        self.device_id = device_id
        self.max_hops = max_hops
        self.allow_relay = allow_relay
        self.seen_messages = set()
        self.relay_store = {} # message_id -> packet

    def receive_packet(self, packet: dict) -> str:
        """Processes an incoming packet. Returns: 'delivered', 'relayed', 'dropped_seen', 'dropped_expired', 'dropped_hops', 'dropped_no_relay'."""
        mid = packet.get("id")
        if not mid:
            return "invalid"

        # Check deduplication
        if mid in self.seen_messages:
            return "dropped_seen"
        self.seen_messages.add(mid)

        # Check TTL
        now = int(time.time())
        created_at = packet.get("timestamp", 0)
        ttl = packet.get("ttl", 86400)
        if now > (created_at + ttl):
            return "dropped_expired"

        # If addressed to this device
        if packet.get("recipient_id") == self.device_id or packet.get("recipient_id") == "broadcast":
            return "delivered"

        # Store-and-forward check
        if not self.allow_relay:
            return "dropped_no_relay"

        hop_count = packet.get("hop_count", 0) + 1
        if hop_count >= packet.get("max_hops", self.max_hops):
            return "dropped_hops"

        # Clone and increment hop count for forwarding
        forward_packet = dict(packet)
        forward_packet["hop_count"] = hop_count
        self.relay_store[mid] = forward_packet
        return "relayed"

def resolve_lww(local_record: dict, incoming_record: dict) -> dict:
    """Last-Write-Wins (LWW) conflict resolver for contacts and offline notes."""
    local_ts = local_record.get("updated_at", local_record.get("created_at", 0))
    incoming_ts = incoming_record.get("updated_at", incoming_record.get("created_at", 0))
    if incoming_ts >= local_ts:
        return incoming_record
    return local_record

class TestOfflineVaultProtocol(unittest.TestCase):
    def test_01_authenticated_encryption(self):
        key = hashlib.sha256(b"village-shared-passphrase").digest()
        secret_msg = "Urgent: Well pump #3 in North Sector is repaired."
        
        # Encrypt
        encrypted = mock_encrypt(secret_msg, key)
        self.assertIn("iv", encrypted)
        self.assertIn("cipher", encrypted)
        self.assertIn("tag", encrypted)

        # Decrypt
        decrypted = mock_decrypt(encrypted, key)
        self.assertEqual(decrypted, secret_msg)

        # Tampering detection
        tampered = dict(encrypted)
        tampered["tag"] = base64.b64encode(os.urandom(16)).decode()
        with self.assertRaises(ValueError):
            mock_decrypt(tampered, key)

    def test_02_store_and_forward_relay(self):
        device_a = "farmer-phone-A"
        device_b = "neighbour-phone-B"
        device_c = "doctor-phone-C"

        relay_b = RelayEngine(device_id=device_b, max_hops=3, allow_relay=True)

        packet = {
            "id": "pkt-uuid-001",
            "sender_id": device_a,
            "recipient_id": device_c,
            "timestamp": int(time.time()),
            "ttl": 3600,
            "hop_count": 0,
            "max_hops": 3,
            "payload": "Encrypted emergency message"
        }

        # Device B receives packet intended for Device C -> relays it
        res = relay_b.receive_packet(packet)
        self.assertEqual(res, "relayed")
        self.assertIn("pkt-uuid-001", relay_b.relay_store)
        self.assertEqual(relay_b.relay_store["pkt-uuid-001"]["hop_count"], 1)

        # Device B receives duplicate -> dropped_seen
        res_dup = relay_b.receive_packet(packet)
        self.assertEqual(res_dup, "dropped_seen")

    def test_03_relay_hop_limits(self):
        relay = RelayEngine(device_id="node-x", max_hops=2, allow_relay=True)
        exhausted_packet = {
            "id": "pkt-uuid-002",
            "sender_id": "node-1",
            "recipient_id": "node-target",
            "timestamp": int(time.time()),
            "ttl": 3600,
            "hop_count": 2, # Already reached max_hops 2
            "max_hops": 2,
            "payload": "Data"
        }
        res = relay.receive_packet(exhausted_packet)
        self.assertEqual(res, "dropped_hops")

    def test_04_relay_ttl_expiry(self):
        relay = RelayEngine(device_id="node-y", max_hops=3, allow_relay=True)
        expired_packet = {
            "id": "pkt-uuid-003",
            "sender_id": "node-1",
            "recipient_id": "node-target",
            "timestamp": int(time.time()) - 10000, # 10000 seconds ago
            "ttl": 3600, # Expired after 1 hour
            "hop_count": 0,
            "max_hops": 3,
            "payload": "Expired alert"
        }
        res = relay.receive_packet(expired_packet)
        self.assertEqual(res, "dropped_expired")

    def test_05_conflict_resolution_lww(self):
        contact_v1 = {"id": "c-101", "name": "Dr. Ananya", "phone": "9876543210", "updated_at": 100}
        contact_v2 = {"id": "c-101", "name": "Dr. Ananya (PHC Lead)", "phone": "9876543210", "updated_at": 200}

        resolved = resolve_lww(contact_v1, contact_v2)
        self.assertEqual(resolved["name"], "Dr. Ananya (PHC Lead)")

        # Local newer should win
        resolved_local = resolve_lww(contact_v2, contact_v1)
        self.assertEqual(resolved_local["name"], "Dr. Ananya (PHC Lead)")

if __name__ == "__main__":
    unittest.main()
