# ---------------------------------------------------------------------
# Step "Standardize" (pamflow Stage 00, Raven Compass-style triage).
#
# Uses pamflow's own engine, pam_standardize():
#   - "std_plan"    dry run: reads every raw file and plans what happens to it
#                   (nothing is written except the plan table in metadata/)
#   - "standardize" the real run: copies / converts recordings into the
#                   standardized folder and copies memos, non-audio and
#                   corrupt files into the isolated folder.
#                   Raw files are never changed or deleted.
#
# pamflow writes no per-file progress for Stage 00, so the app counts calls
# to pam_audio_info() (reading headers) and to fs::file_copy() /
# av::av_audio_convert() (writing files) with trace(). The trace only lives
# inside this R session; pamflow itself is not changed.
#
# Sourced by run_job.R (needs pd_emit, %||%, with_log_events, job).
# ---------------------------------------------------------------------

STD_AUDIO_EXT <- c("wav", "flac", "mp3", "m4a", "ogg", "wma", "aiff", "aif")

# Stage 00 settings: config.yml values, with this run's overrides (job$std).
std_settings <- function(cfg) {
  sc <- utils::modifyList(cfg$standardization %||% list(), as.list(job$std %||% list()))
  list(
    raw_dir = cfg$paths$audio_raw,
    standardized_dir = cfg$paths$audio_standardized,
    isolated_dir = cfg$paths$audio_isolated,
    target_format = tolower(sc$target_format %||% "flac"),
    target_hz = sc$target_hz %||% 48000,
    channels = sc$channels %||% 1,
    min_duration_s = sc$min_duration_s %||% 60,
    organize_folders = sc$organize_folders %||% "grid",
    rename_strategy = sc$rename_strategy %||% "auto",
    prefix = sc$prefix %||% "",
    isolate_non_audio = !isFALSE(sc$isolate_non_audio),
    isolate_short = !isFALSE(sc$isolate_short),
    timezone = sc$timezone %||% cfg$filenames$timezone %||% "Asia/Kolkata"
  )
}

std_norm <- function(p) {
  if (is.null(p) || !nzchar(p)) return("")
  tolower(normalizePath(p, winslash = "/", mustWork = FALSE))
}

# Problems that make running unsafe (empty = fine).
std_problems <- function(s) {
  raw <- std_norm(s$raw_dir); out <- std_norm(s$standardized_dir); iso <- std_norm(s$isolated_dir)
  probs <- character()
  if (!nzchar(raw) || !dir.exists(s$raw_dir)) probs <- c(probs, sprintf("Raw folder not found: %s", s$raw_dir))
  inside <- function(a, b) nzchar(a) && nzchar(b) && (a == b || startsWith(a, paste0(b, "/")))
  if (inside(out, raw) || inside(raw, out)) {
    probs <- c(probs, "The raw and standardized folders must be separate (neither inside the other).")
  }
  if (inside(iso, raw) || inside(raw, iso)) {
    probs <- c(probs, "The raw and isolated folders must be separate (neither inside the other).")
  }
  probs
}

std_plan_path <- function(cfg) file.path(cfg$paths$metadata, "00_standardization_plan.csv")
std_log_path <- function(s) file.path(s$standardized_dir, "standardization_log.csv")

# Summary of a plan or of a finished run (pam_standardize's audit table).
std_summarise <- function(dt, kind, updated) {
  if (is.null(dt) || !nrow(dt) || !all(c("action", "dest_path", "status") %in% names(dt))) {
    return(list(available = FALSE, kind = kind))
  }
  dt <- data.table::as.data.table(dt)
  size_gb <- function(paths) round(sum(suppressWarnings(file.size(paths)), na.rm = TRUE) / 1024^3, 2)
  cat_n <- function(x) sum(dt$category == x, na.rm = TRUE)
  act <- sub("^(PLANNED_|)", "", dt$action)
  good <- dt[dt$category == "standardizable"]
  grid_of <- function(p) basename(dirname(p))
  per_grid <- if (nrow(good)) {
    g <- data.table::data.table(grid = grid_of(good$dest_path))[, .(files = .N), by = grid]
    data.table::setorder(g, grid)
    utils::head(g, 500)
  } else list()
  problems <- dt[dt$category != "standardizable" | dt$status != "SUCCESS"]
  examples <- if (nrow(good)) utils::head(data.table::data.table(
    from = basename(good$source_path), to = good$dest_path), 8) else list()
  list(
    available = TRUE, kind = kind, updated = updated,
    n_files = nrow(dt),
    n_recordings = cat_n("standardizable"),
    n_memos = cat_n("isolated_memo"),
    n_non_audio = cat_n("isolated_non_audio"),
    n_corrupt = cat_n("corrupt"),
    n_convert = sum(act %in% c("TRANSCODE", "TRANSCODED")),
    n_copy = sum(act %in% c("COPY_COMPLIANT", "COPIED_COMPLIANT")),
    n_failed = sum(dt$status == "ERROR", na.rm = TRUE),
    raw_gb = size_gb(good$source_path),
    per_grid = per_grid,
    examples = examples,
    problems = utils::head(problems[, .(file = basename(source_path), category, action, message)], 200)
  )
}

