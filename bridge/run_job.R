# ---------------------------------------------------------------------
# pamflow Desktop — R bridge: run one job
#
#   Rscript run_job.R <job.json>
#
# job.json (written by the app):
#   {
#     "job": "inspect" | "detect" | "process" | "process_results" |
#            "validation_state" | "validation_draw" | "validation_metrics" |
#            "occupancy_build" | "occupancy_results" | "model_input" |
#            "report_preview" | "report",
#     "project": "<project folder or config.yml>",
#     "runtime": "<bundled runtime folder>",
#     "birdnet": { "workers": 4, "min_confidence": 0.3 },   (optional overrides)
#     "sample_n": null,                                       (detect: test on N files)
#     "strategy": "stratified" | "random" | "rare",           (validation_draw)
#     "n": 100, "species": ["..."],                           (validation_draw, optional)
#     "with_pool": true,                                      (validation_state: also count events)
#     "response": "detection" | "counts", "standardize": false (model_input)
#     "formats": ["html", "excel", "pdf"]                     (report)
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

# ---- occupancy (pamflow Stages 6 and 7) -------------------------------------
# pamflow's occupancy step reads the run named in occupancy$run_id. The app
# uses that run when it has cleaned detections, otherwise the run that was
# detected and cleaned in the app (birdnet$run_id). The screen shows which.

occupancy_run_id <- function(cfg) {
  clean_exists <- function(run) {
    !is.null(run) && file.exists(file.path(cfg$paths$detections, run, "processed", "detections_clean.csv"))
  }
  occ <- cfg$occupancy$run_id
  if (clean_exists(occ)) occ else cfg$birdnet$run_id
}

occupancy_dir <- function(cfg) file.path(cfg$paths$occupancy, occupancy_run_id(cfg))

occupancy_settings <- function(cfg) {
  oc <- cfg$occupancy
  list(run_id = occupancy_run_id(cfg), config_run_id = oc$run_id,
       occasion_length_days = oc$occasion_length_days %||% 1,
       min_effort_hours = oc$min_effort_hours %||% 2,
       min_detections = oc$min_detections %||% 10,
       min_confidence = cfg$processing$min_confidence %||% 0.5,
       thresholds_file = cfg$processing$species_thresholds_file)
}

# Send the detection histories and summary pamflow wrote.
emit_occupancy <- function(cfg) {
  dir <- occupancy_dir(cfg)
  summary_path <- file.path(dir, "occupancy_summary.csv")
  base <- list(dir = dir, settings = occupancy_settings(cfg))
  if (!file.exists(summary_path)) {
    do.call(pd_emit, c(list("occupancy", available = FALSE), base))
    return(invisible(FALSE))
  }
  summary <- data.table::fread(summary_path)
  histories <- lapply(summary$species, function(sp) {
    path <- file.path(dir, paste0("detection_history_", gsub(" ", "_", sp), ".csv"))
    if (!file.exists(path)) return(NULL)
    h <- data.table::fread(path, header = TRUE, colClasses = list(character = "site_id"))
    occ_cols <- setdiff(names(h), "site_id")
    list(species = sp, sites = h$site_id, occasions = occ_cols,
         # one string per site: "1", "0" or "." (not surveyed) for each occasion
         rows = vapply(seq_len(nrow(h)), function(i) {
           v <- unlist(h[i, ..occ_cols], use.names = FALSE)
           paste(ifelse(is.na(v), ".", ifelse(v > 0, "1", "0")), collapse = "")
         }, character(1)))
  })
  histories <- Filter(Negate(is.null), histories)
  site_cov <- file.path(dir, "site_covariates.csv")
  do.call(pd_emit, c(list("occupancy", available = TRUE,
                          updated = format(file.mtime(summary_path), "%Y-%m-%d %H:%M"),
                          summary = summary, histories = histories,
                          site_covariates = if (file.exists(site_cov)) names(data.table::fread(site_cov, header = TRUE, nrows = 1)) else list()),
                     base))
  invisible(TRUE)
}

job_occupancy_build <- function(cfg) {
  run <- occupancy_run_id(cfg)
  pd_emit("stage", stage = "occupancy", label = "Building detection histories", run_id = run)
  res <- with_log_events(pam_run_stage("06_occupancy", pam_build_occupancy, cfg, run_id = run, force = TRUE))
  if (res$status != "ok") return(list(status = "failed", message = "Building the histories failed; see the log."))
  if (is.null(res$result)) {
    emit_occupancy(cfg)
    return(list(status = "failed",
                message = "No species had enough detections. Lower occupancy: min_detections in config.yml, or check the cleaned detections."))
  }
  emit_occupancy(cfg)
  list(status = "ok")
}

job_occupancy_results <- function(cfg) {
  emit_occupancy(cfg)
  list(status = "ok")
}

