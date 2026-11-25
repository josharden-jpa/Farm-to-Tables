# 09_pulse_figures_v2.R
# Fixes and follow-ups to script 08:
#   - Food vs feed share now = food / (food + feed), always 0-100%
#     (FAO's domestic supply includes stock changes, so feed could exceed it:
#      Denmark showed 173%. This measure avoids that.)
#   - U.S. highlighted in every graph
#   - New scatter: do countries that send more pulses to food get more protein from pulses?
# First time only: install.packages("ggrepel")  (keeps country labels from overlapping)

library(tidyverse)
library(ggrepel)

hi <- read_rds("data/processed/highincome_snapshot.rds") |>
  mutate(
    pulse_pct_food_of_ff = pulse_food_kt / (pulse_food_kt + pulse_feed_kt) * 100,
    is_us = area == "United States of America",
    # shorter names for labels
    label = case_when(
      area == "United States of America" ~ "United States",
      area == "United Kingdom of Great Britain and Northern Ireland" ~ "United Kingdom",
      area == "Netherlands (Kingdom of the)" ~ "Netherlands",
      area == "Republic of Korea" ~ "South Korea",
      area == "Russian Federation" ~ "Russia",
      area == "China, Hong Kong SAR" ~ "Hong Kong",
      TRUE ~ area
    )
  )

# ---- 1. Check the new measure: any values outside 0-100? (should be none) ----
summary(hi$pulse_pct_food_of_ff)

# ---- 2. Where does the U.S. rank on each measure? (1 = highest) ----
hi |>
  mutate(rank_pulse_protein = min_rank(desc(pulse_share_protein)),
         rank_animal_protein = min_rank(desc(animal_share_protein)),
         rank_pct_food = min_rank(desc(pulse_pct_food_of_ff)),
         rank_produce = min_rank(desc(produce_kg))) |>
  filter(is_us) |>
  select(label, starts_with("rank_"))

# ---- 3. Graph A: of pulses used for food or feed, % used as FOOD ----
hi |>
  ggplot(aes(pulse_pct_food_of_ff, fct_reorder(label, pulse_pct_food_of_ff), fill = is_us)) +
  geom_col() +
  scale_fill_manual(values = c(`FALSE` = "grey65", `TRUE` = "firebrick"), guide = "none") +
  labs(title = "Of the pulses each country uses for food or feed, how much feeds people?",
       subtitle = "High-income countries, population 1M+, average 2021-2023",
       x = "% used as food (rest = animal feed)", y = NULL,
       caption = "Source: FAOSTAT Food Balances (new methodology)") +
  theme_minimal()
ggsave("figures/test_pulse_pct_food_v2.png", width = 7, height = 9)

# ---- 4. Graph B: the scatter (Josh's question) ----
r <- cor(hi$pulse_pct_food_of_ff, hi$pulse_share_protein, use = "complete.obs")
r   # correlation

hi |>
  ggplot(aes(pulse_pct_food_of_ff, pulse_share_protein)) +
  geom_point(aes(color = is_us), size = 2.5) +
  geom_text_repel(aes(label = label, color = is_us), size = 3, max.overlaps = 15) +
  scale_color_manual(values = c(`FALSE` = "grey40", `TRUE` = "firebrick"), guide = "none") +
  labs(title = "Do countries that send pulses to people get more protein from them?",
       subtitle = paste0("Each dot is a high-income country (population 1M+), 2021-2023 average. ",
                         "Correlation r = ", round(r, 2)),
       x = "% of food+feed pulses used as food",
       y = "% of protein supply from pulses",
       caption = "Sources: FAOSTAT Food Balances; World Bank income classification") +
  theme_minimal()
ggsave("figures/test_pulse_scatter.png", width = 8, height = 6)

# ---- 5. Graph C: animal share of protein, U.S. highlighted ----
hi |>
  ggplot(aes(animal_share_protein, fct_reorder(label, animal_share_protein), color = is_us)) +
  geom_point(size = 2.5) +
  scale_color_manual(values = c(`FALSE` = "grey55", `TRUE` = "firebrick"), guide = "none") +
  labs(title = "Share of protein supply from animal products",
       subtitle = "High-income countries, population 1M+, average 2021-2023",
       x = "% of protein supply", y = NULL,
       caption = "Sources: FAOSTAT Food Balances; World Bank income classification") +
  theme_minimal()
ggsave("figures/test_animal_share_protein_hi.png", width = 7, height = 9)

# ---- 6. Totals matter too: total protein vs. animal share ----
# Josh's question: do countries with SIMILAR total protein get it from
# DIFFERENT sources? Or does more protein generally mean more animal protein?
hi |>
  select(label, total_protein_g, animal_protein_g, animal_share_protein) |>
  arrange(desc(total_protein_g)) |>
  mutate(across(where(is.numeric), ~ round(.x, 1))) |>
  print(n = Inf)

r_tot <- cor(hi$total_protein_g, hi$animal_share_protein, use = "complete.obs")
r_tot

hi |>
  ggplot(aes(total_protein_g, animal_share_protein)) +
  geom_point(aes(color = is_us), size = 2.5) +
  geom_text_repel(aes(label = label, color = is_us), size = 3, max.overlaps = 15) +
  scale_color_manual(values = c(`FALSE` = "grey40", `TRUE` = "firebrick"), guide = "none") +
  labs(title = "Similar protein totals, different sources?",
       subtitle = paste0("High-income countries (population 1M+), 2021-2023 average. ",
                         "Correlation r = ", round(r_tot, 2)),
       x = "Total protein supply (g per person per day)",
       y = "% of protein supply from animal products",
       caption = "Sources: FAOSTAT Food Balances; World Bank income classification") +
  theme_minimal()
ggsave("figures/test_protein_total_vs_animal_share.png", width = 8, height = 6)

# ---- 7. Stacked bars: grams of plant vs animal protein per person ----
hi |>
  mutate(plant_protein_g = total_protein_g - animal_protein_g) |>
  select(label, is_us, total_protein_g,
         `Animal protein` = animal_protein_g, `Plant protein` = plant_protein_g) |>
  pivot_longer(c(`Animal protein`, `Plant protein`),
               names_to = "source", values_to = "grams") |>
  mutate(label = if_else(is_us, paste0("▶ ", label), label)) |>  # marks the U.S.
  ggplot(aes(grams, fct_reorder(label, total_protein_g), fill = source)) +
  geom_col() +
  scale_fill_manual(values = c(`Animal protein` = "#b26a00", `Plant protein` = "#2e7d32")) +
  labs(title = "Protein supply per person per day, by source",
       subtitle = "High-income countries, population 1M+, average 2021-2023. Sorted by total.",
       x = "grams per person per day", y = NULL, fill = NULL,
       caption = "Source: FAOSTAT Food Balances") +
  theme_minimal()
ggsave("figures/test_protein_grams_stacked.png", width = 7, height = 9)