"""Render structured JSON and print-ready HTML for the multilingual CINV Patient Passport."""

from __future__ import annotations

import html
from typing import Any, Dict, Optional

from aimesis_rules import generate_cinv_patient_passport

from aimesis_api.passport.translations import PASSPORT_TRANSLATIONS


def render_passport_payload(
    patient_label: str,
    regimen_label: str,
    uza_evaluation: Dict[str, Any],
    language: str = "NL",
    oncologist_signed: bool = False,
    oncologist_name: Optional[str] = None,
    pharmacist_signed: bool = False,
    pharmacist_name: Optional[str] = None,
) -> Dict[str, Any]:
    """Build the structured multilingual passport dictionary and HTML view."""
    lang = language.strip().upper()
    if lang not in PASSPORT_TRANSLATIONS:
        lang = "NL"
    t = PASSPORT_TRANSLATIONS[lang]

    export_unlocked = bool(oncologist_signed and pharmacist_signed)
    base_passport = generate_cinv_patient_passport(
        patient_alias=patient_label,
        uza_evaluation=uza_evaluation,
        language=lang,
        oncologist_signed_by=oncologist_name if oncologist_signed else None,
        pharmacist_signed_by=pharmacist_name if pharmacist_signed else None,
    )

    emetogenicity_str = uza_evaluation.get("overall_tier", "Unknown")
    dosing_lines = uza_evaluation.get("dosing_lines", {})

    schedule_items = [
        {
            "drug": line.get("drug", ""),
            "indicated": line.get("indicated", False),
            "schedule": line.get("frequency", ""),
            "calculated_dose": line.get("dose_text", ""),
            "duration": line.get("duration", ""),
            "rule_citation": line.get("citation", ""),
        }
        for line in dosing_lines.values()
        if line.get("indicated", False)
    ]

    banner = t["sign_off_banner_unlocked"] if export_unlocked else t["sign_off_banner_locked"]

    prophylaxis_rows = "".join(
        f"<tr><td><strong>{html.escape(m['drug'])}</strong></td>"
        f"<td>{html.escape(m['calculated_dose'])}</td>"
        f"<td>{html.escape(m['schedule'])}</td>"
        f"<td>{html.escape(m['duration'])}</td>"
        f"<td><small>{html.escape(m['rule_citation'])}</small></td></tr>"
        for m in schedule_items
    )
    red_flag_items = "".join(f"<li>{html.escape(flag)}</li>" for flag in t["red_flags"])

    printable_html = f"""<!DOCTYPE html>
<html lang="{lang.lower()}">
<head>
  <meta charset="utf-8" />
  <title>{html.escape(t['title'])}</title>
</head>
<body>
  <header>
    <h1>{html.escape(t['title'])}</h1>
    <p>{html.escape(t['subtitle'])}</p>
    <div class="governance-banner {'unlocked' if export_unlocked else 'locked'}">
      {html.escape(banner)}
    </div>
  </header>
  <section class="metadata">
    <p><strong>{html.escape(t['patient_label_header'])}:</strong> {html.escape(patient_label)}</p>
    <p><strong>{html.escape(t['regimen_header'])}:</strong> {html.escape(regimen_label)}</p>
    <p><strong>{html.escape(t['emetogenicity_header'])}:</strong> {html.escape(str(emetogenicity_str))}</p>
  </section>
  <section class="prophylaxis">
    <h2>{html.escape(t['prophylaxis_header'])}</h2>
    <table>
      <thead>
        <tr><th>Medication</th><th>Dose</th><th>Schedule</th><th>Duration</th><th>Rule</th></tr>
      </thead>
      <tbody>{prophylaxis_rows}</tbody>
    </table>
  </section>
  <section class="red-flags">
    <h2>{html.escape(t['red_flags_header'])}</h2>
    <ul>{red_flag_items}</ul>
    <p><strong>{html.escape(t['contact'])}</strong></p>
  </section>
</body>
</html>"""

    return {
        **base_passport,
        "passport_title": t["title"],
        "subtitle": t["subtitle"],
        "language": lang,
        "patient_label": patient_label,
        "regimen_label": regimen_label,
        "emetogenicity_classification": emetogenicity_str,
        "medication_schedule": schedule_items,
        "red_flag_symptoms_contact_hospital": t["red_flags"],
        "emergency_contact_note": t["contact"],
        "sign_off_status": {
            "oncologist_signed": oncologist_signed,
            "oncologist_name": oncologist_name,
            "pharmacist_signed": pharmacist_signed,
            "pharmacist_name": pharmacist_name,
            "export_unlocked": export_unlocked,
            "banner": banner,
            "rule_citation": "AImesis Governance: Dual sign-off (Oncologist + Pharmacist) required before export",
        },
        "printable_html": printable_html,
    }
