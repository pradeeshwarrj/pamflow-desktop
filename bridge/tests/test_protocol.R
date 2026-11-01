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

# checkpoint counting ignores blank and repeated lines
ck <- tempfile(); writeLines(c("a.wav", "", "b.wav", "a.wav"), ck)
ok(pd_checkpoint_count(ck) == 2, "checkpoint count")

# event lines
out <- capture.output(pd_emit("total", n = 5L))
ok(out == '@@PAM {"type":"total","n":5}', "event line format")
cat("all bridge tests passed\n")
