"""End-to-end role check against a running AImesis mock API.

Usage: python3 e2e_check.py <api-url>      (e.g. http://localhost:8080 or the Cloud Run URL)

Needs the demo data loaded (infra/scripts/demo-data.sh load, or LOAD_DEMO_ON_START=true with STORE=memory).
Non-destructive except: one nausea episode for Casus 1, the Casus 3 submit + approve, and pairing parent2 with
Casus 3. Afterwards run `infra/scripts/demo-data.sh load --reset` to start the demo fresh.
"""
import json
import sys
import urllib.error
import urllib.request

U = sys.argv[1].rstrip("/")
P1, P2, P3, P4 = "PAT-2026-0001", "PAT-2026-0002", "PAT-2026-0003", "PAT-2026-0004"


def call(method, path, tok=None, body=None):
    headers = {"content-type": "application/json"}
    if tok:
        headers["authorization"] = "Bearer " + tok
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(U + path, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, (json.loads(raw) if raw else {})


def login(user):
    s, b = call("POST", "/auth/login", body={"email": user + "@demo.aimesis.app", "password": "aimesis-demo"})
    assert s == 200, (user, s, b, "is the demo data loaded? infra/scripts/demo-data.sh load")
    return b["token"]


ok = True


def check(label, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + label + (f"  ({detail})" if detail else ""))


check("demo accounts listed", len(call("GET", "/auth/demo-accounts")[1]) == 6)
onc, ph, nu, teen, par2 = (login(u) for u in ["oncologist", "pharmacist", "nurse", "teen.casus1", "parent.casus2"])
pts = call("GET", "/patients", onc)[1]
demo_ids = [p["id"] for p in pts if "demo" in p.get("tags", [])]
check("clinicians see the 4 demo patients", demo_ids == [P1, P2, P3, P4], demo_ids)
check("?tag=demo filter", [p["id"] for p in call("GET", "/patients?tag=demo", onc)[1]] == [P1, P2, P3, P4])
check("patients carry tags", all(p.get("tags") == ["demo"] for p in pts if p["id"] in demo_ids))
check("teen sees only Casus 1", [p["id"] for p in call("GET", "/patients", teen)[1]] == [P1])
check("parent sees only Casus 2", [p["id"] for p in call("GET", "/patients", par2)[1]] == [P2])
check("family blocked from other child", call("GET", f"/patients/{P2}", teen)[0] == 403)
check("family blocked from clinician plan", call("GET", f"/patients/{P1}/plan", teen)[0] == 403)
check("no token -> 401", call("GET", "/me")[0] == 401)
p2 = call("GET", f"/patients/{P2}/plan", onc)[1]
check("Casus 2 dexamethasone blocked (ALL)", p2["dexamethasone"]["blocked"])
check("advisory text is neutral", p2["advisory"] == "Advisory only — requires clinician sign-off.", p2["advisory"])
p3 = call("GET", f"/patients/{P3}/plan", onc)[1]
check("Casus 3 ifosfamide+etoposide -> high", p3["overallTier"] == "high")
p4 = call("GET", f"/patients/{P4}/plan", onc)[1]
check("Casus 4 critical interaction", any(i["severity"] == "critical" for i in p4["interactions"]))
check("nurse cannot submit", call("POST", f"/patients/{P3}/plan/submit", nu)[0] == 403)
s, b = call("POST", f"/patients/{P3}/plan/submit", onc)
check("oncologist submits", s == 200 and b["status"] == "awaiting_pharmacist", b.get("status"))
s, b = call("POST", f"/patients/{P3}/plan/approve", ph, {"comment": "Checked"})
check("pharmacist approves", s == 200 and b["status"] == "approved", b.get("status"))
s, b = call("GET", f"/patients/{P3}/passport?lang=fr", onc)
check("passport fr signed off", s == 200 and b["signedOff"] and "Jour" in json.dumps(b, ensure_ascii=False))
check("passport disclaimer has no demo wording", "démonstration" not in b.get("disclaimer", "").lower())
s, e = call("POST", f"/patients/{P1}/episodes", teen, {"type": "nausea", "severity": 3})
check("teen logs nausea", s == 201, f"cycleDay {e.get('cycleDay')}")
summ = call("GET", f"/patients/{P1}/plan", onc)[1]["episodesSummary"]["currentCycle"]
check("oncologist sees the home log", sum(d["nausea"] for d in summ) >= 1, summ)
check("pairing code works", call("POST", "/pairing", par2, {"code": "C3-IE03"})[0] == 200)
check("/admin/reset is gone", call("POST", "/admin/reset")[0] in (404, 405))
print("ALL PASS" if ok else "SOME FAILED")
print("Hint: restore a fresh demo with: infra/scripts/demo-data.sh load --reset")
sys.exit(0 if ok else 1)
