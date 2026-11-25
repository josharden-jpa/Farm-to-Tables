# 00_setup.R
# Run once after creating the RStudio Project (File > New Project).
# Creates the folder structure and checks for packages.

# ---- Folders ----
# data/raw       : original downloads, never edited by hand
# data/processed : cleaned files our scripts write
# scripts        : numbered R scripts, run in order
# figures        : saved graphics
# report         : the write-up (e.g., Quarto or R Markdown)
dirs <- c("data/raw", "data/processed", "scripts", "figures", "report")
for (d in dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- Packages ----
pkgs <- c("tidyverse", "janitor", "readxl", "rnassqs", "sf", "tigris", "scales")
missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing) > 0) install.packages(missing)

# ---- API key ----
# Do NOT paste your NASS key into any script.
# Run usethis::edit_r_environ(), add this line, save, and restart R:
#   NASSQS_TOKEN=your_key_here
# Then check that R can see it (this prints TRUE/FALSE, not the key):
nchar(Sys.getenv("NASSQS_TOKEN")) > 0