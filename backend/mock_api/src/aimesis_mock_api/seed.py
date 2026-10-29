"""Seed data for the demo: accounts, 4 fictional patients ("Casus 1–4"), plan state, resources.

All values are mock "Demo data". No real patients, no real people.
"""

from __future__ import annotations

import hashlib

DEMO_PASSWORD_HASH = hashlib.sha256(b"aimesis-demo").hexdigest()

PATIENT_IDS = ["casus-1", "casus-2", "casus-3", "casus-4"]


def hash_password(pw: str) -> str:
    return hashlib.sha256(pw.encode("utf-8")).hexdigest()


def accounts() -> list[dict]:
    def acc(id_, email, role, name, pids):
        return {
            "id": id_,
            "email": email,
            "role": role,
            "displayName": name,
            "patientIds": list(pids),
            "passwordHash": DEMO_PASSWORD_HASH,
        }

    return [
        acc("acc-onc", "oncologist@demo.aimesis.app", "oncologist", "Oncologist (demo)", PATIENT_IDS),
        acc("acc-nurse", "nurse@demo.aimesis.app", "nurse", "Nurse specialist (demo)", PATIENT_IDS),
        acc("acc-pharm", "pharmacist@demo.aimesis.app", "pharmacist", "Hospital pharmacist (demo)", PATIENT_IDS),
        acc("acc-teen1", "teen.casus1@demo.aimesis.app", "patient", "Casus 1 · teen (demo)", ["casus-1"]),
        acc("acc-parent2", "parent.casus2@demo.aimesis.app", "parent", "Casus 2 · parent (demo)", ["casus-2"]),
        acc("acc-parent3", "parent.casus3@demo.aimesis.app", "parent", "Casus 3 · parent (demo)", ["casus-3"]),
    ]


def patients() -> list[dict]:
    """Patient records as stored (camelCase, without derived overallTier/planStatus)."""
    return [
        {
            "id": "casus-1",
            "alias": "Casus 1",
            "age": 16,
            "sex": "F",
            "weightKg": 52,
            "heightCm": 160,
            "bsaM2": 1.52,
            "diagnosis": "Neuroblastoma",
            "diagnosisGroup": "solid",
            "protocol": "HR-NBL2 · RAPID COJEC",
            "cycle": "B4",
            "cycleStart": "2026-09-25",
            "chemo": [
                {"drug": "vincristine", "doseMgM2": 1.5, "days": [1]},
                {"drug": "cisplatin", "doseMgM2": 80, "days": [1]},
            ],
            "activeMeds": [],
            "language": "nl",
            "history": [
                {
                    "cycle": "B3",
                    "date": "2026-09-05",
                    "antiemetics": "Ondansetron 2x/d + aprepitant + dexamethasone + olanzapine",
                    "nauseaDays": [2],
                    "vomitingDays": [],
                    "note": "Toch nausea gehad op dag 2 (toernota)",
                }
            ],
            "pairingCode": "C1-NBL2",
        },
        {
            "id": "casus-2",
            "alias": "Casus 2",
            "age": 2,
            "sex": "M",
            "weightKg": 12.5,
            "heightCm": 87,
            "bsaM2": 0.55,
            "diagnosis": "Acute lymphoblastic leukaemia (ALL)",
            "diagnosisGroup": "ALL",
            "protocol": "ALLTogether1 · Induction B",
            "cycle": "Day 8",
            "cycleStart": "2026-10-29",
            "chemo": [
                {"drug": "vincristine", "doseMgM2": 1.5, "days": [1]},
                {"drug": "daunorubicin", "doseMgM2": 30, "days": [1]},
            ],
            "activeMeds": [],
            "language": "fr",
            "history": [
                {
                    "cycle": "Induction B D1",
                    "nauseaDays": [],
                    "vomitingDays": [],
                    "note": "Geen misselijkheid of braken bij vorige toediening",
                }
            ],
            "pairingCode": "C2-ALL8",
        },
        {
            "id": "casus-3",
            "alias": "Casus 3",
            "age": 14,
            "sex": "M",
            "weightKg": 45,
            "heightCm": 158,
            "bsaM2": 1.41,
            "diagnosis": "Ewing sarcoma",
            "diagnosisGroup": "solid",
            "protocol": "iEuroEwing · IE",
            "cycle": "IE #3",
            "cycleStart": "2026-10-29",
            "chemo": [
                {"drug": "ifosfamide", "doseMgM2": 1800, "days": [1, 2, 3, 4, 5]},
                {"drug": "etoposide", "doseMgM2": 100, "days": [1, 2, 3, 4, 5]},
            ],
            "activeMeds": [],
            "language": "nl",
            "history": [
                {
                    "cycle": "IE #2",
                    "nauseaDays": [4],
                    "vomitingDays": [4],
                    "note": "Misselijkheid en braken op dag 4",
                }
            ],
            "pairingCode": "C3-IE03",
        },
        {
            "id": "casus-4",
            "alias": "Casus 4 · interactions",
            "age": 7,
            "sex": "M",
            "weightKg": 22,
            "heightCm": 120,
            "bsaM2": 0.85,
            "diagnosis": "ALL",
            "diagnosisGroup": "ALL",
            "protocol": "ALLTogether1 · Consolidation",
            "cycle": "C1",
            "cycleStart": "2026-10-29",
            "chemo": [
                {"drug": "cyclophosphamide", "doseMgM2": 1600, "days": [1]},
                {"drug": "vincristine", "doseMgM2": 1.5, "days": [1]},
            ],
            "activeMeds": ["voriconazole"],
            "language": "en",
            "history": [],
            "pairingCode": "C4-DDI7",
        },
    ]


