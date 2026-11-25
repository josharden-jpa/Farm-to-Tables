# R/helpers.R
# Shared look and output helpers. Every final script starts with:
#   source("R/helpers.R")
# so all figures share one style and every result lands in output/.

library(tidyverse)

# ---- Folders ----
for (d in c("output/figures", "output/tables", "data/processed")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# ---- Consistent colors (same meaning in every figure) ----
col_animal <- "#b26a00"   # animal products / feed
col_plant  <- "#2e7d32"   # plant foods / food use
col_fuel   <- "#5c6bc0"   # fuel ethanol
col_export <- "#7a7a7a"   # exports
col_us     <- "firebrick" # the United States, whenever highlighted
col_other  <- "grey65"    # everything else / other countries

# ---- One theme for every figure ----
theme_dwv <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title         = element_text(face = "bold"),
      plot.title.position = "plot",
      plot.caption       = element_text(color = "grey40", hjust = 0),
      plot.caption.position = "plot",
      legend.position    = "top",
      legend.justification = "left",
      panel.grid.minor   = element_blank()
    )
}

# ---- Save a figure: output/figures/<name>.png ----
save_fig <- function(plot, name, width = 8, height = 5) {
  path <- file.path("output/figures", paste0(name, ".png"))
  ggsave(path, plot, width = width, height = height, dpi = 300, bg = "white")
  message("Saved figure: ", path)
  invisible(path)
}

# ---- Save a table: output/tables/<name>.csv ----
save_table <- function(df, name) {
  path <- file.path("output/tables", paste0(name, ".csv"))
  write_csv(df, path)
  message("Saved table: ", path)
  invisible(df)
}

# ---- Record a headline number: appends to output/key_numbers.csv ----
# Every number quoted in the report or slides should be recorded here,
# so it can be traced back to the script that produced it.
record_number <- function(name, value, unit = "", source_script = "", note = "") {
  path <- "output/key_numbers.csv"
  row <- tibble(name = name, value = round(value, 2), unit = unit,
                source_script = source_script, note = note)
  write_csv(row, path, append = file.exists(path))
  invisible(value)
}
