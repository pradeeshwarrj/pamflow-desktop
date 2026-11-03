# ---------------------------------------------------------------------
# Does the "Try with example data" path work through the app's engine?
#
#   pixi run Rscript scripts/check_example_project.R
#
# Does what the app does: makes pamflow's example project in a "Documents"
# folder, reads it, scans it and cleans its sample detections, all through
# bridge/run_job.R. Also writes a diagnostics file.
# ---------------------------------------------------------------------
bridge <- normalizePath(file.path("..", "bridge", "run_job.R"), winslash = "/", mustWork = TRUE)
prefix <- Sys.getenv("CONDA_PREFIX")
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
ok <- function(cond, what, detail = "") {
  cat(sprintf("%-4s  %s %s\n", if (isTRUE(cond)) "OK" else "FAIL", what, detail))
  if (!isTRUE(cond)) quit(status = 1L)
}
run <- function(job) {
  job$runtime <- prefix
  f <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(job, auto_unbox = TRUE, null = "null"), f)
  out <- suppressWarnings(system2(rscript, c(shQuote(bridge), shQuote(f)), stdout = TRUE, stderr = TRUE))
  events <- lapply(grep("^@@PAM ", out, value = TRUE), function(l) jsonlite::fromJSON(sub("^@@PAM ", "", l), simplifyVector = FALSE))
  list(out = out, of = function(type) Filter(function(e) identical(e$type, type), events),
       finished = Filter(function(e) identical(e$type, "finished"), events))
}
status <- function(r) if (length(r$finished)) r$finished[[1]]$status else "none"

docs <- file.path(tempdir(), "Documents"); dir.create(docs)
r <- run(list(job = "example_project", project = "", documents_dir = docs))
ok(length(r$of("example_created")) == 1 && status(r) == "ok", "example project made and read")
p <- r$of("project")[[1]]
ok(identical(p$n_audio, 6L) || identical(p$n_audio, 6), "the project has the six example recordings", sprintf("(%s)", p$n_audio))
root <- r$of("example_created")[[1]]$root

r2 <- run(list(job = "example_project", project = "", documents_dir = docs))
ok(grepl("pamflow example 2$", r2$of("example_created")[[1]]$root), "a second example gets its own folder")

r <- run(list(job = "scan", project = root))
cat(tail(r$out, 8), sep = "\n")
ok(status(r) == "ok", "Scan on the example project")
r <- run(list(job = "process", project = root))
cat(tail(r$out, 8), sep = "\n")
ok(status(r) == "ok", "Process on the example detections")

diag <- file.path(tempdir(), "diag", "diagnostics.txt")
r <- run(list(job = "diagnostics", project = root, target = diag, app_version = "test", models_dir = file.path(docs, "models")))
saved <- r$of("diagnostics_saved")
ok(length(saved) == 1 && file.exists(diag) && file.size(diag) > 500, "diagnostics file written", sprintf("(%s bytes)", file.size(diag)))
txt <- readLines(diag, warn = FALSE)
ok(any(grepl("^pamflow: ", txt)) && any(grepl("^== Settings file", txt)), "diagnostics has versions and the settings file")
cat("\nThe example project works end to end.\n")