DEFAULT_RISK_FACTORS = {
    "casus-1": {"canSwallowTablets": True, "preferredRoute": "oral_tablet", "anticipatory": False},
    "casus-2": {"canSwallowTablets": False, "preferredRoute": "oral_liquid", "anticipatory": False},
    "casus-3": {"canSwallowTablets": True, "preferredRoute": "oral_tablet", "anticipatory": False},
    "casus-4": {"canSwallowTablets": False, "preferredRoute": "oral_liquid", "anticipatory": False},
}


def plan_states() -> list[dict]:
    return [
        {
            "patientId": pid,
            "status": "draft",
            "riskFactors": dict(DEFAULT_RISK_FACTORS[pid]),
            "signoffs": {"oncologist": None, "pharmacist": None},
            "comments": [],
        }
        for pid in PATIENT_IDS
    ]


_RESOURCE_ROWS = [
    ("Fondation contre le Cancer", "La chimiothérapie", "PDF", "fr", "https://www.cancer.be/ressource/la-chimiotherapie/", "low", "Direct French PDF download"),
    ("Stichting tegen Kanker", "Chemotherapie", "PDF", "nl", "https://www.cancer.be/ressource/chemotherapie/", "low", "Direct Dutch PDF download"),
    ("Stichting tegen Kanker", "Die Chemotherapie", "PDF", "de", "https://www.cancer.be/ressource/chemotherapie-de/", "low", "Direct German PDF download"),
    ("CHU de Liège", "Les nausées et les vomissements", "PDF", "fr", "https://www.chuliege.be/cms/c_60648/fr/broch-a5-les-nausees-et-les-vomissements-2024-pp", "low", "Direct clinical PDF download"),
    ("ZAS (Ziekenhuis aan de Stroom)", "Chemotherapie: Informatie voor patiënten", "PDF", "nl", "https://media.zas.be/m/1be42769d38ec4ee/original/Chemotherapie.pdf", "low", "Direct regional PDF download"),
    ("AZ Org", "Chemotherapie... wat nu?", "PDF", "nl", "https://www.azorg.be/sites/default/files/patient_brochures/01016-NL.pdf", "low", "Direct clinical PDF download"),
    ("Fondation contre le Cancer", "Nausées et vomissements", "Web page", "fr", "https://www.cancer.be/les-cancers/effets-secondaires/nausees-et-vomissements", "low", "Direct web article"),
    ("Stichting tegen Kanker", "Misselijkheid en braken", "Web page", "nl", "https://www.cancer.be/kanker/bijwerkingen/misselijkheid-en-braken", "low", "Direct web article"),
    ("AZ Groeninge", "Effets indésirables : nausées et vomissements", "Web page", "fr", "https://www.azgroeninge.be/fr/blogs/bijwerkingen-chemotherapie/effets-indesirables-chimiotherapie-nausees-et-vomissements", "low", "Direct French web guide"),
    ("AZ Groeninge", "Bijwerkingen chemotherapie: misselijkheid en braken", "Web page", "nl", "https://www.azgroeninge.be/nl/blogs/bijwerkingen-chemotherapie/bijwerkingen-chemotherapie-misselijkheid-en-braken", "low", "Direct Dutch web guide"),
    ("KickCancer Foundation", "Family Support & Research Hub", "Web portal", "en", "https://kickcancer.org/en", "low", "Trilingual"),
    ("KickCancer Foundation", "Guide pour les familles", "Web portal", "fr", "https://kickcancer.org/fr", "low", "Trilingual"),
    ("KickCancer Foundation", "Gids voor families", "Web portal", "nl", "https://kickcancer.org/nl", "low", "Trilingual"),
    ("UZ Leuven", "Misselijkheid en braken bij chemotherapie", "Web page", "nl", "https://www.uzleuven.be/nl/chemotherapie/bijwerkingen/misselijkheid-en-braken", "medium", "Language switch resets to home"),
    ("UZ Leuven (KIDZ)", "Kinderoncologie en -hematologie", "Web page", "nl", "https://www.uzleuven.be/nl/kinderoncologie", "medium", "General portal"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - Kinderoncologie", "Web page", "nl", "https://www.uzbrussel.be/web/kidz-health-castle/kinderoncologie", "medium", "Use this deep link; language toggle redirects to homepage"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - Oncologie pédiatrique", "Web page", "fr", "https://www.uzbrussel.be/fr/web/kidz-health-castle/oncologie-pediatrique", "medium", "Use this deep link; language toggle redirects to homepage"),
    ("UZ Brussel / KidZ Health Castle", "KidZ Health Castle - General Overview", "Web page", "en", "https://www.uzbrussel.be/en/web/kidz-health-castle", "medium", "English intro only"),
    ("HUDERF / H.U.B (Brussels)", "Hémato-Oncologie Pédiatrique - Accueil", "Web page", "fr", "https://www.huderf.be/fr/services-medicaux/hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("HUDERF / H.U.B (Brussels)", "Pediatrische Hemato-Oncologie - Onthaal", "Web page", "nl", "https://www.huderf.be/nl/medische-diensten/hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Service d'Hémato-oncologie Pédiatrique", "Web page", "fr", "https://www.saintluc.be/fr/service-hemato-oncologie-pediatrique", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Dienst Pediatrische Hemato-oncologie", "Web page", "nl", "https://www.saintluc.be/nl/dienst-pediatrische-hemato-oncologie", "medium", "Use this deep link; language toggle redirects"),
    ("Cliniques universitaires Saint-Luc", "Pediatric Hematology and Oncology", "Web page", "en", "https://www.saintluc.be/en/pediatric-hematology-and-oncology-department", "medium", "English summaries only"),
    ("UZA (Queen Mathilde Center)", "Kinderoncologie en kinderhematologie", "Web page", "nl", "https://www.uza.be/oncologie-hematologie-kinderen", "medium", "No FR/EN version"),
    ("UZA / magUZA", "Kinderen met kanker behandelen is teamwerk", "Web page", "nl", "https://maguza.be/zorg/artikel/kinderen-met-kanker-behandelen-teamwerk", "medium", "Single article"),
    ("Kinderkankerfonds vzw", "Publicaties & Gids voor Ouders", "Web page", "nl", "https://www.kinderkankerfonds.be", "high", "Registration or print order needed"),
    ("BSPHO", "Clinical Treatment Protocols", "Web page", "en", "https://www.bspho.be", "high", "For professionals"),
]


def resources() -> list[dict]:
    return [
        {
            "id": f"res-{i:02d}",
            "institution": inst,
            "title": title,
            "format": fmt,
            "language": lang,
            "url": url,
            "effort": effort,
            "effortNote": note,
        }
        for i, (inst, title, fmt, lang, url, effort, note) in enumerate(_RESOURCE_ROWS, start=1)
    ]
