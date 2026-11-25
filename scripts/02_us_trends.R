# scripts/02_us_trends.R
# ACT 1: What's on the American plate, and how has it changed? (1961-2024)
#
# Input : data/processed/fbs_slim.rds (from 01_build_fao.R)
# Output: figures fig_01 to fig_04, tables, key numbers
# Series: old FAO method through 2009, new from 2010 (justified by the overlap
#         check in 01: the U.S. animal share differs by <0.1 point between methods).

source("R/helpers.R")
this_script <- "02_us_trends.R"
kcal <- "Food supply (kcal/capita/day)"
method_note <- "Dashed line: FAO method change (2010)."

plant_groups <- c("Cereals - Excluding Beer", "Vegetable Oils", "Sugar & Sweeteners",
                  "Fruits - Excluding Wine", "Vegetables", "Pulses", "Starchy Roots",
                  "Treenuts", "Oilcrops", "Alcoholic Beverages", "Stimulants",
                  "Spices", "Sugar Crops")

# ---- One continuous U.S. series, one column per food group ----
us <- read_rds("data/processed/fbs_slim.rds") |>
  filter(area_code == 231, element == kcal,
         (series == "old" & year <= 2009) | (series == "new" & year >= 2010)) |>
  select(year, item, value) |>
  pivot_wider(names_from = item, values_from = value)

# A group with no U.S. rows at all (e.g. "Sugar Crops") gets no column;
# add it as 0 kcal so every group exists.
for (g in setdiff(plant_groups, names(us))) {
  message("No U.S. rows for '", g, "'; treating as 0 kcal")
  us[[g]] <- 0
}

us <- us |>
  mutate(across(-year, ~ replace_na(.x, 0)),      # a missing year = 0 kcal
         animal_share = `Animal Products` / `Grand Total` * 100) |>
  arrange(year)

save_table(us, "us_kcal_by_group_1961_2024")
first_yr <- min(us$year); last_yr <- max(us$year)
at <- function(var, yr) us[[var]][us$year == yr]

# ---- Check: plant groups add up to FAO's plant total ----
plant_gap <- max(abs(us$`Vegetal Products` - rowSums(us[plant_groups])))
stopifnot("Plant groups do not add up to the plant total" = plant_gap < 5)

# ---- Key numbers ----
record_number("us_total_kcal_first", at("Grand Total", first_yr), "kcal/person/day", this_script, first_yr)
record_number("us_total_kcal_last",  at("Grand Total", last_yr),  "kcal/person/day", this_script, last_yr)
record_number("us_total_kcal_pct_change",
              (at("Grand Total", last_yr) / at("Grand Total", first_yr) - 1) * 100,
              "%", this_script, paste(first_yr, "to", last_yr))
record_number("us_animal_share_first", at("animal_share", first_yr), "% of kcal", this_script, first_yr)
record_number("us_animal_share_last",  at("animal_share", last_yr),  "% of kcal", this_script,
              paste(last_yr, "(post-2017 rise partly an FAO artifact; see 03)"))

# ---- Change by group, first year to last year ----
group_labels <- c(
  "Animal Products" = "All animal products", "Vegetal Products" = "All plant foods",
  "Meat" = "Meat", "Milk - Excluding Butter" = "Milk & dairy", "Eggs" = "Eggs",
  "Aquatic Animals" = "Fish & seafood", "Animal fats" = "Animal fats (lard, butter, tallow)",
  "Cereals - Excluding Beer" = "Grains", "Vegetable Oils" = "Vegetable oils",
  "Sugar & Sweeteners" = "Sugar & sweeteners", "Fruits - Excluding Wine" = "Fruits",
  "Vegetables" = "Vegetables", "Pulses" = "Pulses (beans, peas, lentils)",
  "Starchy Roots" = "Potatoes & roots"
)

