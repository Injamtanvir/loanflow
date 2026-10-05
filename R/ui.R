kpi_card <- function(label, output, note) {
  shiny::div(class = "kpi-card", shiny::div(class = "kpi-label", label),
             shiny::div(class = "kpi-value", shiny::textOutput(output, inline = TRUE)),
             shiny::div(class = "kpi-note", note))
}
loanflow_ui <- function() {
  shiny::fluidPage(
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", type = "text/css", href = "style.css")),
    shiny::div(class = "masthead", shiny::div(shiny::span(class = "brand-mark", "LF"),
      shiny::span(class = "brand-name", "LoanFlow"), shiny::span(class = "brand-caption", "SME APPLICATION OPERATIONS")),
      shiny::span(class = "demo-badge", "INDEPENDENT PROJECT · SYNTHETIC DATA")),
    shiny::div(class = "page-intro", shiny::h1("Every application. A clear next step."),
      shiny::p("Track intake, department queues and processing time from one reconciled application view.")),
    shiny::sidebarLayout(
      shiny::sidebarPanel(width = 3,
        shiny::h4("Explore applications"),
        shiny::selectInput("branch", "Branch", choices = c("All branches" = "__all__")),
        shiny::selectInput("product", "Product", choices = c("All products" = "__all__")),
        shiny::dateRangeInput("dates", "Application date · Dhaka", start = "2026-07-01", end = "2026-10-01", format = "dd M yyyy"),
        shiny::selectInput("stage", "Current processing stage", choices = c("All stages" = "__all__")),
        shiny::actionButton("reset", "Reset filters", class = "btn-block"),
        shiny::tags$hr(), shiny::h4("Data refresh"),
        shiny::actionButton("refresh", "Refresh snapshot", icon = shiny::icon("rotate"), class = "btn-primary btn-block"),
        shiny::selectInput("auto_refresh", "Automatic refresh", choices = c("Off" = 0, "Every minute" = 60, "Every 5 minutes" = 300)),
        shiny::uiOutput("refresh_status"),
        shiny::tags$hr(), shiny::p(class = "sidebar-note", "Date filters select an application cohort. Department metrics use the histories of those same applications. Times shown in Asia/Dhaka.")),
      shiny::mainPanel(width = 9,
        shiny::uiOutput("error_banner"),
        shiny::div(class = "kpi-grid",
          kpi_card("Application volume", "n_applications", "Unique valid application IDs"),
          kpi_card("Pending applications", "n_pending", "Reliable, non-terminal status"),
          kpi_card("Median pending age", "median_pending", "Days in current department"),
          kpi_card("Median turnaround", "median_turnaround", "Days from submission to closure")),
        shiny::uiOutput("cohort_note"),
        shiny::tabsetPanel(id = "main_tab",
          shiny::tabPanel("Overview",
            shiny::div(class = "chart-card", shiny::plotOutput("volume", height = "270px")),
            shiny::div(class = "chart-card", shiny::plotOutput("department", height = "250px")),
            shiny::div(class = "table-card", shiny::h3("Department queues & turnaround"), DT::DTOutput("department_table"))),
          shiny::tabPanel("Applications",
            shiny::div(class = "table-card", shiny::h3("Application register"),
              shiny::p("One row per application. Export includes the current filters, not the table's optional text search."),
              shiny::downloadButton("download_apps", "Export filtered CSV"), DT::DTOutput("applications_table"))),
          shiny::tabPanel("Data quality",
            shiny::div(class = "table-card", shiny::h3("Snapshot quality checks"),
              shiny::p("These checks describe the whole source snapshot, independent of the application filters. One source row may trigger several checks."),
              DT::DTOutput("quality_summary"), shiny::h3("Reconciliation"), DT::DTOutput("reconciliation"),
              shiny::downloadButton("download_quality", "Export issue log"), DT::DTOutput("quality_details"))),
          shiny::tabPanel("Join-fanout lab",
            shiny::div(class = "table-card", shiny::h3("Reproduce an 18% counting error"),
              shiny::p("A separate, intentionally constructed regression fixture has 1,000 applications and 1,180 status rows. It is not a historical production incident or a claim about the main demo's history size."),
              DT::DTOutput("fanout_table"),
              shiny::tags$pre("# Wrong grain: application × historical event\nleft_join(applications, history, by = 'application_id') |> nrow()\n\n# Correct grain: one latest valid status per application\nlatest <- history |> arrange(application_id, desc(status_at), desc(event_id)) |>\n  distinct(application_id, .keep_all = TRUE)\nleft_join(applications, latest, by = 'application_id', relationship = 'one-to-one')"),
              shiny::p("The main dashboard validates the full timeline before reducing history. COUNT(DISTINCT application_id) reconciles totals, but does not alone fix duplicated amounts or biased department durations."))),
          shiny::tabPanel("KPI dictionary",
            shiny::div(class = "table-card", shiny::h3("How the numbers are defined"),
              DT::DTOutput("dictionary"), shiny::p("Full field definitions and exclusion rules are in docs/DATA_DICTIONARY.md. This tool measures synthetic application operations; it does not score creditworthiness or make lending decisions.")))
        )
      )
    ),
    shiny::div(class = "footer", "LoanFlow 1.0 · R Shiny / dplyr / ggplot2 / PostgreSQL · Synthetic operations research")
  )
}
