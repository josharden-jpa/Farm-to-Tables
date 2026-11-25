# Research log: DWV final project

A record of every data decision, check, and change of direction, in order, including how work was divided between Josh and Claude (AI). Items marked **[VERIFY]** still need Josh's confirmation against a source.

## How we worked (centaur model)

Josh set the research direction, chose and downloaded all data, ran all code on his own machine, judged every result, and made the final call on every decision. Claude proposed research questions and methods, wrote the R scripts, interpreted outputs, and flagged problems. Where a decision was Claude's suggestion that Josh adopted, it is marked "(suggested by Claude)". Claude's factual claims not drawn from our data are marked [VERIFY] until checked.

## 1. Choosing the question

- Started from Josh's interest in institutional food (schools, hospitals, prisons) and plant-based defaults.
- First candidate: does local crop production predict local school purchasing (Farm to School Census joined to NASS county data)? Josh dropped it: it would not leave a general audience understanding what is grown and eaten.
- Josh rejected advocacy framing in favor of letting data speak to skeptical readers (suggested by Claude).
- Final question: how the U.S. food supply changed since 1961, where its largest crop goes, and how the U.S. compares with wealthy peers on animal versus plant protein, especially pulses.
- Josh excluded protein-requirement claims from the paper and presentation.
- Influence: email from AC Baker (The Vegan Society) pointing to pulses as food, not feed.

## 2. Data sources and why

- **FAOSTAT Food Balances** (backbone): consistent across ~180 countries and 1961-2024; gives calories and protein by food group and food/feed/other uses.
- **USDA ERS Food Availability, meat table**: independent check on FAO's U.S. meat trend; extends history to 1909. ERS cannot compute total calories after 2010 (fats and oils data discontinued), another reason FAO is the backbone.
- **USDA ERS Feed Grains Yearbook**: names fuel ethanol directly; used for the corn figure instead of FAO (see section 6).
- **World Bank income classification**: defines the high-income comparison group.

## 3. Measurement choices

- **Calories per person per day** as the main U.S. measure; FAO states food calories are comparable across its two methodologies.
- **Protein** for cross-country comparison: it is what animal foods supply and what a plant-based transition must replace.
- **Weight (kg/person/year)** for fruits and vegetables, since calories understate water-heavy produce.
- **Shares and totals shown together**: shares alone can mislead (Josh's point).
- All values are food **supply**, not intake (includes retail and household waste). Always written as "supply" or "available."

## 4. FAO wrangling decisions

- Used FAO's own group items (Grand Total, Animal Products, Meat, Pulses, etc.) and never added a group to its parts, to avoid double counting.
- Removed regional aggregates: all FAO area codes >= 5000 (confirmed against the AreaCodes file).
- Dropped "China" (code 351), which double counts mainland China, Hong Kong, Macao, and Taiwan.
- **Bug found and fixed:** "Eggs" and "Milk - Excluding Butter" each appear twice (group and item, same name, different codes). Kept the group code (29xx). Detected via doubled row counts and a many-to-many join warning.
- **Joining the two FAO series:** old methodology through 2009, new from 2010. Justified by the 2010-2013 overlap check: U.S. totals run about 2% higher in the new series, but the U.S. animal share is identical in both (27.4% in 2010, 26.7% in 2013). Median country gap in total calories: 0.36%; 76% of countries within 5%. Large gaps (Sudan, Serbia) reflect border and population revisions.
- Cross-country snapshot uses the new series only (2021-2023 average) because feed estimation changed between methods.
- Historic file contains dissolved states (USSR, Yugoslavia, Czechoslovakia); not used in cross-country comparisons.

## 5. Checks performed

- Plant food groups sum to FAO's plant total (gap at most 2 kcal).
- "Other animal" (animal products minus meat, milk, eggs, fish) is almost entirely animal fats (199 of 205 kcal in 1961; 140 of 141 in 2024). Relabeled accordingly.
- **FAO vs ERS meat:** correlation 0.91 over 1961-2021. FAO shows a +9.5% jump in 2018 (442 to 484 kcal); ERS shows +1.1%. Treated as a likely FAO data artifact; not interpreted. This also affects the apparent rise in FAO's animal share after 2017.
- ERS warns of a reporting-driven spike in vegetable oils around 2000; the FAO oil series shows a step then. Part of the 180% oil increase may be an artifact. [VERIFY wording]

## 6. Corn

- FAO "Maize and products" categories were ambiguous ("Processing", "Other uses (non-food)").
- Cross-checked against ERS Feed Grains Yearbook (2021-2023 marketing years): feed and residual 39%, fuel ethanol 37%, exports 15%, sweeteners/cereals/beverage alcohol about 8%, starch about 2%. FAO's "non-food uses" (30%) is mostly ethanol; FAO's "processed" matches sweeteners and starch.
- **Decision:** final corn figure uses ERS (names ethanol, official U.S. source, no method break). FAO version kept as a robustness check.
- Ethanol share: 0.5% (1980) to 38.5% (2010), mid-30s since.
- Distillers grains (ethanol byproduct fed to animals) are not separated in these tables; part of ethanol corn returns as feed. [VERIFY: source needed before any number is stated]
- ERS uses Sep-Aug marketing years; 2025-2026 rows are projections and were dropped.

## 7. High-income comparison

- Group: World Bank "High income," population at least 1 million, 2021-2023 average (48 countries). Small states excluded because trade dominates their food balances.
- M49 to ISO3 codes via the countrycode package; only Taiwan failed to match (not in World Bank list).
- Assumption: a missing FAO pulse feed row means zero feed. [VERIFY for a few countries]
- **Fix:** pulse food share redefined as food / (food + feed). The first version used domestic supply as the denominator and produced impossible values (Denmark 173% feed) because supply includes stock changes.
- Norway shows the highest pulse protein share but only ~23% of pulses to food; unexplained, so not featured. [VERIFY]
- Correlations (descriptive, n = 48): pulse food share vs pulse protein share r = 0.38; total protein vs animal protein share r = 0.52. Significance tests to be added.

## 8. Predictions vs results (feeds the Hypothesis section)

| Josh's prediction | Result |
|---|---|
| Animal share fell because total calories grew faster, not less meat | Supported: meat +49%, plant +51%, animal total +11% |
| Plant growth driven by oils, sugar, refined grains | Mostly supported: oils +497 kcal, cereals +211, sugar +71 |
| U.S. would rank very low on pulses among rich countries | Not supported: middle (24th of 48), ~1.9% of protein; pulses small everywhere |
| 15-20% of corn becomes food | Lower: about 10% |
| Ethanol share is large | Supported: about 37% |

## 9. Open items

- Verify every headline number against output/key_numbers.csv.
- Sources for: corn as largest U.S. crop; distillers grains; 2012 drought (if mentioned); beef peak causes (only if cited).
- Add cor.test results; build world map; build final figure set.
