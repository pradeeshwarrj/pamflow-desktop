# Rust design, risks and plan

Read [01-current-system.md](01-current-system.md) first. Crate names below are
**candidates to evaluate**, not decisions: they were chosen from general
knowledge and not tested here, and crate maintenance and licences change. Check
each one (maintenance, licence, platform support, performance on a real
recording) before relying on it.

## 1. Scope

**In scope** (what the desktop app uses): config, project, standardize, scan,
filter, detect, process, validate (including the recall check), occupancy and
other tables, report, soundscape indices, soundscape plots and report.

**Out of scope unless the user asks** (in pamflow but not in the desktop app,
about 3,000 of its 11,600 lines): custom BirdNET classifier training
(`birdnet_train*.R`), the Shiny apps (`*_app.R`, `inst/app`), the benchmark and
cleanup helpers, and fitting occupancy models. The R package pamflow stays as
it is for R users; the Rust engine reimplements the app's needs, it does not
replace the package.

## 2. Proposed architecture

A Cargo workspace:

| Crate | Responsibility | Replaces |
|---|---|---|
| `pamflow-core` | config read, comment-preserving config editor, project discovery, paths, checkpoint files, CSV tables, job and event types, logging | `config.R`, `checkpoint.R`, `logging.R`, `bridge/config_edit.R`, `bridge/protocol.R` |
| `pamflow-audio` | decode (wav, flac, mp3, ogg, m4a), headers, resample, high-pass filter, windows, write wav/flac, clips, spectrogram pictures | `utils_audio.R`, `av`, `tuneR`, `seewave::ffilter`, ffmpeg calls |
| `pamflow-birdnet` | run BirdNET models on audio, batches, parallel workers | `03_detect*.R`, `pam_birdnet_predict.py`, the `birdnet` Python package |
| `pamflow-soundscape` | acoustic indices, batches, summaries, plots | `02b_soundscape.R`, `02c_soundscape_vis.R`, `soundecology`, `seewave` |
| `pamflow-analysis` | process detections, validation sampling and metrics, histories, activity, richness, thresholds, model input | `04_`, `05_`, `05b_`, `06_`, `07_*.R` |
| `pamflow-report` | HTML and Excel reports | `08_report.R`, `inst/rmd`, rmarkdown, pandoc, openxlsx |
| `pamflow-engine` | a command-line binary: `pamflow-engine job.json` runs one job and prints the same `@@PAM` events | `bridge/run_job.R` |
| `src-tauri` | the existing shell; starts the engine | `jobs.rs` and `runtime.rs` change, `setup.rs` mostly disappears |

### Decision: engine as a separate program

Keep the engine as its own binary, started by the shell like `Rscript` is
today, rather than linking it into the Tauri process. Reasons:

- The interface and the event contract stay unchanged, so the Svelte side
  needs no change.
- A corrupt audio file or a crash inside a native library cannot take down
  the window (the Python runner is separate for the same reason today).
- Jobs can be run and tested from a terminal without the app, as `run_job.R`
  can today.
- It allows the strangler approach below: the shell can send a job to the Rust
  engine or, until it is ready, to the R bridge.

Use `rayon` for parallel work on one machine; keep BirdNET workers as
processes or threads according to what the inference library allows.

### Libraries to evaluate

| Need | Candidates |
|---|---|
| YAML read | `serde_yaml` is archived, check `serde_norway` or `yaml-rust2`; **never write config with a YAML writer**, port the line editor |
| CSV | `csv` (already used), or `polars` for table work |
| Regex for file names | `regex` (check named groups `(?<grid>...)` and that the default pattern needs no look-around; otherwise `fancy-regex`) |
| Dates and time zones | `chrono` and `chrono-tz`; check `strptime` formats such as `%d-%m-%Y` against the deployment sheet |
| Audio decode | `symphonia` (wav, flac, mp3, ogg, m4a/aac; check AIFF; WMA is not supported, so decide: drop it, or bundle ffmpeg only for such files) |
| Audio write | `hound` (wav), `flacenc` (flac) |
| Resample | `rubato` |
| Filters | `biquad` or hand-written Butterworth sections (the R code uses a cascade of 2-pole sections) |
| FFT and spectrograms | `rustfft` or `realfft`, `image` for PNG |
| Plots | `plotters` (PNG, SVG), or draw charts in the Svelte UI from the CSV data and embed SVG in reports |
| TFLite | see Risks |
| Excel | `rust_xlsxwriter` |
| HTML report | `tera`, `minijinja` or `askama` templates |
| Parallelism | `rayon` |
| Errors and logging | `thiserror`, `tracing` |

