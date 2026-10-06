"""GramSetu backend: FastAPI + SQLite. Serves the PWA and a small REST API.

Security notes: passwords are PBKDF2-hashed, sessions are random tokens (only their hash is stored),
every protected route checks the role on the server, uploads live outside the static folder.
"""
import base64, binascii, hashlib, hmac, json, logging, os, re, secrets, sqlite3, time
from contextlib import contextmanager
from pathlib import Path
from typing import List, Optional

from fastapi import Depends, FastAPI, Header, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, ValidationError

BASE = Path(__file__).resolve().parent
DB = Path(os.environ.get("GRAMSETU_DB", BASE / "gramsetu.db"))
UPLOADS = Path(os.environ.get("GRAMSETU_UPLOADS", BASE / "uploads"))
UPLOADS.mkdir(parents=True, exist_ok=True)
MAX_FILE = int(os.environ.get("GRAMSETU_MAX_FILE_BYTES", 2 * 1024 * 1024))
MAX_BODY = int(MAX_FILE * 1.4) + 8192          # base64 overhead + JSON
SESSION_MS = 7 * 24 * 3600 * 1000
log = logging.getLogger("gramsetu")
now_ms = lambda: int(time.time() * 1000)

STATUSES = ("Received", "In Progress", "Completed", "Rejected")
OPEN_STATUSES = ("Received", "In Progress")
DOC_STATUSES = ("Received", "Verified", "Rejected")
TYPES = ("general", "healthcare", "agriculture", "government", "sos")
CATEGORIES = ("water", "health", "farming", "road", "electricity", "pension", "job", "other")
TYPE_BY_CAT = {"health": "healthcare", "farming": "agriculture"}
ROLES = ("CITIZEN", "OFFICER", "ADMIN")
ID_RE = r"^[A-Za-z0-9_-]{8,64}$"

app = FastAPI(title="GramSetu API")
if os.environ.get("GRAMSETU_CORS_ORIGINS"):       # same-origin by default; set a comma list to allow others
    from fastapi.middleware.cors import CORSMiddleware
    app.add_middleware(CORSMiddleware, allow_origins=[o.strip() for o in os.environ["GRAMSETU_CORS_ORIGINS"].split(",") if o.strip()],
                       allow_methods=["GET", "POST", "PATCH"], allow_headers=["Authorization", "Content-Type"])

# ---------------------------------------------------------------- database
@contextmanager
def db():
    c = sqlite3.connect(DB, timeout=10)
    c.row_factory = sqlite3.Row
    c.execute("PRAGMA foreign_keys=ON")
    try:
        yield c
        c.commit()
    except Exception:
        c.rollback()
        raise
    finally:
        c.close()

def add_col(c, table, col, ddl):
    if col not in [r["name"] for r in c.execute(f"PRAGMA table_info({table})")]:
        c.execute(f"ALTER TABLE {table} ADD COLUMN {col} {ddl}")

