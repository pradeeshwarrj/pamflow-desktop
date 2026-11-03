# Bundled runtime (the analysis engine)

Everything pamflow Desktop needs to do the analysis, in one folder that ships
inside the installer. Users never install R, Python or ffmpeg.

| Part | Version | Source |
|---|---|---|
| R | 4.5 | conda-forge |
| pamflow's R packages | latest | conda-forge (tuneR and seewave from CRAN) |
| pamflow | a fixed GitHub commit (the 0.6.0 release) | `scripts/install_r_extras.R` |
| Python | 3.12 | conda-forge |
| BirdNET (`birdnet`) | 0.2.16 (`>=0.2.16,<0.3`, as pamflow requires) | PyPI |
| TensorFlow | 2.21 (2.16 on Intel Macs) | PyPI |
| ffmpeg | 8.x | conda-forge |
| pandoc | 3.x (for the HTML report) | conda-forge |

`pixi.toml` is the recipe and `pixi.lock` records the exact versions (commit
it). It is solved for Windows, Apple Silicon Mac, Intel Mac and Linux. The
runtime is sealed off from any R or Python the user already has (no personal R
library, no `.Rprofile`).

BirdNET's own model is **not** part of the runtime: it is non-commercially
licensed, so the user downloads it from inside the app
(`bridge/download_model.py`).

## Build and test it

From this folder:

```bash
pixi install        # downloads R, Python, BirdNET, ffmpeg (4+ GB, 10-20 min)
pixi run setup-r    # adds tuneR, seewave and pamflow
pixi run smoke      # checks everything
```

The full test with your own model and one recording:

```bash
pixi run smoke <model.tflite> <labels.txt> <one recording.wav>
```

The runtime is built in `runtime/.pixi/` (ignored by git). Two more checks run
through the app's own engine (they are what the `app engine checks` workflow
runs):

```bash
pixi run Rscript scripts/check_default_model.R <models folder> <recording.wav>
pixi run Rscript scripts/check_example_project.R
```

## Which pamflow is used

pamflow is always **downloaded from GitHub** at a fixed commit, set by
`PAMFLOW_VERSION` in `scripts/install_r_extras.R` (now the 0.6.0 commit). No
local copy of pamflow is used or changed. To move to a newer pamflow, change
that one line and run `pixi run setup-r` again.

## App-side adjustments to pamflow

`../bridge/pamflow_patches.R` holds small adjustments the app makes to pamflow
**inside its own R session after loading it**; pamflow itself is untouched.

- **Windows Python location.** pamflow expects a Python virtual environment
  (`Scripts\python.exe` on Windows). This runtime keeps Python at `python.exe`
  in the top folder, so the app tells pamflow where to look. macOS and Linux
  need nothing.

Each adjustment can be deleted once pamflow handles that case itself.

## Packing it for the installer

The installer carries the runtime packed, and the app unpacks it on first start
(`src-tauri/src/setup.rs`).

| Script | What it does |
|---|---|
| `scripts/pack_extras.py` | Puts the R packages that are not conda packages (tuneR, seewave, pamflow) into `r-extras.tar.gz`. |
| `scripts/add_extras.py` | Adds that archive to an unpacked runtime (used by the check workflow; the app does the same in Rust). |
| `scripts/runtime_id.py` | Gives the runtime a name that changes when its recipe changes, so an updated app unpacks the new one once and removes the old. |

`pixi-pack` packs the conda packages and Python wheels into `runtime.tar`, and
`pixi-unpack` (shipped in the installer) unpacks it. The `release` workflow does
all of this; the `runtime-pack` workflow checks that a packed runtime still
works after being moved to another folder.

Two things this showed:

- A runtime has to be unpacked where it will stay: unpacking writes the real
  folder into the files that need it.
- On macOS and Linux, R cannot run from a folder with a space in its path, so
  the app unpacks into `~/Library/pamflow` and `~/.local/share/pamflow` (no
  spaces). Windows is fine with spaces.

## Size

| System | Packed (in the installer) | Unpacked on disk |
|---|---|---|
| Windows | about 1.0 GB | about 4.2 GB |
| macOS, Apple Silicon | about 0.8 GB | about 3.5 GB |
| macOS, Intel | about 0.8 GB | about 3.5 GB |
| Linux | about 1.2 GB | about 4.5 GB |

TensorFlow is the biggest part (about 1.9 GB unpacked on Linux). Ways to make it
smaller: use OpenBLAS instead of MKL on Windows (about 100 MB less to download),
and run detection with BirdNET's lighter LiteRT backend instead of TensorFlow
(installers of about 0.6 GB; needs pamflow to use `birdnet` 1.x, and Intel Macs
would keep TensorFlow).
