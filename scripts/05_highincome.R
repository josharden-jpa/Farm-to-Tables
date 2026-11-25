# scripts/05_highincome.R
# ACT 3: Could it look different? Wealthy countries compared.
#
# Inputs : data/processed/fbs_snapshot.rds (from 01_build_fao.R; new FAO series, 2021-2023)
#          data/raw/CLASS_2026_10_08.xlsx (World Bank income classification)
# Outputs: fig_09 to fig_12, tables, key numbers incl. significance tests
#
# Design: compare only HIGH-INCOME countries (population 1M+). All can afford as much
# animal food as they want, so differences reflect choices, culture and policy, not
# poverty. Protein is the main measure: it is what animal foods supply and what a
# plant-based shift must replace. 2021-2023 averaged for stability. New FAO series
# only, because feed estimation changed between methods.
# First time only: install.packages(c("countrycode", "ggrepel"))

source("R/helpers.R")
library(readxl)
library(countrycode)
library(ggrepel)
this_script <- "05_highincome.R"
yrs <- "2021-2023 average"

snap <- read_rds("data/processed/fbs_snapshot.rds")

# ---- 1. Average the three years: one value per country, item, measure ----
avg <- snap |>
  group_by(area_code, area_code_m49, area, item, element) |>
  summarise(value = mean(value, na.rm = TRUE), n_years = n(), .groups = "drop")

# ---- 2. FAO M49 codes -> World Bank 3-letter codes ----
# Only Taiwan (M49 158) fails to match; it is not in the World Bank list.
avg <- avg |>
  mutate(m49  = as.numeric(str_remove(area_code_m49, "'")),
         iso3 = suppressWarnings(countrycode(m49, origin = "un", destination = "iso3c")))
unmatched <- avg |> filter(is.na(iso3)) |> distinct(area)
message("Unmatched FAO areas: ", paste(unmatched$area, collapse = ", "))

wb <- read_excel("data/raw/CLASS_2026_10_08.xlsx", sheet = "List of economies") |>
  janitor::clean_names() |>
  select(iso3 = code, income_group)

# ---- 3. One row per country with short variable names ----
protein <- "Protein supply quantity (g/capita/day)"
kg      <- "Food supply quantity (kg/capita/yr)"

wide <- avg |>
  left_join(wb, by = "iso3") |>
  mutate(var = case_when(
    item == "Population"      & element == "Total Population - Both sexes" ~ "pop_thousands",
    item == "Grand Total"     & element == protein ~ "total_protein_g",
    item == "Animal Products" & element == protein ~ "animal_protein_g",
    item == "Pulses"          & element == protein ~ "pulse_protein_g",
    item == "Pulses"          & element == "Food" ~ "pulse_food_kt",
    item == "Pulses"          & element == "Feed" ~ "pulse_feed_kt",
    item == "Vegetables"      & element == kg ~ "veg_kg",
    item == "Fruits - Excluding Wine" & element == kg ~ "fruit_kg"
  )) |>
  filter(!is.na(var)) |>
  select(area, iso3, income_group, var, value) |>
  pivot_wider(names_from = var, values_from = value)

# ---- 4. High-income, population 1M+ ----
hi <- wide |>
  filter(income_group == "High income", pop_thousands >= 1000) |>
  mutate(
    # ASSUMPTION (RESEARCH_LOG 7): no FAO feed row = no pulses fed to animals
    pulse_feed_kt        = replace_na(pulse_feed_kt, 0),
    plant_protein_g      = total_protein_g - animal_protein_g,
    animal_share_protein = animal_protein_g / total_protein_g * 100,
    pulse_share_protein  = pulse_protein_g / total_protein_g * 100,
    # Share of pulses used for food OR feed that goes to food (always 0-100%;
    # domestic supply is not used as the denominator because it includes stock changes)
    pulse_pct_food       = pulse_food_kt / (pulse_food_kt + pulse_feed_kt) * 100,
    produce_kg           = veg_kg + fruit_kg,
    is_us = iso3 == "USA",
    label = case_when(
      iso3 == "USA" ~ "United States", iso3 == "GBR" ~ "United Kingdom",
      iso3 == "NLD" ~ "Netherlands",   iso3 == "KOR" ~ "South Korea",
      iso3 == "RUS" ~ "Russia",        iso3 == "HKG" ~ "Hong Kong",
      TRUE ~ area)
  )

stopifnot("U.S. missing from comparison" = sum(hi$is_us) == 1,
          "Pulse food share outside 0-100" = all(between(hi$pulse_pct_food, 0, 100), na.rm = TRUE))

hi <- hi |>
  mutate(rank_animal_share = min_rank(desc(animal_share_protein)),
         rank_total_protein = min_rank(desc(total_protein_g)),
         rank_pulse_share  = min_rank(desc(pulse_share_protein)),
         rank_pulse_food   = min_rank(desc(pulse_pct_food)),
         rank_produce      = min_rank(desc(produce_kg)))

