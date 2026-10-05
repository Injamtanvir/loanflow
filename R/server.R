kpi_dictionary <- function() data.frame(
  KPI = c("Application volume", "Pending applications", "Pending age", "Total pending age", "Overall turnaround",
          "Department turnaround", "Department pending age", "Last successful refresh", "Source as-of"),
  Definition = c(
    "Unique valid application IDs matching all filters; includes applications marked Data issue.",
    "Filtered applications whose reliable latest stage is non-terminal; Data issue is excluded.",
    "(Source as-of − current stage entered time) / 86,400; median over pending applications.",
    "(Source as-of − submitted time) / 86,400 for pending applications; exported separately.",
    "Terminal stage entry − submission in elapsed days; median over Approved, Rejected and Withdrawn applications.",
    "Sum closed visit hours per application and department, then median. Exclude app-department pairs with any open visit.",
    "Median/p90 current-stage age among applications currently pending in that department.",
    "Time this session last loaded, validated and published a complete snapshot; unchanged after failure.",
    "Observation cutoff supplied by the source. Frozen for demo data; reloading does not make this newer."
  ), stringsAsFactors = FALSE)

make_server <- function(loader = load_snapshot, clock = Sys.time) {
  function(input, output, session) {
    state <- shiny::reactiveVal(new_refresh_state())
    update_filters <- function(view, reset = FALSE) {
      chosen <- function(value, choices) if (reset || is.null(value) || !value %in% choices) "__all__" else value
      branches <- c("All branches" = "__all__", sort(unique(view$branch)))
      products <- c("All products" = "__all__", sort(unique(view$product)))
      stages <- c("All stages" = "__all__", sort(unique(view$current_stage)))
      shiny::updateSelectInput(session, "branch", choices = branches, selected = chosen(input$branch, branches))
      shiny::updateSelectInput(session, "product", choices = products, selected = chosen(input$product, products))
      shiny::updateSelectInput(session, "stage", choices = stages, selected = chosen(input$stage, stages))
      if (reset || is.null(input$dates)) shiny::updateDateRangeInput(session, "dates", start = min(view$submitted_date), end = max(view$submitted_date))
    }
    do_refresh <- function() {
      result <- refresh_snapshot(shiny::isolate(state()), loader, clock())
      state(result)
      if (is.null(result$error)) update_filters(result$data$view)
    }
    shiny::isolate(do_refresh())
    shiny::observeEvent(input$refresh, do_refresh(), ignoreInit = TRUE)
    shiny::observeEvent(input$reset, {
      if (!is.null(state()$data)) update_filters(state()$data$view, reset = TRUE)
    }, ignoreInit = TRUE)
    shiny::observe({
      seconds <- suppressWarnings(as.numeric(input$auto_refresh))
      if (length(seconds) && !is.na(seconds) && seconds > 0) {
        shiny::invalidateLater(seconds * 1000, session)
        shiny::isolate(do_refresh())
      }
    })
    prepared <- shiny::reactive({ shiny::req(state()$data); state()$data })
    filtered <- shiny::reactive(filter_applications(prepared()$view, input$branch, input$product, input$dates, input$stage))
    kpis <- shiny::reactive(summary_kpis(filtered()))
    departments <- shiny::reactive(department_kpis(filtered(), prepared()$events))
    number <- function(x) if (is.na(x)) "—" else format(round(x, 1), nsmall = 1, trim = TRUE)
    output$n_applications <- shiny::renderText(format(kpis()$applications, big.mark = ","))
    output$n_pending <- shiny::renderText(format(kpis()$pending, big.mark = ","))
    output$median_pending <- shiny::renderText(paste0(number(kpis()$median_pending_days), if (!is.na(kpis()$median_pending_days)) " d"))
    output$median_turnaround <- shiny::renderText(paste0(number(kpis()$median_turnaround_days), if (!is.na(kpis()$median_turnaround_days)) " d"))
    output$refresh_status <- shiny::renderUI({
      s <- state()
      shiny::div(class = "refresh-meta",
        shiny::tags$strong("Last successful refresh"), shiny::p(local_string(s$last_success)),
        shiny::tags$strong("Source as-of"), shiny::p(if (is.null(s$data)) "No successful load" else local_string(s$data$as_of)),
        shiny::tags$small(if (is.null(s$data)) "No snapshot" else paste("Snapshot:", s$data$metadata$snapshot_id)))
    })
    output$error_banner <- shiny::renderUI({
      if (!is.null(state()$error)) shiny::div(class = "alert alert-danger", role = "alert", state()$error,
        shiny::p(paste("Last attempt:", local_string(state()$last_attempt))))
    })
    output$cohort_note <- shiny::renderUI({
      k <- kpis()
      shiny::div(class = "cohort-note", sprintf("%s completed · %s pending · %s with unreliable history. All durations are elapsed calendar time, not business hours.",
        format(k$completed, big.mark = ","), format(k$pending, big.mark = ","), k$data_issues),
        if (k$applications == 0L) shiny::p("No applications match these filters."))
    })
    output$volume <- shiny::renderPlot({ shiny::validate(shiny::need(nrow(filtered()), "No matching applications")); volume_plot(filtered(), compact = isTRUE(session$clientData$output_volume_width < 480)) }, res = 110)
    output$department <- shiny::renderPlot({ shiny::validate(shiny::need(nrow(filtered()), "No matching applications")); department_plot(departments(), compact = isTRUE(session$clientData$output_department_width < 480)) }, res = 110)
    dt <- function(frame, search = FALSE) DT::datatable(frame, rownames = FALSE, escape = TRUE,
      options = list(pageLength = 10, scrollX = TRUE, searching = search, dom = if (search) "ftip" else "tip"))
    output$department_table <- DT::renderDT({
      table <- departments()
      names(table) <- c("Department", "Completed applications", "Median turnaround (h)", "Pending", "Median pending (d)", "P90 pending (d)")
      dt(table) |> DT::formatRound(c("Median turnaround (h)", "Median pending (d)", "P90 pending (d)"), 1)
    })
    export_applications <- shiny::reactive({
      frame <- filtered()
      frame$submitted_at <- utc_string(frame$submitted_at); frame$stage_entered_at <- utc_string(frame$stage_entered_at)
      frame
    })
    output$applications_table <- DT::renderDT({ dt(export_applications(), TRUE) |> DT::formatRound(c("pending_age_days", "total_pending_age_days", "turnaround_days"), 1) }, server = TRUE)
    output$quality_summary <- DT::renderDT(dt(prepared()$issues |> dplyr::count(.data$entity, .data$check, .data$action, name = "issue_rows")))
    output$quality_details <- DT::renderDT(dt(prepared()$issues, TRUE), server = TRUE)
    output$reconciliation <- DT::renderDT(dt(prepared()$reconciliation))
    output$fanout_table <- DT::renderDT(dt(fanout_fixture()$reconciliation) |> DT::formatRound("value", 0))
    output$dictionary <- DT::renderDT(dt(kpi_dictionary()))
    output$download_apps <- shiny::downloadHandler(filename = function() "loanflow-filtered-applications.csv",
      content = function(file) write.csv(csv_safe(export_applications()), file, row.names = FALSE, na = ""))
    output$download_quality <- shiny::downloadHandler(filename = function() "loanflow-quality-issues.csv",
      content = function(file) write.csv(csv_safe(prepared()$issues), file, row.names = FALSE, na = ""))
  }
}
