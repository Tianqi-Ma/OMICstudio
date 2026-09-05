#' Landing page: choose an omics type
#'
#' Renders one card per omics type. Each card carries a small themed canvas whose
#' animation plays on hover (see app.js). Clicking a card sets the `omics` input,
#' which the server uses to route into that pipeline.
#'
#' @return A UI fragment (grid of omics cards).
#' @keywords internal
app_landing <- function() {
  cards <- lapply(omics_catalogue(), function(o) {
    shiny::tags$div(
      class = "omicone-omcard",
      `data-omics` = o$v,
      `data-anim` = o$anim,
      onclick = sprintf("Shiny.setInputValue('omics','%s',{priority:'event'})", o$v),
      tabindex = "0",
      shiny::tags$canvas(class = "omicone-omcanvas"),
      shiny::div(
        class = "omicone-omcard-body",
        shiny::div(class = "omicone-omicon", shiny::icon(o$icon)),
        shiny::div(class = "omicone-omtitle", i18n(o$en, o$zh)),
        shiny::div(class = "omicone-omdesc", i18n(o$desc_en, o$desc_zh)),
        # say up front which pipelines actually run, rather than letting the
        # user discover it by clicking into a wall of placeholders
        if (isTRUE(o$ready))
          shiny::div(class = "omicone-ombadge ready", i18n("Available", "已可用"))
        else
          shiny::div(class = "omicone-ombadge", i18n("Planned", "规划中"))
      )
    )
  })
  shiny::div(
    class = "omicone-landing",
    shiny::div(class = "omicone-landing-head",
               shiny::h3(i18n("Choose an analysis", "选择分析类型")),
               shiny::p(class = "text-muted",
                        i18n("Pick the omics data type to start. Hover a card to preview.",
                             "选择要分析的组学数据类型开始。悬停卡片可预览动画。"))),
    shiny::div(class = "omicone-omgrid", cards)
  )
}
