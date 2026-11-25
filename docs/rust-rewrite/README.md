# Handoff: rebuilding pamflow Desktop entirely in Rust

Status: proposal and inventory, written 2026-11-25 against pamflow Desktop 0.2.1
and the pamflow R package 0.6.0. Nothing in this folder changes the app.

## What this is

pamflow Desktop is a Tauri 2 app: a SvelteKit user interface and a small Rust
shell, with **all analysis done by an R package (pamflow) and a Python
package (BirdNET) that ship inside the installer**. "Entirely in Rust" means
replacing everything that is not Rust today:

| Today | Language | Size |
|---|---|---|
| User interface (`src/`) | Svelte 5 + TypeScript | about 6,900 lines |
| Shell (`src-tauri/src/`) | Rust | about 1,000 lines |
| Bridge (`bridge/`) | R | about 2,000 lines |
| Analysis engine (pamflow, `F:\Pradeeshwar\pamflow`) | R | about 11,600 lines, 87 exported functions, 33 test files |
| BirdNET runner (`inst/python/pam_birdnet_predict.py`) | Python (calls the `birdnet` package, TensorFlow Lite) | one script |
| Bundled runtime (`runtime/`) | R 4.5, Python 3.12, ffmpeg, pandoc | over 4 GB per platform |

The Rust rewrite removes the R and Python runtime. That is the main benefit:
the installer shrinks from several GB to tens of MB, the first-launch setup
step disappears, and there is one language to maintain.

## Read these in order

1. [01-current-system.md](01-current-system.md): what the software does today,
   step by step, with its inputs, outputs and file formats. This is the
   specification to rebuild against.
2. [02-rust-design-and-plan.md](02-rust-design-and-plan.md): proposed Rust
   architecture, what replaces each R or Python piece, the risks, the order
   of work and how to know each part is correct.

## Decisions to make before starting (the user's call)

1. **Keep the Svelte user interface or rewrite it in Rust too?**
   "Entirely in Rust" is ambiguous here. The recommendation is to keep Svelte
   (it is TypeScript, not R or Python, and it is 6,900 lines of working
   screens) and rewrite only the engine. A full Rust UI (Leptos, Dioxus, egui
   or Slint) is a separate, larger project: it would discard every screen and
   the design system.
2. **BirdNET inference.** This is the single biggest risk (see the design
   document, section "Risks"). Decide whether the Rust engine must run the
   BirdNET `.tflite` models itself, or may call a bundled TensorFlow Lite
   library through a C interface. Running them in pure Rust may require
   converting the models.
3. **Scope of the first release.** Workflow B (soundscape indices) and the
   non-BirdNET steps can be done in pure Rust early. Workflow A needs
   BirdNET. The plan is ordered so that something useful ships before BirdNET
   is solved.
4. **Compatibility.** Should the Rust version read and write exactly the
   files the R version does (`config.yml`, `audio_master.csv`,
   `detections_clean.csv` and so on), so existing projects keep working? The
   recommendation is yes. The design document lists these files.
5. **Occupancy and statistics.** The app builds detection histories and the
   input for occupancy models; users then fit models in R (`unmarked`,
   `ubms`). Fitting models is **not** done by the app. Keep it that way.

## Facts that are easy to get wrong

- The app never edits pamflow itself. It changes settings in memory for one
  run, and it patches two behaviours inside its own R session
  (`bridge/pamflow_patches.R`): the soundscape batch size, which pamflow
  fixes at 50. A Rust engine should simply make these settings real.
- pamflow's config merge (`utils::modifyList`) **deletes** a key whose value
  is null, which inverts the soundscape index list (an index named bare in
  the file is removed and unlisted ones stay on). The app works around it in
  `bridge/protocol.R` (`pd_resolve_indices`). In Rust, define the rule
  properly: the indices listed in the file are exactly the ones computed.
- The Acoustic Entropy index (H) is empty in pamflow 0.6.0 and is hidden in
  the app. Do not reproduce the bug; decide whether to implement it.
- Progress reporting: the interface reads one JSON event per line from a job
  (`@@PAM {json}`). The Svelte side depends on these events. Keep the event
  names and fields (document in 01) and the interface keeps working.
- Raw recordings are never modified or deleted by any step.

## Where things are

- App repository: `F:\Pradeeshwar\pamflow-desktop` (GitHub:
  pradeeshwarrj/pamflow-desktop).
- pamflow R package: `F:\Pradeeshwar\pamflow` (GitHub:
  pradeeshwarrj/pamflow). Its tests in `tests/testthat/` are the best
  behavioural specification available.
- Example project for end-to-end checks: created by the app's "Try with
  example data" (`pam_example_project`).
- Release process: `README.md` in the app repository ("Make a release") and
  `.github/workflows/release.yml`.
