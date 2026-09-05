#' WES module 5: Tumour mutational burden
#'
#' Mutations per megabase of captured sequence, per sample. A biomarker in its
#' own right (high TMB predicts immunotherapy response in several tumour types)
#' and the covariate you most often need to adjust for.
#'
#' @param id Module id. @param rv shared hub. @param log_rv repro log.
#' @name mod_wes_tmb
NULL

#' @rdname mod_wes_tmb
#' @keywords internal
mod_wes_tmb_ui <- function(id) {
  ns <- shiny::NS(id)
  explainer <- explainer_card(
    title = list(en = "Tumour mutational burden", zh = "肿瘤突变负荷 TMB"),
    what = list(
      en = "The number of somatic mutations per megabase of sequence your capture
            kit actually covered, calculated for each sample.",
      zh = "每个样本中，每兆碱基（Mb）捕获区域内的体细胞突变数量。"),
    why  = list(
      en = "Raw mutation counts are not comparable between cohorts sequenced with
            different panels — dividing by the captured size is what makes them
            comparable. High TMB is an approved biomarker for checkpoint
            inhibitors in several tumour types.",
      zh = "不同 panel 测序的队列之间，原始突变数不可比——除以捕获区域大小才能比较。在多种肿瘤中，高 TMB 是免疫检查点抑制剂已获批的生物标志物。"),
    how  = list(
      en = "Set <b>capture size</b> to your kit's actual target size in Mb — the
            default 50 Mb is the usual whole-exome figure. Getting this wrong
            scales every value, so check your kit's documentation.",
      zh = "把<b>捕获区域大小</b>设为你所用试剂盒的实际目标区域（Mb）——默认 50 Mb 是全外显子常见值。设错会让所有数值等比例偏移，请查阅试剂盒文档。"),
    example = list(
      en = "Agilent SureSelect V6 covers ~60 Mb; IDT xGen Exome ~39 Mb; a
               targeted 500-gene panel might be ~1.5 Mb.",
      zh = "Agilent SureSelect V6 约覆盖 60 Mb；IDT xGen Exome 约 39 Mb；500 基因的靶向 panel 可能只有约 1.5 Mb。")
  )
  controls <- shiny::tagList(
    label_with_help("Capture size (Mb)",
                    "The target territory of your capture kit. 50 Mb is the conventional whole-exome default.",
                    label_zh = "捕获区域大小（Mb）",
                    tip_zh = "捕获试剂盒的目标区域大小。全外显子通常按 50 Mb 计算。"),
    shiny::numericInput(ns("capture"), NULL, value = 50, min = 0.1, max = 3200, step = 1),
    shiny::checkboxInput(ns("log"), i18n("Log scale", "对数坐标"), value = TRUE),
    run_button(ns("run"), "Compute TMB", "计算 TMB")
  )
  step_container(
    title     = list(en = "Tumour mutational burden", zh = "肿瘤突变负荷 TMB"),
    explainer = explainer,
    controls  = controls,
    summary   = shiny::uiOutput(ns("summary")),
    preview   = bslib::navset_card_tab(
      bslib::nav_panel(i18n("Distribution", "分布图"), preview_plot_ui(ns("plot"))),
      bslib::nav_panel(i18n("Per sample", "各样本"),   shiny::uiOutput(ns("tbl_slot")))
    )
  )
}

#' @rdname mod_wes_tmb
#' @keywords internal
mod_wes_tmb_server <- function(id, rv, log_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    ns  <- session$ns
    res <- shiny::reactiveValues(df = NULL, capture = NA_real_, log = TRUE)

    shiny::observeEvent(input$run, {
      shiny::req(rv$maf)
      if (!require_pkgs("maftools", "TMB")) return(NULL)
      cap <- suppressWarnings(as.numeric(input$capture))
      if (is.na(cap) || cap <= 0) {
        shiny::showNotification("Capture size must be a positive number of megabases.",
                                type = "error", duration = 10)
        return(NULL)
      }
      # maftools::tmb() draws as a side effect; capture the numbers here and
      # redraw in the plot output so the tab does not depend on run order.
      df <- with_progress_notify({
        grDevices::pdf(NULL); on.exit(grDevices::dev.off(), add = TRUE)
        wes_tmb(rv$maf, capture_size = cap, log_scale = isTRUE(input$log))
      }, message = "Computing TMB...")
      if (is.null(df)) return(NULL)
      res$df <- df; res$capture <- cap; res$log <- isTRUE(input$log)
      mark_done(rv, "wes_tmb")
      log_step(log_rv, "WES TMB",
               params = list(captureSize = cap, logScale = input$log),
               code = sprintf('tmb <- maftools::tmb(maf, captureSize = %s, logScale = %s)',
                              cap, input$log))
    })

    tmb_col <- function(df) {
      hit <- grep("per_MB|perMB", colnames(df), ignore.case = TRUE, value = TRUE)
      if (length(hit)) hit[1] else NULL
    }

    output$summary <- shiny::renderUI({
      if (is.null(rv$maf)) return(wes_no_maf())
      df <- res$df
      if (is.null(df)) {
        return(wes_prompt("Set the capture size and click <b>Compute TMB</b>.",
                          "设置捕获区域大小后点击<b>计算 TMB</b>。"))
      }
      cl <- tmb_col(df)
      v  <- if (!is.null(cl)) df[[cl]] else NA_real_
      bslib::layout_columns(
        col_widths = c(3, 3, 3, 3),
        stat_tile(i18n("Samples", "样本数"), format(nrow(df), big.mark = ",")),
        stat_tile(i18n("Median TMB", "中位 TMB"),
                  if (all(is.na(v))) "-" else sprintf("%.2f", stats::median(v, na.rm = TRUE))),
        stat_tile(i18n("Max TMB", "最高 TMB"),
                  if (all(is.na(v))) "-" else sprintf("%.2f", max(v, na.rm = TRUE))),
        stat_tile(i18n("Capture (Mb)", "捕获 (Mb)"), res$capture)
      )
    })

    output$plot <- render_base_plot(function() {
      shiny::req(rv$maf, res$df)
      maftools::tmb(maf = rv$maf, captureSize = res$capture, logScale = res$log)
    })

    output$tbl_slot <- shiny::renderUI({
      if (is.null(res$df)) return(wes_no_maf())
      if (has_pkg("DT")) DT::dataTableOutput(ns("tbl"))
      else shiny::verbatimTextOutput(ns("tbl_txt"))
    })
    view <- shiny::reactive({
      df <- res$df; shiny::req(df)
      cl <- tmb_col(df)
      if (!is.null(cl)) df[[cl]] <- round(df[[cl]], 3)
      df[order(-df[[cl %||% colnames(df)[ncol(df)]]]), , drop = FALSE]
    })
    if (has_pkg("DT")) {
      output$tbl <- DT::renderDataTable(
        DT::datatable(view(), rownames = FALSE, filter = "top",
                      options = list(pageLength = 15, scrollX = TRUE)))
    } else {
      output$tbl_txt <- shiny::renderPrint(utils::head(view(), 20))
    }
  })
}
