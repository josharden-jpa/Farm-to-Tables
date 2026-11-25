# Q&A prep: questions classmates (and the professor) might ask

Answer each in your own words, then check the answer against the data, the research log, or a source. Mark each one when you can answer it without notes.

## Step 01: Building the FAO data (scripts/01_build_fao.R)

1. Why didn't you just use the newer FAO data? Why join two series at all?
2. Your U.S. totals jump about 2% at 2010 because of the method change. Doesn't that make your whole time series unreliable?
3. Why did you drop China from the data? Isn't it the biggest country?
4. How do you know you're not counting any food twice?
5. Your data says Americans have about 3,950 calories available per day. Nobody eats that much. Is the data wrong?
6. Why calories as the main measure, and not weight or dollars?

## Step 02: U.S. trends (scripts/02_us_trends.R)

7. Some food groups have no data for the U.S. You set them to zero. How do you know they're really zero and not just missing?
8. Your titles state conclusions ("Meat rose while animal fats fell"). Isn't that biased? Why not neutral titles?
9. Why does the animal-share chart start at zero? Doesn't that hide the change?
10. Why a bar chart of changes for plant foods instead of lines over time?
11. "Plant calories rose 51%." Doesn't that mean Americans are eating more plant-based?

## Step 03: Meat and the cross-check (scripts/03_meat_ers.R)

12. Why bring in a second data source at all? What did USDA add that FAO didn't?
13. FAO is in calories and USDA in pounds. How can you compare them?
14. What's "boneless weight," and why use it instead of carcass weight?
15. You report a correlation of 0.91 but no p-value. Why not?
16. If you threw out FAO's 2018 meat jump, why trust FAO anywhere else?
17. Americans shifted from beef to chicken. Is that better or worse for animals? For the environment?

## Step 04: Corn (scripts/04_corn_ers.R)

18. Why corn and not soybeans, or wheat?
19. Ethanol corn isn't wasted: it produces distillers grains fed to animals. Doesn't that change your 90%?
20. Exported corn might become food in other countries. Why lump exports with feed and fuel?
21. Is corn syrup really "food"? And isn't starch partly industrial?
22. You switched from FAO to USDA for this figure. Isn't that cherry-picking the source?
23. Feed's share dropped from about 58% to about 37%. Does that mean animals eat less corn?
24. Why a stacked area chart? What does it hide?
