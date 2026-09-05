#' WES module 6: Lollipop plot / protein domains
#'
#' One gene at a time: where along the protein its mutations land, drawn against
#' the domain structure. Recurrent positions stack into tall lollipops.
#'
#' @param id Module id. @param rv shared hub. @param log_rv repro log.
#' @name mod_wes_lolli
NULL

#' @rdname mod_wes_lolli
#' @keywords internal
mod_wes_lolli_ui <- function(id) {
  ns <- shiny::NS(id)
  explainer <- explainer_card(
    title = list(en = "Lollipop / domains", zh = "Lollipop / 结构域"),
    what = list(
      en = "Every mutation in one gene, positioned along the protein sequence and
            drawn over its annotated domains. Stack height = how many patients
            carry that exact change.",
      zh = "某一个基因的全部突变，按其在蛋白序列上的位置绘制，并叠加已注释的结构域。棒棒糖的高度＝有多少患者携带完全相同的改变。"),
    why  = list(
      en = "Where a mutation lands tells you what it does. Oncogenes cluster at
            one or two hotspots (a gain of function); tumour suppressors scatter
            truncating mutations across the whole length (a loss of function).",
      zh = "突变落在哪里决定了它的作用。癌基因会聚集在一两个热点上（功能获得）；抑癌基因则在全长范围内散布截短突变（功能丧失）。"),
    how  = list(
      en = "Pick a gene from the dropdown — it is sorted by mutation frequency.
            The <b>protein change column</b> is auto-detected; if the plot comes
            back empty, your MAF probably names it something unusual and you can
            point at the right column here.",
      zh = "从下拉框选择基因——已按突变频率排序。<b>蛋白改变列</b>会自动识别；如果图是空的，多半是你的 MAF 用了不常见的列名，可在此手动指定。"),
    example = list(
      en = "<code>TP53</code> shows scattered mutations concentrated in the DNA
               binding domain; <code>FLT3</code> shows one dominant hotspot at
               D835 in the kinase domain.",
      zh = "<code>TP53</code> 的突变分散但集中于 DNA 结合结构域；<code>FLT3</code> 则在激酶结构域的 D835 处呈现一个显著热点。")
  )
  controls <- shiny::tagList(
    shiny::uiOutput(ns("gene_ui")),
    shiny::uiOutput(ns("aa_ui")),
    shiny::checkboxInput(ns("show_rate"),
                         i18n("Show mutation rate", "显示突变率"), value = TRUE),
    shiny::checkboxInput(ns("label_pos"),
                         i18n("Label recurrent positions", "标注复发位点"), value = TRUE),
    run_button(ns("run"), "Draw lollipop", "绘制 Lollipop")
  )
  step_container(
    title     = list(en = "Lollipop / domains", zh = "Lollipop / 结构域"),
    explainer = explainer,
    controls  = controls,
    summary   = shiny::uiOutput(ns("summary")),
    preview   = preview_plot_ui(ns("plot"))
  )
}

#' @rdname mod_wes_lolli
#' @keywords internal
mod_wes_lolli_server <- function(id, rv, log_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    ns  <- session$ns
    cfg <- shiny::reactiveVal(NULL)

    output$gene_ui <- shiny::renderUI({
      shiny::req(rv$maf)
      g <- wes_genes(rv$maf, n = 300)
      shiny::tagList(
        label_with_help("Gene", "Sorted by how many samples carry a mutation in it.",
                        label_zh = "基因", tip_zh = "按携带该基因突变的样本数排序。"),
        shiny::selectizeInput(ns("gene"), NULL, choices = g,
                              selected = if (length(g)) g[1] else NULL)
      )
    })

    output$aa_ui <- shiny::renderUI({
      shiny::req(rv$maf)
      f <- wes_fields(rv$maf)
      shiny::tagList(
        label_with_help("Protein change column",
                        "The MAF column with the amino-acid change (e.g. HGVSp_Short, AAChange). Auto-detected.",
                        label_zh = "蛋白改变列",
                        tip_zh = "MAF 中存放氨基酸改变的列（如 HGVSp_Short、AAChange），会自动识别。"),
        shiny::selectInput(ns("aa_col"), NULL,
                           choices = c(stats::setNames("", "(auto)"), f),
                           selected = wes_guess_aa_col(rv$maf) %||% "")
      )
    })

    shiny::observeEvent(input$run, {
      shiny::req(rv$maf, input$gene)
      if (!require_pkgs("maftools", "Lollipop plot")) return(NULL)
      cfg(list(gene = input$gene,
               aa = if (nzchar(input$aa_col %||% "")) input$aa_col else NULL,
               rate = isTRUE(input$show_rate),
               label = isTRUE(input$label_pos)))
      mark_done(rv, "wes_lolli")
      log_step(log_rv, "WES lollipop",
               params = list(gene = input$gene, AACol = input$aa_col),
               code = sprintf('maftools::lollipopPlot(maf, gene = "%s"%s)',
                              input$gene,
                              if (nzchar(input$aa_col %||% ""))
                                sprintf(', AACol = "%s"', input$aa_col) else ""))
    })

    output$summary <- shiny::renderUI({
      if (is.null(rv$maf)) return(wes_no_maf())
      c0 <- cfg()
      if (is.null(c0)) {
        return(wes_prompt("Pick a gene and click <b>Draw lollipop</b>.",
                          "选择基因后点击<b>绘制 Lollipop</b>。"))
      }
      gs <- tryCatch(as.data.frame(maftools::getGeneSummary(rv$maf)),
                     error = function(e) NULL)
      row <- if (!is.null(gs)) gs[gs$Hugo_Symbol == c0$gene, , drop = FALSE] else NULL
      n_samples <- tryCatch(nrow(maftools::getSampleSummary(rv$maf)),
                            error = function(e) NA_integer_)
      mut <- if (!is.null(row) && nrow(row)) row$MutatedSamples[1] else NA_integer_
      bslib::layout_columns(
        col_widths = c(4, 4, 4),
        stat_tile(i18n("Gene", "基因"), c0$gene),
        stat_tile(i18n("Mutated samples", "突变样本数"),
                  if (is.na(mut)) "-" else format(mut, big.mark = ",")),
        stat_tile(i18n("Cohort frequency", "队列频率"),
                  if (is.na(mut) || is.na(n_samples) || !n_samples) "-"
                  else sprintf("%.1f%%", 100 * mut / n_samples))
      )
    })

    output$plot <- render_base_plot(function() {
      c0 <- cfg(); shiny::req(rv$maf, c0)
      args <- list(maf = rv$maf, gene = c0$gene, showMutationRate = c0$rate)
      if (!is.null(c0$aa)) args$AACol <- c0$aa
      if (c0$label) args$labelPos <- "all"
      do.call(maftools::lollipopPlot, args)
    })
  })
}
