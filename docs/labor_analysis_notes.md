# Labor Cost Analysis — Sameer

Script: scripts/labor_analysis.sh (run after scripts/02_clean.sh)
Outputs: output/labor/ (labor_analysis.txt + 3 grouped tables)
Log: logs/labor_analysis.log

## Questions
1. How much is the cost of labor?
2. Does it differ by mode and by state?
3. Does labor explain why some modes cost more per hour?

## Method
- Labor = Operators Wages + Other Salaries & Wages + Operators Paid Absences
  + Other Paid Absences + Fringe Benefits.
- Labor share = labor / Total. Labor per hour = labor / Vehicle Revenue Hours.
- Grouped by mode, by state, and by mode + state (awk arrays, sorted with sort).
- Rates use group totals (sum of labor / sum of hours), so larger agencies weigh more.
- Mode comparison: each mode's extra cost per hour vs. Bus (MB), and how much of
  that extra is labor. Correlation between labor/hr and total/hr across rows.

## Rows used and why (652 of 4,369)
- Excluded 1,226 contracted rows (PT/TX/TN): contractor wages are inside
  "Purchased Transportation", so labor would look artificially low (~8%).
- Excluded 2,474 rows with no labor breakdown: Rural and Reduced reporters
  report one lump sum ("Reduced Reporter Expenses").
- Excluded 17 rows with questionable Vehicle Revenue Hours (Q/W).
- Validation: every remaining row's expense categories add up to Total (0 failed).
  The 29 rows that don't add up are all contracted rows, already excluded.
- Checks in the script: grouped tables add back up to the row totals;
  every labor share is between 0% and 100%.

## Results (observations from the data)
- Labor is 75.5% of operating cost: $162.98 of $215.97 per vehicle revenue hour.
- Labor share is similar across most modes (64–78%); Vanpool is lowest (49%).
- Labor per hour by mode: Ferryboat $1,525, Commuter Rail $475, Light Rail $225,
  Heavy Rail $213, Bus $129, Demand Response $83, Vanpool $26.
- Labor per hour by state (5+ rows): highest NY $238, NJ $208, MA $179;
  lowest WV $57, SC $63, IA $70 — about 4x difference.
- Labor share by state ranges much less: 61% (MD) to 81% (NY).
- Modes costing more than bus: labor accounts for 51–87% of the extra cost
  (e.g. Commuter Rail 70%, Heavy Rail 76%, Streetcar 87%).
- Correlation of labor/hr with total/hr: 0.99 (0.98 without ferries, 0.97 bus only).
- Ferry cost is high at every ferry agency (WA, NY, MA, CA, PR), not one outlier.

## Interpretation (team's explanation, not proven by this data)
- Labor is the main driver of operating cost; modes that cost more per hour
  mostly do so because they spend more on labor per hour.
- Expensive modes likely need larger crews per vehicle (ferries, rail).
- State differences likely reflect wage levels and cost of living, since
  labor's share of cost stays similar while the dollar amount changes.

## Limitations
- Only directly operated service from Full Reporters (larger agencies).
  Small, rural, and contracted service are not represented.
- Groups with fewer than 5 rows (e.g. Alaska Railroad, Cable Car) are unreliable.
- Vehicle Revenue Hours measures service, not ridership, so "per hour" is cost
  of running service, not cost per passenger.
- One year of data (2020), which was affected by COVID service changes.