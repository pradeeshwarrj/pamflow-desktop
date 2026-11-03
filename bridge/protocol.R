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
  dir <- dirname(pd_norm(config))
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
  all <- tryCatch(utils::read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  if (is.null(all) || nrow(all) <= seen) return(list(rows = NULL, seen = seen))
  list(rows = all[(seen + 1L):nrow(all), , drop = FALSE], seen = nrow(all))
}

#' Number of files in a run's checkpoint (done.txt).
pd_checkpoint_count <- function(path) {
  if (!file.exists(path)) return(0L)
  lines <- trimws(readLines(path, warn = FALSE))
  length(unique(lines[nzchar(lines)]))
}