## 3. Risks (in order of size)

### 3.1 Running BirdNET models in Rust (largest)

Today BirdNET runs through the Python `birdnet` package (0.2.16, API below
0.3) on TensorFlow Lite. The inputs are a `.tflite` model and a labels file, and
the user may bring their **own trained classifier**, so models cannot be
converted ahead of time by the project. Options:

1. **Link the TensorFlow Lite C library** from Rust (crates such as `tflitec`
   or `tflite`; check which are maintained). Needs a prebuilt TFLite library per
   platform bundled in the installer (tens of MB, not GB). Most likely path;
   verify that the BirdNET model's operators are supported by the
   library's build.
2. **ONNX Runtime (`ort`)**: needs ONNX models, so every user classifier would
   need conversion, which needs Python. Not suitable unless the project
   chooses to ship converted models only.
3. **Pure-Rust runtimes (`tract`, `candle`)**: check whether they can load these
   `.tflite` models and run the operators BirdNET uses. Unverified.

**Do a spike first** (before any other Rust work): load BirdNET's global model
and one custom classifier, run both on one recording and compare the detections
with the Python output. Read the `birdnet` package source (0.2.16) for the
exact preprocessing, which this document does not claim to know: window length,
sample rate, padding of the last window, overlap handling, how scores become
confidences (the config has `sigmoid_sensitivity`), the top-k rule and the
bandpass. The behaviour to match is `pam_birdnet_predict.py` plus the package.

If the spike fails, the fallback is to keep a small bundled Python for BirdNET
only; the rest of the app is still Rust and the installer is still much
smaller than today. State this to the user as the outcome of the spike.

### 3.2 Numerical parity of audio processing and indices

The indices must match the R results closely enough that existing projects'
results do not change. Differences can come from the resampler, filter design,
FFT window and normalization.

- Make **golden files from R before changing anything**: a fixed set of
  recordings (including mono, stereo, short, corrupt, different sample rates)
  run through the current app, with the raw outputs saved.
- Decide the acceptable tolerance per index (for example 1e-6 relative for
  exact algorithms, looser for ones depending on the resampler), and record
  it.
- **Licence check**: soundecology (GPL) and seewave (GPL-2 or later) are the
  reference implementations, and pamflow Desktop is MIT. Reimplementing by
  reading their source may create a derived work. Implement from the published
  papers (ACI: Pieretti et al. 2011; ADI and AEI: Villanueva-Rivera et al.
  2011; NDSI: Kasten et al. 2012; Bioacoustic Index: Boelman et al. 2007; M:
  Depraetere et al. 2012) and compare results against the R packages as black
  boxes. Get the user's decision on this.

### 3.3 Audio format coverage

ffmpeg (libav) reads nearly everything today. Check the formats in the real
projects (for example the 4,700 recordings, 1.3 TB project in `D:\PAM_GNI`)
before choosing decoders. Decide what happens with formats `symphonia` cannot
read (WMA at least).

### 3.4 Reports and plots

The HTML and PDF reports are R Markdown with ggplot2 charts. In Rust these
become templates plus generated charts. PDF is the hard one; the app does not
offer it today (it needs LaTeX), so keep it out of scope or generate it from
the HTML through the window's print function. Charts must look acceptable, but
need not be pixel-identical.

### 3.5 Edge cases that R handles implicitly

- Time zones and midnight-crossing recordings (effort split across days and
  hours, `06_occupancy.R`, `07_activity.R`).
- Corrupt headers (a file reported a duration of -9.2e12 s) and files that
  cannot be decoded: never stop the run, record the failure.
- Non-ASCII paths and file names on Windows.
- Very large projects: stream tables, do not load everything into memory.
- Resume after Stop or crash: checkpoint files must keep their format so an
  R-started run can be finished by the Rust engine, and the other way round.

