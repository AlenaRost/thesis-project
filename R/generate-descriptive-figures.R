# Generate the descriptive figures and supporting tables shown in the README.
#
# By default, the script reads the final `three_var_df` object from the adjacent
# thesis project's DATA/.RData file. Set TFM_RDATA_PATH to use another copy.

required_packages <- c("dplyr", "ggplot2", "tidyr")
missing_packages <- setdiff(required_packages, rownames(installed.packages()))

if (length(missing_packages) > 0L) {
  stop(
    "Install the missing packages first: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

command_args <- commandArgs(trailingOnly = FALSE)
script_argument <- grep("^--file=", command_args, value = TRUE)
script_path <- sub("^--file=", "", script_argument)
script_directory <- if (length(script_path) == 1L) {
  dirname(normalizePath(script_path))
} else {
  getwd()
}

project_directory <- normalizePath(file.path(script_directory, ".."))
default_source <- file.path(project_directory, "..", "DATA", ".RData")
source_path <- Sys.getenv("TFM_RDATA_PATH", unset = default_source)

if (!file.exists(source_path)) {
  stop(
    "Cannot find the thesis R workspace. Set TFM_RDATA_PATH to its location.",
    call. = FALSE
  )
}

workspace <- new.env(parent = emptyenv())
load(source_path, envir = workspace)

if (!exists("three_var_df", envir = workspace, inherits = FALSE)) {
  stop("The workspace does not contain `three_var_df`.", call. = FALSE)
}

analysis_data <- workspace$three_var_df
required_columns <- c(
  "region_code", "year", "EQI_interp", "GHG_per_GDP", "GDP_per_capita",
  "ind_share", "capital", "km2", "COASTAL", "mountain", "population"
)
missing_columns <- setdiff(required_columns, names(analysis_data))

if (length(missing_columns) > 0L) {
  stop(
    "The analysis panel is missing: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}

figures_directory <- file.path(project_directory, "figures")
tables_directory <- file.path(project_directory, "tables")
dir.create(figures_directory, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_directory, recursive = TRUE, showWarnings = FALSE)

theme_project <- function() {
  ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank()
    )
}

annual_means <- analysis_data |>
  dplyr::group_by(year) |>
  dplyr::summarise(
    mean_EQI = mean(EQI_interp, na.rm = TRUE),
    mean_GHG_intensity = mean(GHG_per_GDP, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(year)

utils::write.csv(
  annual_means,
  file.path(tables_directory, "annual-means.csv"),
  row.names = FALSE
)

ghg_trend <- ggplot2::ggplot(
  annual_means,
  ggplot2::aes(x = year, y = mean_GHG_intensity)
) +
  ggplot2::geom_line(color = "#2C6E9F", linewidth = 1.2) +
  ggplot2::geom_point(color = "#2C6E9F", size = 2.2) +
  ggplot2::scale_x_continuous(breaks = seq(2010, 2023, by = 2)) +
  ggplot2::labs(
    title = "EU Average GHG Emissions Intensity",
    subtitle = "NUTS-2 regional mean, 2010-2023",
    x = "Year",
    y = "Mean GHG emissions intensity"
  ) +
  theme_project()

eqi_trend <- ggplot2::ggplot(
  annual_means,
  ggplot2::aes(x = year, y = mean_EQI)
) +
  ggplot2::geom_line(color = "#D58A28", linewidth = 1.2) +
  ggplot2::geom_point(color = "#D58A28", size = 2.2) +
  ggplot2::scale_x_continuous(breaks = seq(2010, 2023, by = 2)) +
  ggplot2::labs(
    title = "EU Average Quality of Government Index",
    subtitle = "NUTS-2 regional mean, 2010-2023",
    x = "Year",
    y = "Mean EQI"
  ) +
  theme_project()

scatter_plot <- ggplot2::ggplot(
  analysis_data,
  ggplot2::aes(x = EQI_interp, y = GHG_per_GDP)
) +
  ggplot2::geom_point(color = "#315B7D", alpha = 0.32, size = 1.5) +
  ggplot2::geom_smooth(
    method = "lm",
    formula = y ~ x,
    color = "#A33A2B",
    se = FALSE,
    linewidth = 1.1
  ) +
  ggplot2::labs(
    title = "GHG Emissions Intensity and Quality of Government",
    subtitle = "NUTS-2 region-year observations, 2010-2023",
    x = "Quality of Government Index (EQI)",
    y = "GHG emissions intensity"
  ) +
  theme_project()

correlation_variables <- c(
  GHG_per_GDP = "GHG intensity",
  EQI_interp = "EQI",
  GDP_per_capita = "GDP per capita",
  ind_share = "Industry share",
  capital = "Capital city",
  km2 = "Area",
  COASTAL = "Coastal",
  mountain = "Mountain",
  population = "Population"
)

correlation_data <- analysis_data |>
  dplyr::select(dplyr::all_of(names(correlation_variables)))

correlation_matrix <- stats::cor(correlation_data, use = "complete.obs")
dimnames(correlation_matrix) <- list(
  unname(correlation_variables),
  unname(correlation_variables)
)

correlation_p_values <- matrix(
  NA_real_,
  nrow = ncol(correlation_data),
  ncol = ncol(correlation_data),
  dimnames = dimnames(correlation_matrix)
)

for (row_index in seq_len(ncol(correlation_data))) {
  for (column_index in seq_len(ncol(correlation_data))) {
    complete_rows <- stats::complete.cases(
      correlation_data[[row_index]],
      correlation_data[[column_index]]
    )
    correlation_p_values[row_index, column_index] <- stats::cor.test(
      correlation_data[[row_index]][complete_rows],
      correlation_data[[column_index]][complete_rows]
    )$p.value
  }
}

correlation_long <- as.data.frame(as.table(correlation_matrix)) |>
  dplyr::rename(row = Var1, column = Var2, correlation = Freq) |>
  dplyr::mutate(
    row_number = match(row, unname(correlation_variables)),
    column_number = match(column, unname(correlation_variables)),
    p_value = correlation_p_values[cbind(row_number, column_number)],
    stars = dplyr::case_when(
      row_number == column_number ~ "",
      p_value < 0.01 ~ "***",
      p_value < 0.05 ~ "**",
      p_value < 0.10 ~ "*",
      TRUE ~ ""
    ),
    label = paste0(sprintf("%.2f", correlation), stars),
    visible = row_number >= column_number,
    row = factor(row, levels = rev(unname(correlation_variables))),
    column = factor(column, levels = unname(correlation_variables))
  ) |>
  dplyr::filter(visible)

utils::write.csv(
  round(correlation_matrix, 4),
  file.path(tables_directory, "correlation-matrix.csv"),
  row.names = TRUE
)

correlation_plot <- ggplot2::ggplot(
  correlation_long,
  ggplot2::aes(x = column, y = row, fill = correlation)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.7) +
  ggplot2::geom_text(
    ggplot2::aes(label = label),
    size = 3.5,
    color = "#222222"
  ) +
  ggplot2::scale_fill_gradient2(
    low = "#B24A3A",
    mid = "white",
    high = "#346B9A",
    midpoint = 0,
    limits = c(-1, 1),
    name = "Correlation"
  ) +
  ggplot2::coord_equal() +
  ggplot2::labs(
    title = "Pairwise Correlation Matrix",
    subtitle = "Pearson correlations; * p < 0.10, ** p < 0.05, *** p < 0.01",
    x = NULL,
    y = NULL
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title.position = "plot",
    plot.title = ggplot2::element_text(face = "bold"),
    panel.grid = ggplot2::element_blank(),
    axis.text.x = ggplot2::element_text(angle = 40, hjust = 1),
    legend.position = "right"
  )

ggplot2::ggsave(
  file.path(figures_directory, "mean-ghg-intensity-2010-2023.png"),
  ghg_trend,
  width = 9,
  height = 5.5,
  dpi = 180,
  bg = "white"
)
ggplot2::ggsave(
  file.path(figures_directory, "mean-eqi-2010-2023.png"),
  eqi_trend,
  width = 9,
  height = 5.5,
  dpi = 180,
  bg = "white"
)
ggplot2::ggsave(
  file.path(figures_directory, "eqi-ghg-scatter.png"),
  scatter_plot,
  width = 9,
  height = 6,
  dpi = 180,
  bg = "white"
)
ggplot2::ggsave(
  file.path(figures_directory, "correlation-matrix.png"),
  correlation_plot,
  width = 11,
  height = 9,
  dpi = 180,
  bg = "white"
)

message("Generated descriptive figures and tables in: ", project_directory)
