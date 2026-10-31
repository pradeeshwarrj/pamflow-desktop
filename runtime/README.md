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

## Known issue: pamflow on Windows looks for `Scripts\python.exe`

pamflow expects a Python *virtual environment*, where Windows keeps Python in
`Scripts\python.exe`. In this runtime (a conda environment) it is at the top
of the folder: `python.exe`. On macOS and Linux both use `bin/python`, so it
already works there.

The smoke test line **"pamflow finds this Python"** shows whether this is
fixed. The fix is a few lines in pamflow's `R/birdnet_env.R`:

```r
pam_birdnet_python_path <- function(envdir) {
  if (.Platform$OS.type == "windows") {
    venv  <- file.path(envdir, "Scripts", "python.exe")   # virtual environment
    conda <- file.path(envdir, "python.exe")              # conda / pixi environment
    if (!file.exists(venv) && file.exists(conda)) conda else venv
  } else {
    file.path(envdir, "bin", "python")
  }
}
```

Then point pamflow at the runtime with `birdnet: python_env: <runtime folder>`
in the config (the app will do this automatically).

## Size

The Linux runtime is about 4.4 GB on disk, of which TensorFlow is 1.9 GB
and the C compiler (only needed on macOS/Linux to build tuneR and seewave)
several hundred MB. Ways to shrink it are listed for Phase 4:
drop the compiler after building, and use BirdNET's lighter `litert`
backend instead of full TensorFlow where possible.