save_table(hi |> select(label, iso3, pop_thousands, total_protein_g, animal_protein_g,
                        plant_protein_g, animal_share_protein, pulse_protein_g,
                        pulse_share_protein, pulse_pct_food, produce_kg, starts_with("rank_")) |>
             arrange(desc(animal_share_protein)),
           "highincome_comparison_2021_2023")
write_rds(hi, "data/processed/highincome.rds")   # used by 06_world_map.R

# ---- 5. Key numbers ----
us <- hi |> filter(is_us)
n  <- nrow(hi)
record_number("hi_n_countries", n, "countries", this_script, "high income, pop 1M+")
record_number("us_animal_share_protein", us$animal_share_protein, "% of protein", this_script, yrs)
record_number("us_rank_animal_share_protein", us$rank_animal_share, paste("rank of", n), this_script, "1 = highest")
record_number("us_total_protein_g", us$total_protein_g, "g/person/day", this_script, yrs)
record_number("us_rank_total_protein", us$rank_total_protein, paste("rank of", n), this_script)
record_number("us_pulse_share_protein", us$pulse_share_protein, "% of protein", this_script, yrs)
record_number("us_rank_pulse_share", us$rank_pulse_share, paste("rank of", n), this_script)
record_number("us_pulse_pct_food", us$pulse_pct_food, "% of food+feed pulses", this_script, yrs)
record_number("us_rank_pulse_food", us$rank_pulse_food, paste("rank of", n), this_script)
record_number("us_produce_kg", us$produce_kg, "kg/person/yr", this_script, "fruit + vegetables")
record_number("us_rank_produce", us$rank_produce, paste("rank of", n), this_script)
record_number("hi_median_pulse_share_protein", median(hi$pulse_share_protein), "% of protein", this_script)
record_number("hi_max_pulse_share_protein", max(hi$pulse_share_protein), "% of protein", this_script,
              hi$label[which.max(hi$pulse_share_protein)])

# Comparison pairs used in the text (similar totals, different sources)
for (cc in c("ITA", "ESP", "ISR")) {
  row <- hi |> filter(iso3 == cc)
  record_number(paste0(tolower(cc), "_total_protein_g"), row$total_protein_g, "g/person/day", this_script, row$label)
  record_number(paste0(tolower(cc), "_animal_share_protein"), row$animal_share_protein, "% of protein", this_script, row$label)
}

# ---- 6. Significance tests (countries are separate observations, so p-values apply) ----
# Pearson = linear association; Spearman = rank-based, robust to outliers (e.g. Norway, UAE)
test_pair <- function(x, y, name) {
  p <- cor.test(hi[[x]], hi[[y]], method = "pearson")
  s <- suppressWarnings(cor.test(hi[[x]], hi[[y]], method = "spearman", exact = FALSE))
  tibble(test = name, n = sum(complete.cases(hi[[x]], hi[[y]])),
         pearson_r = unname(p$estimate), ci_low = p$conf.int[1], ci_high = p$conf.int[2],
         pearson_p = p$p.value, spearman_rho = unname(s$estimate), spearman_p = s$p.value)
}
tests <- bind_rows(
  test_pair("total_protein_g", "animal_share_protein", "Total protein vs animal share of protein"),
  test_pair("pulse_pct_food", "pulse_share_protein", "Pulses used as food vs pulse share of protein")
)
save_table(tests, "highincome_correlation_tests")
print(tests)

record_number("cor_totalprotein_animalshare_r", tests$pearson_r[1], "Pearson r", this_script)
record_number("cor_totalprotein_animalshare_p", tests$pearson_p[1], "p-value", this_script)
record_number("cor_pulsefood_pulseshare_r", tests$pearson_r[2], "Pearson r", this_script)
record_number("cor_pulsefood_pulseshare_p", tests$pearson_p[2], "p-value", this_script)
record_number("cor_pulsefood_pulseshare_spearman", tests$spearman_rho[2], "Spearman rho", this_script)

fmt_p <- function(p) ifelse(p < 0.001, "p < 0.001", paste0("p = ", signif(p, 2)))

# ============================ FIGURES ============================
spotlight <- c("USA", "ITA", "ESP", "ISR", "JPN", "IRL", "NLD", "SAU", "KOR", "FRA", "DEU", "GBR", "CAN", "NOR")

