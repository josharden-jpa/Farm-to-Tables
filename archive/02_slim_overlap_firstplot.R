# 02_slim_overlap_firstplot.R
# 1. Keep only what we need from the two FAO series (16M rows -> a few thousand)
# 2. Check the 2010-2013 overlap between old and new methods
# 3. First test graph: U.S. share of calories from animal products, 1961-2024

library(tidyverse)
library(janitor)

fbs_new <- read_csv("data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv",
                    locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
  clean_names()
fbs_old <- read_csv("data/raw/FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv",
                    locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
  clean_names()

# ---- 0. Quick look at the old series (we skipped this last time) ----
range(fbs_old$year)
n_distinct(fbs_old$area)

# ---- 1. Choose what to keep ----
# Items: FAO's own groups, so we never double count by adding parts to totals
keep_items <- c("Grand Total", "Vegetal Products", "Animal Products",
                # animal groups
                "Meat", "Milk - Excluding Butter", "Eggs", "Aquatic Animals",
                "Animal fats", "Offals",
                # plant groups (FAO's own group names)
                "Cereals - Excluding Beer", "Starchy Roots", "Sugar & Sweeteners",
                "Sugar Crops", "Pulses", "Treenuts", "Oilcrops", "Vegetable Oils",
                "Vegetables", "Fruits - Excluding Wine", "Stimulants", "Spices",
                "Alcoholic Beverages")
# Measures: calories (main) and protein (robustness check), per person per day
keep_elements <- c("Food supply (kcal/capita/day)",
                   "Protein supply quantity (g/capita/day)")

slim <- function(df, series_name) {
  df |>
    filter(item %in% keep_items,
           element %in% keep_elements,
           area_code < 5000,     # FAO region/world totals use codes 5000+
           area_code != 351) |>  # "China" = mainland + HK + Macao + Taiwan; avoid double count
    select(area_code, area, item_code, item, element, year, value, flag) |>
    mutate(series = series_name) |>
    # FIX: "Eggs" and "Milk - Excluding Butter" each exist twice: as a group
    # (code 29xx) and as an individual item (lower code), same name.
    # Keep only the group row so each item appears once.
    group_by(area_code, item, element, year) |>
    slice_max(item_code, n = 1, with_ties = FALSE) |>
    ungroup()
}

new_slim <- slim(fbs_new, "new (2010-)")
old_slim <- slim(fbs_old, "old (-2013)")

# Did every item/measure come through in BOTH series? Look for missing rows here.
bind_rows(new_slim, old_slim) |>
  count(series, element, item) |>
  print(n = Inf)

# Free memory: we don't need the giant files anymore
rm(fbs_new, fbs_old); gc()

fbs_slim <- bind_rows(old_slim, new_slim)
write_rds(fbs_slim, "data/processed/fbs_slim.rds")  # later scripts start here

# ---- 2. Overlap check: same country, item, measure, year, two methods ----
kcal <- "Food supply (kcal/capita/day)"

overlap <- inner_join(
  old_slim |> filter(year >= 2010),
  new_slim |> filter(year <= 2013),
  by = c("area_code", "item", "element", "year"),
  suffix = c("_old", "_new")
) |>
  mutate(pct_diff = (value_new - value_old) / value_old * 100)

# 2a. The U.S., year by year
overlap |>
  filter(area_new == "United States of America", element == kcal,
         item %in% c("Grand Total", "Animal Products", "Meat")) |>
  select(item, year, value_old, value_new, pct_diff) |>
  arrange(item, year) |>
  print(n = Inf)

# 2b. All countries: average gap per country for total calories
gap_by_country <- overlap |>
  filter(element == kcal, item == "Grand Total") |>
  group_by(area_new) |>
  summarise(mean_pct_diff = mean(pct_diff, na.rm = TRUE), .groups = "drop")

gap_by_country |>
  summarise(n_countries   = n(),
            median_gap    = median(mean_pct_diff),
            share_within_5pct = mean(abs(mean_pct_diff) < 5)) |>
  print(width = Inf)   # show all columns

# Which item codes did we keep? Check that Eggs/Milk now show one code each.
fbs_slim |> distinct(item, item_code) |> arrange(item) |> print(n = Inf)

# Animal SHARE in the overlap years: is it stable across methods?
overlap |>
  filter(area_new == "United States of America", element == kcal,
         item %in% c("Grand Total", "Animal Products")) |>
  select(item, year, value_old, value_new) |>
  pivot_wider(names_from = item, values_from = c(value_old, value_new)) |>
  mutate(share_old = `value_old_Animal Products` / `value_old_Grand Total` * 100,
         share_new = `value_new_Animal Products` / `value_new_Grand Total` * 100) |>
  select(year, share_old, share_new)

# The 10 countries with the biggest gaps (we'll want to know why)
gap_by_country |> arrange(desc(abs(mean_pct_diff))) |> head(10)

# ---- 3. First test graph ----
us_share <- fbs_slim |>
  filter(area == "United States of America", element == kcal,
         item %in% c("Grand Total", "Animal Products")) |>
  select(series, year, item, value) |>
  pivot_wider(names_from = item, values_from = value) |>
  mutate(animal_share = `Animal Products` / `Grand Total` * 100)

ggplot(us_share, aes(year, animal_share, color = series)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  labs(title = "Share of U.S. food-supply calories from animal products",
       subtitle = "Dashed line: FAO method change (series overlap 2010-2013)",
       x = NULL, y = "% of calories", color = "FAO series",
       caption = "Source: FAOSTAT Food Balances") +
  theme_minimal()

ggsave("figures/test_us_animal_share.png", width = 8, height = 5)