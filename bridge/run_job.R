# ---------------------------------------------------------------------
# pamflow Desktop — R bridge: run one job
#
#   Rscript run_job.R <job.json>
#
# job.json (written by the app):
#   {
#     "job": "inspect" | "detect",
#     "project": "<project folder or config.yml>",
#     "runtime": "<bundled runtime folder>",
#     "birdnet": { "workers": 4, "min_confidence": 0.3 },   (optional overrides)
#     "sample_n": null                                        (optional: test on N files)
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
          detections_folder = cfg$paths$detections)
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
         list(status = "failed", message = paste("unknown job:", job$job))),
  error = function(e) list(status = "failed", message = conditionMessage(e)))

do.call(pd_emit, c(list("finished"), result))
quit(status = if (identical(result$status, "ok")) 0L else 1L)
