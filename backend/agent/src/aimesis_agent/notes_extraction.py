"""Ward progress note (`toernota`) structured extraction with verbatim quotes."""

from __future__ import annotations

import re
from typing import Any, Dict, List


def extract_prior_cycle_signals_from_note(note_text: str) -> Dict[str, Any]:
    """Extracts structured CINV signals and verbatim quotes from a ward progress note (`toernota`).

    Clinicians confirm the quoted evidence in the UI before it modifies the regimen.
    """
    text = (note_text or "").strip()
    if not text:
        return {
            "prior_breakthrough_cinv": False,
            "prior_ondansetron_2xd_on_hec": False,
            "anticipatory_vomiting": False,
            "can_swallow_tablets": True,
            "verbatim_quotes": [],
            "requires_clinician_confirmation": False,
        }

    sentences = [s.strip() for s in re.split(r"(?<=[.!?;\n])\s+", text) if s.strip()]
    quotes: List[str] = []

    breakthrough_keywords = (
        "nausea",
        "misselijk",
        "braken",
        "vomiting",
        "emesis",
        "doorbraak",
        "breakthrough",
    )
    negative_prefixes = ("no nausea", "geen nausea", "geen misselijkheid", "geen braken", "no vomiting")

    prior_breakthrough = False
    for s in sentences:
        s_low = s.lower()
        if any(neg in s_low for neg in negative_prefixes):
            continue
        if any(k in s_low for k in breakthrough_keywords):
            prior_breakthrough = True
            quotes.append(s)

    low_text = text.lower()
    prior_ond_2xd = "2x/d" in low_text or "2dd" in low_text or "twice daily" in low_text
    anticipatory = any(k in low_text for k in ("anticipatoir", "anticipatory", "angst voor chemo", "pre-chemo nausea"))
    cannot_swallow = any(k in low_text for k in ("kan geen pillen slikken", "cannot swallow", "siroop", "sonde", "ng tube"))

    return {
        "prior_breakthrough_cinv": prior_breakthrough,
        "prior_ondansetron_2xd_on_hec": prior_ond_2xd,
        "anticipatory_vomiting": anticipatory,
        "can_swallow_tablets": not cannot_swallow,
        "verbatim_quotes": quotes,
        "requires_clinician_confirmation": len(quotes) > 0,
    }
