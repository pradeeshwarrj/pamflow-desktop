# How to change pamflow Desktop

Every kind of change has **one place** to make it. Run `pnpm tauri dev` and
keep the window open: when you save a file, the app updates by itself.

| I want to change… | Edit this file |
|---|---|
| A colour, font, size, spacing, corner roundness | `src/lib/theme/tokens.css` |
| Dark-mode colours | `src/lib/theme/tokens.css` → the `[data-theme='dark']` block |
| Any text on screen (titles, buttons, hints) | `src/lib/i18n/en.json` |
| The order of steps, or which pastel a step uses | `src/lib/config/stages.ts` |
| The demo numbers shown on screen | `src/lib/mock/demo.ts` |
| An icon, or add a new one | `src/lib/components/Icon.svelte` |
| The logo in the sidebar | `src/lib/components/Logo.svelte` |
| The app icon (installer, taskbar, dock) | replace `src-tauri/icons/app-icon.png` (1024×1024; drawing in `app-icon.svg`), then run `pnpm tauri icon src-tauri/icons/app-icon.png` and delete the `android` and `ios` folders it makes |
| The look of all buttons / cards / pills | `src/lib/components/Button.svelte`, `Card.svelte`, `Pills.svelte` |
| What is on one screen | `src/lib/screens/<Step>Live.svelte` (in the app) and `<Step>Demo.svelte` (in a browser); the route file only picks one |
| Window size and title | `src-tauri/tauri.conf.json` → `app.windows` |
| The version number | `package.json`, `src-tauri/Cargo.toml` and `src-tauri/tauri.conf.json` (all three), then `CHANGELOG.md` |
| The settings a new project starts with | not in this app: they are pamflow's own `inst/extdata/config_template.yml` |
| Which settings the screens may change | `EDITABLE` in `bridge/run_job.R` (and the field on the Project screen) |
| Where BirdNET's global model is downloaded from | the constants at the top of `bridge/download_model.py` |
| Which jobs keep the computer awake and ask before closing | `is_long` in `src-tauri/src/jobs.rs` |
| Where the engine and models are unpacked or kept | `src-tauri/src/setup.rs` |
| The pamflow version inside the app | `PAMFLOW_VERSION` in `runtime/scripts/install_r_extras.R` |
| What the installer contains, and what it is called | `src-tauri/tauri.release.conf.json` and `.github/workflows/release.yml` |

## Examples

**Make the Detect step mint instead of lavender**
In `src/lib/config/stages.ts` change `palette: 'lavender'` to `palette: 'mint'`
on the `detect` line. The sidebar, chip, progress panel and buttons all follow.

**Make the lavender softer**
In `tokens.css` change `--lavender-tint` (background) and `--lavender-ink`
(text on it). Do it in both the light block and the dark block.

**Rename a button**
Find the text in `en.json` (for example `"save": "Save and scan recordings"`)
and change only the part on the right of the colon. Keep `{placeholders}` like
`{n}` as they are; the app fills them in.

**Rounder corners everywhere**
In `tokens.css` raise `--radius-xl` (cards) and `--radius-lg` (buttons).

## Rules that keep it easy

- Screens never contain colours or text directly: colours come from
  `tokens.css`, text from `en.json`. Keep it that way when adding things.
- Inside a step's screen, `var(--accent-tint)` and `var(--accent-ink)`
  always mean "this step's pastel". Use them instead of a named colour.
- New screens are built from the pieces in `src/lib/components`.

## Building blocks (src/lib/components)

| Piece | Used for |
|---|---|
| `PageHeader` | Step chip, title, intro at the top of a screen |
| `Card` | Any white box with a title and one-line hint |
| `StatTile` | A big number with a label |
| `Button` | All buttons: primary, secondary, ghost, accent, accent-outline |
| `Pills` | Choose one of a few options |
| `PathField` | Folder/file box with a Browse button |
| `ProgressBar` | Any progress or bar chart bar |
| `Badge` | Small coloured label |
| `Spectrogram` | Spectrogram panel (demo picture now, real image later) |
| `ThemeSwitch`, `Sidebar`, `Logo`, `Icon` | App frame (the sidebar footer holds the version label and *Save diagnostics*) |
| `SaveBar` | "Save to config.yml", "Save as…" and Discard for the settings being edited |
| `ModelCard` | BirdNET's global model or your own classifier, with the download |
| `LongJobPanel` | Progress, Stop and the list of files for Standardize, Filter and Detect |
| `SetupScreen` | The first-start screen that unpacks the analysis engine |
| `ClipSpectrogram`, `HistoryGrid` | Validation clips; detection-history grids |
| `ComingSoon` | Placeholder for steps not built yet |

## Where the work happens

| Layer | Folder | What it does |
|---|---|---|
| Screens | `src/lib/screens`, `src/routes` | What you see. No colours or text of their own. |
| Stores | `src/lib/backend` | One per screen: ask for jobs, keep state, turn events into numbers. All talk to Rust goes through `tauri.ts`. |
| Rust | `src-tauri/src` | Starts and stops jobs, first-launch setup, finding the engine. |
| R bridge | `bridge/` | Runs one job with pamflow and reports progress. See `bridge/README.md`. |
| Engine | `runtime/` | The recipe for the bundled R, Python, BirdNET, ffmpeg. See `runtime/README.md`. |
