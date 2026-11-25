# The system today

How pamflow Desktop works now. Everything here was read from the code; where a
behaviour is described in a comment but not checked, it says so.

## 1. Architecture

```
SvelteKit UI (src/)                       window
   |  invoke("start_job", spec)           events "@@PAM {json}" back
   v
Rust shell (src-tauri/src/)               jobs.rs, runtime.rs, setup.rs, validation.rs
   |  starts:  Rscript bridge/run_job.R <job.json>     (one process per job)
   v
R bridge (bridge/*.R)  ->  pamflow R package  ->  ffmpeg, tuneR/seewave/soundecology,
                                                   av, rmarkdown/pandoc, openxlsx
                                              ->  Python: pam_birdnet_predict.py
                                                   -> birdnet package -> TensorFlow Lite
```

- A **job** is one run of `Rscript bridge/run_job.R job.json`. The job file
  names the job (for example `scan`, `detect`, `soundscape`) and the project.
- The job prints **events**, one per line, as `@@PAM {json}` on stdout. The
  Rust shell forwards them to the window. Every job ends with
  `{"type":"finished","status":"ok"|"failed","message":...}`.
- **Long jobs** (`is_long` in `jobs.rs`: standardize, scan, filter, detect,
  soundscape) can be stopped; the app keeps a lock, and closing the window
  asks first. A stopped job resumes where it stopped (checkpoint files).
- The interface keeps no analysis state: every screen reads its results by
  running a short job (for example `scan_results`, `process_results`).

### Rust shell (already Rust, about 1,000 lines)

| File | Does |
|---|---|
| `jobs.rs` | `start_job`, `stop_job`, close prompt, quit, free disk space, runtime info; one process per job, stdout lines to events; stops jobs on exit |
| `runtime.rs` | finds the bundled R/Python runtime and builds the command line with its environment |
| `setup.rs` | first launch: unpacks the runtime that ships in the installer (tar.gz) into the user's data folder, with progress |
| `validation.rs` | `save_validation_answer` (writes the answer into the results CSV atomically), `allow_media_folder` (lets the window show clips and plots; accepts only folders named `validation` or `plots`) |
| `capabilities/default.json` | permissions: open path scopes for reports (`report_*.html`, `Soundscape_Report_*.html`) and so on |

Crates used: tauri 2, tauri-plugin-opener, tauri-plugin-dialog, serde,
serde_json, csv, fs4, flate2, tar, dunce, keepawake.

### Interface (Svelte, TypeScript)

Screens in `src/lib/screens/` (each with a `*Live` version wired to the engine
and a `*Demo` used when running in a plain browser): Project, Standardize,
Scan, Filter, Detect, Process, Validate, Occupancy, Report (workflow A) and
Soundscape, Visualize (workflow B). The workflow toggle (A or B) is in the
sidebar (`src/lib/workflow/`, `src/lib/config/stages.ts`). Backend stores are
in `src/lib/backend/*.svelte.ts`; `tauri.ts` is the only file that calls the
engine (`runJob`, `startJob`, events). Text is in `src/lib/i18n/en.json`.

If the engine is replaced and the event contract (section 5) is kept, the
interface needs no change.

## 2. The two workflows

| Step | A (detection) | B (soundscape) |
|---|---|---|
| Project (settings) | yes | yes, soundscape settings |
| Standardize | yes | yes |
| Scan | yes | yes |
| Filter | yes | no |
| Soundscape | no | yes |
| Visualize | no | yes |
| Detect (BirdNET) | yes | no |
| Process | yes | no |
| Validate | yes | no |
| Occupancy | yes | no |
| Report | yes | no |

## 3. Steps in detail (what the engine must do)

Settings come from `config.yml` (template:
`pamflow/inst/extdata/config_template.yml`, 148 lines; sections `paths`,
`filenames`, `standardization`, `deployments`, `audio`, `qc`, `filter`,
`birdnet`, `processing`, `soundscape`, `validation`, `recall`, `occupancy`,
`report`). A project folder normally has `config/config.yml`; paths in it that
are not absolute are relative to `paths.project_root`.

### 3.1 Project (inspect)

Reads the config, finds the project, counts recordings and their size, reads
the deployment sheet row count, checks the model and labels, and reports
settings the screen can edit (list in `EDITABLE` in `bridge/run_job.R`, about
80 settings). Saving settings changes only the edited lines of `config.yml`
and keeps every comment and blank line (`bridge/config_edit.R`), validates the
result by reading it, and keeps a dated backup in `config/backups/`.
**A Rust version needs a comment-preserving YAML line editor**, not a normal
YAML writer. The tests in `bridge/tests/test_config_edit.R` define the
behaviour (30 checks) and are the thing to port.

### 3.2 Standardize (pamflow Stage 00, `00_standardization.R`, 526 lines)

Triage of raw recordings: reads every file's header, plans what happens to
each (keep, convert, rename from the timestamp in the name or metadata, move
non-audio and short memo files to an `isolated` folder), then copies or
converts into the standardized folder. Formats handled: wav, flac, mp3, m4a,
ogg, wma, aiff. Conversion uses `av` (libav). Output plan table:
`metadata/00_standardization_plan.csv`; headers table:
`metadata/audio_headers.csv`. A dry run ("plan") writes only the plan. Raw
files are never changed or deleted.

