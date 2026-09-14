## ---------------------------------------------------------------------------
## drat_update.R -- tooling for maintaining the ethanbass/drat repository.
##
## Usage (shell):   tools/drat-add ~/R_packages/chromConverterExtraTests
## Usage (R):       source("tools/drat_update.R"); drat_add("~/R_packages/VPdtw")
##
## Notes on drat's `location` handling, which is inconsistent and easy to get
## wrong for a docs/-based repo:
##
##   insertPackage()   honours options(dratBranch="docs")  -> pass the REPO ROOT
##   pruneRepo()       honours it (guarded by grepl("docs$"))
##   getRepoInfo()     honours it (same guard)
##   archivePackages() calls getRepoInfo() (which appends "docs") but then calls
##                     updateRepo() with the RAW path -- so it only reindexes
##                     correctly if you hand it the docs path
##   updateRepo()      has no `location` argument at all; updateRepo(".") silently
##                     resolves to the top-level ./src/contrib and does nothing
##
## The rule encoded below: repo root for insertPackage(), explicit docs/ path for
## everything else.
## ---------------------------------------------------------------------------

DRAT_MARK_START <- "<!-- drat:packages:start -->"
DRAT_MARK_END   <- "<!-- drat:packages:end -->"
DRAT_MANIFEST   <- "manifest.dcf"

## -- helpers ----------------------------------------------------------------

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0L || is.na(x[1L])) y else x

msg <- function(...) cat(..., "\n", sep = "")
hdr <- function(x) cat("\n== ", x, " ==\n", sep = "")

git <- function(dir, ...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(dir), ...),
                                  stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0L) return(character(0))
  out
}

## Repo root: the parent of the directory holding this script, unless overridden.
script_dir <- function() {
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) return(dirname(normalizePath(sub("^--file=", "", a[1L]))))
  getwd()
}

drat_repo <- function(repo = NULL) {
  repo <- normalizePath(repo %||% dirname(script_dir()), mustWork = TRUE)
  if (!dir.exists(file.path(repo, "docs"))) {
    stop("'", repo, "' does not look like the drat repo (no docs/ directory).",
         call. = FALSE)
  }
  repo
}

drat_docs <- function(repo) file.path(repo, "docs")

## -- locating and describing a source package -------------------------------

## entab is laid out with the package in a subdirectory of its git repo
## (~/R_packages/entab -> entab/entab-r), so look one level down as well.
pkg_source <- function(pkg_path) {
  root <- normalizePath(pkg_path, mustWork = TRUE)
  cand <- c(root, file.path(root, paste0(basename(root), "-r")),
            list.dirs(root, recursive = FALSE))
  dir <- Find(function(d) file.exists(file.path(d, "DESCRIPTION")), cand)
  if (is.null(dir)) {
    stop("No DESCRIPTION found at '", root, "' or one level below it.", call. = FALSE)
  }
  d <- read.dcf(file.path(dir, "DESCRIPTION"))
  url <- if ("URL" %in% colnames(d)) trimws(strsplit(d[1, "URL"], ",")[[1]][1]) else NA_character_
  list(dir = dir,
       package = unname(d[1, "Package"]),
       version = unname(d[1, "Version"]),
       url = sub("/+$", "", url %||% NA_character_))
}

## Prefer the tag matching the version over HEAD -- HEAD has often moved past the
## version being inserted (e.g. VPdtw is at 2.3.0 locally while drat ships 2.2.1).
git_provenance <- function(dir, version) {
  top <- git(dir, "rev-parse", "--show-toplevel")
  if (!length(top)) {
    warning("'", dir, "' is not a git repository; no commit recorded.", call. = FALSE)
    return(list(commit = NA_character_, source = "none"))
  }
  top <- top[1L]
  tags <- c(paste0("v", version), version, paste0("v", sub("\\.(\\d+)$", "-\\1", version)))
  for (tg in tags) {
    sha <- git(top, "rev-list", "-n1", tg)
    if (length(sha)) return(list(commit = sha[1L], source = paste0("tag ", tg)))
  }
  sha <- git(top, "rev-parse", "HEAD")
  if (!length(sha)) return(list(commit = NA_character_, source = "none"))
  if (length(git(top, "status", "--porcelain"))) {
    warning("Working tree of '", top, "' is dirty; recording HEAD anyway.", call. = FALSE)
  }
  message("No tag found for ", version, " in ", top, "; recording HEAD.")
  list(commit = sha[1L], source = "HEAD")
}

## -- manifest ---------------------------------------------------------------

manifest_path <- function(repo) file.path(repo, DRAT_MANIFEST)

