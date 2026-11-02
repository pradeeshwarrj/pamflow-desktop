"""
Print the id of this runtime build, e.g. "rt-osx-arm64-3f9c1a2b7d4e".

The id changes whenever what goes into the runtime changes (pixi.lock, the
R extras script), so an updated app unpacks its new runtime once and removes
the old one, while reinstalling the same version reuses what is there.

    python scripts/runtime_id.py <platform>
"""
import hashlib
import sys
from pathlib import Path

here = Path(__file__).resolve().parent.parent
h = hashlib.sha256()
for name in ["pixi.lock", "scripts/install_r_extras.R"]:
    h.update((here / name).read_bytes())
print(f"rt-{sys.argv[1]}-{h.hexdigest()[:12]}")
