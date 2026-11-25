# 07_explore_worldbank.R
# Goal: LOOK at the World Bank files before using them.
# Main file: CLASS (current income group for each country)
# Also: GDP per capita PPP (for a possible scatter later)

library(tidyverse)
library(readxl)
library(janitor)

# ---- 1. Income classification (CLASS) ----
class_path <- "data/raw/CLASS_2026_10_08.xlsx"
excel_sheets(class_path)            # which sheets are in the workbook?

class <- read_excel(class_path, sheet = 1) |> clean_names()
dim(class)
names(class)
head(class, 10)
class |> count(income_group)        # if this errors, the column has another name; paste names()

# ---- 2. GDP per capita, PPP ----
# World Bank CSVs have 4 lines of notes above the real header, so skip them
gdp <- read_csv("data/raw/API_NY.GDP.PCAP.PP.CD_DS2_en_csv_v2_78481.csv",
                skip = 4, show_col_types = FALSE) |> clean_names()
dim(gdp)
names(gdp)[1:6]                     # first few columns (country name, code, ...)
names(gdp)[(ncol(gdp) - 4):ncol(gdp)]  # last few columns (most recent years)

# ---- 3. Country metadata (often includes income group and region too) ----
meta <- read_csv("data/raw/Metadata_Country_API_NY.GDP.PCAP.PP.CD_DS2_en_csv_v2_78481.csv",
                 show_col_types = FALSE) |> clean_names()
names(meta)
head(meta, 5)

# Paste the output of all three sections back to Claude.