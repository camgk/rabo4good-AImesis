"""CINV Patient Passport builder (NL / FR / EN) for the mock API.

Takes a computed Plan and turns it into a family-facing day-by-day schedule.
Translations are hand-written strings; no LLM involved.
"""

from __future__ import annotations

from datetime import date, timedelta

from .models import Passport, PassportDay, PassportItem, Patient, Plan, Resource
from .rules_mock import ONDANSETRON_TIMES

WARD_PHONE = "+32 3 000 00 00"

TEXT: dict[str, dict] = {
    "nl": {
        "title": "CINV-paspoort · {alias}",
        "day": "Dag {n}",
        "medicines": {
            "ondansetron": "Ondansetron (tegen misselijkheid)",
            "aprepitant": "Aprepitant (tegen misselijkheid)",
            "dexamethasone": "Dexamethason (corticosteroïd)",
            "olanzapine": "Olanzapine (tegen misselijkheid, 's avonds)",
        },
        "routes": {
            "oral_tablet": "tablet via de mond",
            "oral_liquid": "drankje via de mond",
            "ng_tube": "via de neussonde",
            "iv": "via het infuus (in het ziekenhuis)",
        },
        "notes": {
            "evening": "'s Avonds innemen, kan slaperig maken",
            "with_food": "Mag met of zonder eten",
            "hospital": "Wordt in het ziekenhuis gegeven",
        },
        "warning_signs": [
            "Uw kind kan langer dan 6 uur geen vocht binnenhouden",
            "Koorts van 38,5 °C of hoger",
            "Uw kind is erg slaperig of verward",
            "Geen natte luier / geen urine gedurende 8 uur",
            "Bloed of donker 'koffiedik' in het braaksel",
            "Misselijkheid of braken blijft ondanks de extra medicatie",
        ],
        "disclaimer": "Dit schema werd opgesteld door uw zorgteam. Bel de afdeling als u zich zorgen maakt.",
    },
    "fr": {
        "title": "Passeport CINV · {alias}",
        "day": "Jour {n}",
        "medicines": {
            "ondansetron": "Ondansétron (contre les nausées)",
            "aprepitant": "Aprépitant (contre les nausées)",
            "dexamethasone": "Dexaméthasone (corticoïde)",
            "olanzapine": "Olanzapine (contre les nausées, le soir)",
        },
        "routes": {
            "oral_tablet": "comprimé par la bouche",
            "oral_liquid": "sirop par la bouche",
            "ng_tube": "par la sonde nasogastrique",
            "iv": "par perfusion (à l'hôpital)",
        },
        "notes": {
            "evening": "À prendre le soir, peut rendre somnolent",
            "with_food": "Avec ou sans nourriture",
            "hospital": "Administré à l'hôpital",
        },
        "warning_signs": [
            "Votre enfant ne garde pas les liquides pendant plus de 6 heures",
            "Fièvre de 38,5 °C ou plus",
            "Votre enfant est très somnolent ou confus",
            "Pas de couche mouillée / pas d'urine pendant 8 heures",
            "Du sang ou un aspect « marc de café » dans les vomissements",
            "Les nausées ou vomissements continuent malgré le traitement supplémentaire",
        ],
        "disclaimer": "Ce schéma a été préparé par votre équipe soignante. Appelez le service si vous êtes inquiet.",
    },
    "en": {
        "title": "CINV Passport · {alias}",
        "day": "Day {n}",
        "medicines": {
            "ondansetron": "Ondansetron (anti-sickness)",
            "aprepitant": "Aprepitant (anti-sickness)",
            "dexamethasone": "Dexamethasone (steroid)",
            "olanzapine": "Olanzapine (anti-sickness, evening)",
        },
        "routes": {
            "oral_tablet": "tablet by mouth",
            "oral_liquid": "liquid by mouth",
            "ng_tube": "via the nasogastric tube",
            "iv": "through the drip (in hospital)",
        },
        "notes": {
            "evening": "Take in the evening, may cause sleepiness",
            "with_food": "With or without food",
            "hospital": "Given in hospital",
        },
        "warning_signs": [
            "Your child cannot keep fluids down for more than 6 hours",
            "Fever 38.5 °C or higher",
            "Your child is very sleepy or confused",
            "No wet nappy / no urine for 8 hours",
            "Blood or dark 'coffee grounds' in the vomit",
            "Nausea or vomiting continues despite the extra medicine",
        ],
        "disclaimer": "This schedule was prepared by your care team. Call the ward if you are worried.",
    },
}


def _times(drug: str, frequency: str) -> list[str]:
    if drug == "ondansetron":
        n = int(frequency[0]) if frequency[:1].isdigit() else 1
        return ONDANSETRON_TIMES.get(n, ["08:00"])
    if drug == "dexamethasone":
        return ["08:00", "20:00"]
    if drug == "olanzapine":
        return ["20:00"]
    return ["08:00"]


def _amount(dose: float | None, unit: str, lang: str) -> str:
    if dose is None:
        return "—"
    s = f"{dose:.2f}".rstrip("0").rstrip(".") if dose != int(dose) else f"{dose:.0f}"
    if lang in ("nl", "fr"):
        s = s.replace(".", ",")
    return f"{s} {unit}"


def build_passport(patient: Patient, plan: Plan, lang: str, resources: list[Resource]) -> Passport:
    t = TEXT.get(lang, TEXT["en"])
    try:
        start = date.fromisoformat(patient.cycle_start[:10])
    except ValueError:
        start = None

    by_day: dict[int, list[PassportItem]] = {}
    if not plan.refused:
        for line in plan.antiemetics:
            med = t["medicines"].get(line.drug, line.drug)
            route = t["routes"].get(line.route, line.route)
            note = None
            if line.drug == "olanzapine":
                note = t["notes"]["evening"]
            elif line.route == "iv":
                note = t["notes"]["hospital"]
            for d in line.days:
                for tm in _times(line.drug, line.frequency):
                    by_day.setdefault(d, []).append(
                        PassportItem(time=tm, medicine=med, amount=_amount(line.dose_mg, line.unit, lang), route=route, note=note)
                    )

    def sort_key(item: PassportItem) -> str:
        return "24:00" if item.time == "00:00" else item.time

    days = [
        PassportDay(
            day=d,
            label=t["day"].format(n=d),
            date=(start + timedelta(days=d - 1)).isoformat() if start else None,
            items=sorted(by_day[d], key=sort_key),
        )
        for d in sorted(by_day)
    ]

    order = {"low": 0, "medium": 1, "high": 2}
    res = sorted([r for r in resources if r.language == lang], key=lambda r: order[r.effort])[:5]

    return Passport(
        patient_id=patient.id,
        alias=patient.alias,
        lang=lang,
        title=t["title"].format(alias=patient.alias),
        overall_tier=plan.overall_tier,
        status=plan.status,
        signed_off=plan.status == "approved"
        and plan.signoffs.oncologist is not None
        and plan.signoffs.pharmacist is not None,
        days=days,
        warning_signs=list(t["warning_signs"]),
        ward_phone=WARD_PHONE,
        resources=res,
        pairing_code=patient.pairing_code,
        disclaimer=t["disclaimer"],
    )