### 3.3 Scan (Stage 01, `01_scan_audio.R`, 334 lines)

Reads the header of every recording (duration, sample rate, channels), parses
grid and start time from the file name with the `filenames.pattern` regex and
time zone, reads the deployment sheet (CSV: deployment id, recorder, grid,
habitat, deployer, latitude, longitude, deploy and retrieve dates and times),
matches each recording to a deployment, flags quality problems (QC) and writes
`metadata/audio_master.csv`. Resumable: a re-scan reads only new files unless
forced. Corrupt durations must be ignored when summing hours (a known bug:
one file reported -9.2e12 s).

### 3.4 Filter (Stage 02, `02_filter_audio.R`, 274 lines)

Optional Butterworth high-pass (order and cutoff from config) applied with
ffmpeg, in parallel, writing to `data/filtered`. The filter is built as a
cascade of 2-pole sections because ffmpeg's `highpass` supports only 2 poles.

### 3.5 Detect (Stage 03, `03_detect*.R` plus `inst/python`)

Runs BirdNET on every recording in batches, in separate processes so a corrupt
file cannot crash the session. Inputs: the model (`.tflite`) and labels
(`*_Labels.txt`, one species per line in model output order), either BirdNET's
global model (downloaded by the app, non-commercial licence, not shipped) or
the user's own classifier. Settings: minimum confidence, window overlap
(0 to 3 s), workers (default half the physical cores), top-k per window,
sigmoid sensitivity, bandpass on or off with limits, batch size, producers
(decoding threads), device (CPU), audio input (standardized or filtered).
Output per batch: detections CSV with columns `input, start_time, end_time,
species_name, confidence` and a status CSV per file. Checkpointing through a
`done` list (`checkpoint.R`) so a stopped run continues. The run name
(`birdnet.run_id`) names the output folder under `data/detections/`.

### 3.6 Process (Stage 04, `04_process_detections.R`)

Cleans detections: minimum confidence, species whitelist and blacklist, per
species thresholds file (CSV `scientific_name, threshold`), species season
file (`scientific_name, month_start, month_end`), date range, removal of
detections outside deployment dates, merging windows closer than N seconds
into one event (default 3 = consecutive windows), maximum overrun. Output:
`detections_clean.csv` and related tables.

### 3.7 Validate (Stage 05, plus ground truth "recall" 05b)

Draws samples of detections for a human to review (stratified by species and
confidence band, random, or rare species), cuts clips and makes spectrogram
pictures with ffmpeg (padding, top frequency, picture size from config),
stores the reviewer's verdicts, and computes precision per species and
confidence band with Wilson confidence intervals. The recall check draws
random recording segments for listening to find missed detections, then
computes recall metrics. From validation metrics the app can choose one
confidence threshold per species (`07_species_thresholds.R`). In the app,
the answers are saved by Rust (`save_validation_answer`).

### 3.8 Occupancy (Stages 06 and 07)

Builds detection histories (sites by occasions) from detections and recording
effort, plus count histories, activity patterns (detections per recorded hour,
effort split across the clock hours a recording covers), species richness
(Hill numbers, rarefaction, Chao2), detection tables per time bin, and the
input for external model fitting (`pam_model_input`: matrix `y`, `siteCovs`,
`obsCovs`, optional standardized covariates and seasons). **No models are
fitted by the app.** Key settings: occasion length in days, minimum effort
hours per occasion, minimum detections per species, run name. Outputs include
`occupancy_summary.csv`.

### 3.8b Report (Stage 08, `08_report.R` plus `inst/rmd/pam_report.Rmd`)

Gathers results of all completed stages and writes HTML (rmarkdown and pandoc),
Excel (openxlsx) and, in pamflow itself, PDF reports. The desktop app offers
only HTML and Excel (the Report screen sends the chosen formats with the job;
`report.formats` in the config is not used by the app); pamflow's PDF needs
LaTeX, which the app does not bundle. Title and author from config.

### 3.9 Soundscape (Stage 2b, `02b_soundscape.R`, 771 lines)

For each recording (resampled to a target rate, cut into windows of
`window_mins` minutes or the whole file, optional high-pass at `low_stop_hz`
using a Butterworth `seewave::ffilter`), computes the chosen acoustic indices:

| Index | Source today |
|---|---|
| ACI Acoustic Complexity Index | `soundecology::acoustic_complexity` |
| ADI Acoustic Diversity Index (fmin, fmax, bin_step) | `soundecology::acoustic_diversity` |
| AEve Acoustic Evenness Index | `soundecology::acoustic_evenness` |
| Bio Bioacoustic Index (flim) | `soundecology::bioacoustic_index` |
| M Median Amplitude Envelope | `seewave::M` |
| NDSI (anthro_range, bio_range) | `soundecology::ndsi` |
| H Acoustic Entropy | `seewave::sh`, **returns empty in 0.6.0, hidden in the app** |

