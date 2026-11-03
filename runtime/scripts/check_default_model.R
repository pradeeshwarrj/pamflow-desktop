# ---------------------------------------------------------------------
# Does BirdNET's own (global) model work through the app's engine?
#
#   pixi run Rscript scripts/check_default_model.R <models_dir> <recording.wav>
#
# <models_dir> is where bridge/download_model.py put the model (its
# birdnet-v2.4 folder is inside). The script then does what the app does:
# starts a new project, points its settings at the downloaded model, and runs
# a real Detect on the one recording, all through bridge/run_job.R.
# ---------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
models_dir <- normalizePath(args[1], winslash = "/", mustWork = TRUE)
wav <- normalizePath(args[2], winslash = "/", mustWork = TRUE)
bridge <- normalizePath(file.path("..", "bridge", "run_job.R"), winslash = "/", mustWork = TRUE)
prefix <- Sys.getenv("CONDA_PREFIX")
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")

ok <- function(cond, what, detail = "") {
  cat(sprintf("%-4s  %s %s\n", if (isTRUE(cond)) "OK" else "FAIL", what, detail))
  if (!isTRUE(cond)) quit(status = 1L)
}

run <- function(job) {
  job$runtime <- prefix
  job$models_dir <- models_dir
  f <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(job, auto_unbox = TRUE, null = "null"), f)
  out <- suppressWarnings(system2(rscript, c(shQuote(bridge), shQuote(f)), stdout = TRUE, stderr = TRUE))
  lines <- grep("^@@PAM ", out, value = TRUE)
  events <- lapply(lines, function(l) jsonlite::fromJSON(sub("^@@PAM ", "", l), simplifyVector = FALSE))
  list(events = events, out = out,
       of = function(type) Filter(function(e) identical(e$type, type), events),
       finished = Filter(function(e) identical(e$type, "finished"), events))
}

project <- file.path(tempdir(), "default-model-project")
dir.create(project)

r <- run(list(job = "project_create", project = project))
ok(length(r$of("project_created")) == 1 && identical(r$finished[[1]]$status, "ok"), "new project with the default settings")

r <- run(list(job = "model_info", project = project))
info <- r$of("model_info")[[1]]
ok(isTRUE(info$downloaded) && "en_us" %in% unlist(info$languages), "model found in the models folder",
   sprintf("(%s species)", info$n_species))

dir <- info$dir
r <- run(list(job = "config_save", project = project, changes = list(
  list(section = "birdnet", key = "model_dir", value = dir),
  list(section = "birdnet", key = "classifier_name", value = info$name),
  list(section = "birdnet", key = "labels_file", value = file.path(info$labels_dir, "en_us.txt")))))
p <- r$of("project")[[1]]
ok(isTRUE(p$model_found) && isTRUE(p$labels_found), "project settings point at the model",
   sprintf("(%s labels)", p$n_labels))

# a one-recording project that passes pamflow's checks
config <- file.path(project, "config", "config.yml")
txt <- readLines(config)
txt <- sub("^  min_duration_s: 1800", "  min_duration_s: 5", txt)
writeLines(txt, config)
audio <- file.path(project, "data", "standardized", "G0001")
dir.create(audio, recursive = TRUE)
file.copy(wav, file.path(audio, "G0001_20260401_060000.wav"))
dir.create(file.path(project, "metadata"))
writeLines(c(
  "deployment_id,recorder,grid,habitat,deployer,latitude,longitude,deploy_date,deploy_time,retrieve_date,retrieve_time",
  "D1,R1,G0001,forest,test,10,92,01-03-2026,00:00,30-04-2026,23:59"), file.path(project, "metadata", "deployments.csv"))

r <- run(list(job = "detect", project = project, birdnet = list(workers = 1, chunk_size = 1, min_confidence = 0.01)))
cat(tail(r$out, 25), sep = "\n")
fin <- r$finished[[1]]
ok(identical(fin$status, "ok"), "Detect with BirdNET's own model finished", if (is.null(fin$message)) "" else fin$message)
files <- r$of("files")
ok(length(files) >= 1 && files[[length(files)]]$failed == 0 && files[[length(files)]]$done >= 1,
   "the recording was processed without errors",
   sprintf("(%s detections)", files[[length(files)]]$detections))
cat("\nBirdNET's own model works end to end.\n")
