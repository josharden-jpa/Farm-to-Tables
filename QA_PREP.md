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

## Step 05: Wealthy-country comparison (scripts/05_highincome.R)

25. Why only high-income countries? Aren't you hiding the countries that eat the most plants?
26. Why countries with at least 1 million people? Doesn't that cutoff change the results?
27. Why protein here, when the U.S. section used calories?
28. Why average 2021-2023 instead of the latest year?
29. What does r = 0.52 actually mean? Is that strong? What does the p-value tell us, and what doesn't it tell us?
30. Why report both Pearson and Spearman correlations?
31. Does the correlation mean that more protein *causes* a higher animal share?
32. Countries with no FAO pulse-feed data are counted as feeding zero pulses. How do you know?
33. Norway is an outlier. Why not just remove it?
34. "Similar circumstances, different choices": isn't culture or geography (e.g. Ireland's grassland) a circumstance, not a choice?

## Step 06: World map and income (scripts/06_world_map.R)

35. Why map animal share of protein and not something else?
36. Doesn't the map make poor countries look "better" for eating fewer animal products?
37. Why put income on a log scale?
38. Richer countries eat more animal protein. Isn't the U.S. just doing what rich countries do?
39. Why that color scale? Why grey for missing countries?
40. Why an Equal Earth projection instead of the usual world map?
