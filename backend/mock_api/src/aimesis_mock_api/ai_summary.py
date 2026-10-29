"""Gemini (Vertex AI) summary of a computed plan -- explanation only, never a source of doses.

The model sees ONLY the plan JSON produced by the rules engine plus minimal patient context and is
told never to introduce drugs or doses that are not in the plan. Any failure returns (None, error).
"""

from __future__ import annotations

import json
import os
import re

LANG_NAMES = {"nl": "Dutch (Flemish)", "fr": "French", "en": "English"}
DEFAULT_PROJECT = "qwiklabs-gcp-00-cc29ec8bfdd9"
DEFAULT_MODEL = "gemini-2.5-flash"
TIMEOUT_S = 20


def _truthy(v: str | None) -> bool:
    return (v or "").strip().lower() in ("1", "true", "yes", "on")


def _client():
    from google import genai  # lazy: optional dependency
    from google.genai import types

    kwargs = dict(
        vertexai=True,
        project=os.getenv("GOOGLE_CLOUD_PROJECT", DEFAULT_PROJECT),
        location=os.getenv("GOOGLE_CLOUD_LOCATION", "global"),
        http_options=types.HttpOptions(timeout=TIMEOUT_S * 1000),
    )
    token = os.getenv("AIMESIS_GCLOUD_TOKEN")  # local testing only
    if token:
        from google.oauth2.credentials import Credentials

        kwargs["credentials"] = Credentials(token)
    return genai.Client(**kwargs), types


def _prompt(patient: dict, plan: dict) -> str:
    lang = patient.get("language") or "en"
    context = {
        k: patient.get(k)
        for k in ("age", "sex", "diagnosis", "diagnosisGroup", "protocol", "cycle", "language",
                  "weightKg", "heightCm", "bsaM2", "chemo", "activeMeds", "history", "riskFactors")
    }
    return f"""You are assisting a paediatric oncologist with chemotherapy-induced nausea and vomiting (CINV)
prophylaxis. A validated rules engine has ALREADY computed the plan below. Your job is only to explain it.

STRICT RULES:
- Use ONLY drugs, doses, routes, days and frequencies that appear verbatim in PLAN. Never invent, change,
  round or add any drug or dose. If something is not in PLAN, do not mention it.
- Do not give your own clinical recommendation.

Return a JSON object with exactly two string fields:
- "summary": for the oncologist, in English, at most 5 bullet sentences (each line starting with "- "):
  emetogenic tier and why; dexamethasone status; key antiemetic doses exactly as given; interactions;
  step-ups based on previous cycles (if any).
- "familyExplanation": a short, warm, plain-language explanation for the child and family, written in
  {LANG_NAMES.get(lang, 'English')}, no jargon, mentioning what medicines will be given and what to do if
  nausea comes anyway (only using the plan's breakthrough options).

PATIENT CONTEXT:
{json.dumps(context, ensure_ascii=False)}

PLAN:
{json.dumps(plan, ensure_ascii=False)}
"""


def summarise(patient: dict, plan: dict) -> tuple[dict | None, str | None]:
    """(ai dict, None) on success or (None, error string) on any failure. Never raises."""
    if _truthy(os.getenv("AIMESIS_AI_DISABLED")):
        return None, "AI summary disabled (AIMESIS_AI_DISABLED)"
    model = os.getenv("AIMESIS_GEMINI_MODEL", DEFAULT_MODEL)
    try:
        client, types = _client()
        resp = client.models.generate_content(
            model=model,
            contents=_prompt(patient, plan),
            config=types.GenerateContentConfig(temperature=0.2, response_mime_type="application/json"),
        )
        text = (resp.text or "").strip()
        text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text)
        data = json.loads(text)
        return {
            "summary": str(data.get("summary", "")).strip(),
            "familyExplanation": str(data.get("familyExplanation", "")).strip(),
            "model": model,
        }, None
    except Exception as exc:  # noqa: BLE001 - AI is best-effort; plan must still be returned
        return None, f"{type(exc).__name__}: {exc}"[:500]
