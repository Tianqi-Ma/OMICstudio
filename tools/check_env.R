# OmicOne pre-flight check.
#
# Run this before testing to see, step by step, what your machine can actually
# run and what is missing. Nothing here loads the app or touches your data.
#
#   Rscript tools/check_env.R
#   # or, from an R session in the repo:
#   source("tools/check_env.R")
#
# Keep the step->package map below in sync with the require_pkgs() calls in
# R/mod_*.R; tools/check_mirror.sh does not police this one.

have <- function(p) isTRUE(requireNamespace(p, quietly = TRUE))
# Report "-" rather than NA for a package that is not installed. Defined here
# because this script must run standalone, before the package is loaded.
ver  <- function(p) if (have(p)) as.character(utils::packageVersion(p)) else "-"

rule <- function(t) cat("\n", t, "\n", strrep("-", 72), "\n", sep = "")
ok   <- function(x) if (x) "OK     " else "MISSING"

# ---- 1. the app shell -------------------------------------------------------

rule("1. App shell (needed for OmicOne to start at all)")

shell <- list(
  list(p = "shiny",  min = "1.7.4"),
  list(p = "bslib",  min = "0.7.0"),
  list(p = "ggplot2", min = "3.4.0"),
  list(p = "Matrix", min = NA),
  list(p = "survival", min = NA)
)
shell_ok <- TRUE
for (s in shell) {
  v <- ver(s$p)
  good <- have(s$p) && (is.na(s$min) || utils::compareVersion(v, s$min) >= 0)
  if (!good) shell_ok <- FALSE
  cat(sprintf("  %-10s %-9s %s%s\n", s$p, v, ok(good),
              if (!is.na(s$min)) paste0("   (need >= ", s$min, ")") else ""))
}
cat(sprintf("  %-10s %-9s\n", "R", paste0(R.version$major, ".", R.version$minor)))
if (!shell_ok) {
  cat("\n  -> The app will not start until these are satisfied.\n",
      "     install.packages(c('shiny','bslib','ggplot2'))\n", sep = "")
}

# ---- 2. optional niceties ---------------------------------------------------

rule("2. Optional (the app runs without these, but degrades)")
for (p in c("DT", "patchwork", "plotly", "rmarkdown")) {
  cat(sprintf("  %-10s %-9s %s   %s\n", p, ver(p), ok(have(p)),
              switch(p,
                     DT        = "interactive tables -> plain text fallback",
                     patchwork = "multi-panel figures -> first panel only",
                     plotly    = "hover on UMAP / feature plots -> static",
                     rmarkdown = "HTML report -> self-contained HTML fallback")))
}

# ---- 3. per-step readiness --------------------------------------------------

# step label -> packages its run button needs
sc_needs <- list(
  "1  Import"                = "Seurat",
  "2  Quality control"       = "Seurat",
  "3  Doublets"              = c("Seurat", "scDblFinder"),
  "4  Normalize"             = "Seurat",
  "5  Features / PCA"        = "Seurat",
  "6  Integrate (harmony)"   = c("Seurat", "harmony"),
  "7  Cluster"               = "Seurat",
  "8  Embed"                 = "Seurat",
  "9  Markers"               = "Seurat",
  "10 Annotate (SingleR)"    = c("Seurat", "SingleR", "celldex"),
  "11 Enrichment / GSEA"     = "scop",
  "12 Trajectory"            = "scop",
  "13 RNA velocity"          = "scop",
  "14 Dynamic features"      = "scop",
  "15 Cell cycle & sigs"     = c("Seurat", "scop"),
  "16 Cell communication"    = "liana",
  "17 Malignant / CNV"       = c("scop", "copykat"),
  "18 Clinical & survival"   = "survival",
  "19 Visualize"             = "Seurat",
  "20 Report"                = character(0),
  "21 Export"                = character(0)
)
wes_needs <- list(
  "1  Import MAF"            = "maftools",
  "2  Cohort summary"        = "maftools",
  "3  Oncoplot"              = "maftools",
  "4  TiTv / VAF / rainfall" = "maftools",
  "5  TMB"                   = "maftools",
  "6  Lollipop / domains"    = "maftools",
  "7  Drivers & interactions"= "maftools",
  "8  Mutational signatures" = c("maftools", "NMF", "BSgenome.Hsapiens.UCSC.hg19"),
  "9  Clinical/pathway/drug" = "maftools",
  "10 Cohort comparison"     = "maftools",
  "11 Mutation vs survival"  = c("maftools", "survival"),
  "12 Heterogeneity"         = "maftools"
)