Both channels of each window are high-pass filtered and passed to the
index functions (check how soundecology combines left and right before
reimplementing); every call is wrapped so one bad file does not stop the run. Batches (default 50 files,
now a setting), workers, progress per batch, and a checkpoint:
`done.txt` (finished files) plus `soundscape_raw.csv` appended after each
batch. Output folder: `<project_root>/data/soundscape/<run_id>/`. A change of
settings or indices must not mix with old results: the app moves old results
into `old_<time>/` (`pd_archive_stale_soundscape`). When a run finishes
completely, pamflow writes hourly, diel and site-covariate summaries by site
and day or night (day hours setting `[first, last]`). The app can also build
the summaries from the raw results of a partial run
(`pam_soundscape_summarise`).

### 3.10 Visualize (Stage 2c, `02c_soundscape_vis.R`)

24-hour diel curves per index and site (`diel_hourly_<index>.png`), day and
night comparison (`diel_phase_<index>.png`) in `plots/`, and an HTML report
`reports/Soundscape_Report_<run_id>.html` from `inst/rmd/soundscape_report.Rmd`.
Known limit: ignores a custom soundscape output folder.

## 4. Files on disk (the compatibility surface)

| File or folder | Written by | Notes |
|---|---|---|
| `config/config.yml`, `config/backups/` | Project | comments must survive edits |
| `metadata/deployments.csv` | the user | required by Scan |
| `metadata/00_standardization_plan.csv`, `audio_headers.csv` | Standardize | |
| `metadata/audio_master.csv` | Scan | the central table: every recording, its deployment and QC flags |
| `data/standardized/`, `data/filtered/`, `data/isolated/` | Standardize, Filter | |
| `data/detections/<run_id>/...` | Detect | per-batch CSVs and checkpoint |
| `detections_clean.csv` and process tables | Process | |
| validation sample, results CSV, clips, spectrograms | Validate | folder named `validation` |
| `occupancy_summary.csv` and histories | Occupancy | |
| `report_*.html`, Excel, PDF | Report | |
| `data/soundscape/<run_id>/{done.txt, soundscape_raw.csv, *.csv, plots/, reports/, old_*/, settings_used.json}` | Soundscape, Visualize | |
| `logs/` | all | |

Run `pam_example_project()` (or "Try with example data") to get a small project
and compare every file's columns against a Rust run.

## 5. The event contract (interface to engine)

Each line: `@@PAM ` then a JSON object with a `type`. Types the bridge emits
(`pd_emit` in `bridge/*.R`): `started`, `log`, `stage`, `total`, `files`,
`finished`, `scan`, `soundscape`, `processed`, `config_saved`, `std_state`,
`report_preview`, `report_done`, `project`, `project_created`, `prep`,
`no_config`, `model_input`, `model_info`, `metrics`, `filter_info`, `drawn`,
`example_created`, `diagnostics_saved`. The interface also reacts to
`exit` (added by the Rust shell when the process ends), `download`, `text`,
`occupancy` and `validation` (see `src/lib/backend/*.ts`). The exact fields
are defined where the interface reads them (search `src/lib/backend/` for
`e.type ===`) and where the bridge emits them (`pd_emit` in
`bridge/run_job.R`). The log parser (`pd_parse_log` in `bridge/protocol.R`)
turns pamflow's text log lines into progress events (for example "soundscape
processing for N remaining files", "Soundscape Batch b/n complete"); a Rust
engine should emit these events directly instead of printing text to parse.

Job names (23 job functions plus a few inline): `inspect`, `project_create`,
`config_save`, `config_save_as`, `model_info`, `model_download`,
`diagnostics`, `example_project`, `std_state`, `std_plan`, `standardize`,
`scan`, `scan_results`, `filter_info`, `filter`, `detect`, `process`,
`process_results`, `validation_state`, `validation_draw`,
`validation_metrics`, `occupancy_build`, `occupancy_results`, `model_input`,
`soundscape`, `soundscape_results`, `soundscape_vis`, `report_preview`,
`report`.

## 6. Packaging and release today

- `runtime/pixi.toml` defines the bundled runtime (R, Python, ffmpeg, pandoc)
  for win-64, osx-arm64, osx-64, linux-64; `pixi.lock` pins it.
- `runtime-pack.yml` builds and packs it; `release.yml` builds installers
  (Windows `.exe`, macOS `.dmg` for both architectures, Linux `.AppImage` and
  `.deb`) and makes a draft release; the other workflows run tests, runtime
  checks and the website.
- First launch unpacks the runtime (`setup.rs`).

All of this becomes unnecessary or much smaller once the engine is Rust.

## 7. Known problems worth fixing in a rewrite

- Soundscape batch size is fixed at 50 inside pamflow; the app patches it.
- The soundscape index list is inverted by the config merge (see README).
- Acoustic Entropy (H) is empty.
- Plots and report ignore a custom output folder.
- Failed files are counted but not named.
- Old result folders (`old_*`) are never cleaned.
- `audio.sample_rate`, `qc.*`, `filter.ffmpeg_path`, `filter.chunk_size` and a
  few other settings exist in the template but have no field in the app.