manifest_read <- function(repo) {
  p <- manifest_path(repo)
  cols <- c("Package", "Version", "URL", "Commit", "Date")
  if (!file.exists(p)) return(data.frame(matrix(character(0), 0, 5, dimnames = list(NULL, cols))))
  m <- as.data.frame(read.dcf(p), stringsAsFactors = FALSE)
  for (cl in setdiff(cols, names(m))) m[[cl]] <- NA_character_
  m[cols]
}

manifest_write <- function(repo, m) {
  m <- m[order(tolower(m$Package), numeric_version(m$Version)), , drop = FALSE]
  writeLines(sub("\n+$", "", paste(
    vapply(seq_len(nrow(m)), function(i) {
      f <- m[i, !is.na(unlist(m[i, ])), drop = FALSE]
      paste0(paste0(names(f), ": ", unlist(f), collapse = "\n"), "\n")
    }, character(1)), collapse = "\n")), manifest_path(repo))
}

## Records are never rewritten once present -- a version's provenance is fixed.
manifest_upsert <- function(repo, package, version, url, commit) {
  m <- manifest_read(repo)
  hit <- m$Package == package & m$Version == version
  if (any(hit)) {
    msg("  manifest: ", package, " ", version, " already recorded, leaving as is")
    return(invisible(m))
  }
  m <- rbind(m, data.frame(Package = package, Version = version, URL = url %||% NA_character_,
                           Commit = commit %||% NA_character_,
                           Date = format(Sys.Date()), stringsAsFactors = FALSE))
  manifest_write(repo, m)
  msg("  manifest: recorded ", package, " ", version, " @ ", substr(commit %||% "?", 1, 7))
  invisible(m)
}

## -- repository operations --------------------------------------------------

## Regenerate every PACKAGES index from the files actually on disk, across all
## R-version trees. This is the only thing that repairs an index advertising a
## file that is no longer present -- prune and archive act only on files that
## still exist.
drat_reindex <- function(repo = NULL) {
  repo <- drat_repo(repo)
  docs <- drat_docs(repo)

  rds <- list.files(docs, pattern = "^PACKAGES\\.rds$", recursive = TRUE, full.names = TRUE)
  before <- lapply(rds, function(f)
    list(obj = readRDS(f), raw = readBin(f, "raw", file.size(f))))
  names(before) <- rds

  withCallingHandlers(
    drat::updateRepo(docs, type = c("source", "binary"), version = NA),
    warning = function(w) {
      ## PACKAGES has no MD5 column for win.binary; write_PACKAGES says so every time.
      if (grepl("win.binary case", conditionMessage(w))) invokeRestart("muffleWarning")
    })

  ## saveRDS() stores an mtime in its gzip header, so rewriting an unchanged
  ## index still yields different bytes. Put the original back when the content
  ## is identical, so `git status` only shows indexes that really changed.
  for (f in names(before)) {
    if (file.exists(f) && identical(readRDS(f), before[[f]]$obj)) {
      writeBin(before[[f]]$raw, f)
    }
  }

  msg("  reindexed all PACKAGES files under ", docs)
  invisible(TRUE)
}

## Superseded sources are archived, superseded binaries are always deleted
## (CRAN-style repos have no binary archive). `newest` is computed per contrib
## directory, so binaries for older R versions are never collateral damage.
##
## Large tarballs are deleted rather than archived: chromConverterExtraTests
## ships ~95 MB per build, docs/ is already ~380 MB and GitHub Pages caps a
## published site at 1 GB. Nothing is lost -- every published version stays
## reachable in git history.
drat_sweep <- function(repo = NULL, archive = TRUE,
                       archive_max_mb = getOption("dratArchiveMaxMB", 25)) {
  docs <- drat_docs(drat_repo(repo))

  info <- drat::getRepoInfo(docs, type = "source", version = NA)
  old <- if (nrow(info)) info[!info$newest, , drop = FALSE] else info
  for (k in seq_len(nrow(old))) {
    from <- file.path(old$contrib.url[k], old$file[k])
    mb <- file.size(from) / 1048576
    if (archive && mb <= archive_max_mb) {
      dest <- file.path(old$contrib.url[k], "Archive", old$package[k])
      dir.create(dest, recursive = TRUE, showWarnings = FALSE)
      file.rename(from, file.path(dest, old$file[k]))
      msg(sprintf("  archived: %s (%.1f MB)", old$file[k], mb))
    } else {
      unlink(from)
      msg(sprintf("  deleted:  %s (%.1f MB%s)", old$file[k], mb,
                  if (archive) sprintf(", over the %g MB archive limit", archive_max_mb) else ""))
    }
  }

  info <- drat::getRepoInfo(docs, type = "binary", version = NA)
  old <- if (nrow(info)) info[!info$newest, , drop = FALSE] else info
  for (k in seq_len(nrow(old))) {
    from <- file.path(old$contrib.url[k], old$file[k])
    mb <- file.size(from) / 1048576
    unlink(from)
    msg(sprintf("  deleted:  %s (%.1f MB, binary)", old$file[k], mb))
  }
  invisible(TRUE)
}

