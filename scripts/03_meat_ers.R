# scripts/03_meat_ers.R
# ACT 1 (continued): a century of U.S. meat, and an independent check on FAO.
#
# Inputs : data/raw/mtpcc.csv (USDA ERS Food Availability, red meat/poultry/fish)
#          data/processed/fbs_slim.rds (from 01_build_fao.R)
# Outputs: fig_05 (meat by type, 1909-2021), fig_06 (FAO vs ERS cross-check),
#          tables, key numbers
# Notes  : ERS boneless, trimmed weight = closest to food actually available and
#          comparable across meat types; carcass weight includes bone and pet food.
#          ERS fish data stop in 2019 (series under revision by ERS).

source("R/helpers.R")
library(janitor)
this_script <- "03_meat_ers.R"

ers <- read_csv("data/raw/mtpcc.csv", show_col_types = FALSE) |>
  clean_names() |>
  mutate(attribute = str_squish(attribute))   # fixes a line break inside one label

boneless <- ers |>
  filter(commodity == "Red meat, poultry, and fish (boneless weight): Per capita availability")
stopifnot("ERS boneless table not found" = nrow(boneless) > 0)

# ---- Meat by type (lbs per person per year, boneless) ----
by_type <- boneless |>
  filter(attribute %in% c("Red meat-Beef-Pounds", "Red meat-Pork-Pounds",
                          "Poultry-Chicken-Pounds", "Poultry-Turkey-Pounds",
                          "Fish and shellfish-Pounds")) |>
  mutate(type = recode(attribute,
                       "Red meat-Beef-Pounds" = "Beef",
                       "Red meat-Pork-Pounds" = "Pork",
                       "Poultry-Chicken-Pounds" = "Chicken",
                       "Poultry-Turkey-Pounds" = "Turkey",
                       "Fish and shellfish-Pounds" = "Fish & shellfish")) |>
  select(year, type, lbs = value)
save_table(by_type |> pivot_wider(names_from = type, values_from = lbs),
           "ers_meat_by_type_1909_2021")

wide <- by_type |> pivot_wider(names_from = type, values_from = lbs)

beef_peak <- wide |> slice_max(Beef, n = 1)
# Year chicken passed beef for good: the year after the last year beef was ahead
chicken_passes <- max(wide$year[wide$Beef >= wide$Chicken]) + 1

record_number("ers_beef_peak_lbs", beef_peak$Beef, "lbs/person/yr (boneless)", this_script,
              paste("peak year", beef_peak$year))
record_number("ers_beef_last_lbs", wide$Beef[wide$year == max(wide$year)],
              "lbs/person/yr (boneless)", this_script, max(wide$year))
record_number("ers_chicken_first_lbs", wide$Chicken[wide$year == min(wide$year)],
              "lbs/person/yr (boneless)", this_script, min(wide$year))
record_number("ers_chicken_last_lbs", wide$Chicken[wide$year == max(wide$year)],
              "lbs/person/yr (boneless)", this_script, max(wide$year))
record_number("ers_year_chicken_passes_beef", chicken_passes, "year", this_script,
              "first year after which chicken stays above beef")

# ---- Cross-check: ERS red meat + poultry vs FAO "Meat" (FAO Meat excludes fish) ----
ers_meat <- boneless |>
  filter(attribute %in% c("Red meat-Total-Pounds", "Poultry-Total-Pounds")) |>
  group_by(year) |>
  summarise(lbs = sum(value), n_parts = n(), .groups = "drop")
stopifnot("ERS meat total missing a part" = all(ers_meat$n_parts == 2))

fao_meat <- read_rds("data/processed/fbs_slim.rds") |>
  filter(area_code == 231, item == "Meat", element == "Food supply (kcal/capita/day)",
         (series == "old" & year <= 2009) | (series == "new" & year >= 2010)) |>
  select(year, kcal = value)

# Different units (lbs vs kcal), so compare TRENDS: both indexed to 1961 = 100
compare <- inner_join(ers_meat, fao_meat, by = "year") |>
  arrange(year) |>
  mutate(ers_index = lbs  / lbs[year == 1961]  * 100,
         fao_index = kcal / kcal[year == 1961] * 100,
         ers_pct_chg = (lbs / lag(lbs) - 1) * 100,
         fao_pct_chg = (kcal / lag(kcal) - 1) * 100)