std_emit_state <- function(cfg) {
  s <- std_settings(cfg)
  plan <- if (file.exists(std_plan_path(cfg))) data.table::fread(std_plan_path(cfg)) else NULL
  done <- if (file.exists(std_log_path(s))) data.table::fread(std_log_path(s)) else NULL
  n_raw <- if (dir.exists(s$raw_dir %||% "")) {
    length(list.files(s$raw_dir, recursive = TRUE, all.files = FALSE))
  } else NA_integer_
  pd_emit("std_state",
          settings = s, raw_found = dir.exists(s$raw_dir %||% ""), n_raw_files = n_raw,
          problems = std_problems(s),
          plan = std_summarise(plan, "plan",
                               if (!is.null(plan)) format(file.mtime(std_plan_path(cfg)), "%Y-%m-%d %H:%M")),
          last_run = std_summarise(done, "run",
                                   if (!is.null(done)) format(file.mtime(std_log_path(s)), "%Y-%m-%d %H:%M")))
}

job_std_state <- function(cfg) {
  std_emit_state(cfg)
  list(status = "ok")
}

# ---- progress counters via trace() ----------------------------------------

std_counter <- new.env()

std_reset <- function(phase, total) {
  std_counter$phase <- phase
  std_counter$total <- total
  std_counter$done <- 0L
  std_counter$failed <- 0L
  std_counter$rows <- list()
  std_counter$last_emit <- Sys.time()
  if (phase == "write") pd_emit("total", n = total)
}

std_flush <- function(force = FALSE) {
  if (!force && difftime(Sys.time(), std_counter$last_emit, units = "secs") < 1) return(invisible())
  std_counter$last_emit <- Sys.time()
  if (std_counter$phase == "read") {
    pd_emit("prep", done = std_counter$done, total = std_counter$total)
  } else {
    rows <- if (length(std_counter$rows)) data.table::rbindlist(std_counter$rows) else NULL
    std_counter$rows <- list()
    pd_emit("files", batch = 0L, batches = 0L, done = std_counter$done,
            failed = std_counter$failed, detections = 0L, rows = rows)
  }
}

# Called (via trace) each time pamflow reads a header or writes a file.
.pd_std_tick <- function(dest = NULL, what = "") {
  tryCatch({
    std_counter$done <- std_counter$done + 1L
    if (!is.null(dest) && std_counter$phase == "write") {
      std_counter$rows[[length(std_counter$rows) + 1L]] <-
        data.table::data.table(rel = basename(as.character(dest)[1]), ok = TRUE, message = what)
      if (length(std_counter$rows) > 50L) std_counter$rows <- utils::tail(std_counter$rows, 50L)
    }
    std_flush()
  }, error = function(e) NULL)   # progress must never stop pamflow
}

std_trace_on <- function() {
  ns <- asNamespace("pamflow")
  suppressMessages({
    trace("pam_audio_info", where = ns, print = FALSE,
          tracer = quote(if (identical(get("std_counter", envir = .GlobalEnv)$phase, "read"))
            get(".pd_std_tick", envir = .GlobalEnv)()))
    trace("file_copy", where = asNamespace("fs"), print = FALSE,
          exit = quote(get(".pd_std_tick", envir = .GlobalEnv)(new_path, "copied")))
    if (requireNamespace("av", quietly = TRUE)) {
      trace("av_audio_convert", where = asNamespace("av"), print = FALSE,
            exit = quote(get(".pd_std_tick", envir = .GlobalEnv)(output, "converted")))
    }
  })
}

# Header reading ends at the first copy: switch the counter to writing.
std_start_writing <- function(total) {
  std_flush(force = TRUE)
  pd_emit("stage", stage = "standardize", label = "Writing standardized files",
          run_dir = std_counter$out_dir %||% "", already_done = 0L)
  std_reset("write", total)
}

