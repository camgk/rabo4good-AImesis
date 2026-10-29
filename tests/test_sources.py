"""Rule fidelity: every rule's quote must exist on the cited policy page."""
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from verify_sources import verify  # noqa: E402

SOURCE = ROOT / "sources" / "uza_v2_policy.txt"
RULES = ROOT / "rules" / "uza_v2.yaml"

needs_source = pytest.mark.skipif(not SOURCE.exists(), reason=(
    "sources/uza_v2_policy.txt missing — run: pdftotext 'Anti-emetica beleid CINV - V2.pdf' "
    "sources/uza_v2_policy.txt"))


@needs_source
def test_all_quotes_found_in_policy():
    errors, count = verify(RULES, SOURCE)
    assert count > 90
    assert errors == []


@needs_source
def test_verifier_catches_invented_quote(tmp_path):
    fake = tmp_path / "fake.yaml"
    fake.write_text("x: {src: {page: 2, quote: 'Ondansetron 10 mg/m² max 16 mg'}}", encoding="utf-8")
    errors, _ = verify(fake, SOURCE)
    assert len(errors) == 1


def test_every_rule_has_a_source():
    import yaml
    rb = yaml.safe_load(RULES.read_text(encoding="utf-8"))
    for agent_id, a in rb["agents"].items():
        for r in a["rules"]:
            assert r.get("src", {}).get("quote"), f"{agent_id}/{r['id']} has no source"
    for section in ("combinations",):
        for r in rb[section]:
            assert r.get("src", {}).get("quote"), r["id"]
    for drug, d in rb["dosing"].items():
        assert d.get("src"), drug
