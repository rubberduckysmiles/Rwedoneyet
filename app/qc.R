# Bank of Bloody Mary: the one file to source.
# From the repo root:  source("app/qc.R")
# It loads every .R file in app/R/. There are no statistics in this file, only source() calls.

.qc_dir <- local({
  # Find the folder this file lives in, so source("app/qc.R") works from any working directory.
  here <- NULL
  for (i in rev(seq_len(sys.nframe()))) { # source() keeps the file it is reading in a variable called ofile
    f <- sys.frame(i)$ofile
    if (is.character(f) && length(f) == 1) {
      here <- dirname(normalizePath(f))
      break
    }
  }
  if (is.null(here)) { # run as: Rscript app/qc.R
    args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
    if (length(args) > 0) here <- dirname(normalizePath(sub("^--file=", "", args[1])))
  }
  if (is.null(here)) stop("qc.R: cannot tell where this file is. Use source(\"app/qc.R\") from the repo root.")
  here
})

for (.qc_file in sort(list.files(file.path(.qc_dir, "R"), pattern = "\\.[Rr]$", full.names = TRUE))) {
  source(.qc_file, local = TRUE)
}
rm(.qc_file, .qc_dir)
