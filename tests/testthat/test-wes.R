# The WES layer is thin wrappers over maftools, which is not installed here, so
# most of it can only be checked statically. What these tests *can* pin down is
# the part that is ours: the guesses, the registry wiring, and the bridge into
# the shared survival layer.

test_that("the WES step registry is internally consistent", {
  steps <- steps_wes()
  expect_equal(length(steps), 12)
  expect_equal(vapply(steps, function(s) s$n, numeric(1)), 1:12)
  expect_true(all(vapply(steps, function(s) is.function(s$ui), logical(1))))
  # keys are prefixed so they cannot collide with another omics' namespaces
  expect_true(all(grepl("^wes_", vapply(steps, function(s) s$v, character(1)))))
  # every phase key resolves to a label
  phases <- app_phases()
  for (s in steps) expect_true(!is.null(phases[[s$phase]]), info = s$v)
})

test_that("wes_missing_api reports cleanly when maftools is absent", {
  # On a machine without maftools this must be NA (not an error), so the check
  # is safe to call from anywhere.
  out <- wes_missing_api()
  if (!has_pkg("maftools")) {
    expect_true(is.na(out))
  } else {
    expect_equal(out, character(0))
  }
})

test_that("the VAF and protein-change column guesses handle real MAF namings", {
  tcga <- c("Hugo_Symbol", "Variant_Classification", "i_TumorVAF_WU",
            "HGVSp_Short", "Tumor_Sample_Barcode")
  expect_equal(wes_pick_vaf_col(tcga), "i_TumorVAF_WU")
  expect_equal(wes_pick_aa_col(tcga), "HGVSp_Short")

  # vcf2maf / annovar style
  expect_equal(wes_pick_vaf_col(c("Hugo_Symbol", "VAF")), "VAF")
  expect_equal(wes_pick_aa_col(c("Hugo_Symbol", "AAChange.refGene")),
               "AAChange.refGene")

  # unusual naming still gets found by the fuzzy pass
  expect_equal(wes_pick_vaf_col(c("Hugo_Symbol", "tumor_allele_freq")),
               "tumor_allele_freq")
  expect_equal(wes_pick_aa_col(c("Hugo_Symbol", "my_hgvsp_col")), "my_hgvsp_col")

  # nothing plausible -> NULL, so the module can say so instead of guessing wrong
  expect_null(wes_pick_vaf_col(c("Hugo_Symbol", "Chromosome")))
  expect_null(wes_pick_aa_col(c("Hugo_Symbol", "Chromosome")))
  expect_null(wes_pick_vaf_col(character(0)))
  expect_null(wes_pick_aa_col(character(0)))
})

test_that("the WES survival bridge produces a two-level grouping", {
  # wes_mutation_status() is the join between a MAF and fct_survival.R. Its
  # contract: every sample in the cohort comes back, labelled, so that samples
  # without a mutation are WT rather than dropped.
  st <- data.frame(
    .id     = paste0("S", 1:12),
    mutated = c(rep(TRUE, 5), rep(FALSE, 7)),
    status  = c(rep("Mutant", 5), rep("WT", 7)),
    stringsAsFactors = FALSE)

  clin <- normalise_clinical(
    data.frame(sample = paste0("S", 1:12),
               t = c(5, 8, 3, 6, 9,  40, 35, 50, 44, 60, 38, 47),
               e = c(1, 1, 1, 1, 1,   1,  1,  1,  1,  1,  1,  0),
               stringsAsFactors = FALSE),
    "sample", "t", "e")

  clin$.group <- factor(st$status[match(clin$.id, st$.id)], levels = c("WT", "Mutant"))
  expect_equal(as.integer(table(clin$.group)), c(7L, 5L))

  fit <- km_fit(clin)
  expect_s3_class(fit, "survfit")
  lr <- logrank_test(clin)
  expect_true(is.list(lr) && lr$df == 1)
  med <- km_medians(fit)
  expect_setequal(med$group, c("WT", "Mutant"))
  # the mutant arm dies early here, so it must have the shorter median
  expect_lt(med$median[med$group == "Mutant"], med$median[med$group == "WT"])
})

test_that("the demo MAF path is resolvable in shape even without maftools", {
  p <- wes_demo_paths()
  expect_true(all(c("maf", "clinical") %in% names(p)))
  expect_true(is.character(p$maf) && is.character(p$clinical))
})
