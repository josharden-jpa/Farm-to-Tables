# 10_us_corn_uses.R
# "We grow food to feed our food": where does U.S. corn go?
# FAO item "Maize and products", all uses, 1961-2024 (old series to 2009, new from 2010)
# Units: 1000 tonnes. CAUTION: FAO redesigned how it estimates feed in the new
# series, so compare shares across the 2010 break carefully.

library(tidyverse)
library(janitor)

read_fao <- function(path) {
  read_csv(path, locale = locale(encoding = "latin1"), show_col_types = FALSE) |>
    clean_names() |>
    filter(area_code == 231, item == "Maize and products", unit == "1000 t") |>
    select(item_code, element, year, value)
}

old <- read_fao("data/raw/FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv") |>
  mutate(series = "old")
new <- read_fao("data/raw/FoodBalanceSheets_E_All_Data_(Normalized).csv") |>
  mutate(series = "new")

# ---- 1. What elements exist in each series? (names can differ between series) ----
bind_rows(old, new) |> count(series, element) |> print(n = Inf)
bind_rows(old, new) |> distinct(item_code)   # should be a single code

# ---- 2. One continuous series ----
corn <- bind_rows(old |> filter(year <= 2009), new |> filter(year >= 2010))

uses <- c("Export quantity", "Feed", "Food", "Processing",
          "Other uses (non-food)", "Seed", "Losses", "Residuals",
          "Tourist consumption")

corn_uses <- corn |>
  filter(element %in% uses) |>
  mutate(use = case_when(
    element == "Export quantity"       ~ "Exported",
    element == "Feed"                  ~ "Animal feed (U.S.)",
    element == "Food"                  ~ "Food (direct)",
    element == "Processing"            ~ "Processed (sweeteners, starch, oil?)",
    element == "Other uses (non-food)" ~ "Non-food uses (ethanol?)",
    TRUE                               ~ "Seed, losses & residual"
  )) |>
  group_by(year, use) |>
  summarise(mt = sum(value, na.rm = TRUE) / 1000, .groups = "drop")  # million tonnes

# ---- 3. Check: any negative values? (residuals can be negative) ----
corn_uses |> filter(mt < 0)

# ---- 4. Shares in selected years ----
corn_uses |>
  group_by(year) |>
  mutate(share = mt / sum(mt) * 100) |>
  ungroup() |>
  filter(year %in% c(1961, 1980, 2000, 2005, 2010, 2015, 2020, max(year))) |>
  select(year, use, share) |>
  pivot_wider(names_from = year, values_from = share) |>
  mutate(across(where(is.numeric), ~ round(.x, 1))) |>
  print(width = Inf)

# ---- 5. Production, for comparison with total uses ----
prod <- corn |> filter(element == "Production") |>
  transmute(year, production_mt = value / 1000)

# ---- 6. Graph A: uses over time (million tonnes), production as a line ----
use_order <- c("Seed, losses & residual", "Food (direct)",
               "Processed (sweeteners, starch, oil?)", "Non-food uses (ethanol?)",
               "Exported", "Animal feed (U.S.)")

corn_uses |>
  filter(mt >= 0) |>
  mutate(use = factor(use, levels = use_order)) |>
  ggplot(aes(year, mt)) +
  geom_area(aes(fill = use), alpha = 0.9) +
  geom_line(data = prod, aes(year, production_mt), linewidth = 0.8, linetype = "dotted") +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  scale_fill_manual(values = c("Animal feed (U.S.)" = "#b26a00",
                               "Exported" = "#7a7a7a",
                               "Non-food uses (ethanol?)" = "#5c6bc0",
                               "Processed (sweeteners, starch, oil?)" = "#9ccc65",
                               "Food (direct)" = "#2e7d32",
                               "Seed, losses & residual" = "grey85")) +
  labs(title = "Where U.S. corn goes, 1961-2024",
       subtitle = "Million tonnes per year. Dotted line = U.S. production. Dashed line = FAO method change",
       x = NULL, y = "million tonnes", fill = NULL,
       caption = "Source: FAOSTAT Food Balances ('Maize and products')") +
  theme_minimal()
ggsave("figures/test_corn_uses_over_time.png", width = 9, height = 5.5)

# ---- 7. Graph B: recent snapshot, 2021-2023 average, as shares ----
corn_uses |>
  filter(year %in% 2021:2023, mt >= 0) |>
  group_by(use) |>
  summarise(mt = mean(mt), .groups = "drop") |>
  mutate(share = mt / sum(mt) * 100,
         use = fct_reorder(use, share)) |>
  ggplot(aes(share, use)) +
  geom_col(fill = "#b26a00") +
  geom_text(aes(label = paste0(round(share), "%")), hjust = -0.15) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Where U.S. corn goes (average 2021-2023)",
       x = "% of total uses", y = NULL,
       caption = "Source: FAOSTAT Food Balances ('Maize and products')") +
  theme_minimal()
ggsave("figures/test_corn_uses_snapshot.png", width = 8, height = 4.5)