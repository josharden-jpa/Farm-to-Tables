# scripts/04_corn_ers.R
# ACT 2: What do we grow it for? Where U.S. corn goes, 1980-2024.
#
# Input : data/raw/feed-grains-yearbook-all-years.csv (USDA ERS Feed Grains Yearbook)
# Output: fig_07 (shares over time), fig_08 (recent snapshot), tables, key numbers
# Why ERS, not FAO: ERS names fuel ethanol directly, is the official U.S. source,
#   and has no method break. An FAO version (archive/10_us_corn_uses.R) agreed
#   closely on feed and exports (see RESEARCH_LOG.md, section 6).
# Notes: marketing years (Sep-Aug); 2025+ rows are projections, so dropped.
#   Distillers grains (an ethanol byproduct fed to animals) are not separated in
#   these tables, so part of "fuel ethanol" corn returns as animal feed.

source("R/helpers.R")
library(janitor)
this_script <- "04_corn_ers.R"
recent <- 2021:2023

ers <- read_csv("data/raw/feed-grains-yearbook-all-years.csv", show_col_types = FALSE) |>
  clean_names()

corn <- ers |>
  filter(commodity == "Corn", frequency == "Annual",
         str_starts(table_name, "Table 4--") | str_starts(table_name, "Table 31--"),
         year >= 1980, year <= 2024) |>
  select(year, attribute, amount) |>
  distinct()

wide <- corn |> pivot_wider(names_from = attribute, values_from = amount)

uses <- wide |>
  transmute(
    year,
    `Animal feed`                  = `Feed and residual use`,
    `Fuel ethanol`                 = `Alcohol for fuel use`,
    `Exported`                     = Exports,
    `Sweeteners, cereals & drinks` = `High-fructose corn syrup (HFCS) use` +
                                     `Glucose and dextrose use` +
                                     `Cereals and other products use` +
                                     `Alcohol for beverages and manufacturing use`,
    `Starch (food & industrial)`   = `Starch use`,
    `Seed`                         = `Seed use`,
    total_use                      = `Total use`
  )

# ---- Check: parts add up to ERS's own total use ----
# Relative tolerance: ERS rounds each published component separately, so small
# gaps occur (largest: 1 million bushels in 1982, ~0.01%). A missing category
# would produce a gap of several percent and stop the script.
rel_gap <- abs(uses$total_use - rowSums(select(uses, -year, -total_use))) / uses$total_use
stopifnot("Corn uses do not add up to total use" = max(rel_gap) < 0.001)

long <- uses |>
  select(-total_use) |>
  pivot_longer(-year, names_to = "use", values_to = "mbu") |>
  group_by(year) |>
  mutate(share = mbu / sum(mbu) * 100) |>
  ungroup()
save_table(long, "corn_uses_ers_1980_2024")

snapshot <- long |>
  filter(year %in% recent) |>
  group_by(use) |>
  summarise(share = mean(share), .groups = "drop") |>
  arrange(desc(share))
save_table(snapshot, "corn_uses_ers_2021_2023")

# ---- Key numbers ----
sh <- function(u) snapshot$share[snapshot$use == u]
shy <- function(u, y) long$share[long$use == u & long$year == y]
yr_note <- "2021-2023 marketing-year average"

record_number("corn_feed_share", sh("Animal feed"), "% of corn use", this_script, yr_note)
record_number("corn_ethanol_share", sh("Fuel ethanol"), "% of corn use", this_script, yr_note)
record_number("corn_export_share", sh("Exported"), "% of corn use", this_script, yr_note)
record_number("corn_feed_ethanol_export_share",
              sh("Animal feed") + sh("Fuel ethanol") + sh("Exported"),
              "% of corn use", this_script, yr_note)
record_number("corn_sweeteners_cereals_drinks_share", sh("Sweeteners, cereals & drinks"),
              "% of corn use", this_script, yr_note)
record_number("corn_ethanol_share_1980", shy("Fuel ethanol", 1980), "% of corn use", this_script)
record_number("corn_ethanol_share_2010", shy("Fuel ethanol", 2010), "% of corn use", this_script)
record_number("corn_feed_share_1980", shy("Animal feed", 1980), "% of corn use", this_script)
record_number("corn_total_use_pct_change",
              (uses$total_use[uses$year == 2024] / uses$total_use[uses$year == 1980] - 1) * 100,
              "%", this_script, "1980 to 2024, total corn use")
record_number("corn_feed_volume_pct_change",
              (uses$`Animal feed`[uses$year == 2024] / uses$`Animal feed`[uses$year == 1980] - 1) * 100,
              "%", this_script, "1980 to 2024, feed and residual use")

# ============================ FIGURES ============================

use_levels <- c("Seed", "Starch (food & industrial)", "Sweeteners, cereals & drinks",
                "Exported", "Fuel ethanol", "Animal feed")
use_colors <- c("Animal feed" = col_animal, "Fuel ethanol" = col_fuel,
                "Exported" = col_export, "Sweeteners, cereals & drinks" = col_plant,
                "Starch (food & industrial)" = "#9ccc65", "Seed" = "grey85")
corn_caption <- paste(
  "Source: USDA ERS Feed Grains Yearbook, Tables 4 and 31. Marketing years (Sep-Aug).",
  "Ethanol production yields distillers grains that are fed to animals, so part of",
  "ethanol corn returns as feed.")

# ---- fig_07: shares over time (100% stacked area) ----
fig7 <- long |>
  mutate(use = factor(use, levels = use_levels)) |>
  ggplot(aes(year, share, fill = use)) +
  geom_area() +
  annotate("text", x = 2016, y = 55, label = "Fuel ethanol", color = "white",
           fontface = "bold", size = 4.5) +
  annotate("text", x = 1992, y = 28, label = "Animal feed", color = "white",
           fontface = "bold", size = 4.5) +
  annotate("text", x = 1992, y = 76, label = "Exported", color = "white",
           fontface = "bold", size = 4.5) +
  scale_fill_manual(values = use_colors, breaks = rev(use_levels)) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
  labs(title = "Fuel ethanol wedged its way into America's largest crop",
       subtitle = "Share of total U.S. corn use, 1980-2024",
       x = NULL, y = NULL, fill = NULL,
       caption = wrap_caption(corn_caption)) +
  theme_dwv() +
  theme(legend.position = "right")
save_fig(fig7, "fig_07_corn_uses_over_time", width = 9, height = 5.5)

# ---- fig_08: recent snapshot ----
fig8 <- snapshot |>
  mutate(use = factor(use, levels = use_levels)) |>
  ggplot(aes(share, use, fill = use)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = ifelse(share < 1, "<1%", paste0(round(share), "%"))),
            hjust = -0.15, size = 4) +
  scale_fill_manual(values = use_colors) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12)),
                     labels = function(x) paste0(x, "%")) +
  labs(title = paste0("About ", round(sh("Animal feed") + sh("Fuel ethanol") + sh("Exported")),
                      "% of U.S. corn goes to animal feed, fuel, or export"),
       subtitle = "Share of total U.S. corn use, average of 2021-2023 marketing years",
       x = NULL, y = NULL,
       caption = wrap_caption(corn_caption)) +
  theme_dwv()
save_fig(fig8, "fig_08_corn_uses_snapshot", height = 4.5)

message("04_corn_ers.R done")
