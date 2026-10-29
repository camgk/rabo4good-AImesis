"""Check that every `src.quote` in a rulebook appears on the cited page of the
source policy text. Run: python tools/verify_sources.py [rules.yaml] [source.txt]

The source text is produced with `pdftotext <policy.pdf> sources/uza_v2_policy.txt`
(pages are separated by form feeds). Whitespace is normalised before matching.
Exit code 1 if any quote is missing — use it as a CI gate.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]


def _norm(s: str) -> str:
    s = s.replace(" ", " ").replace("’", "'").replace("‘", "'")
    return re.sub(r"\s+", " ", s).strip().lower()


def iter_sources(node, path="$"):
    """Yield (yaml_path, page, quote) for every src block in the rulebook."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "src":
                items = v if isinstance(v, list) else [v]
                for i, s in enumerate(items):
                    yield f"{path}.src[{i}]", s["page"], s["quote"]
            else:
                yield from iter_sources(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from iter_sources(v, f"{path}[{i}]")


def verify(rules_path: Path, source_path: Path) -> list[str]:
    rules = yaml.safe_load(rules_path.read_text(encoding="utf-8"))
    pages = [_norm(p) for p in source_path.read_text(encoding="utf-8").split("\f")]
    errors = []
    count = 0
    for where, page, quote in iter_sources(rules):
        count += 1
        if page < 1 or page > len(pages) or _norm(quote) not in pages[page - 1]:
            errors.append(f"{where}: quote not found on page {page}: {quote!r}")
    return errors, count


def main(argv: list[str]) -> int:
    rules = Path(argv[1]) if len(argv) > 1 else ROOT / "rules" / "uza_v2.yaml"
    source = Path(argv[2]) if len(argv) > 2 else ROOT / "sources" / "uza_v2_policy.txt"
    errors, count = verify(rules, source)
    for e in errors:
        print("MISSING", e)
    print(f"{count - len(errors)}/{count} quotes verified against {source.name}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