## 4. Approach: replace job by job (strangler)

Do not rewrite everything and switch once. The shell starts a job with
`Rscript bridge/run_job.R`; change it so each job name is sent either to the
Rust engine or to the R bridge, chosen by a table. Each Rust job then ships as
soon as it passes its acceptance check, the app always works, and the R
runtime is removed only when the table has no R entries left.

## 5. Order of work

| Step | Work | Result |
|---|---|---|
| 0 | Decisions in the README of this folder; golden files from R; the BirdNET spike | go or no-go on pure-Rust BirdNET; test fixtures |
| 1 | `pamflow-core`: config read, comment-preserving editor (port `test_config_edit.R`, 30 checks), project discovery, event writer, `pamflow-engine` skeleton, shell routing table | jobs `inspect`, `config_save`, `config_save_as`, `project_create`, `diagnostics`, `example_project` in Rust |
| 2 | `pamflow-audio` and Scan, Standardize | jobs `scan`, `scan_results`, `std_*`, `standardize`; `audio_master.csv` identical in content |
| 3 | `pamflow-soundscape` | workflow B fully in Rust: `soundscape*`, plots, report. First release without the R and Python runtime for workflow B users |
| 4 | Filter, Process, Validate (clips, spectrograms, metrics) | jobs `filter*`, `process*`, `validation_*` |
| 5 | `pamflow-birdnet` (from the spike) | job `detect`, `model_*` |
| 6 | Histories, activity, richness, thresholds, model input, report | jobs `occupancy_*`, `model_input`, `report*` |
| 7 | Remove R and Python from the installer, delete `runtime/` and the first-launch unpack (`setup.rs`), update CI, installers and docs | the all-Rust release |

Steps 3 to 6 can be reordered; step 0 and the BirdNET spike come first
because they decide whether step 5 needs a bundled Python.

## 6. How to know each part is right

- **Golden comparison** per job: run the R app and the Rust engine on the same
  fixtures and compare output tables column by column (names, types, row
  counts, values within the recorded tolerance). Keep the comparison script in
  the repository so it can be re-run.
- **Port the R tests**: pamflow's `tests/testthat/` has 33 files. The ones for
  the steps in scope (`test-scan_audio`, `test-standardization`,
  `test-filter_audio`, `test-process_detections`, `test-validation`,
  `test-groundtruth`, `test-occupancy*`, `test-count_history`, `test-activity`,
  `test-richness`, `test-model_input`, `test-detection_table`,
  `test-species_thresholds`, `test-soundscape*`, `test-report`,
  `test-checkpoint`, `test-utils_audio`, `test-detect*`) describe the expected
  behaviour and edge cases; port them as Rust tests. The bridge tests in
  `bridge/tests/` (config editing, protocol parsing, the soundscape index
  rules) port too.
- **End to end**: the example project, then a real project of realistic
  size. Check speed and memory as well as results. Rust should not be slower
  than R on the same machine; measure it.
- **Resume compatibility**: stop a run, switch engines, finish it.
- **Interface**: the existing Svelte screens, with no change, are the test of
  the event contract. `pnpm check` and a manual pass of every screen in both
  workflows.

## 7. Installer and release changes

- The runtime (over 4 GB per platform) and `runtime-pack.yml` go away; the
  installer holds the app, the engine binary and, if needed, the TFLite
  library (and ffmpeg only if the user wants exotic formats).
- First-launch setup (`setup.rs`, the setup screen in the interface) can be
  removed or reduced to the BirdNET model download.
- `release.yml` keeps building the same installers for Windows, macOS (both
  architectures) and Linux, but faster and without the runtime download.
- The `app engine checks` and `runtime check` workflows become Rust tests.

## 8. First week, concretely

1. Read `01-current-system.md` and run the app on the example project to see
   every screen.
2. Make golden outputs from the current app for the example project and for two
   or three real recordings of different formats.
3. Do the BirdNET spike (3.1) and report the result.
4. Start `pamflow-core` with the config editor, using the R tests as the
   specification.
5. Add the routing table to the shell and ship the first Rust jobs behind it.
