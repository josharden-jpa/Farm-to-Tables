# scripts/01_build_fao.R
# STEP 1 of the pipeline: read both FAOSTAT Food Balance series once,
# keep only what later scripts need, check the method change, save small files.
#
# Inputs : data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv          (2010-2024, new method)
#          data/raw/FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv  (1961-2013, old method)
# Outputs: data/processed/fbs_slim.rds       per-person kcal + protein by food group, both series
#          data/processed/fbs_snapshot.rds   new series, 2021-2023, rows for the country comparison
#          output/tables/fao_overlap_us.csv  U.S. values under both methods, 2010-2013
#          output/tables/fao_overlap_countries.csv  method gap by country
#          output/key_numbers.csv            overlap check results

source("R/helpers.R")
library(janitor)
this_script <- "01_build_fao.R"

# ---- Decisions (see RESEARCH_LOG.md, sections 3-4) ----
# 1. Use FAO's own GROUP items so nothing is double counted.
group_items <- c(
  "Grand Total", "Vegetal Products", "Animal Products",
  # animal groups
  "Meat", "Milk - Excluding Butter", "Eggs", "Aquatic Animals", "Animal fats", "Offals",
  # plant groups
  "Cereals - Excluding Beer", "Starchy Roots", "Sugar & Sweeteners", "Sugar Crops",
  "Pulses", "Treenuts", "Oilcrops", "Vegetable Oils", "Vegetables",
  "Fruits - Excluding Wine", "Stimulants", "Spices", "Alcoholic Beverages"
)
per_person <- c("Food supply (kcal/capita/day)",
                "Protein supply quantity (g/capita/day)")

# 2. Country comparison needs a few extra measures (new series only).
snapshot_items <- c("Population", "Grand Total", "Animal Products", "Pulses",
                    "Vegetables", "Fruits - Excluding Wine")
snapshot_elements <- c("Total Population - Both sexes", "Food", "Feed",
                       "Domestic supply quantity", "Production",
                       "Food supply quantity (kg/capita/yr)",
                       "Protein supply quantity (g/capita/day)")
snapshot_years <- 2021:2023

# ---- Read: only the columns we use (these files are 0.7 and 1.5 GB) ----
read_fbs <- function(path) {
  read_csv(path,
           col_select = c(`Area Code`, `Area Code (M49)`, Area, `Item Code`,
                          Item, Element, Year, Unit, Value),
           locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
    clean_names()
}

# Keep countries only:
#   - FAO regional/world totals use area codes >= 5000 (checked against AreaCodes file)
#   - "China" (351) = mainland + Hong Kong + Macao + Taiwan, which are also listed separately
countries_only <- function(df) df |> filter(area_code < 5000, area_code != 351)

# Some names exist twice: a group (code 29xx) and an item (e.g. "Eggs").
# Keep the group row (highest item code) so each name appears once.
one_row_per_name <- function(df) {
  df |>
    group_by(area_code, item, element, year) |>
    slice_max(item_code, n = 1, with_ties = FALSE) |>
    ungroup()
}

message("Reading new FAO series...")
new_raw <- read_fbs("data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv") |>
  countries_only()

new_slim <- new_raw |>
  filter(item %in% group_items, element %in% per_person) |>
  one_row_per_name() |>
  mutate(series = "new")

snapshot <- new_raw |>
  filter(item %in% snapshot_items, element %in% snapshot_elements,
         year %in% snapshot_years) |>
  one_row_per_name()

rm(new_raw); gc()

message("Reading historic FAO series (large file)...")
old_slim <- read_fbs("data/raw/FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv") |>
  countries_only() |>
  filter(item %in% group_items, element %in% per_person) |>
  one_row_per_name() |>
  mutate(series = "old")
gc()

# ---- Check 1: every item and measure present in both series ----
coverage <- bind_rows(new_slim, old_slim) |>
  count(series, element, item) |>
  pivot_wider(names_from = series, values_from = n)
save_table(coverage, "fao_item_coverage")
missing <- coverage |> filter(is.na(new) | is.na(old))
if (nrow(missing) > 0) warning("Items missing from one series:\n",
                               paste(missing$item, collapse = ", "))

# ---- Check 2: each name appears once per country-year (duplicate fix worked) ----
dupes <- bind_rows(new_slim, old_slim) |>
  count(series, area_code, item, element, year) |>
  filter(n > 1)
stopifnot("Duplicate rows remain" = nrow(dupes) == 0)

# ---- Check 3: the 2010-2013 overlap between methods ----
kcal <- "Food supply (kcal/capita/day)"

overlap <- inner_join(
  old_slim |> filter(year >= 2010),
  new_slim |> filter(year <= 2013),
  by = c("area_code", "item", "element", "year"),
  suffix = c("_old", "_new")
) |>
  mutate(pct_diff = (value_new - value_old) / value_old * 100)

# 3a. U.S.: totals and the animal SHARE under each method
overlap_us <- overlap |>
  filter(area_code == 231, element == kcal,
         item %in% c("Grand Total", "Animal Products")) |>
  select(year, item, value_old, value_new) |>
  pivot_wider(names_from = item, values_from = c(value_old, value_new)) |>
  transmute(year,
            total_old = `value_old_Grand Total`,
            total_new = `value_new_Grand Total`,
            total_pct_diff = (total_new - total_old) / total_old * 100,
            animal_share_old = `value_old_Animal Products` / total_old * 100,
            animal_share_new = `value_new_Animal Products` / total_new * 100)
save_table(overlap_us, "fao_overlap_us")

# 3b. All countries: average method gap in total calories
overlap_countries <- overlap |>
  filter(element == kcal, item == "Grand Total") |>
  group_by(area = area_new) |>
  summarise(mean_pct_diff = mean(pct_diff, na.rm = TRUE), .groups = "drop") |>
  arrange(desc(abs(mean_pct_diff)))
save_table(overlap_countries, "fao_overlap_countries")

record_number("us_total_kcal_method_gap_avg", mean(overlap_us$total_pct_diff),
              "% (new vs old)", this_script, "2010-2013 average")
record_number("us_animal_share_max_method_gap",
              max(abs(overlap_us$animal_share_new - overlap_us$animal_share_old)),
              "percentage points", this_script, "largest gap 2010-2013")
record_number("countries_median_method_gap", median(overlap_countries$mean_pct_diff),
              "%", this_script, "total kcal, 2010-2013")
record_number("countries_share_within_5pct",
              mean(abs(overlap_countries$mean_pct_diff) < 5) * 100,
              "% of countries", this_script, "total kcal, 2010-2013")
record_number("countries_in_overlap", nrow(overlap_countries),
              "countries", this_script)

# ---- Save ----
fbs_slim <- bind_rows(old_slim, new_slim)
write_rds(fbs_slim, "data/processed/fbs_slim.rds")
write_rds(snapshot, "data/processed/fbs_snapshot.rds")

message("01_build_fao.R done: ", nrow(fbs_slim), " rows in fbs_slim, ",
        nrow(snapshot), " rows in fbs_snapshot")
