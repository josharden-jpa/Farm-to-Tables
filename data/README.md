# Data sources

Raw files are not stored in this repository (several exceed GitHub's 100 MB limit).
Download each file below into `data/raw/`, keeping the file names shown.

| File(s) | Source | How to get it |
|---|---|---|
| `FoodBalanceSheets_E_All_Data_(Normalized).csv` and lookup files (`_AreaCodes`, `_ItemCodes`, `_Elements`, `_Flags`) | FAOSTAT, Food Balances (2010-) | FAOSTAT > Food Balances (2010-) > Bulk Downloads > "All Data Normalized"; unzip |
| `FoodBalanceSheetsHistoric_E_All_Data_(Normalized).csv` and lookup files | FAOSTAT, Food Balances (-2013, old methodology) | Same steps, historic series |
| `mtpcc.csv` | USDA ERS, Food Availability (Per Capita) Data System | "Red meat, poultry, and fish" table, CSV |
| `feed-grains-yearbook-all-years.csv` | USDA ERS, Feed Grains Database | "Feed Grains Yearbook Tables - All years", CSV |
| `CLASS_2026_10_08.xlsx` | World Bank, Country and Lending Groups | Current classification file |

Supporting documents (cited, not used by code): FAO "Key differences between new and old FBS methodology" (June 2022); FAO FBS and SUA resource handbook; USDA ERS Food Availability Documentation.

Download dates: FAOSTAT files downloaded November 24, 2026 (FAO last update November 23, 2026). Add dates for the other files.
