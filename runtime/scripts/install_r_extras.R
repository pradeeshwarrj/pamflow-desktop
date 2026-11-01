# ---------------------------------------------------------------------
# Install the R packages that conda-forge does not provide, into the
# runtime's own R library (never into the user's normal R).
#
#   tuneR, seewave  : pamflow imports, not on conda-forge
#   av              : only on Apple Silicon (no conda-forge build there)
#   pamflow         : downloaded from GitHub at a fixed version (below),
#                     never from a local folder
#
# Windows uses CRAN's ready-made binaries (no compiler needed).
# macOS and Linux compile from source with the compiler in the runtime.
# Safe to run again: packages already installed are skipped.
# ---------------------------------------------------------------------

options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)

norm <- function(p) tolower(normalizePath(p, winslash = "/", mustWork = FALSE))
lib <- .libPaths()[1]
prefix <- Sys.getenv("CONDA_PREFIX")
if (!nzchar(prefix) || !startsWith(norm(lib), norm(prefix))) {
  stop("Run this through pixi (`pixi run setup-r`) so packages go into the runtime, not your own R library.\n",
       "  R library in use: ", lib)
}
cat("Installing into:", lib, "\n")

is_windows <- .Platform$OS.type == "windows"
is_mac_arm <- Sys.info()[["sysname"]] == "Darwin" && R.version$arch %in% c("aarch64", "arm64")

wanted <- c("tuneR", "seewave")
if (is_mac_arm) wanted <- c("av", wanted)

missing <- wanted[!vapply(wanted, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  cat("From CRAN:", paste(missing, collapse = ", "), "\n")
  install.packages(missing, lib = lib, type = if (is_windows) "binary" else "source",
                   dependencies = c("Depends", "Imports", "LinkingTo"))
} else {
  cat("tuneR/seewave already installed\n")
}

still <- wanted[!vapply(wanted, requireNamespace, logical(1), quietly = TRUE)]
if (length(still)) stop("Could not install: ", paste(still, collapse = ", "))

# pamflow itself, from GitHub (pure R, so no compiler is needed).
# Pinned to the 0.6.0 commit so every build gets exactly the same pamflow.
# To use a newer pamflow, change this line (a tag like "@v0.6.0" also works).
PAMFLOW_VERSION <- "pradeeshwarrj/pamflow@0a49bcdb9075fe083f25183989f7bbb736aba721"  # 0.6.0
ref <- Sys.getenv("PAMFLOW_REF", PAMFLOW_VERSION)
cat("pamflow from GitHub:", ref, "\n")
# Download the plain source archive ("owner/repo@version" -> .tar.gz) instead of
# remotes::install_github(): that asks GitHub's API first, which allows only
# 60 requests per hour per network address and fails on shared networks.
parts <- regmatches(ref, regexec("^([^/]+)/([^@]+)@(.+)$", ref))[[1]]
if (length(parts) != 4) stop("PAMFLOW_REF must look like owner/repo@version, got: ", ref)
url <- sprintf("https://github.com/%s/%s/archive/%s.tar.gz", parts[2], parts[3], parts[4])
remotes::install_url(url, lib = lib, dependencies = FALSE, upgrade = "never",
                     build_vignettes = FALSE, force = TRUE, quiet = TRUE)

cat("\npamflow", as.character(utils::packageVersion("pamflow", lib.loc = lib)), "installed.\n")
cat("Next: pixi run smoke\n")
