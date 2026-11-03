# Changelog

All notable changes to pamflow Desktop. Versions follow the numbers in
`package.json`.

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
