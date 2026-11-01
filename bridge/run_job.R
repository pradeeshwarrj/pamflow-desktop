# ---------------------------------------------------------------------
# pamflow Desktop — R bridge: run one job
#
#   Rscript run_job.R <job.json>
#
# job.json (written by the app):
#   {
#     "job": "inspect" | "detect" | "process" | "process_results" |
#            "validation_state" | "validation_draw" | "validation_metrics",
#     "project": "<project folder or config.yml>",
#     "runtime": "<bundled runtime folder>",
#     "birdnet": { "workers": 4, "min_confidence": 0.3 },   (optional overrides)
#     "sample_n": null,                                       (detect: test on N files)
#     "strategy": "stratified" | "random" | "rare",           (validation_draw)
#     "n": 100, "species": ["..."],                           (validation_draw, optional)
#     "with_pool": true                                       (validation_state: also count events)
#   }
#
# Progress goes to stdout as "@@PAM {json}" lines (see protocol.R).
# pamflow is used exactly as installed; the app only changes settings
# for this run (never the user's config.yml on disk).
# Exit status: 0 = job finished, 1 = job failed, 2 = bad job file.
# ---------------------------------------------------------------------

bridge_dir <- local({
  arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  normalizePath(dirname(sub("^--file=", "", arg[1])), winslash = "/")
})
source(file.path(bridge_dir, "protocol.R"))
`%||%` <- function(a, b) if (is.null(a)) b else a
# no animated progress bars: the app shows progress from the events
options(cli.progress_show_after = Inf, cli.dynamic = FALSE, cli.num_colors = 1)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1 || !file.exists(args[1])) {
  pd_emit("finished", status = "failed", message = "usage: Rscript run_job.R <job.json>")
  quit(status = 2L)
}
job <- jsonlite::fromJSON(args[1], simplifyVector = TRUE)

fail <- function(message, code = 1L) {
  pd_emit("finished", status = "failed", message = message)
  quit(status = code)
}

# ---- load pamflow and the app's adjustments ----------------------------
suppressPackageStartupMessages(library(pamflow))
patches <- file.path(bridge_dir, "pamflow_patches.R")
if (file.exists(patches)) {
  source(patches)
  pam_desktop_apply_patches()
}

# ---- find the project and read its config -------------------------------
found <- pd_find_config(job$project)
if (is.null(found)) {
  fail(sprintf("No pamflow config found in %s (looked for config/config.yml and config.yml).",
               job$project))
}
setwd(found$root)          # pamflow resolves relative paths from the project folder
cfg <- tryCatch(pam_config_read(found$config), error = function(e) fail(conditionMessage(e)))

# settings the app changes for this run only
if (length(job$birdnet)) cfg$birdnet <- utils::modifyList(cfg$birdnet, as.list(job$birdnet))
if (is.null(cfg$birdnet$python_env) && nzchar(job$runtime %||% "")) {
  cfg$birdnet$python_env <- job$runtime   # BirdNET runs with the bundled Python
}

# ---- jobs ----------------------------------------------------------------

job_inspect <- function(cfg) {
  audio_dir <- cfg$paths$audio_standardized
  n_audio <- if (dir.exists(audio_dir)) length(pam_list_audio(audio_dir)) else NA_integer_
  bc <- cfg$birdnet
  model_dir <- bc$model_dir
  if (!is.null(model_dir) && !fs::is_absolute_path(model_dir)) {
    model_dir <- file.path(cfg$paths$project_root, model_dir)
  }
  model_file <- if (!is.null(model_dir)) file.path(model_dir, paste0(bc$classifier_name, ".tflite")) else NA
  pd_emit("project",
          config = found$config,
          root = found$root,
          audio_folder = audio_dir,
          audio_folder_found = dir.exists(audio_dir),
          n_audio = n_audio,
          scanned = file.exists(file.path(cfg$paths$metadata, "audio_master.csv")),
          deployment_sheet = cfg$paths$deployment_sheet,
          deployment_sheet_found = file.exists(cfg$paths$deployment_sheet %||% ""),
          model_file = model_file,
          model_found = isTRUE(file.exists(model_file)),
          run_id = bc$run_id,
          min_confidence = bc$min_confidence,
          workers = bc$workers,
          cores_physical = parallel::detectCores(logical = FALSE),
          cores_logical = parallel::detectCores(logical = TRUE),
          detections_folder = cfg$paths$detections,
          processing = processing_settings(cfg))
  list(status = "ok")
}

