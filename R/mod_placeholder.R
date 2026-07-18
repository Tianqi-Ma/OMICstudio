#' Placeholder module for planned (not-yet-implemented) pipeline steps
#'
#' Shows a friendly "coming soon" card so the WES / Bulk / Spatial / integration
#' steppers display their planned roadmap before those modules are built.
#'
#' @param id Module id.
#' @name mod_placeholder
NULL

#' @rdname mod_placeholder
#' @keywords internal
mod_placeholder_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::card(
    class = "omicstudio-step", full_screen = TRUE,
    bslib::card_body(
      shiny::div(
        class = "omicstudio-placeholder", style = "margin:auto; max-width:520px;",
        shiny::div(style = "font-size:2rem; margin-bottom:.5rem;", "\U0001F6A7"),
        shiny::h4(i18n("Coming soon", "即将推出")),
        shiny::p(i18n(
          "This analysis step is planned and will be added in an upcoming release.",
          "该分析步骤已在规划中，将于后续版本加入。")),
        shiny::p(class = "text-muted",
                 i18n("Single-cell is fully available today — pick it from the start screen.",
                      "单细胞流程现已完整可用——可在起始页选择。"))
      )
    )
  )
}

#' @rdname mod_placeholder
#' @param rv,log_rv Shared hub / log (unused by the placeholder).
#' @keywords internal
mod_placeholder_server <- function(id, rv, log_rv) {
  shiny::moduleServer(id, function(input, output, session) {
    # no-op
  })
}