report <- function(title, needs) {
  rule(title)
  n_ready <- 0
  for (nm in names(needs)) {
    miss <- needs[[nm]][!vapply(needs[[nm]], have, logical(1))]
    ready <- length(miss) == 0
    n_ready <- n_ready + ready
    cat(sprintf("  %-26s %s%s\n", nm, ok(ready),
                if (ready) "" else paste0("   needs: ", paste(miss, collapse = ", "))))
  }
  cat(sprintf("\n  %d / %d steps runnable here.\n", n_ready, length(needs)))
  invisible(n_ready)
}
report("3. Single-cell pipeline", sc_needs)
report("4. WES pipeline", wes_needs)

# ---- 4. maftools API drift --------------------------------------------------

rule("5. maftools API")
if (!have("maftools")) {
  cat("  maftools not installed.\n",
      "  It is a plain Bioconductor binary - no source build, no compiler:\n",
      "      install.packages('BiocManager'); BiocManager::install('maftools')\n", sep = "")
} else {
  cat(sprintf("  maftools %s\n", ver("maftools")))
  needed <- c("read.maf", "getSampleSummary", "getGeneSummary", "getClinicalData",
              "getFields", "subsetMaf", "plotmafSummary", "oncoplot", "titv",
              "plotTiTv", "plotVaf", "rainfallPlot", "tmb", "lollipopPlot",
              "oncodrive", "plotOncodrive", "somaticInteractions",
              "trinucleotideMatrix", "extractSignatures", "compareSignatures",
              "plotSignatures", "plotApobecDiff", "clinicalEnrichment",
              "plotEnrichmentResults", "drugInteractions", "mafCompare",
              "forestPlot", "coBarplot", "inferHeterogeneity", "plotClusters")
  ns <- asNamespace("maftools")
  missing <- needed[!vapply(needed, exists, logical(1), where = ns, inherits = FALSE)]
  if (!exists("pathways", where = ns, inherits = FALSE) &&
      !exists("OncogenicPathways", where = ns, inherits = FALSE)) {
    missing <- c(missing, "pathways / OncogenicPathways")
  }
  if (!length(missing)) {
    cat("  All 31 entry points the WES modules call are present.\n")
  } else {
    cat("  Not found in your maftools (the modules call these):\n")
    cat(paste0("    - ", missing, collapse = "\n"), "\n")
  }
  demo <- system.file("extdata", "tcga_laml.maf.gz", package = "maftools")
  cat(sprintf("  Bundled TCGA LAML demo: %s\n",
              if (nzchar(demo)) "present (no download needed)" else "NOT FOUND"))
}

# ---- 5. what to do next -----------------------------------------------------

rule("6. Suggested test order")
lines <- c(
  "  a. Launch the app and click through the landing page  (needs nothing more)",
  "  b. WES: Import MAF -> keep 'Demo data' -> Load MAF     (needs maftools only)",
  "  c. Clinical & survival with a small CSV                (needs nothing more)",
  "  d. Single-cell: Import -> ... -> Visualize             (needs Seurat)",
  "  e. Anything marked 'scop' above: use the Docker image, not this machine")
cat(paste(lines, collapse = "\n"), "\n\n")
cat("  Launch without building the package (works when a policy blocks Rcmd.exe):\n")
cat("      pkgload::load_all('.'); run_app()\n\n")