# The cleaning rules from config.yml, for display.
processing_settings <- function(cfg) {
  pc <- cfg$processing
  list(min_confidence = pc$min_confidence,
       drop_outside_deployment = isTRUE(pc$drop_outside_deployment %||% TRUE),
       merge_gap_s = pc$merge_gap_s %||% 0,
       max_overrun_s = pc$max_overrun_s %||% 3,
       thresholds_file = pc$species_thresholds_file,
       season_file = pc$species_season_file,
       n_whitelist = length(unlist(pc$species_whitelist)),
       n_blacklist = length(unlist(pc$species_blacklist)),
       date_range = unlist(pc$date_range))
}

processed_dir <- function(cfg) file.path(cfg$paths$detections, cfg$birdnet$run_id, "processed")

# Read the files pamflow's Stage 4 wrote and send a summary to the app.
emit_processed <- function(cfg) {
  out_dir <- processed_dir(cfg)
  steps_path <- file.path(out_dir, "processing_steps.csv")
  clean_path <- file.path(out_dir, "detections_clean.csv")
  if (!file.exists(steps_path) || !file.exists(clean_path)) {
    pd_emit("processed", available = FALSE, out_dir = out_dir)
    return(invisible(FALSE))
  }
  steps <- data.table::fread(steps_path)
  clean <- data.table::fread(clean_path)
  cols <- intersect(c("scientific_name", "common_name", "confidence", "grid"), names(clean))
  clean <- clean[, ..cols]
  species <- if (nrow(clean)) {
    clean[, .(events = .N, max_confidence = round(max(confidence), 3)),
          by = .(scientific_name, common_name)][order(-events)]
  } else data.table::data.table()
  merge_step <- grepl("^merged", steps$rule)
  pd_emit("processed",
          available = TRUE,
          out_dir = out_dir,
          updated = format(file.mtime(clean_path), "%Y-%m-%d %H:%M"),
          raw = if (nrow(steps)) steps$n_before[1] else 0L,
          removed = sum(steps$n_removed[!merge_step]),
          events = nrow(clean),
          n_species = nrow(species),
          n_grids = if ("grid" %in% names(clean)) data.table::uniqueN(clean$grid) else NA_integer_,
          steps = steps,
          species = utils::head(species, 15))
  invisible(TRUE)
}

job_process <- function(cfg) {
  pd_emit("stage", stage = "process", label = "Cleaning detections")
  res <- with_log_events(pam_run_stage("04_process", pam_process_detections, cfg))
  if (res$status != "ok") {
    return(list(status = "failed", message = "Cleaning the detections failed; see the log."))
  }
  emit_processed(cfg)
  list(status = "ok", minutes = round(as.numeric(res$duration), 2), warnings = res$warnings)
}

job_process_results <- function(cfg) {
  emit_processed(cfg)
  list(status = "ok")
}

# ---- validation (pamflow Stage 5) ------------------------------------------
# Files live in <detections>/<run_id>/validation/, exactly as pamflow's own
# validation app uses them, so the app and RStudio can be used in turn.

validation_dir <- function(cfg) file.path(cfg$paths$detections, cfg$birdnet$run_id, "validation")

# Species BirdNET can name (the model's labels), for the "what is it?" list.
model_labels <- function(cfg) {
  tryCatch(readLines(pamflow:::pam_detect_settings(cfg)$labels_file, warn = FALSE, encoding = "UTF-8"),
           error = function(e) character())
}

