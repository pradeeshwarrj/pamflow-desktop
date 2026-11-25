# Tests for the comment-preserving config editor. Run from the project folder:
#   Rscript bridge/tests/test_config_edit.R [path/to/pamflow/config_template.yml]
source(file.path("bridge", "protocol.R"))
source(file.path("bridge", "config_edit.R"))
ok <- function(cond, what) { if (!isTRUE(cond)) stop("FAILED: ", what); cat("ok  ", what, "\n") }

cfg_text <- c(
  "paths:",
  "  project_root: \".\"",
  "  audio_standardized: \"data/standardized\"",
  "",
  "filenames:",
  "  # G0059_YYYYMMDD_HHMMSS.flac ; timestamps are local time",
  "  pattern: \"^(?<grid>G\\\\d{4})_(?<date>\\\\d{8})_(?<time>\\\\d{6})(_chunk\\\\d+)?\\\\.(flac|wav)$\"",
  "  timezone: \"Asia/Kolkata\"",
  "",
  "birdnet:",
  "  run_id: \"run01\"",
  "  min_confidence: 0.3",
  "  workers: null             # parallel worker processes, each with its own model copy.",
  "                            # null = half of the physical cores.",
  "  chunk_size: 100           # files per batch",
  "",
  "deployments:",
  "  columns: [deployment_id, recorder, grid]",
  "processing:",
  "  species_whitelist:",
  "    - Psittacula columboides",
  "    - Ocyceros griseus",
  "  min_confidence: 0.5",
  "report:",
  "  title: \"PAM # Report\"   # a hash inside quotes is not a comment")

parse <- function(lines) yaml::yaml.load(paste(lines, collapse = "\n"))

# 1. change a number, keep the comment and the continued comment lines
out <- pd_yaml_set(cfg_text, "birdnet", "workers", 8)
ok(any(out == "  workers: 8  # parallel worker processes, each with its own model copy."), "value changed, comment kept")
ok(any(grepl("# null = half of the physical cores.", out, fixed = TRUE)), "continued comment line kept")
ok(parse(out)$birdnet$workers == 8 && parse(out)$birdnet$chunk_size == 100, "file still parses, neighbours unchanged")

# 2. strings are quoted and escaped; Windows paths keep their backslashes
out <- pd_yaml_set(cfg_text, "paths", "audio_standardized", "E:\\GNI\\Standard \"set\"")
ok(parse(out)$paths$audio_standardized == "E:\\GNI\\Standard \"set\"", "string with backslashes and quotes round-trips")

# 3. the regex pattern line is never touched by other edits
out <- pd_yaml_set(cfg_text, "filenames", "timezone", "Asia/Kolkata")
ok(identical(out[7], cfg_text[7]), "pattern line untouched")
ok(parse(out)$filenames$pattern == parse(cfg_text)$filenames$pattern, "pattern value unchanged")

# 4. a block list is replaced by a flow list
out <- pd_yaml_set(cfg_text, "processing", "species_whitelist", list())
ok(identical(parse(out)$processing$species_whitelist, list()), "block list replaced by []")
ok(parse(out)$processing$min_confidence == 0.5, "setting after the list kept")
out <- pd_yaml_set(cfg_text, "processing", "species_whitelist", list("Gracula religiosa"))
ok(identical(parse(out)$processing$species_whitelist, "Gracula religiosa"), "one-item list")

# 5. booleans and null
out <- pd_yaml_set(cfg_text, "birdnet", "chunk_size", NULL)
ok(is.null(parse(out)$birdnet$chunk_size) && any(grepl("chunk_size: null  # files per batch", out)), "null keeps comment")
out <- pd_yaml_set(cfg_text, "validation", "show_confidence", TRUE)
ok(isTRUE(parse(out)$validation$show_confidence), "new section added")

# 6. a key missing from an existing section is added inside it
out <- pd_yaml_set(cfg_text, "birdnet", "overlap_s", 1.5)
p <- parse(out)
ok(p$birdnet$overlap_s == 1.5 && p$birdnet$run_id == "run01", "missing key added to its section")
ok(which(out == "  overlap_s: 1.5") < which(out == "deployments:"), "added inside the section, not after it")

# 7. a # inside quotes is part of the value
out <- pd_yaml_set(cfg_text, "report", "title", "Nilgiris PAM")
ok(any(out == "  title: \"Nilgiris PAM\"  # a hash inside quotes is not a comment"), "quoted # handled")