# A conversion error from pamflow's log: count it as failed, not done.
std_on_error <- function(text) {
  if (identical(std_counter$phase, "write") && grepl("^Failed to convert", text)) {
    std_counter$done <- max(0L, std_counter$done - 1L)
    std_counter$failed <- std_counter$failed + 1L
    src <- sub("^Failed to convert (.*?): .*$", "\\1", text)
    std_counter$rows[[length(std_counter$rows) + 1L]] <-
      data.table::data.table(rel = basename(src), ok = FALSE, message = "conversion failed")
  }
}

# pamflow 0.6.0 names the output folder after the first token of the raw
# file name (e.g. the recorder "SW001"), even when a prefix (the grid, e.g.
# "G0059") is set and used for the file names. With a prefix, the app makes
# the folder the prefix too, for this run only (pamflow is not changed).
std_with_prefix_folders <- function(prefix, expr) {
  if (!nzchar(prefix %||% "")) return(expr)
  ns <- asNamespace("pamflow")
  original <- get("pam_extract_grid", envir = ns)
  utils::assignInNamespace("pam_extract_grid", function(filename, pattern = NULL) prefix, ns = "pamflow")
  on.exit(utils::assignInNamespace("pam_extract_grid", original, ns = "pamflow"), add = TRUE)
  expr
}

std_call <- function(cfg, s, dry_run) {
  std_with_prefix_folders(s$prefix, pam_standardize(cfg, raw_dir = s$raw_dir, standardized_dir = s$standardized_dir,
                  isolated_dir = s$isolated_dir, dry_run = dry_run, prefix = s$prefix,
                  target_format = s$target_format, target_hz = s$target_hz, channels = s$channels,
                  min_duration_s = s$min_duration_s, organize_folders = s$organize_folders,
                  rename_strategy = s$rename_strategy, isolate_non_audio = s$isolate_non_audio,
                  isolate_short = s$isolate_short, timezone = s$timezone))
}

std_count_audio <- function(raw_dir) {
  files <- list.files(raw_dir, recursive = TRUE, full.names = FALSE)
  list(all = length(files), audio = sum(tolower(tools::file_ext(files)) %in% STD_AUDIO_EXT))
}

# Dry run: plan every file, save the plan, nothing else is written.
job_std_plan <- function(cfg) {
  s <- std_settings(cfg)
  probs <- std_problems(s)
  if (length(probs)) return(list(status = "failed", message = paste(probs, collapse = " ")))
  n <- std_count_audio(s$raw_dir)
  pd_emit("stage", stage = "std_inspect", label = "Reading raw files")
  std_reset("read", n$audio)
  std_flush(force = TRUE)
  std_trace_on()
  plan <- tryCatch(with_log_events(std_call(cfg, s, dry_run = TRUE)),
                   error = function(e) { pd_state$last_error <- conditionMessage(e); NULL })
  std_flush(force = TRUE)
  if (is.null(plan)) return(list(status = "failed", message = "Checking the raw files failed; see the log."))
  dir.create(cfg$paths$metadata, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(plan, std_plan_path(cfg))
  std_emit_state(cfg)
  list(status = "ok")
}

# The real run. pam_standardize reads every header again, then writes.
job_standardize <- function(cfg) {
  s <- std_settings(cfg)
  probs <- std_problems(s)
  if (length(probs)) return(list(status = "failed", message = paste(probs, collapse = " ")))
  n <- std_count_audio(s$raw_dir)
  std_counter$out_dir <- s$standardized_dir
  plan <- if (file.exists(std_plan_path(cfg))) data.table::fread(std_plan_path(cfg)) else NULL
  to_write <- if (!is.null(plan)) sum(plan$action != "SKIPPED") else n$all

  pd_emit("stage", stage = "std_inspect", label = "Reading raw files")
  std_reset("read", n$audio)
  std_flush(force = TRUE)
  std_trace_on()
  # the first file written switches the counter from reading to writing
  .pd_std_tick_read <- .pd_std_tick
  assign(".pd_std_tick", function(dest = NULL, what = "") {
    if (identical(std_counter$phase, "read") && !is.null(dest)) std_start_writing(to_write)
    .pd_std_tick_read(dest, what)
  }, envir = .GlobalEnv)

  t0 <- Sys.time()
  res <- tryCatch(with_log_events(std_call(cfg, s, dry_run = FALSE)),
                  error = function(e) { pd_state$last_error <- conditionMessage(e); NULL })
  if (identical(std_counter$phase, "read")) std_start_writing(to_write)  # nothing was written
  std_flush(force = TRUE)
  if (is.null(res)) return(list(status = "failed", message = "Standardizing failed; see the log."))
  std_emit_state(cfg)
  list(status = "ok", run_dir = s$standardized_dir,
       n_done = std_counter$done, n_failed = std_counter$failed,
       minutes = round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 2))
}
