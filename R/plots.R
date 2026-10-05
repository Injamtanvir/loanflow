loanflow_theme <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   panel.grid.major.x = ggplot2::element_blank(),
                   plot.title = ggplot2::element_text(face = "bold", color = "#193a3c"),
                   axis.title = ggplot2::element_text(color = "#597072"),
                   plot.background = ggplot2::element_rect(fill = "white", color = NA))
}
volume_plot <- function(apps, compact = FALSE) {
  daily <- apps |> dplyr::count(.data$submitted_date, name = "applications")
  if (nrow(daily)) {
    dates <- data.frame(submitted_date = seq(min(daily$submitted_date), max(daily$submitted_date), by = "day"))
    daily <- dplyr::left_join(dates, daily, by = "submitted_date", relationship = "one-to-one")
    daily$applications[is.na(daily$applications)] <- 0L
  }
  ggplot2::ggplot(daily, ggplot2::aes(.data$submitted_date, .data$applications)) +
    ggplot2::geom_col(fill = "#187e7a", width = .8) +
    ggplot2::labs(title = "Application intake", x = NULL, y = "Unique applications") +
    ggplot2::scale_x_date(date_labels = if (compact) "%b" else "%d %b", date_breaks = if (compact) "1 month" else "2 weeks") + loanflow_theme()
}
department_plot <- function(departments, compact = FALSE) {
  chart_title <- if (compact) "Median department\nturnaround" else "Median department turnaround"
  departments$department <- factor(departments$department, levels = rev(DEPARTMENTS))
  departments <- departments[!is.na(departments$median_turnaround_hours), ]
  if (!nrow(departments)) {
    return(ggplot2::ggplot() +
      ggplot2::annotate("text", x = 0, y = 0, label = "No completed department visits in this cohort", color = "#627778", size = 4) +
      ggplot2::labs(title = chart_title) + ggplot2::theme_void() +
      ggplot2::theme(plot.title = ggplot2::element_text(face = "bold", color = "#193a3c")))
  }
  ggplot2::ggplot(departments, ggplot2::aes(.data$department, .data$median_turnaround_hours)) +
    ggplot2::geom_col(fill = "#224d60", width = .55, na.rm = TRUE) + ggplot2::scale_x_discrete(drop = FALSE) + ggplot2::coord_flip() +
    ggplot2::labs(title = chart_title, x = NULL, y = if (compact) "Elapsed hours" else "Elapsed hours · completed app-department visits") + loanflow_theme()
}