change <- us |>
  filter(year %in% c(first_yr, last_yr)) |>
  select(year, all_of(names(group_labels))) |>
  pivot_longer(-year, names_to = "item", values_to = "kcal") |>
  pivot_wider(names_from = year, values_from = kcal, names_prefix = "y") |>
  rename(start = 2, end = 3) |>
  mutate(label = group_labels[item],
         change = end - start,
         pct_change = change / start * 100)
save_table(change, "us_change_by_group")

ch <- function(it, col) change[[col]][change$item == it]
record_number("us_meat_pct_change", ch("Meat", "pct_change"), "%", this_script)
record_number("us_animal_fats_pct_change", ch("Animal fats", "pct_change"), "%", this_script)
record_number("us_plant_kcal_change", ch("Vegetal Products", "change"), "kcal/person/day", this_script)
record_number("us_oils_kcal_change", ch("Vegetable Oils", "change"), "kcal/person/day", this_script,
              "part of rise near 2000 may be a reporting artifact (ERS)")
record_number("us_oils_grains_sugar_share_of_plant_growth",
              (ch("Vegetable Oils", "change") + ch("Cereals - Excluding Beer", "change") +
                 ch("Sugar & Sweeteners", "change")) / ch("Vegetal Products", "change") * 100,
              "% of added plant kcal", this_script)
record_number("us_pulses_kcal_last", at("Pulses", last_yr), "kcal/person/day", this_script, last_yr)
record_number("us_pulses_share_of_kcal_last", at("Pulses", last_yr) / at("Grand Total", last_yr) * 100,
              "% of kcal", this_script, last_yr)

# ============================ FIGURES ============================

# ---- fig_01: total, plant, and animal calories (y-axis from zero) ----
fig1 <- us |>
  select(year, Total = `Grand Total`, `Plant foods` = `Vegetal Products`,
         `Animal products` = `Animal Products`) |>
  pivot_longer(-year, names_to = "source", values_to = "kcal") |>
  mutate(source = factor(source, levels = c("Total", "Plant foods", "Animal products"))) |>
  ggplot(aes(year, kcal, color = source)) +
  geom_vline(xintercept = 2010, linetype = "dashed", color = "grey50") +
  geom_line(linewidth = 1.1) +
  scale_color_manual(values = c("Total" = "grey25", "Plant foods" = col_plant,
                                "Animal products" = col_animal)) +
  scale_y_continuous(limits = c(0, NA), labels = scales::comma) +
  labs(title = "Americans have far more food available than in 1961, mostly from plants",
       subtitle = "U.S. food supply, calories per person per day",
       x = NULL, y = NULL, color = NULL,
       caption = wrap_caption(paste("Source: FAOSTAT Food Balances. Supply, not intake (includes waste).",
                       method_note))) +
  theme_dwv()
save_fig(fig1, "fig_01_us_kcal_by_source")

# ---- fig_02: animal share of calories (y-axis from zero, endpoints labeled) ----
ends <- us |> filter(year %in% c(first_yr, last_yr))
fig2 <- ggplot(us, aes(year, animal_share)) +
  geom_vline(xintercept = 2010, linetype = "dashed", color = "grey50") +
  geom_line(linewidth = 1.1, color = col_animal) +
  geom_point(data = ends, color = col_animal, size = 2.5) +
  geom_text(data = ends, aes(label = paste0(round(animal_share), "%")),
            vjust = -1, color = col_animal, fontface = "bold") +
  scale_y_continuous(limits = c(0, 40), labels = function(x) paste0(x, "%")) +
  labs(title = "The share of calories from animal products fell from 35% to under 30%",
       subtitle = "Share of U.S. food-supply calories from animal products",
       x = NULL, y = NULL,
       caption = wrap_caption(paste("Source: FAOSTAT Food Balances.", method_note,
                       "Rises after 2017 reflect FAO data jumps in meat and animal fats not confirmed elsewhere."))) +
  theme_dwv()
save_fig(fig2, "fig_02_us_animal_share")

