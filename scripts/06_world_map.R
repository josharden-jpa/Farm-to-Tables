# scripts/06_world_map.R
# ACT 3 (context): where the U.S. sits in the world, and why the comparison
# is limited to high-income countries.
#
# Inputs : data/processed/fbs_snapshot.rds (from 01; new FAO series, 2021-2023)
#          data/raw/CLASS_2026_10_08.xlsx (World Bank income groups)
#          data/raw/API_NY.GDP.PCAP.PP.CD_DS2_en_csv_v2_78481.csv (GDP per capita, PPP)
# Outputs: fig_13 (world map, animal share of protein), fig_14 (animal share vs income),
#          tables, key numbers
# First time only: install.packages(c("sf", "rnaturalearth", "rnaturalearthdata"))

source("R/helpers.R")
library(sf)
library(rnaturalearth)
library(countrycode)
library(readxl)
this_script <- "06_world_map.R"
yrs <- "2021-2023 average"
protein <- "Protein supply quantity (g/capita/day)"

# ---- 1. Animal share of protein, every country with data ----
world_share <- read_rds("data/processed/fbs_snapshot.rds") |>
  filter(element == protein, item %in% c("Grand Total", "Animal Products")) |>
  group_by(area_code_m49, area, item) |>
  summarise(value = mean(value, na.rm = TRUE), .groups = "drop") |>
  pivot_wider(names_from = item, values_from = value) |>
  mutate(animal_share = `Animal Products` / `Grand Total` * 100,
         m49 = as.numeric(str_remove(area_code_m49, "'")),
         iso3 = suppressWarnings(countrycode(m49, origin = "un", destination = "iso3c")),
         iso3 = if_else(m49 == 158, "TWN", iso3))   # Taiwan: map it, even though WB omits it

# ---- 2. Income group and GDP per capita (PPP), averaged over the same years ----
wb <- read_excel("data/raw/CLASS_2026_10_08.xlsx", sheet = "List of economies") |>
  janitor::clean_names() |>
  select(iso3 = code, income_group)

gdp <- read_csv("data/raw/API_NY.GDP.PCAP.PP.CD_DS2_en_csv_v2_78481.csv",
                skip = 4, show_col_types = FALSE) |>
  janitor::clean_names() |>
  select(iso3 = country_code, x2021, x2022, x2023) |>
  pivot_longer(-iso3, values_to = "gdp") |>
  group_by(iso3) |>
  summarise(gdp_pc_ppp = mean(gdp, na.rm = TRUE), .groups = "drop") |>
  mutate(gdp_pc_ppp = if_else(is.nan(gdp_pc_ppp), NA_real_, gdp_pc_ppp))

world_share <- world_share |>
  left_join(wb, by = "iso3") |>
  left_join(gdp, by = "iso3") |>
  mutate(income_group = factor(income_group,
           levels = c("Low income", "Lower middle income", "Upper middle income", "High income")),
         rank_all = min_rank(desc(animal_share)))
save_table(world_share |> select(area, iso3, income_group, gdp_pc_ppp,
                                 total_protein_g = `Grand Total`,
                                 animal_protein_g = `Animal Products`, animal_share, rank_all) |>
             arrange(desc(animal_share)),
           "world_animal_share_protein_2021_2023")

# ---- 3. Join to map shapes ----
# Natural Earth marks a few countries (e.g. France, Norway) with iso_a3 = "-99";
# its adm0_a3 code fills those gaps.
world_map <- ne_countries(scale = "medium", returnclass = "sf") |>
  filter(admin != "Antarctica") |>
  mutate(iso3 = if_else(iso_a3 == "-99", adm0_a3, iso_a3)) |>
  select(iso3, admin, geometry) |>
  left_join(world_share |> select(iso3, animal_share), by = "iso3")

not_mapped <- world_share |> filter(!iso3 %in% world_map$iso3 | is.na(iso3))
message("FAO countries not found on the map: ",
        ifelse(nrow(not_mapped) == 0, "none", paste(not_mapped$area, collapse = ", ")))
save_table(not_mapped |> select(area, iso3), "map_unmatched_countries")

# ---- 4. Key numbers ----
us <- world_share |> filter(iso3 == "USA")
n_all <- sum(!is.na(world_share$animal_share))
record_number("world_n_countries_mapped", sum(!is.na(world_map$animal_share)), "countries", this_script)
record_number("world_median_animal_share", median(world_share$animal_share, na.rm = TRUE),
              "% of protein", this_script, yrs)
