# Tests for the bridge's pure helpers. Run from the project folder:
#   Rscript bridge/tests/test_protocol.R
source(file.path("bridge", "protocol.R"))
ok <- function(cond, what) { if (!isTRUE(cond)) stop("FAILED: ", what); cat("ok  ", what, "\n") }

# pamflow 0.6.0 log wording -> progress
p <- pd_parse_log("birdnet 0.2.16; 63 files pending; input=standardized; 4 workers; top_k=all")
ok(p$kind == "total" && p$n == 63, "total from 'files pending'")
ok(pd_parse_log("nothing pending for this run")$n == 0, "nothing pending -> total 0")
p <- pd_parse_log("batch 2/8: 7 ok, 1 failed, 120 detections | 40.0 files/h | ETA 90 min")
ok(p$kind == "batch" && p$batch == 2 && p$batches == 8 && p$ok == 7 && p$failed == 1 && p$detections == 120,
   "batch line parsed")
ok(pd_parse_log("stage started")$kind == "other", "other lines ignored")
p <- pd_parse_log("123 files to filter (12.3 GB input; filtered copies need about the same space in D:/f)")
ok(p$kind == "total" && p$n == 123, "filter total")
ok(pd_parse_log("nothing pending; all files already filtered")$n == 0, "filter nothing pending")
p <- pd_parse_log("batch 3/9: 198 ok, 2 failed")
ok(p$kind == "batch" && p$batch == 3 && p$batches == 9 && p$ok == 198 && p$failed == 2 && p$detections == 0,
   "filter batch line parsed")
ok(pd_parse_log("filtering finished: 400 ok, 2 failed of 402")$kind == "other", "filter finish line ignored")

# log line splitting
s <- pd_split_log_line("2026-11-01 10:00:00 [WARN] [03_detect] 2 files not found")
ok(s$level == "WARN" && s$stage == "03_detect" && s$text == "2 files not found", "log line split")
ok(pd_split_log_line("plain text")$text == "plain text", "plain text kept")

# config discovery
d <- tempfile(); dir.create(file.path(d, "config"), recursive = TRUE)
writeLines("paths: {}", file.path(d, "config", "config.yml"))
f <- pd_find_config(d)
ok(!is.null(f) && basename(f$config) == "config.yml" && f$root == normalizePath(d, winslash = "/"),
   "finds config/config.yml in a project folder")
f2 <- pd_find_config(file.path(d, "config", "config.yml"))
ok(f2$root == normalizePath(d, winslash = "/"), "config.yml path -> project root above config/")
ok(is.null(pd_find_config(tempfile())), "missing project -> NULL")

# a settings file anywhere (explicit config), and a pinned project_root
elsewhere <- tempfile(); dir.create(elsewhere)
writeLines("paths: {}", file.path(elsewhere, "my_settings.yml"))
f3 <- pd_find_config(d, config = file.path(elsewhere, "my_settings.yml"))
ok(basename(f3$config) == "my_settings.yml" && f3$root == normalizePath(elsewhere, winslash = "/"),
   "explicit config wins; relative project_root -> the file's own folder")
proj <- tempfile(); dir.create(proj)
writeLines(c("paths:", paste0("  project_root: \"", normalizePath(proj, winslash = "/"), "\"")), file.path(elsewhere, "pinned.yml"))
f4 <- pd_find_config("", config = file.path(elsewhere, "pinned.yml"))
ok(f4$root == normalizePath(proj, winslash = "/"), "absolute project_root in the file decides the project folder")
ok(is.null(pd_find_config(d, config = file.path(elsewhere, "gone.yml"))), "explicit config that is missing -> NULL")
ok(is.null(pd_find_config("")), "empty project -> NULL")
ok(pd_is_absolute("C:/data") && pd_is_absolute("C:\\data") && pd_is_absolute("/home/x") && !pd_is_absolute(".") &&
     !pd_is_absolute("data/raw"), "absolute path check")

# checkpoint counting ignores blank and repeated lines
ck <- tempfile(); writeLines(c("a.wav", "", "b.wav", "a.wav"), ck)
ok(pd_checkpoint_count(ck) == 2, "checkpoint count")

# event lines
out <- capture.output(pd_emit("total", n = 5L))
ok(out == '@@PAM {"type":"total","n":5}', "event line format")
cat("all bridge tests passed\n")
