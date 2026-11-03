# ---------------------------------------------------------------------
# pamflow Desktop — R bridge: change settings in config.yml
#
# Changes only the lines of the settings being edited and leaves every
# comment, blank line and other setting exactly as it was (a normal YAML
# writer would drop all comments). Works on pamflow's two-level layout:
#
#   section:
#     key: value          # comment kept
#
# Pure functions (no pamflow calls) so they can be tested alone.
# ---------------------------------------------------------------------

#' Format an R value as a YAML value on one line.
pd_yaml_value <- function(value) {
  if (is.null(value) || (length(value) == 1 && is.na(value))) return("null")
  quote <- function(s) paste0('"', gsub('"', '\\\\"', gsub("\\\\", "\\\\\\\\", s)), '"')
  one <- function(v) {
    if (is.logical(v)) return(if (v) "true" else "false")
    if (is.numeric(v)) return(format(v, scientific = FALSE, trim = TRUE, digits = 15))
    quote(as.character(v))
  }
  if (is.list(value) || length(value) != 1 || isTRUE(attr(value, "as_list"))) {
    items <- unlist(value)
    return(if (length(items)) paste0("[", paste(vapply(items, one, ""), collapse = ", "), "]") else "[]")
  }
  one(value)
}

# Indent of a line (number of leading spaces).
pd_indent <- function(line) nchar(line) - nchar(sub("^ +", "", line))

# Is this line a comment or blank?
pd_is_blank <- function(line) grepl("^\\s*(#.*)?$", line)

#' The trailing comment of a "key: value  # comment" line, or "".
#' A # inside quotes is part of the value, not a comment.
pd_trailing_comment <- function(rest) {
  chars <- strsplit(rest, "", fixed = TRUE)[[1]]
  in_single <- FALSE; in_double <- FALSE
  for (i in seq_along(chars)) {
    ch <- chars[i]
    if (ch == "'" && !in_double) in_single <- !in_single
    else if (ch == '"' && !in_single && (i == 1 || chars[i - 1] != "\\")) in_double <- !in_double
    else if (ch == "#" && !in_single && !in_double && (i == 1 || chars[i - 1] %in% c(" ", "\t"))) {
      return(substring(rest, i))
    }
  }
  ""
}

#' Set `section: key:` to `value` in the lines of a config file.
#' @param lines Character vector (the file's lines).
#' @param section,key Names, e.g. "birdnet", "min_confidence".
#' @param value An R value (see pd_yaml_value).
#' @return The changed lines.
pd_yaml_set <- function(lines, section, key, value) {
  yaml_value <- pd_yaml_value(value)
  header <- grep(sprintf("^%s:\\s*(#.*)?$", section), lines)
  if (!length(header)) {
    # new section at the end
    if (length(lines) && nzchar(lines[length(lines)])) lines <- c(lines, "")
    return(c(lines, paste0(section, ":"), sprintf("  %s: %s", key, yaml_value)))
  }
  header <- header[1]

  # the section's block: until the next line that starts at column 0
  end <- length(lines)
  if (header < length(lines)) {
    for (i in (header + 1):length(lines)) {
      if (!pd_is_blank(lines[i]) && pd_indent(lines[i]) == 0) { end <- i - 1; break }
    }
  }
  block <- if (end > header) (header + 1):end else integer()
  content <- block[!vapply(lines[block], pd_is_blank, logical(1))]
  base <- if (length(content)) min(vapply(lines[content], pd_indent, numeric(1))) else 2

  key_re <- sprintf("^ {%d}%s:(\\s.*|)$", base, gsub(".", "\\.", key, fixed = TRUE))
  hit <- block[grepl(key_re, lines[block])]
  new_line <- function(comment) {
    paste0(strrep(" ", base), key, ": ", yaml_value, if (nzchar(comment)) paste0("  ", comment) else "")
  }

  if (length(hit)) {
    at <- hit[1]
    rest <- sub(sprintf("^ {%d}%s:\\s?", base, gsub(".", "\\.", key, fixed = TRUE)), "", lines[at])
    comment <- pd_trailing_comment(rest)
    # a value written as an indented block below the key (e.g. a "- item" list)
    # is replaced too
    # Comment lines are always kept (pamflow's template continues comments on
    # the next lines); a blank line or the next setting ends the old value.
    cont <- integer()
    i <- at + 1
    while (i <= end) {
      l <- lines[i]
      if (grepl("^\\s*$", l)) break
      if (grepl("^\\s*#", l)) { i <- i + 1; next }
      if (pd_indent(l) > base || grepl(sprintf("^ {%d}- ", base), l)) { cont <- c(cont, i); i <- i + 1; next }
      break
    }
    lines[at] <- new_line(comment)
    if (length(cont)) lines <- lines[-cont]
    return(lines)
  }

  # key not in the section yet: add it after the section's last setting
  last <- if (length(content)) max(content) else header
  append(lines, new_line(""), after = last)
}

#' Apply several changes: `changes` is a list of list(section, key, value).
pd_yaml_apply <- function(lines, changes) {
  for (ch in changes) lines <- pd_yaml_set(lines, ch$section, ch$key, ch$value)
  lines
}


# ---- new settings files --------------------------------------------------

#' The project folder a settings file at `target` would belong to if it did not
#' pin `project_root` (same rule as pd_config_root in protocol.R).
pd_derive_root <- function(target) {
  dir <- dirname(normalizePath(path.expand(target), winslash = "/", mustWork = FALSE))
  if (tolower(basename(dir)) == "config") dirname(dir) else dir
}

#' Lines of a new settings file: pamflow's own default settings with a short
#' header on top. If the file will not sit at <root>/config/config.yml (or in
#' <root> itself), `project_root` is written as the absolute project folder so
#' the folders in the file still point at the project.
#' @param template_lines pamflow's config_template.yml, read as lines.
#' @param root the project folder (absolute).
#' @param target where the new file will be written.
pd_new_config_lines <- function(template_lines, root, target, version = "", date = format(Sys.Date())) {
  root <- gsub("\\\\", "/", root)
  pin <- !identical(tolower(pd_derive_root(target)), tolower(normalizePath(root, winslash = "/", mustWork = FALSE)))
  header <- c(
    "# pamflow project settings",
    sprintf("# Created by pamflow Desktop on %s from the default settings of pamflow%s.", date,
            if (nzchar(version)) paste0(" ", version) else ""),
    "# Change them in the app (Project step) or in any text editor; the app keeps these comments.",
    if (pin) "# project_root below is the project folder; other folders are relative to it."
    else "# Folders that are not absolute are relative to project_root (\".\" = the project folder).",
    "")
  body <- template_lines
  if (pin) body <- pd_yaml_set(body, "paths", "project_root", root)
  c(header, body)
}

#' Write lines as UTF-8 with the given line endings.
pd_write_lines <- function(x, file, crlf = FALSE) {
  con <- file(file, open = "wb")
  on.exit(close(con))
  eol <- if (crlf) "\r\n" else "\n"
  writeBin(charToRaw(enc2utf8(paste0(paste(x, collapse = eol), eol))), con)
}
