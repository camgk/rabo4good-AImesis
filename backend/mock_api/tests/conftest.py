import os
import sys
from pathlib import Path

os.environ.setdefault("STORE", "memory")
os.environ.setdefault("TOKEN_SECRET", "test-secret")
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
