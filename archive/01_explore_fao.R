# 01_explore_fao.R
# Goal: LOOK at the FAOSTAT Food Balance files before cleaning anything.
# We don't assume column names; we inspect them and decide together.
# Put the unzipped CSVs in data/raw/ and edit the file names below.

library(tidyverse)
library(janitor)

# Edit these to match your downloaded files
fbs_new_path <- "data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv"
fbs_old_path <- "data/raw/FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv"

# FAOSTAT bulk files are often Latin-1 encoded; this avoids garbled country names
fbs_new <- read_csv(fbs_new_path, locale = locale(encoding = "latin1")) |>
  clean_names()   # turns "Area Code" into area_code, etc.

# ---- 1. Structure ----
dim(fbs_new)       # rows and columns
names(fbs_new)     # column names
glimpse(fbs_new)

# ---- 2. What's inside? ----
fbs_new |> distinct(element, unit) |> print(n = Inf)  # measures available
fbs_new |> distinct(item) |> print(n = Inf)            # food items
range(fbs_new$year)                                    # years covered
n_distinct(fbs_new$area)                               # countries/regions

# ---- 3. A first look at the U.S. ----
fbs_new |>
  filter(area == "United States of America") |>
  count(element) |>
  print(n = Inf)

# Repeat steps 1-2 for the historic file:
fbs_old <- read_csv(fbs_old_path, locale = locale(encoding = "latin1")) |> clean_names()

# Paste the outputs of sections 1-3 back to Claude (not the whole dataset).