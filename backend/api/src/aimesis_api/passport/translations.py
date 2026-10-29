"""Dutch (NL), French (FR), and English (EN) translation strings for the UZA
Pediatric Oncology CINV Patient Passport.
"""

from __future__ import annotations

from typing import Any

PASSPORT_TRANSLATIONS: dict[str, dict[str, Any]] = {
    "NL": {
        "title": "UZA Kinderoncologie — Anti-emetica Paspoort voor Thuis & Afdeling",
        "subtitle": "Gepersonaliseerd schema tegen misselijkheid en braken (UZA Beleid V2 Juli 2026)",
        "patient_label_header": "Patiënt",
        "regimen_header": "Chemotherapie schema",
        "emetogenicity_header": "Emetogeniciteitsklasse",
        "prophylaxis_header": "Vast profylactisch schema (op tijd innemen, ook zonder klachten)",
        "rescue_header": "Noodmedicatie (enkel bij doorbraakmisselijkheid of braken)",
        "red_flags_header": "Wanneer onmiddellijk contact opnemen met het ziekenhuis?",
        "red_flags": [
            "Aanhoudend braken (> 3 keer in 24 uur) of geen vocht kunnen binnenhouden gedurende > 12 uur",
            "Tekenen van uitdroging: droge mond, weinig plassen / droge luiers, sufheid of duizeligheid",
            "Koorts >= 38.0 °C (bel onmiddellijk de wachtdienst kinderoncologie)",
            "Stijfheid in nek/kaak of onwillekeurige spiertrekkingen (mogelijke extrapiramidale reactie op metoclopramide)",
        ],
        "contact": "UZA Kinderoncologie 24/7 Wachtdienst — Neem dit paspoort mee bij elk ziekenhuisbezoek.",
        "sign_off_banner_locked": (
            "CONCEPT — Export geblokkeerd tot dubbele validatie door kinderoncoloog EN ziekenhuisapotheker."
        ),
        "sign_off_banner_unlocked": (
            "GEVALIDEERD — Dubbele handtekening (Kinderoncoloog + Ziekenhuisapotheker) voltooid."
        ),
    },
    "FR": {
        "title": "UZA Oncologie Pédiatrique — Passeport Antiémétique Patient & Famille",
        "subtitle": "Schéma personnalisé contre les nausées et vomissements (Politique UZA V2 Juillet 2026)",
        "patient_label_header": "Patient",
        "regimen_header": "Protocole de chimiothérapie",
        "emetogenicity_header": "Classe d'émétogénicité",
        "prophylaxis_header": "Traitement préventif fixe (à prendre à l'heure, même sans nausées)",
        "rescue_header": "Médicament de secours (uniquement en cas de nausées ou vomissements)",
        "red_flags_header": "Quand contacter immédiatement l'hôpital ?",
        "red_flags": [
            "Vomissements persistants (> 3 fois en 24h) ou incapacité de boire pendant > 12h",
            "Signes de déshydratation : bouche sèche, diminution des urines, somnolence",
            "Fièvre >= 38.0 °C (appelez immédiatement la garde d'oncologie pédiatrique)",
            "Raideur de la nuque/mâchoire ou mouvements anormaux (effet secondaire possible du métoclopramide)",
        ],
        "contact": "Service de garde 24/7 Oncologie Pédiatrique UZA — Apportez ce passeport à chaque visite.",
        "sign_off_banner_locked": (
            "BROUILLON — Exportation verrouillée jusqu'à la double validation (Oncologue + Pharmacien)."
        ),
        "sign_off_banner_unlocked": (
            "VALIDÉ — Double signature (Oncologue pédiatre + Pharmacien hospitalier) complète."
        ),
    },
    "EN": {
        "title": "UZA Pediatric Oncology — Patient & Family Antiemetic Passport",
        "subtitle": "Personalized schedule for nausea and vomiting prevention (UZA Policy V2 July 2026)",
        "patient_label_header": "Patient",
        "regimen_header": "Chemotherapy regimen",
        "emetogenicity_header": "Emetogenicity class",
        "prophylaxis_header": "Scheduled preventive medications (take on time, even if feeling well)",
        "rescue_header": "Rescue medication (only if breakthrough nausea or vomiting occurs)",
        "red_flags_header": "When to contact the hospital immediately:",
        "red_flags": [
            "Persistent vomiting (> 3 episodes in 24h) or inability to keep fluids down for > 12h",
            "Signs of dehydration: dry mouth, reduced urination / dry diapers, lethargy",
            "Fever >= 38.0 °C (call Pediatric Oncology on-call immediately)",
            "Neck/jaw stiffness or involuntary muscle spasms (possible extrapyramidal reaction to metoclopramide)",
        ],
        "contact": "UZA Pediatric Oncology 24/7 On-Call Service — Bring this passport to every visit.",
        "sign_off_banner_locked": (
            "DRAFT — Export locked until dual sign-off by Pediatric Oncologist AND Clinical Pharmacist."
        ),
        "sign_off_banner_unlocked": (
            "VERIFIED — Dual sign-off (Pediatric Oncologist + Clinical Pharmacist) complete."
        ),
    },
}