# ---- fig_03: inside animal products ----
fig3 <- us |>
  select(year, Meat, `Milk & dairy` = `Milk - Excluding Butter`,
         `Animal fats (lard, butter, tallow)` = `Animal fats`,
         Eggs, `Fish & seafood` = `Aquatic Animals`) |>
  pivot_longer(-year, names_to = "type", values_to = "kcal") |>
  mutate(type = fct_reorder2(type, year, kcal)) |>
  ggplot(aes(year, kcal, color = type)) +
  geom_vline(xintercept = 2010, linetype = "dashed", color = "grey50") +
  geom_line(linewidth = 1.1) +
  scale_color_manual(values = c("Meat" = col_animal, "Milk & dairy" = "#4a90c2",
                                "Animal fats (lard, butter, tallow)" = "#c0392b",
                                "Eggs" = "#e0b040", "Fish & seafood" = "#5aa89a")) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "Meat rose while animal fats fell",
       subtitle = "U.S. animal-product calories per person per day, by type",
       x = NULL, y = NULL, color = NULL,
       caption = wrap_caption(paste("Source: FAOSTAT Food Balances.", method_note,
                       "Sudden jumps in meat (2018) and animal fats (after 2020) appear only in FAO's new series; the meat jump is not confirmed by USDA ERS."))) +
  theme_dwv() +
  theme(legend.position = "right")
save_fig(fig3, "fig_03_us_animal_by_type")

# ---- fig_04: change in plant calories by group, first year to last year ----
plant_change <- change |>
  filter(item %in% c("Cereals - Excluding Beer", "Vegetable Oils", "Sugar & Sweeteners",
                     "Fruits - Excluding Wine", "Vegetables", "Pulses", "Starchy Roots")) |>
  mutate(label = fct_reorder(label, change),
         highlight = item == "Pulses")

fig4 <- ggplot(plant_change, aes(change, label, fill = highlight)) +
  geom_col() +
  geom_text(aes(label = paste0(ifelse(change >= 0, "+", ""), round(change)),
                color = highlight, fontface = ifelse(highlight, "bold", "plain")),
            hjust = -0.2, size = 3.8, show.legend = FALSE) +
  scale_color_manual(values = c(`FALSE` = "grey20", `TRUE` = col_us), guide = "none") +
  scale_fill_manual(values = c(`FALSE` = col_plant, `TRUE` = col_us), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Oils, grains, and sugar drove the rise in plant calories; pulses stayed flat",
       subtitle = paste0("Change in U.S. calories per person per day, ", first_yr, " to ", last_yr),
       x = "kcal per person per day", y = NULL,
       caption = wrap_caption(paste("Source: FAOSTAT Food Balances (old method to 2009, new from 2010).",
                       "Part of the oil increase near 2000 may reflect a reporting change."))) +
  theme_dwv()
save_fig(fig4, "fig_04_us_plant_change", height = 4.5)

# ---- fig_04b: plant groups over time (small multiples, shared scale) ----
fig4b <- us |>
  select(year, all_of(c("Cereals - Excluding Beer", "Vegetable Oils", "Sugar & Sweeteners",
                        "Fruits - Excluding Wine", "Vegetables", "Pulses", "Starchy Roots"))) |>
  pivot_longer(-year, names_to = "item", values_to = "kcal") |>
  mutate(label = fct_reorder(group_labels[item], kcal, .fun = last, .desc = TRUE)) |>
  ggplot(aes(year, kcal)) +
  geom_vline(xintercept = 2010, linetype = "dashed", color = "grey70") +
  geom_area(fill = col_plant, alpha = 0.25) +
  geom_line(color = col_plant, linewidth = 0.9) +
  facet_wrap(~ label, nrow = 2) +
  labs(title = "U.S. plant calories by group, 1961-2024",
       subtitle = "Calories per person per day (same scale in every panel)",
       x = NULL, y = NULL,
       caption = wrap_caption(paste("Source: FAOSTAT Food Balances.", method_note))) +
  theme_dwv()
save_fig(fig4b, "fig_04b_us_plant_groups_over_time", width = 10, height = 5.5)

message("02_us_trends.R done")
