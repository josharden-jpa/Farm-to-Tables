# 06_ers_meat_crosscheck.R
# 1. Cross-check FAO's U.S. meat trend against USDA ERS (independent source)
#    - ERS: boneless weight, red meat + poultry (fish excluded, to match FAO "Meat")
#    - Units differ (lbs vs kcal), so compare TRENDS: index both to 1961 = 100
# 2. Check the sudden FAO jump around 2018: does ERS show it too?
# 3. Bonus history graph: U.S. meat by type, 1909-2021 (boneless)

library(tidyverse)
library(janitor)

ers <- read_csv("data/raw/mtpcc.csv", show_col_types = FALSE) |>
  clean_names() |>
  mutate(attribute = str_squish(attribute))   # fixes "Other\n chicken" line break

# ---- 1. Keep the boneless-weight table only ----
boneless <- ers |>
  filter(commodity == "Red meat, poultry, and fish (boneless weight): Per capita availability")

boneless |> count(attribute)   # which measures are in this table?

ers_meat <- boneless |>
  filter(attribute %in% c("Red meat-Total-Pounds", "Poultry-Total-Pounds")) |>
  group_by(year) |>
  summarise(lbs = sum(value), n_parts = n(), .groups = "drop")

ers_meat |> count(n_parts)   # should be 2 in every year; if not, tell Claude

# ---- 2. FAO meat, same continuous series as before ----
fao_meat <- read_rds("data/processed/fbs_slim.rds") |>
  filter(area == "United States of America", item == "Meat",
         element == "Food supply (kcal/capita/day)") |>
  filter((series == "old (-2013)" & year <= 2009) |
           (series == "new (2010-)" & year >= 2010)) |>
  select(year, kcal = value)

compare <- inner_join(ers_meat, fao_meat, by = "year") |>
  mutate(ers_index = lbs  / lbs[year == 1961]  * 100,
         fao_index = kcal / kcal[year == 1961] * 100)

# How closely do the two sources move together? (1 = perfectly)
cor(compare$lbs, compare$kcal)

# ---- 3. The suspicious years: year-to-year % change in each source ----
compare |>
  arrange(year) |>
  mutate(ers_pct_chg = (lbs / lag(lbs) - 1) * 100,
         fao_pct_chg = (kcal / lag(kcal) - 1) * 100) |>
  filter(year >= 2010) |>
  select(year, lbs, ers_pct_chg, kcal, fao_pct_chg) |>
  print(n = Inf)

# ---- 4. Graph: two sources, one trend? ----
compare |>
  select(year, `USDA ERS (boneless lbs)` = ers_index,
         `FAO (kcal)` = fao_index) |>
  pivot_longer(-year, names_to = "source", values_to = "index") |>
  ggplot(aes(year, index, color = source)) +
  geom_hline(yintercept = 100, color = "grey60") +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  labs(title = "U.S. meat availability per person: two independent sources",
       subtitle = "Red meat + poultry, indexed to 1961 = 100. Dashed line: FAO method change",
       x = NULL, y = "Index (1961 = 100)", color = NULL,
       caption = "Sources: FAOSTAT Food Balances; USDA ERS Food Availability Data") +
  theme_minimal()
ggsave("figures/test_meat_crosscheck.png", width = 8, height = 5)

# ---- 5. Bonus: a century of U.S. meat, by type (boneless lbs/person/year) ----
boneless |>
  filter(attribute %in% c("Red meat-Beef-Pounds", "Red meat-Pork-Pounds",
                          "Poultry-Chicken-Pounds", "Poultry-Turkey-Pounds",
                          "Fish and shellfish-Pounds")) |>
  mutate(type = str_remove(attribute, "-Pounds") |>
           str_remove("Red meat-|Poultry-")) |>
  ggplot(aes(year, value, color = type)) +
  geom_line(linewidth = 1) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "U.S. meat available per person, by type, 1909-2021",
       subtitle = "Boneless, trimmed weight",
       x = NULL, y = "Pounds per person per year", color = NULL,
       caption = "Source: USDA ERS Food Availability Data") +
  theme_minimal()
ggsave("figures/test_meat_by_type_century.png", width = 8, height = 5)