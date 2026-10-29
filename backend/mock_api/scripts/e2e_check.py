"""End-to-end role check against a deployed AImesis demo API. Usage: python3 e2e.py <api-url>"""
import json
import sys
import urllib.error
import urllib.request

U = sys.argv[1].rstrip("/")


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
    assert s == 200, (user, s, b)
    return b["token"]


ok = True


def check(label, cond, detail=""):
    global ok
    ok &= bool(cond)
    print(("PASS " if cond else "FAIL ") + label + (f"  ({detail})" if detail else ""))


onc, ph, nu, teen, par2 = (login(u) for u in ["oncologist", "pharmacist", "nurse", "teen.casus1", "parent.casus2"])
check("clinicians see 4 patients", len(call("GET", "/patients", onc)[1]) == 4)
check("teen sees only casus-1", [p["id"] for p in call("GET", "/patients", teen)[1]] == ["casus-1"])
check("parent sees only casus-2", [p["id"] for p in call("GET", "/patients", par2)[1]] == ["casus-2"])
check("family blocked from other child", call("GET", "/patients/casus-2", teen)[0] == 403)
check("family blocked from clinician plan", call("GET", "/patients/casus-1/plan", teen)[0] == 403)
check("no token -> 401", call("GET", "/me")[0] == 401)
p2 = call("GET", "/patients/casus-2/plan", onc)[1]
check("casus-2 dexamethasone blocked (ALL)", p2["dexamethasone"]["blocked"])
p3 = call("GET", "/patients/casus-3/plan", onc)[1]
check("casus-3 ifosfamide+etoposide -> high", p3["overallTier"] == "high")
p4 = call("GET", "/patients/casus-4/plan", onc)[1]
check("casus-4 critical interaction", any(i["severity"] == "critical" for i in p4["interactions"]))
check("nurse cannot submit", call("POST", "/patients/casus-3/plan/submit", nu)[0] == 403)
s, b = call("POST", "/patients/casus-3/plan/submit", onc)
check("oncologist submits", s == 200 and b["status"] == "awaiting_pharmacist", b.get("status"))
s, b = call("POST", "/patients/casus-3/plan/approve", ph, {"comment": "Checked"})
check("pharmacist approves", s == 200 and b["status"] == "approved", b.get("status"))
s, b = call("GET", "/patients/casus-3/passport?lang=fr", onc)
check("passport fr signed off", s == 200 and b["signedOff"] and "Jour" in json.dumps(b, ensure_ascii=False))
s, e = call("POST", "/patients/casus-1/episodes", teen, {"type": "nausea", "severity": 3})
check("teen logs nausea", s == 201, f"cycleDay {e.get('cycleDay')}")
summ = call("GET", "/patients/casus-1/plan", onc)[1]["episodesSummary"]["currentCycle"]
check("oncologist sees the home log", sum(d["nausea"] for d in summ) >= 1, summ)
check("pairing code works", call("POST", "/pairing", par2, {"code": "C3-IE03"})[0] == 200)
print("ALL PASS" if ok else "SOME FAILED")
