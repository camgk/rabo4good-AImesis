import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from aimesis_engine import Rulebook  # noqa: E402


@pytest.fixture(scope="session")
def rb():
    return Rulebook()
