# Tests for the comment-preserving config editor. Run from the project folder:
#   Rscript bridge/tests/test_config_edit.R [path/to/pamflow/config_template.yml]
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
  "    - Otus alius",
  "    - Ducula nicobarica",
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
out <- pd_yaml_set(cfg_text, "processing", "species_whitelist", list("Otus alius"))
ok(identical(parse(out)$processing$species_whitelist, "Otus alius"), "one-item list")

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
out <- pd_yaml_set(cfg_text, "report", "title", "Nicobar PAM")
ok(any(out == "  title: \"Nicobar PAM\"  # a hash inside quotes is not a comment"), "quoted # handled")

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
                list(section = "processing", key = "species_whitelist", value = list("Otus alius")),
                list(section = "occupancy", key = "occasion_length_days", value = 7),
                list(section = "report", key = "author", value = "Pradeeshwar"),
                list(section = "validation", key = "reviewer", value = "RJ"))
  out <- pd_yaml_apply(tpl, edits)
  comments <- function(l) l[grepl("#", l)]
  ok(length(setdiff(sub(".*?#", "#", comments(tpl)), sub(".*?#", "#", comments(out)))) == 0, "template: all comments kept")
  p <- parse(out); p0 <- parse(tpl)
  ok(p$birdnet$workers == 6 && p$birdnet$min_confidence == 0.35 && p$occupancy$occasion_length_days == 7 &&
       p$report$author == "Pradeeshwar" && p$validation$reviewer == "RJ" &&
       identical(p$processing$species_whitelist, "Otus alius"), "template: edits applied")
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
cat("all config editor tests passed\n")