# ---- fig_09: similar protein totals, different sources ----
fig9 <- ggplot(hi, aes(total_protein_g, animal_share_protein)) +
  geom_smooth(method = "lm", formula = y ~ x, color = "grey60", fill = "grey88", linewidth = 0.7) +
  geom_point(aes(color = is_us), size = 2.6) +
  geom_text_repel(data = filter(hi, iso3 %in% spotlight),
                  aes(label = label, color = is_us), size = 3.4, seed = 1,
                  min.segment.length = 0, box.padding = 0.4) +
  scale_color_manual(values = c(`FALSE` = "grey35", `TRUE` = col_us), guide = "none") +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Countries with similar protein supplies get it from very different sources",
       subtitle = paste0("High-income countries (population 1M+), ", yrs, ". ",
                         "r = ", round(tests$pearson_r[1], 2), ", ", fmt_p(tests$pearson_p[1]),
                         ", n = ", n),
       x = "Total protein supply (grams per person per day)",
       y = "Share of protein from animal products",
       caption = wrap_caption(paste(
         "Sources: FAOSTAT Food Balances; World Bank income classification.",
         "Supply, not intake. Grey line: linear fit with 95% confidence band."))) +
  theme_dwv()
save_fig(fig9, "fig_09_protein_total_vs_animal_share", width = 9, height = 6)

# ---- fig_10: grams of plant vs animal protein, sorted by total ----
fig10 <- hi |>
  select(label, is_us, total_protein_g, `Plant protein` = plant_protein_g,
         `Animal protein` = animal_protein_g) |>
  pivot_longer(c(`Plant protein`, `Animal protein`), names_to = "source", values_to = "g") |>
  mutate(source = factor(source, levels = c("Animal protein", "Plant protein")),
         label = fct_reorder(label, total_protein_g)) |>
  ggplot(aes(g, label, fill = source)) +
  geom_col(width = 0.8) +
  scale_fill_manual(values = c(`Animal protein` = col_animal, `Plant protein` = col_plant)) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.03))) +
  labs(title = "Protein supply per person, by source",
       subtitle = paste0("High-income countries (population 1M+), ", yrs, ". United States in red."),
       x = "grams per person per day", y = NULL, fill = NULL,
       caption = wrap_caption("Source: FAOSTAT Food Balances. Supply, not intake.")) +
  theme_dwv() +
  theme(axis.text.y = element_text(
    color = ifelse(levels(fct_reorder(hi$label, hi$total_protein_g)) == "United States", col_us, "grey30"),
    face  = ifelse(levels(fct_reorder(hi$label, hi$total_protein_g)) == "United States", "bold", "plain")))
save_fig(fig10, "fig_10_protein_by_source", width = 7.5, height = 10)

# ---- fig_11: of pulses used for food or feed, share going to people ----
fig11 <- hi |>
  mutate(label = fct_reorder(label, pulse_pct_food)) |>
  ggplot(aes(pulse_pct_food, label, fill = is_us)) +
  geom_col(width = 0.8) +
  scale_fill_manual(values = c(`FALSE` = "grey65", `TRUE` = col_us), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.03))) +
  labs(title = "Some wealthy countries feed most of their pulses to animals",
       subtitle = paste0("Of pulses (beans, peas, lentils) used as food or feed, % used as food. ", yrs),
       x = NULL, y = NULL,
       caption = wrap_caption(paste(
         "Source: FAOSTAT Food Balances (new methodology). High-income countries, population 1M+.",
         "Feed is estimated by FAO's model; countries with no reported feed are counted as 0%."))) +
  theme_dwv()
save_fig(fig11, "fig_11_pulse_food_vs_feed", width = 7.5, height = 10)

# ---- fig_12: sending pulses to people vs eating them ----
fig12 <- ggplot(hi, aes(pulse_pct_food, pulse_share_protein)) +
  geom_point(aes(color = is_us), size = 2.6) +
  geom_text_repel(data = filter(hi, iso3 %in% c(spotlight, "ARE", "CRI")),
                  aes(label = label, color = is_us), size = 3.4, seed = 1,
                  min.segment.length = 0, box.padding = 0.4) +
  scale_color_manual(values = c(`FALSE` = "grey35", `TRUE` = col_us), guide = "none") +
  scale_x_continuous(labels = function(x) paste0(x, "%")) +
  scale_y_continuous(labels = function(x) paste0(x, "%")) +
  labs(title = "Sending pulses to people is not the same as people eating them",
       subtitle = paste0("Pearson r = ", round(tests$pearson_r[2], 2), " (", fmt_p(tests$pearson_p[2]), "); ",
                         "Spearman rho = ", round(tests$spearman_rho[2], 2),
                         " (", fmt_p(tests$spearman_p[2]), "). n = ", n),
       x = "Pulses used as food (% of food + feed use)",
       y = "Share of protein supply from pulses",
       caption = wrap_caption(paste(
         paste0("Source: FAOSTAT Food Balances, ", yrs, "."),
         "Norway's high pulse protein despite low food use is unexplained and not interpreted."))) +
  theme_dwv()
save_fig(fig12, "fig_12_pulse_food_vs_protein", width = 9, height = 6)

message("05_highincome.R done")
