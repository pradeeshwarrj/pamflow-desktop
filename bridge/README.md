# The R bridge

How the app asks pamflow to do things. The app (Rust) starts

```
Rscript bridge/run_job.R <job.json>
```

inside the bundled analysis engine. `job.json` says which job to run and gives
its settings. R runs pamflow and prints one event per line to its standard
output, in the form `@@PAM {json}`; Rust passes each event to the screen. Exit
status: 0 = finished, 1 = failed, 2 = bad job file.

pamflow is used as published. The app only changes settings for a run, and
makes small adjustments inside its own R session (`pamflow_patches.R`).

## Files

| File | What it holds |
|---|---|
| `run_job.R` | Reads the job and runs it. One function per job. |
| `protocol.R` | The event format, finding a project's settings file, reading pamflow's log lines as progress. |
| `config_edit.R` | Comment-preserving edits of the settings file, and the header of a new one. |
| `standardize.R` | The Standardize jobs (they count files as pamflow reads and writes them). |
| `pamflow_patches.R` | App-side adjustments to pamflow (for example Python's location on Windows). |
| `download_model.py` | Downloads BirdNET's global model (standard library only). |
| `tests/` | Tests of the helpers: `Rscript bridge/tests/test_protocol.R`, `test_config_edit.R`. |

## Jobs

| Job | What it does |
|---|---|
| `inspect` | Reads a project: recordings, deployment sheet, model, every editable setting. |
| `project_create` | Writes the default settings file for a folder, then reads the project. |
| `example_project` | Makes pamflow's example project in the Documents folder, then reads it. |
| `config_save`, `config_save_as` | Saves edited settings (checked with pamflow first, previous version backed up), here or to another file. |
| `model_info`, `model_download` | Is BirdNET's global model downloaded; download it. |
| `std_state`, `std_plan`, `standardize` | Standardize: current state, dry run, the real run. |
| `scan`, `scan_results` | Scan the recordings; read the last scan. |
| `filter_info`, `filter` | High-pass filter settings and run. |
| `detect` | BirdNET detection (scans first if needed). |
| `process`, `process_results` | Clean detections; read the result. |
| `validation_state`, `validation_draw`, `validation_metrics` | Validation samples, drawing a round, precision tables. |
| `occupancy_build`, `occupancy_results`, `model_input` | Detection histories and the input for occupancy models. |
| `report_preview`, `report` | What a report would contain; write it (HTML, Excel). |
| `diagnostics` | Writes one text file for bug reports; needs no project. |

Settings the screens may change are listed in `EDITABLE` in `run_job.R`.

## Events

`started`, `stage`, `total`, `files` (progress with the latest file rows), `log`
(pamflow's own log lines), `finished` (`status` and `message`), and one result
event per job (for example `project`, `scan`, `std_state`, `model_info`).
Rust adds `text` (any other output line) and `exit` (the process ended).

## Adding a job

1. Write `job_<name> <- function(cfg)` in `run_job.R` and add it to the `switch`
   at the end; emit its result with `pd_emit("<type>", ...)`.
2. Add the name to the job list in `src/lib/backend/tauri.ts`.
3. Add a store in `src/lib/backend/` that runs it with `runJob`, and a screen.
4. If it can run for minutes or more, add the name to `is_long` in
   `src-tauri/src/jobs.rs` so the computer stays awake and closing asks first.
