# 04_us_plant_breakdown.R
# Josh's prediction: plant calories grew mostly through vegetable oils,
# sugar/sweeteners, and cereals (processed foods), not fruits, vegetables, pulses.
# Also checks what "Other animal" really contains.
# Run AFTER rerunning script 02 with the expanded keep_items list.

library(tidyverse)

fbs_slim <- read_rds("data/processed/fbs_slim.rds")
kcal <- "Food supply (kcal/capita/day)"

us <- fbs_slim |>
  filter(area == "United States of America", element == kcal) |>
  filter((series == "old (-2013)" & year <= 2009) |
           (series == "new (2010-)" & year >= 2010)) |>
  select(year, item, value) |>
  pivot_wider(names_from = item, values_from = value) |>
  mutate(across(everything(), ~ replace_na(.x, 0)))  # a missing group = 0 kcal

plant_groups <- c("Cereals - Excluding Beer", "Starchy Roots", "Sugar & Sweeteners",
                  "Sugar Crops", "Pulses", "Treenuts", "Oilcrops", "Vegetable Oils",
                  "Vegetables", "Fruits - Excluding Wine", "Stimulants", "Spices",
                  "Alcoholic Beverages")

# ---- 1. Check: do the plant groups add up to FAO's plant total? ----
# If the gap is near zero, our groups cover everything (and nothing twice).
us |>
  mutate(sum_groups = rowSums(across(any_of(plant_groups))),
         gap = `Vegetal Products` - sum_groups) |>
  select(year, `Vegetal Products`, sum_groups, gap) |>
  filter(year %in% c(1961, 1990, 2010, max(year)))

# ---- 2. Check "Other animal": is it mostly animal fats and offal? ----
us |>
  mutate(other_animal = `Animal Products` - Meat - `Milk - Excluding Butter` -
           Eggs - `Aquatic Animals`) |>
  select(year, other_animal, `Animal fats`, Offals) |>
  filter(year %in% c(1961, 1990, 2010, max(year)))

# ---- 3. Test the prediction: change by plant group, 1961 -> latest ----
us |>
  filter(year %in% c(min(year), max(year))) |>
  select(year, any_of(plant_groups)) |>
  pivot_longer(-year) |>
  pivot_wider(names_from = year, values_from = value) |>
  rename(start = 2, end = 3) |>
  mutate(change = end - start,
         pct_change = change / start * 100) |>
  arrange(desc(change)) |>
  print(width = Inf)

# ---- 4. Graph: plant calories by group over time ----
# Keep the big groups; lump the small ones so the graph stays readable
us |>
  select(year, any_of(plant_groups)) |>
  pivot_longer(-year, names_to = "group", values_to = "kcal") |>
  mutate(group = case_when(
    group == "Cereals - Excluding Beer" ~ "Cereals (grains)",
    group == "Vegetable Oils"           ~ "Vegetable oils",
    group == "Sugar & Sweeteners"       ~ "Sugar & sweeteners",
    group == "Fruits - Excluding Wine"  ~ "Fruits",
    group == "Vegetables"               ~ "Vegetables",
    group == "Pulses"                   ~ "Pulses (beans, peas, lentils)",
    group == "Starchy Roots"            ~ "Potatoes & roots",
    TRUE                                ~ "Other plant"
  )) |>
  group_by(year, group) |>
  summarise(kcal = sum(kcal), .groups = "drop") |>
  ggplot(aes(year, kcal, color = group)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "U.S. plant-based calories per person per day, by group",
       subtitle = "Dashed line: FAO method change",
       x = NULL, y = "kcal per person per day", color = NULL,
       caption = "Source: FAOSTAT Food Balances") +
  theme_minimal()
ggsave("figures/test_us_plant_breakdown.png", width = 8, height = 5)