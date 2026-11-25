# 05_explore_ers_meat.R
# Goal: LOOK at the ERS "Red meat, poultry, and fish" file before using it.
# We need to find: the year column, the meat types, the weight basis
# (we want boneless/trimmed weight), and the units (lbs per person per year).

library(tidyverse)
library(janitor)

# Edit to match your downloaded file name in data/raw/
ers_path <- "data/raw/mtpcc.csv"

ers <- read_csv(ers_path, show_col_types = FALSE) |> clean_names()

# ---- 1. Structure ----
dim(ers)
names(ers)
glimpse(ers)

# ---- 2. What's in each text column? ----
# Prints the distinct values of every character column (up to 60 each),
# so we can find the labels for meat type, weight basis, and units.
ers |>
  select(where(is.character)) |>
  map(~ head(unique(.x), 60))

# ---- 3. Years covered ----
# Shows the range of any numeric column with "year" in its name
ers |> select(contains("year")) |> map(range, na.rm = TRUE)

# Paste sections 1-3 back to Claude.