drat_add <- function(pkg_path, repo = NULL, binary = TRUE, source = TRUE,
                     archive = TRUE, readme = TRUE) {
  repo <- drat_repo(repo)
  src <- pkg_source(pkg_path)
  hdr(paste(src$package, src$version))
  msg("  source: ", src$dir)

  prov <- git_provenance(src$dir, src$version)
  msg("  commit: ", substr(prov$commit %||% "?", 1, 7), " (", prov$source, ")")

  dest <- file.path(tempfile("dratbuild")); dir.create(dest)
  on.exit(unlink(dest, recursive = TRUE), add = TRUE)
  built <- character(0)
  if (source) built <- c(built, pkgbuild::build(src$dir, dest_path = dest, binary = FALSE))
  if (binary) built <- c(built, pkgbuild::build(src$dir, dest_path = dest, binary = TRUE))

  old <- getOption("dratBranch"); options(dratBranch = "docs")
  on.exit(options(dratBranch = old), add = TRUE)
  for (f in built) {
    ## repo ROOT here: insertPackage appends "docs" itself. No OSflavour -- on
    ## R >= 4.6 the platform (aarch64-apple-darwin23) maps to no known osx
    ## folder, so drat picks type "binary" and the right tree either way.
    drat::insertPackage(f, repodir = repo)
    msg("  inserted: ", basename(f))
  }

  drat_sweep(repo, archive = archive)
  drat_reindex(repo)
  manifest_upsert(repo, src$package, src$version, src$url, prov$commit)
  if (readme) drat_readme(repo)
  invisible(src)
}

## -- README / index.html ----------------------------------------------------

## Versions come from the source index (the truth about what the repo serves);
## URLs and commit SHAs come from the manifest.
drat_packages_block <- function(repo) {
  idx <- file.path(drat_docs(repo), "src", "contrib", "PACKAGES.rds")
  if (!file.exists(idx)) stop("No source index at ", idx, call. = FALSE)
  p <- as.data.frame(readRDS(idx), stringsAsFactors = FALSE)[c("Package", "Version")]
  p <- p[order(tolower(p$Package)), , drop = FALSE]
  m <- manifest_read(repo)

  entries <- vapply(seq_len(nrow(p)), function(i) {
    pkg <- p$Package[i]; ver <- p$Version[i]
    r <- m[m$Package == pkg & m$Version == ver, , drop = FALSE]
    url <- if (nrow(r)) r$URL[1L] else NA_character_
    sha <- if (nrow(r)) r$Commit[1L] else NA_character_
    head <- if (is.na(url)) paste0("- **", pkg, "**") else paste0("- **[", pkg, "](", url, ")**")
    detail <- if (is.na(sha)) {
      paste0("    - *v", ver, "*")
    } else if (is.na(url)) {
      paste0("    - *v", ver, ": ", substr(sha, 1, 7), "*")
    } else {
      paste0("    - *v", ver, ": [", substr(sha, 1, 7), "](", url, "/commit/", sha, ")*")
    }
    paste(head, detail, sep = "\n")
  }, character(1))

  paste(entries, collapse = "\n\n")
}

## Rewrites only the text between the markers; prose outside them is untouched.
drat_readme <- function(repo = NULL) {
  repo <- drat_repo(repo)
  path <- file.path(repo, "README.md")
  lines <- readLines(path, warn = FALSE)
  i <- which(trimws(lines) == DRAT_MARK_START)
  j <- which(trimws(lines) == DRAT_MARK_END)
  if (length(i) != 1L || length(j) != 1L || j <= i) {
    stop("README.md must contain exactly one ", DRAT_MARK_START, " / ",
         DRAT_MARK_END, " pair.", call. = FALSE)
  }
  new <- c(lines[seq_len(i)], "", strsplit(drat_packages_block(repo), "\n")[[1]], "",
           lines[j:length(lines)])
  if (!identical(new, lines)) {
    writeLines(new, path)
    msg("  README.md: package list regenerated")
  } else {
    msg("  README.md: already up to date")
  }
  drat_render_index(repo)
  invisible(TRUE)
}