def init_db():
    """Safe, additive migration: existing tables/rows are kept."""
    with db() as c:
        c.execute("PRAGMA journal_mode=WAL")
        c.execute("""CREATE TABLE IF NOT EXISTS users(
            id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT NOT NULL UNIQUE COLLATE NOCASE, name TEXT, village TEXT,
            pw_hash TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'CITIZEN' CHECK(role IN ('CITIZEN','OFFICER','ADMIN')),
            active INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL)""")
        c.execute("""CREATE TABLE IF NOT EXISTS sessions(
            token_hash TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL)""")
        c.execute("""CREATE TABLE IF NOT EXISTS requests(
            id TEXT PRIMARY KEY, name TEXT, village TEXT, category TEXT, text TEXT,
            lang TEXT, status TEXT DEFAULT 'Received', created_at INTEGER, synced_at INTEGER)""")
        add_col(c, "requests", "type", "TEXT")
        add_col(c, "requests", "details", "TEXT")
        add_col(c, "requests", "user_id", "INTEGER REFERENCES users(id)")
        add_col(c, "requests", "assigned_to", "INTEGER REFERENCES users(id)")
        add_col(c, "requests", "updated_at", "INTEGER")
        c.execute("""UPDATE requests SET type = CASE category WHEN 'health' THEN 'healthcare'
                     WHEN 'farming' THEN 'agriculture' ELSE 'government' END WHERE type IS NULL""")
        c.execute("""CREATE TABLE IF NOT EXISTS documents(
            id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), category TEXT, filename TEXT NOT NULL,
            mime TEXT NOT NULL, size INTEGER NOT NULL, sha256 TEXT NOT NULL, stored_name TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'Received', created_at INTEGER, synced_at INTEGER NOT NULL,
            UNIQUE(user_id, sha256))""")
        c.execute("""CREATE TABLE IF NOT EXISTS sync_history(
            id INTEGER PRIMARY KEY AUTOINCREMENT, at INTEGER NOT NULL, user_id INTEGER REFERENCES users(id),
            received INTEGER, created INTEGER, duplicates INTEGER, rejected INTEGER)""")
        for ddl in ("CREATE INDEX IF NOT EXISTS ix_req_status ON requests(status)",
                    "CREATE INDEX IF NOT EXISTS ix_req_type ON requests(type)",
                    "CREATE INDEX IF NOT EXISTS ix_req_user ON requests(user_id)",
                    "CREATE INDEX IF NOT EXISTS ix_req_created ON requests(created_at)",
                    "CREATE INDEX IF NOT EXISTS ix_req_assigned ON requests(assigned_to)",
                    "CREATE INDEX IF NOT EXISTS ix_doc_user ON documents(user_id)",
                    "CREATE INDEX IF NOT EXISTS ix_sess_exp ON sessions(expires_at)"):
            c.execute(ddl)

# ---------------------------------------------------------------- passwords / sessions
def hash_pw(pw: str, iters: int = 210_000) -> str:
    salt = secrets.token_bytes(16)
    dk = hashlib.pbkdf2_hmac("sha256", pw.encode(), salt, iters)
    return f"pbkdf2_sha256${iters}${salt.hex()}${dk.hex()}"

def check_pw(pw: str, stored: str) -> bool:
    try:
        _, it, salt, h = stored.split("$")
        dk = hashlib.pbkdf2_hmac("sha256", pw.encode(), bytes.fromhex(salt), int(it))
        return hmac.compare_digest(dk.hex(), h)
    except Exception:
        return False

def sha(s: str) -> str:
    return hashlib.sha256(s.encode()).hexdigest()

def create_user(c, username, password, role, name="", village=""):
    c.execute("INSERT INTO users(username,name,village,pw_hash,role,created_at) VALUES(?,?,?,?,?,?)",
              (username, name, village, hash_pw(password), role, now_ms()))

def seed_staff():
    """First start: create an ADMIN. Credentials come from env vars; never hard-coded in source."""
    with db() as c:
        if not c.execute("SELECT 1 FROM users WHERE role='ADMIN' AND active=1").fetchone():
            user = os.environ.get("GRAMSETU_ADMIN_USER", "admin")
            pw = os.environ.get("GRAMSETU_ADMIN_PASSWORD")
            generated = not pw
            pw = pw or secrets.token_urlsafe(10)
            while c.execute("SELECT 1 FROM users WHERE username=?", (user,)).fetchone():
                user += "-" + secrets.token_hex(2)
            create_user(c, user, pw, "ADMIN", "Administrator")
            print(f"[GramSetu] Admin account created: username={user}" + (f" password={pw}  (shown once - save it)" if generated else ""))
        ou, op = os.environ.get("GRAMSETU_OFFICER_USER"), os.environ.get("GRAMSETU_OFFICER_PASSWORD")
        if ou and op and not c.execute("SELECT 1 FROM users WHERE username=?", (ou,)).fetchone():
            create_user(c, ou, op, "OFFICER", "Officer")
            print(f"[GramSetu] Officer account created: username={ou}")

init_db()
seed_staff()
_DUMMY = hash_pw("dummy-password")

# ---------------------------------------------------------------- rate limit (in memory, per IP)
_hits = {}
def limiter(name: str, limit: int, window: int):
    def dep(request: Request):
        key, t = (name, request.client.host if request.client else "?"), time.time()
        hits = [x for x in _hits.get(key, []) if t - x < window]
        if len(hits) >= limit:
            raise HTTPException(429, "rate_limited")
        hits.append(t)
        _hits[key] = hits
        if len(_hits) > 5000:
            _hits.clear()
    return dep

