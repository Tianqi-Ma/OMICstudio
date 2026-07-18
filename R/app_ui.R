#' Top-level UI: omics landing page + per-omics plot-first pipeline
#'
#' On launch a splash animation plays, then a landing page lets the user pick an
#' omics type. Choosing one routes into that pipeline (a grouped left stepper +
#' the step's plot-first workspace). The single-cell pipeline is fully
#' implemented; other omics show their planned roadmap via placeholders.
#'
#' @return A [bslib::page_sidebar()] UI wrapped with the splash overlay.
#' @keywords internal
app_ui <- function() {
  theme <- bslib::bs_theme(
    version = 5, preset = "shiny",
    primary = "#2f81c7",
    base_font = bslib::font_google("Inter", local = FALSE),
    heading_font = bslib::font_google("Inter", local = FALSE)
  )

  page <- bslib::page_sidebar(
    theme = theme,
    title = shiny::div(
      class = "omicstudio-topbar",
      shiny::span(class = "omicstudio-brand",
                  shiny::strong("OMICstudio"),
                  shiny::span(class = "omicstudio-sub", "multi-omics, locally")),
      shiny::div(
        class = "omicstudio-topright",
        shiny::actionLink("switch_omics", i18n("← Omics", "← 切换组学"),
                          class = "omicstudio-switch"),
        bslib::popover(
          shiny::actionLink("export_menu", i18n("⤓ Export", "⤓ 导出"),
                            class = "omicstudio-switch"),
          title = i18n("Export current data", "导出当前数据"),
          shiny::downloadButton("dl_rds",   i18n("Object (.rds)", "对象 (.rds)"), class = "btn-sm w-100 mb-1"),
          shiny::downloadButton("dl_meta",  i18n("Cell metadata (.csv)", "细胞元数据 (.csv)"), class = "btn-sm w-100 mb-1"),
          shiny::downloadButton("dl_matrix",i18n("Counts matrix (.rds)", "表达矩阵 (.rds)"), class = "btn-sm w-100 mb-1"),
          shiny::downloadButton("dl_embed", i18n("Embeddings (.csv)", "降维坐标 (.csv)"), class = "btn-sm w-100")
        ),
        shiny::div(class = "omicstudio-pydot", id = "py-status",
                   i18n("Python: not set up", "Python：未配置")),
        shiny::tags$div(
          class = "omicstudio-lang",
          shiny::tags$button(class = "omicstudio-lang-btn active", `data-lang` = "en",
                             onclick = "OMICstudioSetLang('en')", "EN"),
          shiny::tags$button(class = "omicstudio-lang-btn", `data-lang` = "zh",
                             onclick = "OMICstudioSetLang('zh')", "中")
        ),
        bslib::input_dark_mode(id = "dark", mode = "dark")
      )
    ),
    sidebar = bslib::sidebar(
      title = i18n("Workflow", "分析流程"),
      width = 232, open = "open", id = "stepbar",
      shiny::uiOutput("step_nav"),
      shiny::hr(),
      shiny::div(class = "omicstudio-mini", shiny::uiOutput("global_status"))
    ),
    shiny::tags$head(
      shiny::tags$link(rel = "stylesheet", type = "text/css", href = "omicstudio/custom.css"),
      shiny::tags$script(src = "omicstudio/app.js")
    ),
    shiny::uiOutput("main_body")
  )

  shiny::tagList(
    shiny::div(
      id = "omicstudio-splash",
      shiny::tags$canvas(id = "omicstudio-splash-canvas"),
      shiny::div(id = "omicstudio-splash-logo",
                 shiny::div(class = "t", "OMICstudio"),
                 shiny::div(class = "s", "multi-omics analysis, on your own machine"))
    ),
    page
  )
}