# Everything the review screen needs: the samples ready to review, in the
# same blind (shuffled) order as pamflow's Shiny app, plus earlier answers.
emit_validation_state <- function(cfg, with_pool = FALSE) {
  vdir <- validation_dir(cfg)
  samples_path <- file.path(vdir, "validation_samples.csv")
  results_path <- file.path(vdir, "validation_results.csv")
  clip_dir <- file.path(vdir, "clips"); spec_dir <- file.path(vdir, "spectrograms")

  pool <- NULL
  if (with_pool) {
    pool_dt <- tryCatch(pam_validation_pool(cfg), error = function(e) NULL)
    if (!is.null(pool_dt) && nrow(pool_dt)) {
      sp <- pool_dt[, .N, by = .(scientific_name, common_name)][order(-N)]
      pool <- list(n_events = nrow(pool_dt), species = sp)
    } else pool <- list(n_events = 0L, species = list())
  }

  vc <- cfg$validation
  common <- list(val_dir = vdir, clips_dir = clip_dir, specs_dir = spec_dir,
                 results_path = results_path,
                 show_confidence = isTRUE(vc$show_confidence),
                 reviewer = vc$reviewer %||% "",
                 bands = unlist(vc$bands), n_per_cell = vc$n_per_cell,
                 spec_max_hz = vc$spec_max_hz %||% 12000,
                 rare_max_events = vc$rare_max_events, rare_n = vc$rare_n,
                 pool = pool)

  if (!file.exists(samples_path)) {
    do.call(pd_emit, c(list("validation", available = FALSE, n_samples = 0L, n_ready = 0L,
                            samples = list(), results = list(), labels = model_labels(cfg)), common))
    return(invisible(NULL))
  }
  samples <- data.table::fread(samples_path, colClasses = list(character = c(
    "recording_date", "detection_datetime", "band", "clip_file", "spec_file")))
  ready <- file.exists(file.path(clip_dir, samples$clip_file)) &
    file.exists(file.path(spec_dir, samples$spec_file))
  shown <- samples[ready]
  order_ids <- if (nrow(shown)) withr::with_seed(1, sample(shown$sample_id)) else integer()
  shown <- shown[match(order_ids, shown$sample_id)]
  keep <- intersect(c("sample_id", "round", "strategy", "species", "scientific_name", "common_name",
                      "confidence", "band", "grid", "recorder", "detection_datetime", "filename",
                      "clip_file", "spec_file", "clip_dur_s", "event_offset_s", "event_end_offset_s"),
                    names(shown))
  results <- if (file.exists(results_path)) {
    r <- data.table::fread(results_path, colClasses = list(
      character = c("verdict", "true_species", "note", "reviewer", "reviewed_at")))
    unique(r, by = "sample_id", fromLast = TRUE)
  } else data.table::data.table()

  do.call(pd_emit, c(list("validation", available = TRUE,
                          n_samples = nrow(samples), n_ready = nrow(shown),
                          rounds = if (nrow(samples)) max(samples$round) else 0L,
                          samples = shown[, ..keep], results = results,
                          labels = unique(c(model_labels(cfg), samples$species))), common))
}

job_validation_state <- function(cfg) {
  emit_validation_state(cfg, with_pool = isTRUE(job$with_pool))
  list(status = "ok")
}

# Draw a new round of events, then make their clips and spectrograms.
job_validation_draw <- function(cfg) {
  strategy <- job$strategy %||% "stratified"
  pd_emit("stage", stage = "draw", label = "Choosing events")
  args <- list(strategy = strategy)
  if (!is.null(job$n)) args$n <- as.integer(job$n)
  if (length(job$species)) args$species <- job$species
  drawn <- with_log_events(pam_run_stage("05_validation", function(cfg) do.call(pam_validation_draw, c(list(cfg), args)), cfg))
  if (drawn$status != "ok") return(list(status = "failed", message = "Choosing events failed; see the log."))
  n_new <- if (is.null(drawn$result)) 0L else nrow(drawn$result)
  pd_emit("drawn", n = n_new)

  pd_emit("stage", stage = "export", label = "Making clips and spectrograms", n = n_new)
  exported <- with_log_events(pam_run_stage("05_export", pam_validation_export, cfg))
  if (exported$status != "ok") return(list(status = "failed", message = "Making clips failed; see the log."))
  emit_validation_state(cfg)
  list(status = "ok", n_new = n_new, n_failed = exported$result$n_failed %||% 0L)
}