# ---------------------------------------------------------------- auth dependencies
def current_user(authorization: Optional[str] = Header(None)):
    if not authorization or not authorization.lower().startswith("bearer "):
        return None
    with db() as c:
        row = c.execute("""SELECT u.id,u.username,u.name,u.village,u.role FROM sessions s JOIN users u ON u.id=s.user_id
                           WHERE s.token_hash=? AND s.expires_at>? AND u.active=1""",
                        (sha(authorization[7:].strip()), now_ms())).fetchone()
    return dict(row) if row else None

def require_user(u=Depends(current_user)):
    if not u:
        raise HTTPException(401, "login_required")
    return u

def require_roles(*roles):
    def dep(u=Depends(require_user)):
        if u["role"] not in roles:
            raise HTTPException(403, "forbidden")
        return u
    return dep

staff = require_roles("OFFICER", "ADMIN")
admin_only = require_roles("ADMIN")

# ---------------------------------------------------------------- middleware / errors
@app.middleware("http")
async def guard(request: Request, call_next):
    cl = request.headers.get("content-length")
    if cl and cl.isdigit() and int(cl) > MAX_BODY:
        return JSONResponse({"detail": "file_too_large"}, status_code=413)
    try:
        resp = await call_next(request)
    except Exception:
        log.exception("unhandled error")
        return JSONResponse({"detail": "server_error"}, status_code=500)
    resp.headers["X-Content-Type-Options"] = "nosniff"
    resp.headers["Referrer-Policy"] = "same-origin"
    resp.headers["X-Frame-Options"] = "DENY"
    if request.url.path.startswith("/api/") and request.url.path != "/api/schemes":
        resp.headers["Cache-Control"] = "no-store"
    return resp

@app.exception_handler(RequestValidationError)
async def bad_input(request, exc):
    return JSONResponse({"detail": "validation"}, status_code=422)

# ---------------------------------------------------------------- public data (unchanged idea, more schemes)
KEYWORDS = {
    "water": ["water", "tap", "well", "borewell", "पानी", "नल", "कुआं", "தண்ணீர்", "குடிநீர்", "கிணறு"],
    "health": ["health", "doctor", "hospital", "medicine", "fever", "स्वास्थ्य", "डॉक्टर", "अस्पताल", "दवा", "மருத்துவ", "மருந்து", "காய்ச்சல்"],
    "farming": ["farm", "crop", "seed", "fertilizer", "kisan", "खेत", "फसल", "बीज", "किसान", "விவசாய", "பயிர்", "விதை"],
    "road": ["road", "bridge", "pothole", "bus", "सड़क", "पुल", "बस", "சாலை", "பாலம்"],
    "electricity": ["electric", "power", "light", "current", "बिजली", "मीटर", "மின்சாரம்", "மின்"],
    "pension": ["pension", "widow", "old age", "पेंशन", "विधवा", "ஓய்வூதியம்", "முதியோர்"],
    "job": ["job", "work", "wage", "mgnrega", "रोजगार", "काम", "मजदूरी", "வேலை", "கூலி"],
}
def S(id, cat, en, hi, ta, den, dhi, dta):
    return {"id": id, "cat": cat, "name": {"en": en, "hi": hi, "ta": ta}, "desc": {"en": den, "hi": dhi, "ta": dta}}