# 8. several changes at once; all other lines identical
out <- pd_yaml_apply(cfg_text, list(list(section = "birdnet", key = "min_confidence", value = 0.4),
                                    list(section = "report", key = "title", value = "X")))
changed <- which(out != cfg_text)
ok(length(out) == length(cfg_text) && length(changed) == 2, "only the two edited lines differ")

# 9. on pamflow's real template (if given): every edit keeps all comments
args <- commandArgs(trailingOnly = TRUE)
if (length(args) && file.exists(args[1])) {
  tpl <- readLines(args[1], warn = FALSE)
  edits <- list(list(section = "birdnet", key = "workers", value = 6),
                list(section = "birdnet", key = "min_confidence", value = 0.35),
                list(section = "processing", key = "species_whitelist", value = list("Gracula religiosa")),
                list(section = "occupancy", key = "occasion_length_days", value = 7),
                list(section = "report", key = "author", value = "Pradeeshwar"),
                list(section = "validation", key = "reviewer", value = "RJ"))
  out <- pd_yaml_apply(tpl, edits)
  comments <- function(l) l[grepl("#", l)]
  ok(length(setdiff(sub(".*?#", "#", comments(tpl)), sub(".*?#", "#", comments(out)))) == 0, "template: all comments kept")
  p <- parse(out); p0 <- parse(tpl)
  ok(p$birdnet$workers == 6 && p$birdnet$min_confidence == 0.35 && p$occupancy$occasion_length_days == 7 &&
       p$report$author == "Pradeeshwar" && p$validation$reviewer == "RJ" &&
       identical(p$processing$species_whitelist, "Gracula religiosa"), "template: edits applied")
  edited <- vapply(edits, function(e) paste(e$section, e$key, sep = "."), "")
  same <- TRUE
  for (sec in names(p0)) {
    if (!is.list(p0[[sec]])) { same <- same && identical(p[[sec]], p0[[sec]]); next }
    for (k in names(p0[[sec]])) {
      if (paste(sec, k, sep = ".") %in% edited) next
      same <- same && (k %in% names(p[[sec]])) && identical(p[[sec]][[k]], p0[[sec]][[k]])
    }
  }
  ok(same && identical(names(p), names(p0)), "template: every other setting unchanged")
}

# ---- new settings files -------------------------------------------------
tpl_lines <- if (length(commandArgs(TRUE)) && file.exists(commandArgs(TRUE)[1])) readLines(commandArgs(TRUE)[1], warn = FALSE) else cfg_text
proj <- file.path(tempdir(), "my project")
std <- pd_new_config_lines(tpl_lines, proj, file.path(proj, "config", "config.yml"), version = "0.6.0", date = "2026-11-03")
ok(std[1] == "# pamflow project settings" && grepl("2026-11-03", std[2]) && grepl("pamflow 0.6.0", std[2]), "new file: header")
ok(identical(parse(std)$paths$project_root, parse(tpl_lines)$paths$project_root), "new file in <project>/config: project_root left as in the template")
ok(identical(parse(std)[names(parse(tpl_lines))], parse(tpl_lines)), "new file: every setting equals the template")
ok(all(tpl_lines %in% std), "new file: template lines kept as they are")
elsewhere <- file.path(tempdir(), "shared", "study.yml")
pin <- pd_new_config_lines(tpl_lines, proj, elsewhere)
ok(identical(parse(pin)$paths$project_root, gsub("\\\\", "/", normalizePath(proj, winslash = "/", mustWork = FALSE))),
   "new file elsewhere: project_root pinned to the project folder")
ok(identical(pd_derive_root(file.path(proj, "config", "x.yml")), gsub("\\\\", "/", normalizePath(proj, winslash = "/", mustWork = FALSE))) ||
     identical(tolower(pd_derive_root(file.path(proj, "config", "x.yml"))), tolower(normalizePath(proj, winslash = "/", mustWork = FALSE))),
   "root derived from config/ folder")
f <- tempfile(fileext = ".yml"); pd_write_lines(std, f)
ok(identical(readLines(f, warn = FALSE), std) && !any(readBin(f, "raw", file.size(f)) == as.raw(13)), "written with plain line endings, read back unchanged")

