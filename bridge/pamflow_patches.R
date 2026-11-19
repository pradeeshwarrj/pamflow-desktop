# ---------------------------------------------------------------------
# Small adjustments the desktop app applies to pamflow AFTER loading it.
#
# The pamflow package itself is never changed: it is installed as-is from
# GitHub. These adjustments live only inside the app's R session, so they
# can be removed as soon as pamflow handles the case itself.
#
# Usage (the app's R bridge, and the smoke test, do this at start-up):
#   source("bridge/pamflow_patches.R"); pam_desktop_apply_patches()
# ---------------------------------------------------------------------

pam_desktop_apply_patches <- function() {
  applied <- character()

  # 1. Windows: Python location inside the bundled runtime.
  #    pamflow expects a Python *virtual environment*, where Windows keeps
  #    Python in Scripts\python.exe. The bundled runtime is a conda/pixi
  #    environment, where it is python.exe at the top of the folder.
  #    macOS and Linux use bin/python in both cases, so nothing changes there.
  if (.Platform$OS.type == "windows") {
    fixed <- function(envdir) {
      venv  <- file.path(envdir, "Scripts", "python.exe")
      conda <- file.path(envdir, "python.exe")
      if (!file.exists(venv) && file.exists(conda)) conda else venv
    }
    ns <- asNamespace("pamflow")
    if (exists("pam_birdnet_python_path", envir = ns, inherits = FALSE)) {
      utils::assignInNamespace("pam_birdnet_python_path", fixed, ns = "pamflow")
      applied <- c(applied, "python path (Windows conda layout)")
    }
  }

  # 2. Soundscape: batch size from config.yml (soundscape: batch_size:).
  #    pamflow 0.6.0 fixes it at 50 files inside pam_soundscape_batch(). The one
  #    line is rewritten to read the setting (still 50 when it is not set).
  #    If pamflow changes that line, nothing is patched.
  ns <- asNamespace("pamflow")
  if (exists("pam_soundscape_batch", envir = ns, inherits = FALSE)) {
    txt <- deparse(get("pam_soundscape_batch", envir = ns), width.cutoff = 500L)
    hit <- grep("^\\s*batch_size <- 50L?\\s*$", txt)
    if (length(hit) == 1) {
      txt[hit] <- "  batch_size <- max(1L, as.integer(pam_or(sc_cfg$batch_size, 50L)))"
      utils::assignInNamespace("pam_soundscape_batch", eval(parse(text = txt), envir = ns), ns = "pamflow")
      applied <- c(applied, "soundscape batch size from config")
    }
  }

  invisible(applied)
}