save_table(compare, "meat_crosscheck_fao_ers")

r <- cor(compare$lbs, compare$kcal)
record_number("meat_fao_ers_correlation", r, "r", this_script,
              paste(min(compare$year), "to", max(compare$year),
                    "(descriptive; no p-value because years are not independent)"))
record_number("fao_meat_change_2018", compare$fao_pct_chg[compare$year == 2018],
              "% vs 2017", this_script, "likely FAO data artifact")
record_number("ers_meat_change_2018", compare$ers_pct_chg[compare$year == 2018],
              "% vs 2017", this_script)
record_number("ers_meat_index_last", compare$ers_index[compare$year == max(compare$year)],
              "index (1961 = 100)", this_script, max(compare$year))

# ============================ FIGURES ============================

type_colors <- c("Beef" = "#8c2d04", "Chicken" = "#e0a030", "Pork" = "#d46a8c",
                 "Turkey" = "#9c7bb5", "Fish & shellfish" = "#5aa89a")

# ---- fig_05: a century of meat by type, lines labeled directly ----
last_points <- by_type |>
  filter(!is.na(lbs)) |>
  group_by(type) |>
  slice_max(year, n = 1)

fig5 <- ggplot(by_type |> filter(!is.na(lbs)), aes(year, lbs, color = type)) +
  geom_line(linewidth = 1.1) +
  geom_text(data = last_points, aes(label = type), hjust = -0.1,
            fontface = "bold", size = 3.8, show.legend = FALSE) +
  annotate("text", x = beef_peak$year, y = beef_peak$Beef + 5,
           label = paste0("Beef peaks, ", beef_peak$year), size = 3.5, color = "grey30") +
  scale_color_manual(values = type_colors, guide = "none") +
  scale_x_continuous(breaks = seq(1910, 2020, 20),
                     expand = expansion(mult = c(0.02, 0.15))) +
  scale_y_continuous(limits = c(0, NA)) +
  labs(title = "Over a century, Americans shifted from beef to chicken",
       subtitle = "Meat available per person, pounds per year (boneless, trimmed weight), 1909-2021",
       x = NULL, y = NULL,
       caption = wrap_caption(paste(
         "Source: USDA ERS Food Availability Data System.",
         "Supply, not intake. Fish data end in 2019 (series under revision)."))) +
  theme_dwv()
save_fig(fig5, "fig_05_us_meat_by_type_century", width = 9)

# ---- fig_06: two independent sources, one long-run trend ----
fig6 <- compare |>
  select(year, `USDA ERS (pounds, boneless)` = ers_index, `FAO (calories)` = fao_index) |>
  pivot_longer(-year, names_to = "source", values_to = "index") |>
  ggplot(aes(year, index, color = source)) +
  geom_hline(yintercept = 100, color = "grey70") +
  geom_vline(xintercept = 2010, linetype = "dashed", color = "grey50") +
  geom_line(linewidth = 1.1) +
  annotate("text", x = 2017.5, y = max(compare$fao_index) - 2,
           label = "FAO-only\njump (2018)", size = 3.5, color = "grey30",
           hjust = 1, lineheight = 0.9) +
  scale_color_manual(values = c("USDA ERS (pounds, boneless)" = "grey30",
                                "FAO (calories)" = col_animal)) +
  labs(title = "Two independent sources agree on the long-run rise in meat",
       subtitle = paste0("U.S. red meat + poultry available per person, indexed to 1961 = 100. ",
                         "Correlation r = ", round(r, 2)),
       x = NULL, y = NULL, color = NULL,
       caption = wrap_caption(paste(
         "Sources: FAOSTAT Food Balances; USDA ERS Food Availability Data System.",
         "Units differ, so both are indexed. Dashed line: FAO method change (2010).",
         paste0("FAO's 2018 jump (+", round(compare$fao_pct_chg[compare$year == 2018], 1),
                "%) is not seen in ERS (+", round(compare$ers_pct_chg[compare$year == 2018], 1),
                "%), so it is treated as a data artifact.")))) +
  theme_dwv()
save_fig(fig6, "fig_06_meat_crosscheck")

message("03_meat_ers.R done")