SCHEMES = [
    S("pmkisan", "farming", "PM-KISAN", "पीएम-किसान", "பிஎம்-கிசான்", "Rs 6,000 a year income support for farmer families.", "किसान परिवारों को सालाना 6,000 रुपये की सहायता।", "விவசாய குடும்பங்களுக்கு ஆண்டுக்கு ரூ.6,000 உதவி."),
    S("pmjay", "health", "Ayushman Bharat", "आयुष्मान भारत", "ஆயுஷ்மான் பாரத்", "Health cover up to Rs 5 lakh per family per year.", "प्रति परिवार सालाना 5 लाख रुपये तक का स्वास्थ्य बीमा।", "குடும்பத்திற்கு ஆண்டுக்கு ரூ.5 லட்சம் வரை மருத்துவ காப்பீடு."),
    S("mgnrega", "job", "MGNREGA", "मनरेगा", "மகாத்மா காந்தி வேலை உறுதி", "100 days of guaranteed wage work for rural households.", "ग्रामीण परिवारों को 100 दिन का रोजगार।", "கிராம குடும்பங்களுக்கு 100 நாள் வேலை உறுதி."),
    S("jjm", "water", "Jal Jeevan Mission", "जल जीवन मिशन", "ஜல் ஜீவன் மிஷன்", "Tap water connection for every rural home.", "हर ग्रामीण घर में नल से जल।", "ஒவ்வொரு கிராம வீட்டிற்கும் குழாய் குடிநீர்."),
    S("nsap", "pension", "NSAP Pension", "राष्ट्रीय पेंशन योजना", "தேசிய ஓய்வூதியத் திட்டம்", "Monthly pension for the elderly, widows and disabled.", "बुजुर्गों, विधवाओं और दिव्यांगों को मासिक पेंशन।", "முதியோர், விதவைகள், மாற்றுத்திறனாளிகளுக்கு மாத ஓய்வூதியம்."),
    S("jsy", "health", "Janani Suraksha Yojana", "जननी सुरक्षा योजना", "ஜனனி சுரக்ஷா யோஜனா", "Cash support for mothers who deliver in a government or accredited health facility.", "सरकारी या मान्यता प्राप्त स्वास्थ्य केंद्र में प्रसव कराने वाली माताओं को नकद सहायता।", "அரசு அல்லது அங்கீகரிக்கப்பட்ட மருத்துவ மையத்தில் பிரசவிக்கும் தாய்மார்களுக்கு பண உதவி."),
    S("pmsma", "health", "Safe Motherhood Day (PMSMA)", "सुरक्षित मातृत्व अभियान", "பாதுகாப்பான தாய்மை திட்டம்", "Free check-up for pregnant women at government facilities on the 9th of every month.", "हर महीने की 9 तारीख को सरकारी केंद्रों पर गर्भवती महिलाओं की मुफ्त जांच।", "ஒவ்வொரு மாதமும் 9ஆம் தேதி அரசு மையங்களில் கர்ப்பிணிகளுக்கு இலவச பரிசோதனை."),
    S("indradhanush", "health", "Mission Indradhanush", "मिशन इंद्रधनुष", "மிஷன் இந்திரதனுஷ்", "Free vaccines for children and pregnant women against preventable diseases.", "बच्चों और गर्भवती महिलाओं के लिए रोकथाम योग्य बीमारियों के मुफ्त टीके।", "குழந்தைகள், கர்ப்பிணிகளுக்கு தடுக்கக்கூடிய நோய்களுக்கான இலவச தடுப்பூசிகள்."),
    S("pmfby", "farming", "Crop Insurance (PMFBY)", "फसल बीमा योजना", "பயிர் காப்பீட்டுத் திட்டம்", "Insurance against crop loss from natural calamities, pests and diseases.", "प्राकृतिक आपदा, कीट और रोग से फसल नुकसान का बीमा।", "இயற்கை பேரிடர், பூச்சி, நோயால் ஏற்படும் பயிர் இழப்புக்கு காப்பீடு."),
    S("kcc", "farming", "Kisan Credit Card", "किसान क्रेडिट कार्ड", "கிசான் கிரெடிட் கார்டு", "Affordable, timely credit for farming needs such as seed and fertilizer.", "बीज, खाद जैसी खेती की जरूरतों के लिए सस्ता और समय पर कर्ज।", "விதை, உரம் போன்ற விவசாயத் தேவைகளுக்கு குறைந்த வட்டியில் கடன்."),
    S("shc", "farming", "Soil Health Card", "मृदा स्वास्थ्य कार्ड", "மண் வள அட்டை", "Free soil test report with advice on the right fertilizer for your field.", "आपके खेत के लिए सही खाद की सलाह के साथ मुफ्त मिट्टी जांच रिपोर्ट।", "உங்கள் வயலுக்கு ஏற்ற உரப் பரிந்துரையுடன் இலவச மண் பரிசோதனை அறிக்கை."),
    S("enam", "farming", "e-NAM Market", "ई-नाम बाजार", "இ-நாம் சந்தை", "Online market to sell your produce to buyers in many mandis.", "कई मंडियों के खरीदारों को उपज बेचने का ऑनलाइन बाजार।", "பல மண்டிகளின் வாங்குபவர்களுக்கு விளைபொருளை விற்கும் ஆன்லைன் சந்தை."),
]

