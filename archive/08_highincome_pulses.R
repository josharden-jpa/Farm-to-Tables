# 08_highincome_pulses.R
# "Similar circumstances, different choices": among HIGH-INCOME countries,
#   1. How much protein comes from pulses (beans, peas, lentils)?
#   2. Where does each country's pulse supply go: food or animal feed? (AC's point)
#   3. How much fruit and vegetables are available (kg/person/yr; weight, not kcal)?
# Uses the NEW FAO series only (feed is only comparable within it).
# Averages several recent years for stability.
# First time only: install.packages("countrycode")

library(tidyverse)
library(janitor)
library(readxl)
library(countrycode)

years <- 2021:2023   # 3-year average; check coverage in section 1 before trusting it

# ---- 1. Pull what we need from the raw FAO file ----
fbs_new <- read_csv("data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv",
                    locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
  clean_names()

items <- c("Population", "Grand Total", "Animal Products", "Pulses",
           "Vegetables", "Fruits - Excluding Wine")
elements <- c("Total Population - Both sexes",
              "Food", "Feed", "Domestic supply quantity", "Production",
              "Food supply quantity (kg/capita/yr)",
              "Protein supply quantity (g/capita/day)")

x <- fbs_new |>
  filter(item %in% items, element %in% elements, year %in% years,
         area_code < 5000, area_code != 351) |>
  select(area_code, area_code_m49, area, item_code, item, element, year, value) |>
  group_by(area_code, item, element, year) |>
  slice_max(item_code, n = 1, with_ties = FALSE) |>   # same-name group/item fix
  ungroup()

rm(fbs_new); gc()

# Coverage check: rows per item/measure (about 3 years x ~190 countries expected)
x |> count(item, element) |> print(n = Inf)

# ---- 2. Average the years, one value per country/item/measure ----
avg <- x |>
  group_by(area_code, area_code_m49, area, item, element) |>
  summarise(value = mean(value, na.rm = TRUE), n_years = n(), .groups = "drop")

# ---- 3. Translate FAO's M49 codes to World Bank 3-letter codes ----
avg <- avg |>
  mutate(m49  = as.numeric(str_remove(area_code_m49, "'")),
         iso3 = countrycode(m49, origin = "un", destination = "iso3c"))

# Countries that didn't translate (check these; a few small ones are expected)
avg |> filter(is.na(iso3)) |> distinct(area, m49)

class <- read_excel("data/raw/CLASS_2026_10_08.xlsx", sheet = "List of economies") |>
  clean_names() |>
  select(iso3 = code, income_group, wb_region = region)

joined <- avg |> left_join(class, by = "iso3")

# FAO countries with no World Bank match (check)
joined |> filter(is.na(income_group)) |> distinct(area, iso3)

# ---- 4. One row per country, with short clear variable names ----
protein <- "Protein supply quantity (g/capita/day)"
kg      <- "Food supply quantity (kg/capita/yr)"

wide <- joined |>
  mutate(var = case_when(
    item == "Population"      & element == "Total Population - Both sexes" ~ "pop_thousands",
    item == "Grand Total"     & element == protein ~ "total_protein_g",
    item == "Animal Products" & element == protein ~ "animal_protein_g",
    item == "Pulses"          & element == protein ~ "pulse_protein_g",
    item == "Pulses"          & element == "Food" ~ "pulse_food_kt",
    item == "Pulses"          & element == "Feed" ~ "pulse_feed_kt",
    item == "Pulses"          & element == "Domestic supply quantity" ~ "pulse_supply_kt",
    item == "Pulses"          & element == "Production" ~ "pulse_prod_kt",
    item == "Vegetables"      & element == kg ~ "veg_kg",
    item == "Fruits - Excluding Wine" & element == kg ~ "fruit_kg"
  )) |>
  filter(!is.na(var)) |>
  select(area, iso3, income_group, wb_region, var, value) |>
  pivot_wider(names_from = var, values_from = value) |>
  mutate(
    # ASSUMPTION: FAO leaves out a row when a country feeds no pulses -> treat as 0
    pulse_feed_kt    = replace_na(pulse_feed_kt, 0),
    pulse_share_protein  = pulse_protein_g / total_protein_g * 100,
    animal_share_protein = animal_protein_g / total_protein_g * 100,
    pulse_pct_food   = pulse_food_kt / pulse_supply_kt * 100,
    pulse_pct_feed   = pulse_feed_kt / pulse_supply_kt * 100,
    produce_kg       = veg_kg + fruit_kg
  )

# High-income countries with at least 1 million people
# (tiny states' food balances are dominated by trade and can be erratic)
hi <- wide |>
  filter(income_group == "High income", pop_thousands >= 1000)

nrow(hi)   # how many countries are in the comparison?
write_rds(hi, "data/processed/highincome_snapshot.rds")

# ---- 5. Quick tables ----
hi |>
  arrange(desc(pulse_share_protein)) |>
  select(area, pulse_protein_g, pulse_share_protein, animal_share_protein,
         pulse_pct_food, pulse_pct_feed, produce_kg) |>
  mutate(across(where(is.numeric), ~ round(.x, 1))) |>
  print(n = Inf, width = Inf)

# ---- 6. Graph A: pulse share of protein, U.S. highlighted ----
hi |>
  mutate(is_us = area == "United States of America") |>
  ggplot(aes(pulse_share_protein, fct_reorder(area, pulse_share_protein), color = is_us)) +
  geom_point(size = 2.5) +
  scale_color_manual(values = c(`FALSE` = "grey55", `TRUE` = "firebrick"), guide = "none") +
  labs(title = "Share of protein supply from pulses (beans, peas, lentils)",
       subtitle = paste0("High-income countries, population 1M+, average ",
                         min(years), "-", max(years)),
       x = "% of protein supply", y = NULL,
       caption = "Sources: FAOSTAT Food Balances; World Bank income classification") +
  theme_minimal()
ggsave("figures/test_pulse_share_protein.png", width = 7, height = 9)

# ---- 7. Graph B: where pulses go, food vs feed ----
hi |>
  filter(pulse_supply_kt > 0) |>
  mutate(other_pct = 100 - pulse_pct_food - pulse_pct_feed) |>
  select(area, Food = pulse_pct_food, Feed = pulse_pct_feed, Other = other_pct) |>
  pivot_longer(-area, names_to = "use", values_to = "pct") |>
  mutate(use = factor(use, levels = c("Other", "Feed", "Food"))) |>
  ggplot(aes(pct, fct_reorder2(area, use == "Food", pct), fill = use)) +
  geom_col() +
  scale_fill_manual(values = c(Food = "#2e7d32", Feed = "#b26a00", Other = "grey75")) +
  labs(title = "Where each country's pulse supply goes",
       subtitle = "'Other' = seed, losses, processing, etc. High-income countries, population 1M+",
       x = "% of domestic pulse supply", y = NULL, fill = NULL,
       caption = "Source: FAOSTAT Food Balances (new methodology)") +
  theme_minimal()
ggsave("figures/test_pulse_food_vs_feed.png", width = 7, height = 9)