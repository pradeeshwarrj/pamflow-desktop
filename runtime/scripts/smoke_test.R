# ---------------------------------------------------------------------
# Phase 0 smoke test: does everything in the runtime work together?
#
#   pixi run smoke
#   pixi run smoke <model.tflite> <labels.txt> [recording.wav]
#
# With a custom BirdNET model it also loads the model, and with a
# recording it runs a real detection through pamflow's own BirdNET
# runner — exactly what the app will do.
# Every check prints OK / FAIL; the summary at the end says what to send back.
# ---------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
results <- data.frame(check = character(), status = character(), detail = character())
record <- function(check, ok, detail = "") {
  status <- if (isTRUE(ok)) "OK" else "FAIL"
  cat(sprintf("%-4s  %-26s %s\n", status, check, detail))
  results[nrow(results) + 1L, ] <<- list(check, status, detail)
  invisible(ok)
}
timed <- function(expr) { t <- proc.time()[["elapsed"]]; v <- expr; list(value = v, s = proc.time()[["elapsed"]] - t) }

cat("\n== pamflow runtime smoke test ==\n\n")

prefix <- Sys.getenv("CONDA_PREFIX")
is_windows <- .Platform$OS.type == "windows"
record("runtime folder", nzchar(prefix) && dir.exists(prefix), prefix)
record("R", TRUE, paste(R.version$version.string, "|", R.version$platform))
norm <- function(p) tolower(normalizePath(p, winslash = "/", mustWork = FALSE))
outside <- .libPaths()[!startsWith(norm(.libPaths()), norm(prefix))]
record("R uses only runtime library", length(outside) == 0,
       if (length(outside)) paste("also sees:", paste(outside, collapse = ", ")) else .libPaths()[1])

# --- R packages ---
pkgs <- c("pamflow", "av", "cli", "data.table", "fs", "ggplot2", "glue", "processx", "ps",
          "rlang", "seewave", "shiny", "tuneR", "withr", "yaml",
          "reticulate", "openxlsx", "rmarkdown", "knitr", "jsonlite")
for (p in pkgs) {
  ok <- suppressWarnings(requireNamespace(p, quietly = TRUE))
  record(paste("R package", p), ok, if (ok) as.character(utils::packageVersion(p)) else "not installed")
}

# --- ffmpeg ---
ffmpeg <- Sys.which("ffmpeg")
ff_ok <- nzchar(ffmpeg) && startsWith(normalizePath(ffmpeg, winslash = "/"), normalizePath(prefix, winslash = "/"))
ff_ver <- if (nzchar(ffmpeg)) tryCatch(system2(ffmpeg, "-version", stdout = TRUE)[1], error = function(e) "") else ""
record("ffmpeg (bundled)", ff_ok, if (nzchar(ffmpeg)) paste(ffmpeg, "|", sub(" Copyright.*", "", ff_ver)) else "not found")

# --- Python + BirdNET ---
python <- if (is_windows) file.path(prefix, "python.exe") else file.path(prefix, "bin", "python")
record("Python (bundled)", file.exists(python), python)

probe <- c(
  "import os, sys, time",
  "os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'",
  "from importlib import metadata",
  "t = time.time()",
  "import tensorflow as tf, birdnet",
  "print('PROBE python=' + sys.version.split()[0])",
  "print('PROBE birdnet=' + metadata.version('birdnet'))",
  "print('PROBE tensorflow=' + tf.__version__)",
  "print('PROBE import_s=%.1f' % (time.time() - t))")
probe_file <- tempfile(fileext = ".py"); writeLines(probe, probe_file)
out <- tryCatch(suppressWarnings(system2(python, c("-I", shQuote(probe_file)), stdout = TRUE, stderr = TRUE)),
                error = function(e) conditionMessage(e))
kv <- sub("^PROBE ", "", grep("^PROBE ", out, value = TRUE))
record("BirdNET + TensorFlow import", length(kv) == 4, paste(kv, collapse = "  "))
if (length(kv) != 4) cat(tail(out, 15), sep = "\n")

# --- pamflow finds the bundled Python? (after the app's own adjustments) ---
source(file.path("scripts", "pamflow_patches.R"))
patched <- tryCatch(pam_desktop_apply_patches(), error = function(e) paste("error:", conditionMessage(e)))
if (length(patched)) cat("      app adjustments applied:", paste(patched, collapse = "; "), "\n")
pf_python <- tryCatch(pamflow:::pam_birdnet_python_path(prefix), error = function(e) NA_character_)
record("pamflow finds this Python", isTRUE(file.exists(pf_python)),
       if (isTRUE(file.exists(pf_python))) pf_python else paste("pamflow looks for", pf_python))

# --- Optional: the user's custom model and a real recording ---
script <- tryCatch(pamflow:::pam_birdnet_py_script(), error = function(e) "")
if (length(args) >= 2) {
  model <- normalizePath(args[1], winslash = "/", mustWork = FALSE)
  labels <- normalizePath(args[2], winslash = "/", mustWork = FALSE)
  r <- timed(suppressWarnings(system2(python, c(shQuote(script), "--check",
    "--model", shQuote(model), "--labels", shQuote(labels)), stdout = TRUE, stderr = TRUE)))
  line <- grep("^PAMCHECK", r$value, value = TRUE)
  record("custom model loads", length(line) == 1, if (length(line)) sprintf("%s (%.0f s)", line, r$s) else "see output above")
  if (!length(line)) cat(tail(r$value, 15), sep = "\n")

  if (length(args) >= 3 && length(line)) {
    wav <- normalizePath(args[3], winslash = "/", mustWork = FALSE)
    files <- tempfile(fileext = ".txt"); writeLines(wav, files)
    out_csv <- tempfile(fileext = ".csv"); status_csv <- tempfile(fileext = ".csv")
    r <- timed(suppressWarnings(system2(python, c(shQuote(script),
      "--files", shQuote(files), "--out", shQuote(out_csv), "--status", shQuote(status_csv),
      "--model", shQuote(model), "--labels", shQuote(labels),
      "--min-confidence", "0.3", "--n-workers", "1"), stdout = TRUE, stderr = TRUE)))
    det <- if (file.exists(out_csv)) utils::read.csv(out_csv) else NULL
    ok <- !is.null(det)
    detail <- if (ok) {
      top <- if (nrow(det)) names(sort(table(det$species_name), decreasing = TRUE))[1] else "none"
      sprintf("%d detections in %.0f s (most: %s)", nrow(det), r$s, top)
    } else "no output — see above"
    record("real detection on 1 file", ok, detail)
    if (!ok) cat(tail(r$value, 20), sep = "\n")
  }
} else {
  cat("\n(skipped model + detection test: run `pixi run smoke <model.tflite> <labels.txt> <recording.wav>`)\n")
}

# --- Size of the runtime ---
size_gb <- tryCatch({
  f <- list.files(prefix, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  sum(file.size(f), na.rm = TRUE) / 1024^3
}, error = function(e) NA)
cat(sprintf("\nRuntime size: %.2f GB\n", size_gb))

fails <- sum(results$status == "FAIL")
cat(sprintf("\n== %d checks, %d failed ==\n", nrow(results), fails))
cat(if (fails) "Send the FAIL lines above back to Claude.\n" else "Everything works. Phase 0 runtime is good.\n")
quit(status = if (fails) 1L else 0L)