def classify(text: str) -> str:
    t = text.lower()
    scores = {k: sum(1 for w in ws if w in t) for k, ws in KEYWORDS.items()}
    best = max(scores, key=scores.get)
    return best if scores[best] else "other"

# ---------------------------------------------------------------- models
class Req(BaseModel):
    id: str = Field(pattern=ID_RE)
    name: str = Field("", max_length=100)
    village: str = Field("", max_length=100)
    category: str = "other"
    type: str = "general"
    text: str = Field(min_length=1, max_length=2000)
    lang: str = Field("en", pattern=r"^[a-z]{2}$")
    created_at: int = Field(gt=0)
    details: dict = {}

class SyncBody(BaseModel):
    requests: List[dict] = Field(max_length=50)

class RegisterBody(BaseModel):
    username: str = Field(pattern=r"^[A-Za-z0-9_.@-]{3,40}$")
    password: str = Field(min_length=8, max_length=128)
    name: str = Field(min_length=1, max_length=100)
    village: str = Field("", max_length=100)

class LoginBody(BaseModel):
    username: str = Field(max_length=40)
    password: str = Field(max_length=128)

class DocBody(BaseModel):
    id: str = Field(pattern=ID_RE)
    category: str = Field("other", max_length=30)
    filename: str = Field(min_length=1, max_length=200)
    mime: str = Field(max_length=100)
    data: str
    created_at: int = Field(gt=0)