# Model input for unmarked / spOccupancy / ubms (pamflow prepares, it does not fit).
job_model_input <- function(cfg) {
  run <- occupancy_run_id(cfg)
  binary <- !identical(job$response, "counts")
  standardize <- isTRUE(job$standardize)
  out_dir <- file.path(occupancy_dir(cfg), if (binary) "model_input_detection" else "model_input_counts")
  pd_emit("stage", stage = "model_input", label = "Preparing model input", run_id = run)
  res <- with_log_events(pam_run_stage("07_model_input", function(cfg) {
    histories <- pam_count_histories(cfg, run_id = run)
    x <- pam_model_input(histories, binary = binary, standardize = standardize, dir = out_dir)
    list(x = x, checks = pam_check_model_input(x, error = FALSE))
  }, cfg))
  if (res$status != "ok") return(list(status = "failed", message = "Preparing the model input failed; see the log."))
  x <- res$result$x
  d <- dim(x$y)
  pd_emit("model_input", dir = out_dir, binary = binary, standardize = standardize,
          dims = d, layout = attr(x, "layout"),
          n_sites = length(x$site_ids),
          site_covariates = names(x$siteCovs), obs_covariates = names(x$obsCovs),
          checks = res$result$checks,
          files = basename(list.files(out_dir, pattern = "\\.csv$")))
  list(status = "ok")
}

# ---- report (pamflow Stage 8) ------------------------------------------------
# pamflow's report covers the run that was detected, cleaned and validated in
# the app (birdnet$run_id). Sections without data are left out by pamflow.

report_files <- function(cfg, run) {
  dir <- cfg$paths$reports
  files <- c(html = paste0("report_", run, ".html"), pdf = paste0("report_", run, ".pdf"),
             excel = paste0("report_", run, ".xlsx"))
  lapply(names(files), function(k) {
    path <- file.path(dir, files[[k]])
    list(format = k, path = path, exists = file.exists(path),
         updated = if (file.exists(path)) format(file.mtime(path), "%Y-%m-%d %H:%M") else NULL,
         size_kb = if (file.exists(path)) round(file.size(path) / 1024) else NULL)
  })
}

# Headline numbers and which report sections have data.
job_report_preview <- function(cfg) {
  run <- cfg$birdnet$run_id
  d <- tryCatch(suppressMessages(pamflow:::pam_report_data(cfg, run)), error = function(e) NULL)
  has <- function(x) !is.null(x) && NROW(x) > 0
  n <- function(x) if (has(x)) NROW(x) else 0L
  eff <- d$effort
  hours <- if (has(eff)) {
    col <- intersect(c("effort_hours", "hours"), names(eff))
    if (length(col)) round(sum(eff[[col[1]]], na.rm = TRUE)) else NA
  } else NA
  sites <- if (has(eff)) {
    col <- intersect(c("site_id", "grid"), names(eff))
    if (length(col)) data.table::uniqueN(eff[[col[1]]]) else NA
  } else NA
  pd_emit("report_preview",
          run_id = run,
          title = cfg$report$title %||% "PAM Workflow Report",
          author = cfg$report$author %||% "",
          formats = unlist(cfg$report$formats),
          reports_dir = cfg$paths$reports,
          pandoc = isTRUE(tryCatch(rmarkdown::pandoc_available("2.0"), error = function(e) FALSE)),
          latex = nzchar(Sys.which("pdflatex")) || nzchar(Sys.which("xelatex")) ||
            isTRUE(tryCatch(tinytex::is_tinytex(), error = function(e) FALSE)),
          numbers = list(effort_hours = hours, sites = sites,
                         events = n(d$detections), species = n(d$species_counts)),
          sections = list(effort = has(d$effort), detections = has(d$species_counts),
                          richness = has(d$richness_sites), activity = has(d$activity_hour) || has(d$activity_week),
                          validation = has(d$precision) || has(d$recall) || has(d$thresholds),
                          occupancy = has(d$occupancy)),
          top_species = if (has(d$species_counts)) utils::head(d$species_counts, 10) else list(),
          files = report_files(cfg, run))
  list(status = "ok")
}

job_report <- function(cfg) {
  run <- cfg$birdnet$run_id
  formats <- intersect(unlist(job$formats) %||% c("html", "excel"), c("html", "pdf", "excel"))
  if (!length(formats)) return(list(status = "failed", message = "Choose at least one format."))
  pd_emit("stage", stage = "report", label = "Writing the report", formats = formats)
  res <- with_log_events(pam_run_stage("08_report", pam_report, cfg, run_id = run,
                                       formats = formats, force = TRUE))
  if (res$status != "ok") return(list(status = "failed", message = "Writing the report failed; see the log."))
  files <- report_files(cfg, run)
  made <- vapply(files, function(f) f$format %in% formats && isTRUE(f$exists) &&
                   difftime(Sys.time(), file.mtime(f$path), units = "mins") < 30, logical(1))
  pd_emit("report_done", files = files,
          made = vapply(files[made], `[[`, "", "format"),
          missing = setdiff(formats, vapply(files[made], `[[`, "", "format")),
          warnings = res$warnings)
  list(status = if (any(made)) "ok" else "failed",
       message = if (any(made)) "" else "No report file was written; see the log.")
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
         occupancy_build = job_occupancy_build(cfg),
         occupancy_results = job_occupancy_results(cfg),
         model_input = job_model_input(cfg),
         report_preview = job_report_preview(cfg),
         report = job_report(cfg),
         list(status = "failed", message = paste("unknown job:", job$job))),
  error = function(e) list(status = "failed", message = conditionMessage(e)))

do.call(pd_emit, c(list("finished"), result))
quit(status = if (identical(result$status, "ok")) 0L else 1L)
