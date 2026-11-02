"""
Pack the R packages that are not conda packages (tuneR, seewave, pamflow,
and av on Apple Silicon) into one archive, so the installer can add them to
the runtime after it is unpacked on the user's computer.

    pixi run python scripts/pack_extras.py <output.tar.gz>

A package counts as "extra" when no file of it is listed in conda-meta/
(the record of what conda installed). Everything else comes from the
runtime pack (pixi-pack) itself.
"""
import json
import os
import subprocess
import sys
import tarfile
from pathlib import Path


def r_library() -> Path:
    out = subprocess.run(
        ["Rscript", "-e", "cat(normalizePath(.libPaths()[1], winslash = '/'))"],
        check=True, capture_output=True, text=True,
    ).stdout.strip()
    return Path(out)


def conda_owned_packages(prefix: Path, library: Path) -> set[str]:
    """Names of R packages that some conda package installed."""
    lib_rel = os.path.relpath(library, prefix).replace("\\", "/").lower().rstrip("/") + "/"
    owned = set()
    for meta in (prefix / "conda-meta").glob("*.json"):
        try:
            files = json.loads(meta.read_text(encoding="utf-8")).get("files", [])
        except (OSError, ValueError):
            continue
        for f in files:
            f = f.replace("\\", "/")
            if f.lower().startswith(lib_rel):
                owned.add(f[len(lib_rel):].split("/", 1)[0])
    return owned


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    out = Path(sys.argv[1]).resolve()
    prefix = Path(os.environ["CONDA_PREFIX"]).resolve()
    library = r_library()
    owned = {p.lower() for p in conda_owned_packages(prefix, library)}
    extras = sorted(
        d.name for d in library.iterdir()
        if d.is_dir() and (d / "DESCRIPTION").exists() and d.name.lower() not in owned
    )
    if not extras:
        print("No extra R packages found: run `pixi run setup-r` first.")
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(out, "w:gz") as tar:
        for name in extras:
            tar.add(library / name, arcname=name)
    print(f"R library: {library}")
    print(f"Extra R packages ({len(extras)}): {', '.join(extras)}")
    print(f"Wrote {out} ({out.stat().st_size / 1024**2:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