drat_render_index <- function(repo = NULL) {
  repo <- drat_repo(repo)
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    warning("rmarkdown not installed; docs/index.html not regenerated.", call. = FALSE)
    return(invisible(FALSE))
  }
  lines <- readLines(file.path(repo, "README.md"), warn = FALSE)
  lines <- lines[!trimws(lines) %in% c(DRAT_MARK_START, DRAT_MARK_END)]
  tmp <- file.path(tempdir(), "README.md")
  writeLines(lines, tmp)
  rmarkdown::render(tmp, output_file = "index.html", output_dir = drat_docs(repo),
                    intermediates_dir = tempdir(), quiet = TRUE,
                    output_options = list(pandoc_args = c("--metadata", "title=drat")))
  msg("  docs/index.html: re-rendered")
  invisible(TRUE)
}

## -- consistency check ------------------------------------------------------

## Every file advertised by an index must exist, and every package file must be
## advertised. Returns TRUE when the repo is consistent.
drat_check <- function(repo = NULL) {
  repo <- drat_repo(repo)
  ok <- TRUE
  for (d in list.dirs(drat_docs(repo), recursive = TRUE)) {
    idx <- file.path(d, "PACKAGES.rds")
    if (!file.exists(idx)) next
    p <- as.data.frame(readRDS(idx), stringsAsFactors = FALSE)
    ext <- if (grepl("src/contrib$", d)) ".tar.gz" else ".tgz"
    if (grepl("bin/windows", d)) ext <- ".zip"
    want <- paste0(p$Package, "_", p$Version, ext)
    have <- list.files(d, pattern = paste0("\\", ext, "$"))
    rel <- sub(paste0("^", repo, "/"), "", d)
    if (length(setdiff(want, have))) {
      ok <- FALSE; msg("  MISSING FILE  ", rel, ": ", paste(setdiff(want, have), collapse = ", "))
    }
    if (length(setdiff(have, want))) {
      ok <- FALSE; msg("  NOT INDEXED   ", rel, ": ", paste(setdiff(have, want), collapse = ", "))
    }
  }
  if (ok) msg("  all indexes consistent with files on disk")
  invisible(ok)
}

## -- CLI --------------------------------------------------------------------

drat_cli <- function(argv) {
  usage <- paste(
    "Usage: tools/drat-add [options] [<package-path>...]",
    "",
    "  --repo <path>   drat repo root (default: parent of this script)",
    "  --no-binary     skip the mac binary build",
    "  --no-source     skip the source build",
    "  --no-archive    delete superseded sources instead of archiving them",
    "  --reindex       only reindex + regenerate README/index.html",
    "  --check         only report index/file inconsistencies",
    "  -h, --help",
    sep = "\n")
  opt <- list(repo = NULL, binary = TRUE, source = TRUE, archive = TRUE,
              reindex = FALSE, check = FALSE)
  paths <- character(0)
  i <- 1L
  while (i <= length(argv)) {
    a <- argv[i]
    switch(a,
      "--repo"       = { opt$repo <- argv[i + 1L]; i <- i + 1L },
      "--no-binary"  = opt$binary <- FALSE,
      "--no-source"  = opt$source <- FALSE,
      "--no-archive" = opt$archive <- FALSE,
      "--reindex"    = opt$reindex <- TRUE,
      "--check"      = opt$check <- TRUE,
      "-h"           = { cat(usage, "\n"); return(invisible(0L)) },
      "--help"       = { cat(usage, "\n"); return(invisible(0L)) },
      if (startsWith(a, "-")) { cat(usage, "\n"); stop("Unknown option: ", a, call. = FALSE) }
      else paths <- c(paths, a))
    i <- i + 1L
  }
  repo <- drat_repo(opt$repo)

  if (opt$check) { hdr("check"); return(invisible(if (drat_check(repo)) 0L else 1L)) }

  if (length(paths)) {
    for (p in paths) {
      drat_add(p, repo = repo, binary = opt$binary, source = opt$source,
               archive = opt$archive)
    }
  } else if (opt$reindex) {
    hdr("reindex"); drat_sweep(repo); drat_reindex(repo); drat_readme(repo)
  } else {
    cat(usage, "\n"); return(invisible(1L))
  }

  hdr("check"); drat_check(repo)
  hdr("review and commit")
  st <- git(repo, "status", "--short")
  if (!length(st)) { msg("  working tree clean -- nothing to commit"); return(invisible(0L)) }
  cat(paste0("  ", st, collapse = "\n"), "\n", sep = "")
  last <- if (length(paths)) pkg_source(paths[length(paths)]) else NULL
  suggest <- if (is.null(last)) "reindex drat repo" else paste(last$package, paste0("v", last$version))
  msg("\n  git -C ", repo, " add -A && git -C ", repo, " commit -m ", shQuote(suggest))
  msg("  git -C ", repo, " push origin master")
  invisible(0L)
}

if (!interactive() && sys.nframe() == 0L) {
  quit(status = drat_cli(commandArgs(trailingOnly = TRUE)) %||% 0L)
}
