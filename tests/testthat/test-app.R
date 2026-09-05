# Smoke tests for the app shell: the UI must build and the full server graph
# (all 12 modules) must initialise without data and without the heavy Suggests
# packages installed. These guard against wiring regressions.

test_that("app_ui builds and renders to HTML", {
  ui <- app_ui()
  rt <- htmltools::renderTags(ui)
  html <- paste(as.character(rt$html), as.character(rt$head))
  expect_true(nchar(html) > 2000)
  # chrome: stylesheet + script served from the registered resource path,
  # the splash overlay, the language switch, and the bilingual data attributes
  expect_match(html, "omicone/custom.css", fixed = TRUE)
  expect_match(html, "omicone/app.js", fixed = TRUE)
  expect_match(html, "omicone-splash", fixed = TRUE)
  expect_match(html, "OmicOneSetLang", fixed = TRUE)
  expect_match(html, "data-zh=", fixed = TRUE)
})

test_that("every omics step registry is consistent with app_phases", {
  phases <- app_phases()
  all_vals <- character(0)
  for (omics in c("sc", "wes", "bulk", "spatial", "integration")) {
    steps <- steps_for(omics)
    expect_true(length(steps) >= 1, info = omics)
    for (s in steps) {
      expect_true(!is.null(phases[[s$phase]]), info = paste(omics, s$v))
      expect_true(is.function(s$ui), info = paste(omics, s$v))
    }
    all_vals <- c(all_vals, vapply(steps, function(s) s$v, character(1)))
  }
  # step ids are globally unique (needed for module namespacing)
  expect_equal(anyDuplicated(all_vals), 0L)
})

test_that("omics catalogue matches the step registries", {
  cat_v <- vapply(omics_catalogue(), function(o) o$v, character(1))
  expect_setequal(cat_v, c("sc", "wes", "bulk", "spatial", "integration"))
})

test_that("landing page renders", {
  html <- as.character(app_landing())
  expect_match(html, "omicone-omcard", fixed = TRUE)
  expect_match(html, "data-anim", fixed = TRUE)
})

test_that("full server graph initialises with no data loaded", {
  # Should not error even though Seurat/plotly/etc. may be absent, because
  # compute is gated behind Run buttons and outputs handle the NULL object.
  expect_no_error(
    shiny::testServer(app_server, {
      session$flushReact()
    })
  )
})

test_that("import module server initialises", {
  rv <- shiny::reactiveValues(obj = NULL, source = NULL)
  log_rv <- shiny::reactiveVal(list())
  expect_no_error(
    shiny::testServer(mod_import_server, args = list(rv = rv, log_rv = log_rv), {
      session$flushReact()
    })
  )
})
