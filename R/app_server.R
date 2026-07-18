#' Top-level server: omics routing, per-omics stepper, shared state
#'
#' `rv$omics` selects the active pipeline (NULL = landing page). The left
#' navigator and the main workspace are rendered from that omics' step registry
#' (see steps.R). A single `rv` hub carries the working object, per-step status,
#' the clinical/survival table (shared across omics), and the reproducibility log.
#'
#' @param input,output,session Standard Shiny server arguments.
#' @keywords internal
app_server <- function(input, output, session) {

  rv <- shiny::reactiveValues(
    omics = NULL, obj = NULL, source = NULL, status = list(),
    clinical = NULL   # shared OS/clinical table for prognosis across omics
  )
  log_rv <- shiny::reactiveVal(list())

  # --- Omics routing ---------------------------------------------------------
  shiny::observeEvent(input$omics, { rv$omics <- input$omics })
  shiny::observeEvent(input$switch_omics, { rv$omics <- NULL })

  # Main body: landing page, or the selected omics' hidden tabset.
  output$main_body <- shiny::renderUI({
    if (is.null(rv$omics)) return(app_landing())
    steps <- steps_for(rv$omics)
    panels <- lapply(steps, function(s) {
      bslib::nav_panel(title = s$en, value = s$v, do.call(s$ui, list(s$v)))
    })
    do.call(bslib::navset_hidden, c(list(id = "steps"), panels))
  })

  # Left navigator: grouped, status-coloured; empty on the landing page.
  output$step_nav <- shiny::renderUI({
    if (is.null(rv$omics)) {
      return(shiny::div(class = "omicstudio-status-empty",
                        i18n("Pick an analysis to begin.", "选择一个分析开始。")))
    }
    current <- input$steps %||% steps_for(rv$omics)[[1]]$v
    status  <- rv$status
    phases  <- app_phases()
    steps   <- steps_for(rv$omics)
    children <- list()
    for (ph in phase_order_for(rv$omics)) {
      lab <- phases[[ph]]
      children[[length(children) + 1]] <-
        shiny::div(class = "omicstudio-phase", i18n(lab$en, lab$zh))
      for (s in Filter(function(x) identical(x$phase, ph), steps)) {
        state <- if (identical(s$v, current)) "current"
                 else if (isTRUE(status[[s$v]])) "done" else "todo"
        children[[length(children) + 1]] <- shiny::tags$a(
          class = paste("omicstudio-navitem", state),
          onclick = sprintf("Shiny.setInputValue('goto','%s',{priority:'event'})", s$v),
          shiny::span(class = "omicstudio-navdot"),
          shiny::span(class = "omicstudio-navnum", s$n),
          shiny::span(class = "omicstudio-navlabel", i18n(s$en, s$zh))
        )
      }
    }
    shiny::div(class = "omicstudio-nav", children)
  })

  shiny::observeEvent(input$goto, { bslib::nav_select("steps", input$goto) })

  # --- Global dataset status (bottom of sidebar) -----------------------------
  output$global_status <- shiny::renderUI({
    obj <- rv$obj
    if (is.null(obj)) {
      return(shiny::div(class = "omicstudio-status-empty",
                        i18n("No data loaded.", "尚未加载数据")))
    }
    dims <- obj_dims(obj)
    advice <- memory_advice(dims$cells)
    shiny::tagList(
      stat_line(i18n("Cells", "细胞"), format(dims$cells, big.mark = ",")),
      stat_line(i18n("Genes", "基因"), format(dims$genes, big.mark = ",")),
      if (nzchar(advice))
        shiny::div(class = "omicstudio-warn", shiny::icon("triangle-exclamation"), " ", advice)
    )
  })

  # --- Single-cell module servers (fully implemented) ------------------------
  mod_import_server("import", rv, log_rv, parent = session)
  mod_qc_server("qc", rv, log_rv)
  mod_doublet_server("doublet", rv, log_rv)
  mod_normalize_server("normalize", rv, log_rv)
  mod_reduce_server("reduce", rv, log_rv)
  mod_integrate_server("integrate", rv, log_rv)
  mod_cluster_server("cluster", rv, log_rv)
  mod_embed_server("embed", rv, log_rv)
  mod_markers_server("markers", rv, log_rv)
  mod_annotate_server("annotate", rv, log_rv)
  mod_enrichment_server("enrichment", rv, log_rv)
  mod_trajectory_server("trajectory", rv, log_rv)
  mod_velocity_server("velocity", rv, log_rv)
  mod_dynamic_server("dynamic", rv, log_rv)
  mod_cellcycle_signatures_server("cellcycle", rv, log_rv)
  mod_cellcomm_server("cellcomm", rv, log_rv)
  mod_malignancy_server("malignancy", rv, log_rv)
  mod_viz_server("viz", rv, log_rv)
  mod_report_server("report", rv, log_rv)
  mod_export_server("export", rv, log_rv)

  # --- Placeholder servers for planned omics steps ---------------------------
  ph_ids <- unlist(lapply(c("wes", "bulk", "spatial", "integration"),
                          function(o) vapply(steps_for(o), function(s) s$v, character(1))))
  for (pid in ph_ids) mod_placeholder_server(pid, rv, log_rv)
}

#' NULL-coalescing helper
#' @keywords internal
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Mark a pipeline step completed (colours the navigator)
#' @param rv Shared hub. @param step Step key.
#' @keywords internal
mark_done <- function(rv, step) {
  st <- rv$status; st[[step]] <- TRUE; rv$status <- st; invisible(TRUE)
}

#' Small labelled status line for the sidebar
#' @keywords internal
stat_line <- function(label, value) {
  shiny::div(class = "omicstudio-statline",
             shiny::span(class = "omicstudio-statlabel", label),
             shiny::span(class = "omicstudio-statvalue", value))
}