class StatusBody(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[int] = None

class UserPatch(BaseModel):
    role: Optional[str] = None
    active: Optional[bool] = None

# ---------------------------------------------------------------- public routes
@app.get("/api/health")
def health():
    return {"ok": True, "time": now_ms()}

@app.get("/api/schemes")
def schemes():
    return SCHEMES

@app.post("/api/classify")
def api_classify(body: dict):
    cat = classify(str(body.get("text", ""))[:2000])
    return {"category": cat, "schemes": [s["id"] for s in SCHEMES if s["cat"] == cat]}

@app.get("/api/stats")
def stats():
    with db() as c:
        rows = c.execute("SELECT category, COUNT(*) n FROM requests GROUP BY category").fetchall()
        return {"total": sum(r["n"] for r in rows), "by_category": {r["category"]: r["n"] for r in rows}}

# ---------------------------------------------------------------- auth
def public_user(u):
    return {k: u[k] for k in ("id", "username", "name", "village", "role")}

@app.post("/api/auth/register", dependencies=[Depends(limiter("register", 10, 600))])
def register(b: RegisterBody):
    with db() as c:
        if c.execute("SELECT 1 FROM users WHERE username=?", (b.username,)).fetchone():
            raise HTTPException(409, "username_taken")
        create_user(c, b.username, b.password, "CITIZEN", b.name.strip(), b.village.strip())   # self-signup is always CITIZEN
    return _login(b.username, b.password)

def _login(username, password):
    with db() as c:
        row = c.execute("SELECT * FROM users WHERE username=? AND active=1", (username,)).fetchone()
        ok = check_pw(password, row["pw_hash"] if row else _DUMMY)
        if not row or not ok:
            raise HTTPException(401, "bad_credentials")
        tok = secrets.token_urlsafe(32)
        c.execute("DELETE FROM sessions WHERE expires_at<?", (now_ms(),))
        c.execute("INSERT INTO sessions(token_hash,user_id,created_at,expires_at) VALUES(?,?,?,?)",
                  (sha(tok), row["id"], now_ms(), now_ms() + SESSION_MS))
        return {"token": tok, "user": public_user(row)}

@app.post("/api/auth/login", dependencies=[Depends(limiter("login", 10, 300))])
def login(b: LoginBody):
    return _login(b.username, b.password)

@app.post("/api/auth/logout")
def logout(authorization: Optional[str] = Header(None)):
    if authorization and authorization.lower().startswith("bearer "):
        with db() as c:
            c.execute("DELETE FROM sessions WHERE token_hash=?", (sha(authorization[7:].strip()),))
    return {"ok": True}

@app.get("/api/auth/me")
def me(u=Depends(require_user)):
    return public_user(u)

# ---------------------------------------------------------------- sync (idempotent)
def clean_details(d: dict) -> str:
    s = json.dumps(d, ensure_ascii=False)
    if len(s) > 4000:
        raise ValueError("details too large")
    return s

@app.post("/api/sync", dependencies=[Depends(limiter("sync", 60, 60))])
def sync(body: SyncBody, user=Depends(current_user)):
    """Idempotent batch upload. The same client id is stored once, so retries/duplicates are safe.
    Works for anonymous users (rural reports / SOS); if the user is logged in the request is linked to them."""
    results, created, dups, rej = [], 0, 0, 0
    with db() as c:
        for raw in body.requests:
            rid = str(raw.get("id", ""))[:64] if isinstance(raw, dict) else ""
            try:
                r = Req(**raw)
                if r.category not in CATEGORIES or r.type not in TYPES:
                    raise ValueError("bad enum")
                details = clean_details(r.details)
            except (ValidationError, ValueError, TypeError):
                results.append({"id": rid, "status": "rejected", "error": "validation"}); rej += 1
                continue
            cat = r.category if r.category != "other" else classify(r.text)
            typ = r.type if r.type != "general" else TYPE_BY_CAT.get(cat, "government")
            cur = c.execute("""INSERT OR IGNORE INTO requests(id,name,village,category,text,lang,created_at,synced_at,type,details,user_id,updated_at)
                               VALUES(?,?,?,?,?,?,?,?,?,?,?,?)""",
                            (r.id, r.name, r.village, cat, r.text, r.lang, r.created_at, now_ms(), typ, details,
                             user["id"] if user else None, now_ms()))
            if cur.rowcount:
                created += 1; results.append({"id": r.id, "status": "created"})
            else:
                dups += 1; results.append({"id": r.id, "status": "duplicate"})
        c.execute("INSERT INTO sync_history(at,user_id,received,created,duplicates,rejected) VALUES(?,?,?,?,?,?)",
                  (now_ms(), user["id"] if user else None, len(body.requests), created, dups, rej))
    return {"synced": [x["id"] for x in results if x["status"] != "rejected"], "results": results}

@app.get("/api/requests")
def list_requests(ids: str = "", user=Depends(current_user)):
    """With ?ids=a,b : minimal status lookup by (unguessable) client id. Without ids: staff only."""
    wanted = [i for i in re.split(r"[,\s]+", ids) if re.match(ID_RE, i)][:100]
    with db() as c:
        if wanted:
            q = f"SELECT id,category,type,status,synced_at FROM requests WHERE id IN ({','.join('?' * len(wanted))})"
            return [dict(r) for r in c.execute(q, wanted)]
        if not user or user["role"] not in ("OFFICER", "ADMIN"):
            raise HTTPException(403, "forbidden")
        return [dict(r) for r in c.execute("SELECT id,name,village,category,type,text,status,created_at,synced_at FROM requests ORDER BY created_at DESC LIMIT 100")]

@app.get("/api/my/requests")
def my_requests(u=Depends(require_user)):
    with db() as c:
        return [dict(r) for r in c.execute("SELECT id,category,type,text,status,created_at,synced_at FROM requests WHERE user_id=? ORDER BY created_at DESC LIMIT 200", (u["id"],))]

# ---------------------------------------------------------------- documents
MAGIC = {".pdf": (b"%PDF", "application/pdf"), ".png": (b"\x89PNG", "image/png"), ".jpg": (b"\xff\xd8\xff", "image/jpeg"), ".jpeg": (b"\xff\xd8\xff", "image/jpeg")}

@app.post("/api/documents", dependencies=[Depends(limiter("upload", 30, 60))])
def upload_doc(b: DocBody, u=Depends(require_user)):
    name = re.sub(r"[^\w.\- ]", "_", Path(b.filename.replace("\\", "/")).name)[:120] or "document"
    ext = Path(name).suffix.lower()
    if ext not in MAGIC:
        raise HTTPException(400, "file_type")
    if len(b.data) > MAX_FILE * 4 // 3 + 16:
        raise HTTPException(413, "file_too_large")
    try:
        raw = base64.b64decode(b.data, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(400, "validation")
    if not raw:
        raise HTTPException(400, "validation")
    if len(raw) > MAX_FILE:
        raise HTTPException(413, "file_too_large")
    if not raw.startswith(MAGIC[ext][0]):
        raise HTTPException(400, "file_type")
    digest = hashlib.sha256(raw).hexdigest()
    with db() as c:
        same = c.execute("SELECT id FROM documents WHERE id=? OR (user_id=? AND sha256=?)", (b.id, u["id"], digest)).fetchone()
        if same:
            return {"id": same["id"], "status": "duplicate"}
        stored = secrets.token_hex(16) + ext
        (UPLOADS / stored).write_bytes(raw)
        c.execute("INSERT INTO documents(id,user_id,category,filename,mime,size,sha256,stored_name,created_at,synced_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                  (b.id, u["id"], b.category[:30], name, MAGIC[ext][1], len(raw), digest, stored, b.created_at, now_ms()))
    return {"id": b.id, "status": "created"}

DOC_COLS = "id,category,filename,mime,size,status,created_at,synced_at"

@app.get("/api/my/documents")
def my_documents(u=Depends(require_user)):
    with db() as c:
        return [dict(r) for r in c.execute(f"SELECT {DOC_COLS} FROM documents WHERE user_id=? ORDER BY synced_at DESC LIMIT 200", (u["id"],))]

@app.get("/api/documents/{doc_id}/download")
def download_doc(doc_id: str, u=Depends(require_user)):
    with db() as c:
        d = c.execute("SELECT * FROM documents WHERE id=?", (doc_id,)).fetchone()
    if not d or (d["user_id"] != u["id"] and u["role"] not in ("OFFICER", "ADMIN")):
        raise HTTPException(404, "not_found")             # 404 (not 403) so other citizens can't probe ids
    path = UPLOADS / d["stored_name"]
    if not path.is_file():
        raise HTTPException(404, "not_found")
    return FileResponse(path, media_type=d["mime"], filename=d["filename"], content_disposition_type="attachment")

# ---------------------------------------------------------------- staff (officer / admin) APIs
def scope(u, alias=""):
    """Officers see requests assigned to them or still unassigned; admins see everything."""
    return ("1=1", []) if u["role"] == "ADMIN" else (f"({alias}assigned_to IS NULL OR {alias}assigned_to=?)", [u["id"]])

@app.get("/api/admin/stats")
def admin_stats(u=Depends(staff)):
    with db() as c:
        one = lambda q, *a: c.execute(q, a).fetchone()[0]
        by = lambda col: {r[0] or "other": r[1] for r in c.execute(f"SELECT {col}, COUNT(*) FROM requests GROUP BY {col}")}
        w, p = scope(u)
        recent = [dict(r) for r in c.execute(f"SELECT id,name,village,type,category,status,created_at,substr(text,1,100) AS text FROM requests WHERE {w} ORDER BY created_at DESC LIMIT 10", p)]
        by_type = by("type")
        return {"users": one("SELECT COUNT(*) FROM users WHERE role='CITIZEN'"), "total": one("SELECT COUNT(*) FROM requests"),
                "pending": one("SELECT COUNT(*) FROM requests WHERE status IN ('Received','In Progress')"),
                "completed": one("SELECT COUNT(*) FROM requests WHERE status='Completed'"),
                "by_type": by_type, "by_category": by("category"), "by_status": by("status"),
                "sos_open": one("SELECT COUNT(*) FROM requests WHERE type='sos' AND status IN ('Received','In Progress')"),
                "documents": one("SELECT COUNT(*) FROM documents"), "recent": recent}

@app.get("/api/admin/requests")
def admin_requests(status: str = "", type: str = "", q: str = "", page: int = Query(1, ge=1), page_size: int = Query(20, ge=1, le=100), u=Depends(staff)):
    w, p = scope(u)
    where = [w]
    if status in STATUSES: where.append("status=?"); p.append(status)
    if type in TYPES: where.append("type=?"); p.append(type)
    if q.strip():
        like = "%" + q.strip()[:60].replace("%", "").replace("_", "") + "%"
        where.append("(text LIKE ? OR name LIKE ? OR village LIKE ? OR id LIKE ?)"); p += [like] * 4
    cond = " AND ".join(where)
    with db() as c:
        total = c.execute(f"SELECT COUNT(*) FROM requests WHERE {cond}", p).fetchone()[0]
        rows = c.execute(f"""SELECT id,name,village,category,type,status,created_at,synced_at,assigned_to,substr(text,1,160) AS text
                             FROM requests WHERE {cond} ORDER BY (type='sos') DESC, created_at DESC LIMIT ? OFFSET ?""",
                         p + [page_size, (page - 1) * page_size]).fetchall()
    return {"items": [dict(r) for r in rows], "total": total, "page": page, "page_size": page_size}

def _get_req(c, rid, u):
    w, p = scope(u)
    row = c.execute(f"SELECT * FROM requests WHERE id=? AND {w}", [rid] + p).fetchone()
    if not row:
        raise HTTPException(404, "not_found")
    return row

@app.get("/api/admin/requests/{rid}")
def admin_request(rid: str, u=Depends(staff)):
    with db() as c:
        d = dict(_get_req(c, rid, u))
    try: d["details"] = json.loads(d.get("details") or "{}")
    except ValueError: d["details"] = {}
    return d

@app.patch("/api/admin/requests/{rid}")
def admin_update(rid: str, b: StatusBody, u=Depends(staff)):
    with db() as c:
        _get_req(c, rid, u)
        if b.status is not None:
            if b.status not in STATUSES: raise HTTPException(422, "validation")
            c.execute("UPDATE requests SET status=?, updated_at=? WHERE id=?", (b.status, now_ms(), rid))
        if b.assigned_to is not None:
            if u["role"] != "ADMIN": raise HTTPException(403, "forbidden")
            if b.assigned_to and not c.execute("SELECT 1 FROM users WHERE id=? AND role IN ('OFFICER','ADMIN') AND active=1", (b.assigned_to,)).fetchone():
                raise HTTPException(422, "validation")
            c.execute("UPDATE requests SET assigned_to=?, updated_at=? WHERE id=?", (b.assigned_to or None, now_ms(), rid))
    return {"ok": True}

@app.get("/api/admin/documents")
def admin_documents(page: int = Query(1, ge=1), u=Depends(staff)):
    with db() as c:
        rows = c.execute(f"SELECT d.{DOC_COLS.replace(',', ',d.')}, u.username AS owner FROM documents d JOIN users u ON u.id=d.user_id ORDER BY d.synced_at DESC LIMIT 25 OFFSET ?", ((page - 1) * 25,)).fetchall()
    return [dict(r) for r in rows]

@app.patch("/api/admin/documents/{doc_id}")
def admin_doc_status(doc_id: str, b: StatusBody, u=Depends(staff)):
    if b.status not in DOC_STATUSES: raise HTTPException(422, "validation")
    with db() as c:
        if not c.execute("UPDATE documents SET status=? WHERE id=?", (b.status, doc_id)).rowcount:
            raise HTTPException(404, "not_found")
    return {"ok": True}

@app.get("/api/admin/sync-history")
def admin_sync_history(u=Depends(staff)):
    with db() as c:
        return [dict(r) for r in c.execute("SELECT id,at,received,created,duplicates,rejected FROM sync_history ORDER BY id DESC LIMIT 30")]

@app.get("/api/admin/users")
def admin_users(u=Depends(admin_only)):
    with db() as c:
        return [dict(r) for r in c.execute("SELECT id,username,name,village,role,active,created_at FROM users ORDER BY id LIMIT 200")]

@app.patch("/api/admin/users/{uid}")
def admin_user_patch(uid: int, b: UserPatch, u=Depends(admin_only)):
    if uid == u["id"]:
        raise HTTPException(422, "validation")            # admins can't demote/disable themselves
    with db() as c:
        if b.role is not None:
            if b.role not in ROLES: raise HTTPException(422, "validation")
            c.execute("UPDATE users SET role=? WHERE id=?", (b.role, uid))
        if b.active is not None:
            c.execute("UPDATE users SET active=? WHERE id=?", (1 if b.active else 0, uid))
            if not b.active: c.execute("DELETE FROM sessions WHERE user_id=?", (uid,))
    return {"ok": True}

app.mount("/", StaticFiles(directory=BASE.parent / "frontend", html=True), name="static")