# Precision by species from the answers so far (pamflow's validation report).
job_validation_metrics <- function(cfg) {
  res <- with_log_events(pam_run_stage("05_report", pam_validation_report, cfg))
  if (res$status != "ok") return(list(status = "failed", message = "Could not compute precision; see the log."))
  m <- res$result
  cells <- m$cells
  by_species <- cells[, .(n_pool = sum(n_pool), n_reviewed = sum(n_reviewed), n_correct = sum(n_correct),
                          n_incorrect = sum(n_incorrect), n_unsure = sum(n_unsure)), by = scientific_name]
  by_species <- by_species[n_reviewed > 0]
  ci <- pamflow:::pam_wilson_ci(by_species$n_correct, by_species$n_correct + by_species$n_incorrect)
  by_species[, `:=`(precision = ifelse(n_correct + n_incorrect > 0, n_correct / (n_correct + n_incorrect), NA_real_),
                    ci_low = ci$low, ci_high = ci$high)]
  data.table::setorder(by_species, -n_reviewed)
  pd_emit("metrics", species = by_species, cells = cells,
          thresholds = m$thresholds[scientific_name == "ALL"],
          confusion = utils::head(m$confusion, 20), out_dir = validation_dir(cfg))
  list(status = "ok")
}

job_detect <- function(cfg) {
  # Stage 1 first, if this project has not been scanned yet
  if (!file.exists(file.path(cfg$paths$metadata, "audio_master.csv"))) {
    pd_emit("stage", stage = "scan", label = "Scanning recordings")
    scan <- with_log_events(pam_run_stage("01_scan", pam_scan_audio, cfg))
    if (scan$status != "ok") return(list(status = "failed", message = "Scanning the recordings failed; see the log."))
  }

  run_dir <- file.path(cfg$paths$detections, cfg$birdnet$run_id)
  results_path <- file.path(run_dir, "file_results.csv")
  seen <- if (file.exists(results_path)) nrow(utils::read.csv(results_path)) else 0L
  pd_emit("stage", stage = "detect", label = "Detecting calls", run_dir = run_dir,
          already_done = pd_checkpoint_count(file.path(run_dir, "done.txt")))

  totals <- list(done = 0L, failed = 0L, detections = 0L)
  on_batch <- function(p) {
    new <- pd_new_results(results_path, seen)
    seen <<- new$seen
    totals$done <<- totals$done + p$ok
    totals$failed <<- totals$failed + p$failed
    totals$detections <<- totals$detections + p$detections
    pd_emit("files", batch = p$batch, batches = p$batches,
            done = totals$done, failed = totals$failed, detections = totals$detections,
            rows = new$rows)
  }

  res <- with_log_events(
    pam_run_stage("03_detect", pam_detect, cfg, sample_n = job$sample_n),
    on_batch = on_batch)
  out <- res$result
  list(status = res$status,
       message = if (res$status != "ok") "Detection failed; see the log." else "",
       run_dir = run_dir,
       n_pending = out$n_pending, n_done = out$n_done, n_failed = out$n_failed,
       n_detections = out$n_detections,
       minutes = round(as.numeric(res$duration), 2),
       warnings = res$warnings)
}

# Turn pamflow's log messages into events while `expr` runs.
with_log_events <- function(expr, on_batch = NULL) {
  withCallingHandlers(expr, message = function(m) {
    for (line in strsplit(sub("\n$", "", conditionMessage(m)), "\n", fixed = TRUE)[[1]]) {
      if (!nzchar(trimws(line))) next
      parts <- pd_split_log_line(line)
      pd_emit("log", level = parts$level, stage = parts$stage, text = parts$text)
      # progress reporting must never be able to stop pamflow's own work
      tryCatch({
        p <- pd_parse_log(parts$text)
        if (p$kind == "total") pd_emit("total", n = p$n)
        if (p$kind == "batch" && !is.null(on_batch)) on_batch(p)
      }, error = function(e) pd_emit("log", level = "WARN", stage = "app",
                                     text = paste("progress update skipped:", conditionMessage(e))))
    }
    invokeRestart("muffleMessage")
  })
}

# ---- run ------------------------------------------------------------------
pd_emit("started", job = job$job, project = found$root,
        pamflow = as.character(utils::packageVersion("pamflow")), pid = Sys.getpid())

result <- tryCatch(
  switch(job$job,
         inspect = job_inspect(cfg),
         detect = job_detect(cfg),
         process = job_process(cfg),
         process_results = job_process_results(cfg),
         validation_state = job_validation_state(cfg),
         validation_draw = job_validation_draw(cfg),
         validation_metrics = job_validation_metrics(cfg),
         list(status = "failed", message = paste("unknown job:", job$job))),
  error = function(e) list(status = "failed", message = conditionMessage(e)))

do.call(pd_emit, c(list("finished"), result))
quit(status = if (identical(result$status, "ok")) 0L else 1L)
