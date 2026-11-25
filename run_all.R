# run_all.R
# Master script: reproduces every figure, table, and key number from raw data.
# 1. Download the raw files listed in data/README.md into data/raw/
# 2. Open the .Rproj, then run this file top to bottom.
# Outputs: output/figures/*.png, output/tables/*.csv, output/key_numbers.csv

# Start fresh: key numbers are rebuilt on every run
if (file.exists("output/key_numbers.csv")) file.remove("output/key_numbers.csv")

scripts <- c(
  "scripts/01_build_fao.R",        # read + slim both FAO series, overlap check
  "scripts/02_us_trends.R",        # Act 1: U.S. calories, animal and plant breakdowns
  "scripts/03_meat_ers.R",         # Act 1: century of meat + FAO/ERS cross-check
  "scripts/04_corn_ers.R",         # Act 2: where U.S. corn goes
  "scripts/05_highincome.R",       # Act 3: wealthy-country comparison + significance tests
  "scripts/06_world_map.R"         # Act 3: world map, animal share of protein
)

for (s in scripts) {
  if (!file.exists(s)) { message("Not built yet, skipping: ", s); next }
  message("\n==== Running ", s, " ====")
  t <- system.time(source(s, local = new.env()))
  message("Done in ", round(t["elapsed"], 1), " s")
}

message("\nAll done. Key numbers:")
if (file.exists("output/key_numbers.csv")) print(readr::read_csv("output/key_numbers.csv",
                                                                  show_col_types = FALSE), n = Inf)
