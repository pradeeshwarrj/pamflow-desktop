# ---------------------------------------------------------------------
# pamflow Desktop — R bridge: message protocol and helpers
#
# The app (Rust) starts `Rscript run_job.R <job.json>` in the bundled
# runtime and reads its standard output line by line. Every line that
# starts with "@@PAM " is one event, written as JSON:
#
#   @@PAM {"type":"stage","stage":"detect","label":"Detecting calls"}
#   @@PAM {"type":"total","n":63}
#   @@PAM {"type":"files","rows":[...],"done":8,"failed":0,"detections":120}
#   @@PAM {"type":"log","level":"INFO","text":"..."}
#   @@PAM {"type":"finished","status":"ok", ...}
#
# Anything else on stdout/stderr is shown in the app's log as plain text.
# These functions are pure (no pamflow calls) so they can be tested alone.
# ---------------------------------------------------------------------

PD_PREFIX <- "@@PAM "

#' Write one event line. `...` become the JSON fields.
pd_emit <- function(type, ..., con = stdout()) {
  fields <- c(list(type = type), list(...))
  json <- jsonlite::toJSON(fields, auto_unbox = TRUE, null = "null", na = "null",
                           digits = NA, POSIXt = "ISO8601")
  cat(PD_PREFIX, json, "\n", sep = "", file = con)
  flush(con)
  invisible(fields)
}

#' Is this path written as an absolute path (C:/..., /home/..., ~/..., \\\\server\\...)?
pd_is_absolute <- function(p) {
  is.character(p) && length(p) == 1 && !is.na(p) && grepl("^([A-Za-z]:[/\\\\]|/|~|\\\\\\\\)", p)
}

pd_norm <- function(p) normalizePath(path.expand(p), winslash = "/", mustWork = FALSE)

#' The project folder a settings file belongs to.
#'
#' If the file pins `paths: project_root:` to an absolute folder, that folder.
#' Otherwise the folder above `config/` when the file sits in a folder called
#' config, or else the folder holding the file (relative folders in the file
#' are resolved from there).
pd_config_root <- function(config) {
  pinned <- tryCatch(yaml::read_yaml(config)$paths$project_root, error = function(e) NULL)
  if (pd_is_absolute(pinned)) return(pd_norm(pinned))
  pd_derive_root(config)
}

#' The project folder a settings file at `target` would belong to if it did not
#' pin `project_root`: the folder above `config/`, or else the folder holding it.
pd_derive_root <- function(target) {
  dir <- dirname(pd_norm(target))
  if (tolower(basename(dir)) == "config") dirname(dir) else dir
}

#' Find a project's settings (config) file.
#'
#' `project` is a project folder (looks for config/config.yml, then
#' config.yml) or a path straight to a .yml file. `config` is a settings file
#' chosen explicitly, which can be anywhere; it wins over `project`.
#' @return list(config = path, root = folder to work in), or NULL if none.
pd_find_config <- function(project, config = NULL) {
  project <- if (length(project) == 1 && !is.na(project) && nzchar(project)) pd_norm(project) else ""
  explicit <- if (length(config) == 1 && !is.na(config) && nzchar(config)) pd_norm(config) else NULL
  yml <- if (!is.null(explicit)) explicit else if (grepl("\\.ya?ml$", project, ignore.case = TRUE)) project else NULL
  if (!is.null(yml)) {
    if (!file.exists(yml)) return(NULL)
    return(list(config = yml, root = pd_config_root(yml)))
  }
  if (!nzchar(project)) return(NULL)
  for (candidate in c("config/config.yml", "config/config.yaml", "config.yml", "config.yaml")) {
    path <- file.path(project, candidate)
    if (file.exists(path)) return(list(config = path, root = project))
  }
  NULL
}

