# Changelog

All notable changes to pamflow Desktop. Versions follow the numbers in
`package.json`.

## Unreleased

### Added
- Project step: a folded **More settings** section with the rest of pamflow's settings: deployment sheet format (header, grid prefix, date and time format, columns), species filters for Process (keep/remove lists, date range, thresholds and season files, maximum overrun), BirdNET speed and sensitivity, validation sampling, recall check and report formats.

## 0.2.0

### Added
- Soundscape: choose the indices in the Project step (written to `soundscape: acoustic_indices:`), progress by batch, and a Stop button; a stopped run continues where it stopped.
- Visualize step (workflow B): 24-hour diel plots, Day/Night comparisons and an HTML report, also from a partly finished run.
- Soundscape settings in the Project step: window, high-pass, day hours, indices, batch size, workers.
- Soundscape progress counts files from earlier runs too; results made with other settings are moved to an `old_*` folder.
- Workflow toggle in the sidebar: A (detection, as before) and B (soundscape indices: Project, Standardize, Scan, Soundscape with plots and an HTML report).

### Changed
- Acoustic Entropy (H) is not offered: it comes out empty in pamflow 0.6.0.

## 0.1.1 (in testing)

Fixes from a code audit.

### Fixes
- Validate: the 1, 2 and 3 keys no longer record answers while the draw card is open.
- Validate: an answer can no longer wipe the results file if saving is interrupted.
- Validate: a round with a single clip is shown correctly.
- Job results: the last messages of a job always arrive before it is reported as ended.
- Report: a file counts as written only if pamflow wrote it just now.
- Detect and Scan wait for Filter and Standardize (and each other).
- The sidebar no longer shows "Analysis engine not found" after first-launch setup.
- The example project is set in the Western Ghats (Nilgiris), with Malabar Parakeet and Malabar Grey Hornbill, instead of the Nicobar Islands.

### Internals
- Faster progress updates and project reads on large projects.
- Tests for the interface, Rust and R bridge now run on every push.
- The release build checks that its unpacker opens the packed engine.

## 0.1.0 (in testing)

First version.

### Workflow
- Project, Standardize, Scan, Filter, Detect, Process, Validate, Occupancy and
  Report screens, in light and dark mode.
- Standardize: pamflow's Stage 00 (Raven Compass-style triage), with a dry-run
  check before anything is copied. The prefix also names the output folder.
- Detect and Filter: progress, stop and continue.
- Validate: spectrogram and audio for each event, precision by species.
- Report: HTML and Excel.

### Settings and models
- New projects start from pamflow's default settings; nothing to prepare.
- Settings are edited on screen and saved to the settings file with comments
  kept and a backup of the previous version. **Save as…** and **Open another
  settings file…** put the file anywhere.
- BirdNET's own global model can be downloaded in the app (once, shared by all
  projects), with a choice of species-name language.
- Own `.tflite` classifiers keep working.

### Installers and reliability
- One installer per system (Windows, macOS Apple Silicon and Intel, Linux
  AppImage and .deb) with the analysis engine inside; the first start unpacks it
  once.
- The computer is kept awake while a long run goes on; closing during a run asks
  first.
- Error messages show pamflow's own error text; **Save diagnostics** writes one
  file to attach to a bug report.
- **Try with example data** makes pamflow's example project.
- The sidebar shows the real app and pamflow versions and warns if the analysis
  engine is missing.

### Known limits
- Installers are not signed (Windows SmartScreen and macOS warn).
- Uninstalling leaves the unpacked analysis engine behind.
- Standardize cannot resume a stopped run; it starts over.
- Occupancy prepares histories and model input; it does not fit models.
- PDF reports are not produced.
