# 03_us_calorie_breakdown.R
# Hypothesis (Josh): the animal SHARE fell because total calories grew faster
# than animal calories -- not because Americans had less meat available.
# Test: plot the absolute numbers (kcal/person/day) behind the share.

library(tidyverse)

fbs_slim <- read_rds("data/processed/fbs_slim.rds")
kcal <- "Food supply (kcal/capita/day)"

# ---- 1. One continuous series: old method to 2009, new method from 2010 ----
# (Justified by the overlap check: shares nearly identical across methods.)
us <- fbs_slim |>
  filter(area == "United States of America", element == kcal) |>
  filter((series == "old (-2013)" & year <= 2009) |
           (series == "new (2010-)" & year >= 2010)) |>
  select(year, item, value) |>
  pivot_wider(names_from = item, values_from = value) |>
  mutate(
    # Whatever animal calories aren't meat, milk, eggs, or fish:
    # mostly animal fats, butter, cream, offal (check against FAO item list)
    `Other animal` = `Animal Products` - Meat - `Milk - Excluding Butter` -
      Eggs - `Aquatic Animals`
  )

# ---- 2. Test the hypothesis directly ----
# Compare the first and last years: did each category go up or down?
us |>
  filter(year %in% c(min(year), max(year))) |>
  select(year, `Grand Total`, `Vegetal Products`, `Animal Products`,
         Meat, `Milk - Excluding Butter`, Eggs, `Aquatic Animals`, `Other animal`) |>
  pivot_longer(-year) |>
  pivot_wider(names_from = year, values_from = value) |>
  rename(start = 2, end = 3) |>   # column 2 = first year, column 3 = last year
  mutate(change = end - start,
         pct_change = change / start * 100) |>
  print(width = Inf)

# ---- 3. Graph A: total, plant, and animal calories over time ----
us |>
  select(year, Total = `Grand Total`, Plant = `Vegetal Products`,
         Animal = `Animal Products`) |>
  pivot_longer(-year, names_to = "source", values_to = "kcal") |>
  ggplot(aes(year, kcal, color = source)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  scale_y_continuous(limits = c(0, NA)) +   # start at zero this time
  labs(title = "U.S. food supply per person per day, by source",
       subtitle = "Dashed line: FAO method change",
       x = NULL, y = "kcal per person per day", color = NULL,
       caption = "Source: FAOSTAT Food Balances") +
  theme_minimal()
ggsave("figures/test_us_kcal_total_plant_animal.png", width = 8, height = 5)

# ---- 4. Graph B: what's inside "animal products"? ----
us |>
  select(year, Meat, Milk = `Milk - Excluding Butter`, Eggs,
         `Fish & seafood` = `Aquatic Animals`, `Other animal`) |>
  pivot_longer(-year, names_to = "category", values_to = "kcal") |>
  ggplot(aes(year, kcal, color = category)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = 2010, linetype = "dashed") +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "U.S. animal-product calories per person per day, by type",
       subtitle = "'Other animal' = mostly animal fats, butter, cream, offal",
       x = NULL, y = "kcal per person per day", color = NULL,
       caption = "Source: FAOSTAT Food Balances") +
  theme_minimal()
ggsave("figures/test_us_animal_breakdown.png", width = 8, height = 5)