#' Recognise pamflow log lines the app turns into progress.
#'
#' Reads the text of pamflow's own log messages (pam_log), so it follows
#' their wording in pamflow 0.6.0 (Detect and Filter):
#'   "birdnet 0.2.16; 63 files pending; input=..."      -> total
#'   "123 files to filter (12.3 GB input; ..."            -> total
#'   "nothing pending ..."                                -> total 0
#'   "batch 2/8: 8 ok, 0 failed, 120 detections | ..."    -> batch done
#'   "batch 2/8: 8 ok, 0 failed"                          -> batch done (filter)
#' @return list(kind = "total"|"batch"|"other", ...)
pd_parse_log <- function(text) {
  # Detect: "birdnet 0.2.16; 63 files pending; ..."   Filter: "123 files to filter (12.3 GB input; ..."
  m <- regmatches(text, regexec("; ([0-9]+) files pending;", text))[[1]]
  if (length(m) != 2) m <- regmatches(text, regexec("^([0-9]+) files to filter \\(", text))[[1]]
  if (length(m) == 2) return(list(kind = "total", n = as.integer(m[2])))
  # Soundscape: "Starting soundscape processing for 416 remaining files across 4 worker core(s)..."
  m <- regmatches(text, regexec("soundscape processing for ([0-9]+) remaining files", text))[[1]]
  if (length(m) == 2) return(list(kind = "total", n = as.integer(m[2])))
  if (grepl("All requested soundscape batch files are already processed", text, fixed = TRUE)) {
    return(list(kind = "total", n = 0L))
  }
  # Soundscape: "Soundscape Batch 2/9 complete. Speed: ..." (pamflow's batches are 50 files)
  m <- regmatches(text, regexec("Soundscape Batch ([0-9]+)/([0-9]+) complete", text))[[1]]
  if (length(m) == 3) return(list(kind = "batch", batch = as.integer(m[2]), batches = as.integer(m[3]),
                                  ok = NA_integer_, failed = 0L, detections = 0L))
  if (grepl("nothing pending for this run", text, fixed = TRUE) ||
      grepl("nothing pending; all files already filtered", text, fixed = TRUE)) {
    return(list(kind = "total", n = 0L))
  }
  # Detect: "batch 2/8: 8 ok, 0 failed, 120 detections | ..."   Filter: "batch 2/8: 8 ok, 0 failed"
  m <- regmatches(text, regexec(
    "batch ([0-9]+)/([0-9]+): ([0-9]+) ok, ([0-9]+) failed(, ([0-9]+) detections)?", text))[[1]]
  if (length(m) >= 5 && nzchar(m[1])) {
    v <- as.integer(m[2:5])
    det <- if (length(m) >= 7 && nzchar(m[7])) as.integer(m[7]) else 0L
    return(list(kind = "batch", batch = v[1], batches = v[2], ok = v[3], failed = v[4],
                detections = det))
  }
  list(kind = "other")
}

#' Split a pamflow log line "2026-11-01 10:00:00 [INFO] [03_detect] text".
#' @return list(level, stage, text); level "INFO" when the line has no prefix.
pd_split_log_line <- function(line) {
  m <- regmatches(line, regexec("^\\S+ \\S+ \\[(INFO|WARN|ERROR)\\] \\[([^]]+)\\] (.*)$", line))[[1]]
  if (length(m) == 4) list(level = m[2], stage = m[3], text = m[4])
  else list(level = "INFO", stage = "", text = line)
}

#' Rows of file_results.csv added since `seen` rows were read.
#' @return list(rows = data.frame, seen = new row count)
pd_new_results <- function(path, seen = 0L) {
  if (!file.exists(path)) return(list(rows = NULL, seen = seen))
  # read only the new lines, not the whole file again (it grows to one row per recording)
  new <- tryCatch({
    header <- names(data.table::fread(path, nrows = 0L))
    data.table::fread(path, skip = seen + 1L, header = FALSE, col.names = header, data.table = FALSE)
  }, error = function(e) NULL)
  if (is.null(new) || !nrow(new)) return(list(rows = NULL, seen = seen))
  list(rows = new, seen = seen + nrow(new))
}

#' Number of files in a run's checkpoint (done.txt).
pd_checkpoint_count <- function(path) {
  if (!file.exists(path)) return(0L)
  lines <- trimws(readLines(path, warn = FALSE))
  length(unique(lines[nzchar(lines)]))
}

