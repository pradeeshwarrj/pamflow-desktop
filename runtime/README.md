# Bundled runtime

Everything pamflow Desktop needs to do the analysis, in one folder that
ships inside the installer. Users never install R, Python or ffmpeg.

| Part | Version | Source |
|---|---|---|
| R | 4.5 | conda-forge |
| pamflow's R packages | latest | conda-forge (tuneR, seewave from CRAN) |
| pamflow | GitHub main | `scripts/install_r_extras.R` |
| Python | 3.12 | conda-forge |
| BirdNET (`birdnet`) | 0.2.16 (`>=0.2.16,<0.3`, same as pamflow) | PyPI |
| TensorFlow | 2.21 (2.16 on Intel Macs) | PyPI |
| ffmpeg | 8.x | conda-forge |
| pandoc | 3.x (for the HTML report) | conda-forge |

`pixi.toml` is the recipe. It is solved for Windows, Apple Silicon Mac,
Intel Mac and Linux.

## Build and test it (Windows)

In PowerShell, from this folder:

```powershell
cd F:\Pradeeshwar\pamflow-desktop\runtime
pixi install        # downloads R, Python, BirdNET, ffmpeg (~2–4 GB, 10–20 min)
pixi run setup-r    # adds tuneR, seewave and pamflow
pixi run smoke      # checks everything
```

Then the full test with your own model and one recording:

```powershell
pixi run smoke E:/Pradeeshwar/pamflow_pilot/model/BirdNet_v2_custom.tflite E:/Pradeeshwar/pamflow_pilot/model/BirdNet_v2_custom_Labels.txt <path to one .wav>
```

The runtime is built in `runtime\.pixi\` (ignored by git). `pixi.lock`,
created by `pixi install`, records the exact versions: commit it.

## Which pamflow is used

pamflow is always **downloaded from GitHub** at a fixed version, set by
`PAMFLOW_VERSION` in `scripts/install_r_extras.R` (now: the 0.6.0 commit).
No local copy of pamflow is used or changed. To move to a newer pamflow,
change that one line and run `pixi run setup-r` again.

## App-side adjustments to pamflow

`bridge/pamflow_patches.R` (in the project's main folder) holds small adjustments the app makes to pamflow
**inside its own R session after loading it**; pamflow itself is untouched.

- **Windows Python location.** pamflow expects a Python virtual environment
  (`Scripts\python.exe` on Windows). This runtime keeps Python at
  `python.exe` in the top folder, so the app tells pamflow where to look.
  macOS and Linux need nothing.

Each adjustment can be deleted once pamflow handles that case itself.

## Size

The Linux runtime is about 4.4 GB on disk, of which TensorFlow is 1.9 GB
and the C compiler (only needed on macOS/Linux to build tuneR and seewave)
several hundred MB. Ways to shrink it are listed for Phase 4:
drop the compiler after building, and use BirdNET's lighter `litert`
backend instead of full TensorFlow where possible.