record_number("us_rank_animal_share_all_countries", us$rank_all, paste("rank of", n_all),
              this_script, "1 = highest; all countries with FAO data")

by_income <- world_share |>
  filter(!is.na(income_group)) |>
  group_by(income_group) |>
  summarise(n = n(), median_animal_share = median(animal_share, na.rm = TRUE), .groups = "drop")
save_table(by_income, "animal_share_by_income_group")
for (i in seq_len(nrow(by_income))) {
  record_number(paste0("median_animal_share_", janitor::make_clean_names(by_income$income_group[i])),
                by_income$median_animal_share[i], "% of protein", this_script,
                paste0("n = ", by_income$n[i]))
}

# Income vs animal share (log GDP, since income effects are proportional)
inc <- world_share |> filter(!is.na(gdp_pc_ppp), !is.na(animal_share))
ct <- cor.test(log10(inc$gdp_pc_ppp), inc$animal_share)
record_number("cor_loggdp_animalshare_r", unname(ct$estimate), "Pearson r", this_script,
              paste0("n = ", nrow(inc), ", log10 GDP per capita PPP"))
record_number("cor_loggdp_animalshare_p", ct$p.value, "p-value", this_script)
fmt_p <- function(p) ifelse(p < 0.001, "p < 0.001", paste0("p = ", signif(p, 2)))

# ============================ FIGURES ============================

# ---- fig_13: world map ----
fig13 <- ggplot(world_map) +
  geom_sf(aes(fill = animal_share), color = "white", linewidth = 0.1) +
  geom_sf(data = filter(world_map, iso3 == "USA"), fill = NA, color = col_us, linewidth = 0.4) +
  scale_fill_distiller(palette = "YlOrBr", direction = 1, na.value = "grey85",
                       limits = c(0, 75), breaks = seq(0, 75, 15),
                       labels = function(x) paste0(x, "%"),
                       name = "Share of protein\nfrom animal products") +
  coord_sf(crs = "+proj=eqearth", datum = NA) +
  labs(title = "Where protein comes from: animal products' share of the food supply",
       subtitle = paste0(yrs, ". United States outlined in red. Grey = no FAO data."),
       caption = wrap_caption(paste(
         "Source: FAOSTAT Food Balances (new methodology); map: Natural Earth.",
         "Supply, not intake. Low shares in poorer countries often reflect income, not choice;",
         "see the income comparison."))) +
  theme_dwv() +
  theme(legend.position = "right", panel.grid = element_blank(), axis.text = element_blank(),
        plot.margin = margin(5, 5, 5, 5))
save_fig(fig13, "fig_13_world_map_animal_share", width = 11, height = 5.2)

# ---- fig_14: animal share rises with income, which is why we compare rich countries ----
fig14 <- ggplot(inc, aes(gdp_pc_ppp, animal_share)) +
  geom_point(aes(color = income_group), size = 2, alpha = 0.85) +
  geom_point(data = filter(inc, iso3 == "USA"), color = col_us, size = 3.5) +
  annotate("text", x = us$gdp_pc_ppp, y = us$animal_share + 4, label = "United States",
           color = col_us, fontface = "bold", size = 3.6) +
  scale_x_log10(labels = scales::label_dollar(scale_cut = scales::cut_short_scale())) +
  scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, NA)) +
  scale_color_manual(values = c("Low income" = "#c6dbef", "Lower middle income" = "#6baed6",
                                "Upper middle income" = "#2171b5", "High income" = "#08306b"),
                     name = NULL, na.translate = FALSE) +
  labs(title = "Richer countries get more of their protein from animals",
       subtitle = paste0("Each dot is a country, ", yrs, ". r = ", round(unname(ct$estimate), 2),
                         " with log income, ", fmt_p(ct$p.value), ", n = ", nrow(inc)),
       x = "GDP per person (purchasing power parity, log scale)",
       y = "Share of protein from animal products",
       caption = wrap_caption(paste(
         "Sources: FAOSTAT Food Balances; World Bank GDP per capita (PPP) and income groups.",
         "Because income shapes diets this strongly, the main comparison uses high-income countries only."))) +
  theme_dwv()
save_fig(fig14, "fig_14_animal_share_vs_income", width = 9, height = 6)

message("06_world_map.R done")
