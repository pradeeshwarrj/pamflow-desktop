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

  invisible(applied)
}
