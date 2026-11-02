"""
Add the extra R packages (from pack_extras.py) to an unpacked runtime.

    <runtime>/python add_extras.py <runtime folder> <r-extras.tar.gz>

Run with the runtime's own Python. The packages go into the runtime's R
library (found by asking its Rscript), replacing any older copy.
"""
import os
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path


def rscript(env: Path) -> Path:
    if os.name == "nt":
        return env / "Lib" / "R" / "bin" / "Rscript.exe"
    return env / "bin" / "Rscript"


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    env = Path(sys.argv[1]).resolve()
    archive = Path(sys.argv[2]).resolve()
    run_env = dict(os.environ, R_LIBS_USER="NULL", R_LIBS="", R_PROFILE_USER="NULL",
                   R_ENVIRON_USER="NULL", CONDA_PREFIX=str(env))
    run_env.pop("R_HOME", None)
    res = subprocess.run(
        [str(rscript(env)), "-e", "cat(normalizePath(.libPaths()[1], winslash = '/'))"],
        capture_output=True, text=True, env=run_env,
    )
    if res.returncode != 0:
        print(f"The runtime's R did not start ({rscript(env)}):")
        print(res.stdout + res.stderr)
        return 1
    library = Path(res.stdout.strip())
    with tarfile.open(archive, "r:gz") as tar:
        names = sorted({m.name.split("/", 1)[0] for m in tar.getmembers()})
        for name in names:
            shutil.rmtree(library / name, ignore_errors=True)
        tar.extractall(library, filter="data")
    print(f"Added to {library}: {', '.join(names)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