# soundscape indices: keep what stays selected, add defaults for new ones, drop the rest
sc <- c("soundscape:", "  enabled: true", "  window_mins: 10",
        "  acoustic_indices:   # which indices",
        "    ACI:", "    Bio:", "      flim: [1500, 9000]   # my range", "    NDSI:",
        "      anthro_range: [1000, 2000]",
        "  day_hours: [6, 17]", "", "occupancy:", '  run_id: "x"')
o <- pd_yaml_set_indices(sc, c("NDSI", "Bio", "ADI"))
p <- parse(o)
ok(identical(names(p$soundscape$acoustic_indices), c("ADI", "Bio", "NDSI")), "indices: chosen ones only, in pamflow's order")
ok(identical(p$soundscape$acoustic_indices$Bio$flim, c(1500L, 9000L)) && any(grepl("# my range", o, fixed = TRUE)), "indices: kept index keeps its settings and comment")
ok(identical(p$soundscape$acoustic_indices$ADI$bin_step, 1000L), "indices: new index gets pamflow's defaults")
ok(any(grepl("# which indices", o, fixed = TRUE)) && identical(p$soundscape$day_hours, c(6L, 17L)) && identical(p$occupancy$run_id, "x"), "indices: neighbours and comment untouched")
ok(identical(names(parse(pd_yaml_set_indices(sc[1:3], "M"))$soundscape$acoustic_indices), "M"), "indices: added when the key is missing")
ok(identical(names(parse(pd_yaml_set_indices(c("paths:", "  a: 1"), c("M", "ACI")))$soundscape$acoustic_indices), c("ACI", "M")), "indices: added when the section is missing")
ok(inherits(try(pd_yaml_set_indices(sc, character()), silent = TRUE), "try-error"), "indices: an empty choice is refused")
ok(identical(names(parse(pd_yaml_apply(sc, list(list(section = "soundscape", key = "acoustic_indices", value = list("AEve", "M")))))$soundscape$acoustic_indices), c("AEve", "M")), "indices: reached through pd_yaml_apply")

# every new "More settings" kind of value, written into pamflow's real template
tpl_path <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else NA
if (!is.na(tpl_path) && file.exists(tpl_path)) {
  tl <- readLines(tpl_path, warn = FALSE, encoding = "UTF-8")
  chg <- list(
    list(section = "processing", key = "species_whitelist", value = list("Psittacula columboides")),
    list(section = "processing", key = "species_blacklist", value = list("Gallus gallus", "Pavo cristatus")),
    list(section = "processing", key = "date_range", value = list("2026-03-26", "2026-04-20")),
    list(section = "processing", key = "species_thresholds_file", value = "data/thr.csv"),
    list(section = "processing", key = "species_season_file", value = NULL),
    list(section = "birdnet", key = "top_k", value = 5L),
    list(section = "birdnet", key = "device", value = "GPU"),
    list(section = "deployments", key = "columns", value = list("deployment_id", "grid", "deploy_date")),
    list(section = "validation", key = "bands", value = list(0.4, 0.6, 1)),
    list(section = "validation", key = "spec_px", value = list(800L, 300L)),
    list(section = "recall", key = "hours", value = list()),
    list(section = "report", key = "formats", value = list("html")))
  o <- pd_yaml_apply(tl, chg)
  r <- parse(o)
  ok(identical(r$processing$species_whitelist, "Psittacula columboides") && identical(r$processing$species_blacklist, c("Gallus gallus", "Pavo cristatus")), "template: species lists")
  ok(identical(r$processing$date_range, c("2026-03-26", "2026-04-20")) && identical(r$processing$species_thresholds_file, "data/thr.csv") && is.null(r$processing$species_season_file), "template: dates, file and null")
  ok(identical(r$birdnet$top_k, 5L) && identical(r$birdnet$device, "GPU"), "template: BirdNET values")
  ok(identical(r$deployments$columns, c("deployment_id", "grid", "deploy_date")), "template: the multi-line column list is replaced whole")
  ok(identical(r$validation$spec_px, c(800L, 300L)) && isTRUE(all.equal(r$validation$bands, c(0.4, 0.6, 1))), "template: number lists")
  ok(length(r$recall$hours) == 0 && identical(r$report$formats, "html"), "template: empty list and one-item list")
  ok(identical(names(r), names(parse(tl))), "template: sections kept")
  ok(sum(grepl("^[[:space:]]*#", o)) == sum(grepl("^[[:space:]]*#", tl)), "template: every comment line kept")
} else cat("skip template test (pass the path of pamflow's config_template.yml)\n")
cat("all config editor tests passed\n")