#' Put pamflow's example project in the Western Ghats (it ships with Great Nicobar data):
#' new coordinates and habitats in the deployment sheet, and Western Ghats bird names in
#' the sample detections. Changes only what it finds, so a different example is left alone.
pd_localize_example <- function(deployments, detections) {
  sheet <- readLines(deployments, warn = FALSE, encoding = "UTF-8")
  sheet <- sub(",Forest,Asha,7.01,93.82,", ",Shola forest,Asha,11.41,76.70,", sheet, fixed = TRUE)
  sheet <- sub(",Plantation,Ravi,7.05,93.85,", ",Tea plantation,Ravi,11.38,76.73,", sheet, fixed = TRUE)
  writeLines(sheet, deployments)

  d <- utils::read.csv(detections, stringsAsFactors = FALSE)
  rename <- list(c("Psittacula longicauda", "Psittacula columboides", "Long-tailed Parakeet", "Malabar Parakeet"),
                 c("Ducula nicobarica", "Ocyceros griseus", "Nicobar Imperial-Pigeon", "Malabar Grey Hornbill"))
  for (r in rename) {
    d$scientific_name[d$scientific_name == r[1]] <- r[2]
    d$common_name[d$common_name == r[3]] <- r[4]
  }
  utils::write.csv(d, detections, row.names = FALSE)
  invisible(TRUE)
}

#' Soundscape results belong to the settings that made them.
#'
#' pamflow remembers the files it finished per run name and skips them, so after
#' the indices, window or filter change, old results would be mixed with new
#' ones. If the run folder holds results made with other settings, they are moved
#' (not deleted) into old_<time>/ so the next run starts fresh. Results from the
#' same settings are left alone, so a stopped run continues.
#' @param dir the run's folder; @param signature the settings as one line of text;
#' @param indices the index names switched on (e.g. "ACI").
#' @return the folder the old results were moved to, or NULL when nothing moved.
pd_archive_stale_soundscape <- function(dir, signature, indices) {
  raw <- file.path(dir, "soundscape_raw.csv")
  sig_file <- file.path(dir, "settings_used.json")
  remember <- function() { dir.create(dir, recursive = TRUE, showWarnings = FALSE); writeLines(signature, sig_file) }
  if (!file.exists(raw) || file.size(raw) == 0) { remember(); return(NULL) }
  header <- tryCatch(names(utils::read.csv(raw, nrows = 1, check.names = FALSE)), error = function(e) NULL)
  if (is.null(header)) return(NULL)
  made_with <- tolower(setdiff(header, c("file_id", "window_index", "window_start_sec", "window_end_sec")))
  same_indices <- setequal(made_with, tolower(indices))
  # results from before the settings were recorded: only their columns can be checked
  same_settings <- if (file.exists(sig_file)) identical(readLines(sig_file, warn = FALSE)[1], signature) else TRUE
  if (same_indices && same_settings) { remember(); return(NULL) }
  stamp <- file.path(dir, paste0("old_", format(Sys.time(), "%Y%m%d-%H%M%S")))
  old <- stamp
  for (n in 2:99) if (dir.exists(old)) old <- paste0(stamp, "_", n)
  dir.create(old, recursive = TRUE)
  for (f in c("soundscape_raw.csv", "done.txt", "soundscape_hourly.csv", "soundscape_diel_summary.csv",
              "soundscape_site_covariates.csv", "plots", "reports", "settings_used.json")) {
    if (file.exists(file.path(dir, f))) file.rename(file.path(dir, f), file.path(old, f))
  }
  remember()
  old
}

# Indices the app does not offer: Acoustic Entropy (H) comes out empty for every file in pamflow 0.6.0.
# Remove it here once pamflow computes it.
PD_UNAVAILABLE_INDICES <- "H"

#' The soundscape indices a settings file asks for.
#'
#' pamflow merges the file over its own defaults with modifyList(), where a
#' listed index with no settings ("ACI:" = null) is DELETED and an index that is
#' not listed stays on: the opposite of what the list says. The list in the file
#' is the choice, so exactly those indices are used, each with its own settings
#' laid over pamflow's defaults for that index.
#' @param user `soundscape: acoustic_indices:` as read from the file itself.
#' @param defaults the same from pamflow's template.
#' @return a named list, one entry per chosen index (an empty list when it has no settings).
pd_resolve_indices <- function(user, defaults) {
  out <- list()
  for (name in setdiff(names(user), PD_UNAVAILABLE_INDICES)) {
    base <- if (is.list(defaults[[name]])) defaults[[name]] else list()
    own <- user[[name]]
    out[[name]] <- if (is.list(own) && length(own)) utils::modifyList(base, own) else base
  }
  out
}
