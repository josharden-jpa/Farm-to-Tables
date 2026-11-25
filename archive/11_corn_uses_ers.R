# 11_corn_uses_ers.R
# Final "where does U.S. corn go" figure, from USDA ERS Feed Grains Yearbook.
# Why ERS instead of FAO here: ERS names fuel ethanol directly, is the official
# U.S. source, and has no method break (1980 onward).
# Notes: marketing years (Sep-Aug); 2025+ rows are projections, so we drop them.
# Units: million bushels (shares don't depend on the unit).

library(tidyverse)
library(janitor)

ers <- read_csv("data/raw/feed-grains-yearbook-all-years.csv", show_col_types = FALSE) |>
  clean_names()

corn <- ers |>
  filter(commodity == "Corn", frequency == "Annual",
         str_starts(table_name, "Table 4--") | str_starts(table_name, "Table 31--"),
         year >= 1980, year <= 2024) |>      # 2025+ = projections
  select(year, attribute, amount) |>
  distinct()

# ---- 1. Check: attributes available ----
corn |> distinct(attribute) |> print(n = Inf)

wide <- corn |> pivot_wider(names_from = attribute, values_from = amount)

uses <- wide |>
  transmute(
    year,
    `Animal feed (& residual)` = `Feed and residual use`,
    `Fuel ethanol`             = `Alcohol for fuel use`,
    `Exported`                 = Exports,
    `Sweeteners, cereals & drinks` = `High-fructose corn syrup (HFCS) use` +
      `Glucose and dextrose use` +
      `Cereals and other products use` +
      `Alcohol for beverages and manufacturing use`,
    `Starch (food & industrial)` = `Starch use`,
    `Seed`                     = `Seed use`,
    total_use                  = `Total use`
  )

# ---- 2. Check: do the parts add up to ERS's total use? (gap should be ~0) ----
uses |>
  mutate(sum_parts = rowSums(across(-c(year, total_use))),
         gap = total_use - sum_parts) |>
  filter(year %in% c(1980, 2000, 2010, 2024)) |>
  select(year, total_use, sum_parts, gap)

long <- uses |>
  select(-total_use) |>
  pivot_longer(-year, names_to = "use", values_to = "mbu") |>
  group_by(year) |>
  mutate(share = mbu / sum(mbu) * 100) |>
  ungroup()

# ---- 3. Shares in selected years ----
long |>
  filter(year %in% c(1980, 1990, 2000, 2005, 2010, 2015, 2020, 2024)) |>
  select(year, use, share) |>
  pivot_wider(names_from = year, values_from = share) |>
  mutate(across(where(is.numeric), ~ round(.x, 1))) |>
  print(width = Inf)

use_levels <- c("Seed", "Starch (food & industrial)", "Sweeteners, cereals & drinks",
                "Exported", "Fuel ethanol", "Animal feed (& residual)")
use_colors <- c("Animal feed (& residual)" = "#b26a00",
                "Fuel ethanol" = "#5c6bc0",
                "Exported" = "#7a7a7a",
                "Sweeteners, cereals & drinks" = "#2e7d32",
                "Starch (food & industrial)" = "#9ccc65",
                "Seed" = "grey85")

# ---- 4. Graph A: shares over time (100% stacked) ----
long |>
  mutate(use = factor(use, levels = use_levels)) |>
  ggplot(aes(year, share, fill = use)) +
  geom_area() +
  scale_fill_manual(values = use_colors) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
  labs(title = "Where U.S. corn goes, 1980-2024",
       subtitle = "Share of total corn use, by marketing year (Sep-Aug)",
       x = NULL, y = NULL, fill = NULL,
       caption = "Source: USDA ERS Feed Grains Yearbook, Tables 4 and 31") +
  theme_minimal()
ggsave("figures/corn_uses_ers_over_time.png", width = 9, height = 5.5)

# ---- 5. Graph B: recent snapshot, 2021-2023 average ----
long |>
  filter(year %in% 2021:2023) |>
  group_by(use) |>
  summarise(share = mean(share), .groups = "drop") |>
  mutate(use = factor(use, levels = use_levels)) |>
  ggplot(aes(share, use, fill = use)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(round(share), "%")), hjust = -0.15) +
  scale_fill_manual(values = use_colors) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Where U.S. corn goes (average of 2021-2023 marketing years)",
       x = "% of total corn use", y = NULL,
       caption = "Source: USDA ERS Feed Grains Yearbook, Tables 4 and 31") +
  theme_minimal()
ggsave("figures/corn_uses_ers_snapshot.png", width = 8, height = 4.5)