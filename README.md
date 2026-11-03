# pamflow Desktop

A desktop app (Windows, macOS, Linux) for the
[pamflow](https://github.com/pradeeshwarrj/pamflow) passive acoustic
monitoring workflow: from raw recordings to detections, validation, occupancy
histories and reports, without writing code.

The interface is built with Tauri (Rust) and SvelteKit. The analysis is done by
the pamflow R package, which comes inside the installer together with R, Python,
BirdNET, ffmpeg and pandoc, so users install nothing else.

**Status:** version 0.1.0, in testing. Windows and macOS installers have been
tried by hand; all four systems are built and checked on GitHub.

## What it does

| Step | What happens |
|---|---|
| **Project** | Open a project folder, start a new one with default settings, or try the example project. Choose the recordings folder, deployment sheet and BirdNET model; edit every setting. |
| **Standardize** | Optional first pass over raw recordings: one tidy, consistently named set of FLAC or WAV files, with memos, non-audio and corrupt files set aside. Raw files are never changed. |
| **Scan** | Reads every recording, checks quality (unreadable, truncated, duplicates, gaps) and matches it to the deployment sheet. |
| **Filter** | High-pass filter against wind and traffic noise, with progress, stop and continue. |
| **Detect** | Runs BirdNET (your own classifier, or BirdNET's global model) on all recordings. Progress is saved after every batch, so a stopped run continues where it stopped. |
| **Process** | Cleans the detections: merges overlaps, applies confidence, species and date rules. |
| **Validate** | Draws events for review (stratified, random or rare species), shows the clip and its spectrogram, and calculates precision by species and confidence. |
| **Occupancy** | Builds a detection history per species and the input for occupancy models. |
| **Report** | Writes an HTML report and an Excel workbook. |

Everything stays on your computer. Nothing is uploaded; the only thing that
needs internet is the optional download of BirdNET's own model.

## For users

### Install

Download the installer for your system from the
[Releases](https://github.com/pradeeshwarrj/pamflow-desktop/releases) page.

| System | File | Size |
|---|---|---|
| Windows | `pamflow_<version>_x64-setup.exe` (installs for your user, no administrator needed) | about 1 GB |
| macOS, Apple Silicon | `pamflow_<version>_aarch64.dmg` | about 0.8 GB |
| macOS, Intel | `pamflow_<version>_x64.dmg` | about 0.9 GB |
| Linux | `.AppImage` (any distribution) or `.deb` (Ubuntu, Debian) | about 1.3 GB |

You need about **6 GB of free disk space**: the analysis engine takes 4–4.5 GB
once unpacked.

**The first start sets up the analysis engine.** pamflow shows a "Setting up
pamflow" screen for 1–5 minutes while it unpacks R, Python, BirdNET and ffmpeg
into your user folder. This happens once (and again only after an update that
changes the engine). No internet is needed.

The installers are not yet signed, so your system will warn you:

- **Windows:** "Windows protected your PC": choose **More info**, then **Run anyway**.
- **macOS:** if it says pamflow "is damaged and can't be opened", drag it into
  Applications and run this once in Terminal, then open it normally:
  ```bash
  xattr -cr /Applications/pamflow.app
  ```
- **Linux AppImage:** make it executable (`chmod +x pamflow_*.AppImage`) and run it.

### Your first project

1. Open pamflow and, on the **Project** step, either:
   - choose a folder and press **Open**. If the folder has no settings yet,
     press **Start with the default settings**; or
   - press **Try with example data** to get a small ready-made project in your
     Documents folder (six short tones with sample detections). Scan, Process,
     Validate, Occupancy and Report work on it; Detect needs a model.
2. Set the **recordings folder**, the **deployment sheet** and the **BirdNET
   model** on the same screen, then press **Save to config.yml**.
3. Work down the steps in the sidebar.

### The settings file

Every project has one settings file (`config.yml`). A new project gets pamflow's
own default settings, written to `<project>/config/config.yml`, so there is
nothing to prepare. Settings you change on screen are saved to that file with
your comments kept; the previous version goes to a `backups` folder next to it.

It can live anywhere: **Save as…** (on every settings bar) writes the settings to
a file you choose and the app uses that file from then on, and **Open another
settings file…** opens one. A settings file outside the project's `config` folder
records the project folder, so the paths inside still work.

### BirdNET models

On the **Project** step, under **BirdNET model**, choose:

- **BirdNET default (global):** BirdNET's own model for about 6,500 species
  worldwide. **Download the model** fetches it once (about 73 MB, from
  [zenodo.org](https://zenodo.org/records/15050749)); it is then shared by all
  your projects, and you can pick the language of the species names.
- **My own classifier:** a `.tflite` classifier trained with BirdNET-Analyzer,
  with its `_Labels.txt` beside it.

BirdNET's models are free for research and other non-commercial use
(CC BY-NC-SA 4.0). Please cite Kahl et al. (2021), *BirdNET: A deep learning
solution for avian diversity monitoring*, Ecological Informatics 61, 101236.

### Long runs

- While Detect, Filter, Standardize, Scan, Process, Report or a model download
  run, the computer is kept from going to sleep on its own. Closing the lid or
  choosing Sleep yourself still sleeps it.
- Closing the window during a run asks first. Stopping is safe: the run
  continues where it stopped on the next **Start**.

### Where things are stored

| What | Windows | macOS | Linux |
|---|---|---|---|
| Analysis engine | `%LOCALAPPDATA%\org.pamflow.desktop\runtime` | `~/Library/pamflow/runtime` | `~/.local/share/pamflow/runtime` |
| Downloaded models | `%LOCALAPPDATA%\org.pamflow.desktop\models` | `~/Library/pamflow/models` | `~/.local/share/pamflow/models` |
| Your project, results and settings | the project folder you chose | | |

Uninstalling the app does not remove the analysis engine; delete the `runtime`
folder above to get the space back.

### When something goes wrong

Press **Save diagnostics** at the bottom of the sidebar. It writes one text
file with versions, system information, your settings file and the end of
pamflow's logs, and shows it in its folder. Look it over (it can contain folder
paths, and so your user name), then attach it to an
[issue](https://github.com/pradeeshwarrj/pamflow-desktop/issues).

## For developers

### Requirements

[Node.js](https://nodejs.org) 22 and [pnpm](https://pnpm.io), the
[Rust](https://rustup.rs) toolchain (with the platform's Tauri requirements),
and [pixi](https://pixi.sh) for the analysis engine.

### Run it

```bash
pnpm install

# the analysis engine (first time: 10-20 minutes, 4+ GB)
cd runtime
pixi install
pixi run setup-r
cd ..

pnpm tauri dev
```

In a plain browser (`pnpm dev`) the interface shows demo data instead; the
first Rust build takes a few minutes. Without the engine built, the app starts
but cannot run anything; point `PAMFLOW_RUNTIME` at an engine folder to use one
from somewhere else.

### Tests and checks

```bash
pnpm check                                   # types for the interface
cd src-tauri && cargo test --lib             # Rust
cd .. && Rscript bridge/tests/test_protocol.R
Rscript bridge/tests/test_config_edit.R <path to pamflow's config_template.yml>
```

### How it fits together

```
interface (Svelte)  <->  Rust (Tauri)  <->  Rscript bridge/run_job.R <job.json>  ->  pamflow
```

- The interface asks for a **job** (`scan`, `detect`, `config_save`, ...).
- Rust writes the job to a small JSON file and starts R from the bundled engine.
- R runs pamflow and prints progress as `@@PAM {json}` lines; Rust passes them on
  to the screen. Stop ends R and everything it started.
- pamflow is used exactly as published; the app never edits it. Small
  adjustments are made inside the app's own R session
  (`bridge/pamflow_patches.R`).

See [`bridge/README.md`](bridge/README.md) for the jobs and
[HOW-TO-CHANGE.md](HOW-TO-CHANGE.md) for where each kind of change goes.

### Layout

```
src/
  lib/
    theme/       tokens.css (colours and sizes), base.css, light/dark switch
    config/      stages.ts (the workflow steps)
    i18n/        en.json (all text)
    backend/     the stores that talk to Rust and hold each screen's state
    components/  reusable building blocks
    screens/     one *Live.svelte (in the app) and one *Demo.svelte (in a browser) per step
    mock/        demo.ts (demo numbers for the browser version)
  routes/        one folder per screen
bridge/          the R side: run_job.R and helpers, download_model.py, tests
runtime/         the recipe and scripts for the bundled analysis engine
src-tauri/       Rust (jobs, first-launch setup, runtime lookup) and app settings
```

### GitHub workflows

| Workflow | What it checks or does |
|---|---|
| `runtime-check` | Builds the analysis engine on Windows, both Macs and Linux and runs its smoke test. |
| `runtime-pack` | Packs the engine as the installer will, unpacks it somewhere else and runs the smoke test from there. |
| `app engine checks` (`model-check.yml`) | Downloads BirdNET's own model and runs a detection with it; runs the example project, Scan, Process and the diagnostics file through the app's engine. |
| `release` | Builds the installers for all four systems and attaches them to a **draft** release. |

Start any of them from the repository's **Actions** tab. GitHub only reads
workflow files in `.github/workflows/`.

### Make a release

1. Set the version in `package.json`, `src-tauri/Cargo.toml` and
   `src-tauri/tauri.conf.json`, and add the changes to
   [CHANGELOG.md](CHANGELOG.md).
2. Run the **release** workflow (or push a tag such as `v0.1.0`). It takes
   30-60 minutes.
3. Try the installers from the draft release, then press **Publish release**.

The engine inside the installer is described in
[`runtime/README.md`](runtime/README.md).

## Licenses and credits

- pamflow Desktop: MIT (see `package.json`).
- pamflow, the R package: MIT.
- BirdNET models: CC BY-NC-SA 4.0 (non-commercial); downloaded by the user, not
  shipped in the installer.
- R, Python, TensorFlow, ffmpeg, pandoc and the other packages in the engine keep
  their own licenses.
