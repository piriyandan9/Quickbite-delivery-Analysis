# Data Quality Issues — Food Delivery Dataset

**Dataset:** Kaggle — Food Delivery Dataset (Gaurav Malik)  
**Raw rows:** 45,593  
**Raw columns:** 20  
**Documented by:** Piriyandan  
**Date:** April 2026

---

## Summary

The raw dataset has significant quality issues requiring cleaning before analysis can begin. Issues include hidden null values stored as strings, garbage text prefixes in multiple columns, inconsistent whitespace, typos in categorical values, invalid GPS coordinates, and incorrect data types on numeric columns.

---

## Issue 1 — Hidden Nulls Stored as "NaN" Strings

**Affected columns:**

| Column | Null Count | % of Dataset |
|---|---|---|
| Delivery_person_Age | 1854 | 4.07% |
| Delivery_person_Ratings | 1908 | 4.18% |
| Time_Orderd | 1731 | 3.80% |
| Road_traffic_density | 601 | 1.32% |
| multiple_deliveries | 993 | 2.18% |
| Festival | 228 | 0.50% |
| City | 1200 | 2.63% |
| Weatherconditions | 616 | 1.35% |

**Root cause:** During export, missing values were written as the literal string "NaN " (with trailing space) instead of empty fields. Pandas treats these as valid strings, so `df.isnull().sum()` returns 0 — the nulls are invisible until columns are converted to numeric types.

**Business impact:** If left as strings, these rows silently break every groupby, join, and aggregation. Numeric columns like Age and Ratings cannot be converted to int/float while "NaN " strings are present.

---

## Issue 2 — Garbage Text Prefixes

**Affected columns:**
- `Weatherconditions` — every value prefixed with `"conditions "` (e.g., `"conditions Sunny"`, `"conditions Stormy"`)
- `Time_taken(min)` — every value prefixed with `"(min) "` (e.g., `"(min) 24"`)

**Root cause:** Likely a bad CSV export from the source system where column header text bled into cell values.

**Business impact:** These prefixes prevent type conversion (Time_taken should be integer) and make the values ugly in any dashboard display.

**Fix strategy:** Strip the prefix using `.str.replace()` or regex.

---

## Issue 3 — Inconsistent Whitespace

**Affected columns:** Most text columns including `Delivery_person_ID`, `ID`, `City`, `Festival`.

**Example:** City values appear as `"Urban "`, `" Metropolitian "` — spaces at start and/or end.

**Business impact:** In SQL and Python, `"Urban"` ≠ `"Urban "`. This silently breaks groupby, joins, and filters. A query for `City = 'Urban'` would miss every row with a trailing space.

**Fix strategy:** Apply `.str.strip()` to all object/text columns globally.

---

## Issue 4 — Typo in Categorical Value

**Affected column:** `City`

**Issue:** Value `"Metropolitian"` (34,093 rows) should be `"Metropolitan"`.

**Root cause:** Data entry error in the source system, consistent across all affected rows.

**Business impact:** Minor for analysis (the typo is consistent so groupby works) but unprofessional if shown to stakeholders in a dashboard.

**Fix strategy:** Map `"Metropolitian"` → `"Metropolitan"` during cleaning. Document as a finding in the case study.

---

## Issue 5 — Invalid GPS Coordinates

**Counts:**
- Restaurant latitude = 0: 3,640 rows
- Restaurant latitude < 0 (negative, impossible for India): 431 rows
- Overall latitude range: -30.9 to 30.9 (India's actual range: 8 to 37)

**Business impact:** Cannot compute delivery distance (haversine formula) when coordinates are invalid. Distance analysis would produce garbage results and map visualizations would place deliveries in the ocean.

**Fix strategy:** Drop rows where restaurant lat = 0 OR lat < 6 (below India's southernmost point). Do not impute — we have no way to know the true location.

---

## Issue 6 — Incorrect Data Types

Columns stored as `object` (text) that should be numeric:

| Column | Current Type | Should Be |
|---|---|---|
| Delivery_person_Age | object | int |
| Delivery_person_Ratings | object | float |
| multiple_deliveries | object | int |
| Time_taken(min) | object | int |

**Root cause:** Hidden "NaN " strings and garbage prefixes prevent automatic type inference by pandas.

**Fix strategy:** Strip prefixes first (Issue 2), replace "NaN " with actual `np.nan` (Issue 1), then `pd.to_numeric()` or `.astype()`.

---

## Issue 7 — Ugly Column Names

**Examples:**
- `Weatherconditions` — missing underscore, should be `weather_conditions`
- `Time_Orderd` — typo (missing 'e'), should be `time_ordered`
- `Time_taken(min)` — parentheses are SQL-hostile, should be `delivery_minutes`

**Business impact:** Parentheses break SQL queries (`SELECT Time_taken(min)` fails to parse). Inconsistent casing hurts readability. Typos look unprofessional.

**Fix strategy:** Rename all columns to `snake_case` during cleaning with descriptive names.

---

## Decisions — Fix Strategy Summary

| Column | Issue | Decision | Rationale |
|---|---|---|---|
| Delivery_person_Age | 1854 nulls (4.07%) | Impute with median | Low missingness. Dropping would lose info in other columns of same rows. Median is robust to outliers. |
| Delivery_person_Ratings | 1908 nulls (4.18%) | Impute with median | Same reasoning as Age. Ratings bounded 1-5 so median is stable. |
| multiple_deliveries | 993 nulls (2.18%) | Impute with 0 | Null likely represents "no additional deliveries" — a blank field means nothing to report. Business logic over statistics. |
| Time_Orderd | 1731 nulls (3.80%) | Drop rows | Timestamps cannot be meaningfully imputed. Faking them would poison all time-based analysis. |
| Road_traffic_density | 601 nulls (1.32%) | Impute with mode ("Low") | Categorical column, only mode applies. Low missingness makes mode imputation safe. |
| Weatherconditions | 616 nulls (1.35%) | Impute with mode | Same reasoning as Traffic. Categorical, low missingness. |
| Festival | 228 nulls (0.50%) | Impute with "No" | 98% of orders are non-festival. Base rate strongly favors "No." |
| City | 1200 nulls (2.63%) | Drop rows | Critical for geographic analysis. Imputing would guess wrong ~25% of the time. |
| Restaurant lat = 0 | 3640 rows (7.98%) | Drop rows | Coordinates (0,0) indicate GPS failure, not a real location. Would corrupt distance/map analysis. |
| Restaurant lat < 6 | 431 rows (0.95%) | Drop rows | Outside India's geographic range clear data error. |

**Expected final row count after cleaning:** ~40,000 to 41,000 rows (some overlap between drop conditions).

---

## Notes for Dashboard Case Study

- Document the `Metropolitian` → `Metropolitan` typo fix as a "data quality finding" in the final report.
- Report the percentage of rows dropped vs imputed to maintain transparency for stakeholders.
- Flag that orders with `Festival = "Yes"` may show different operational patterns  worth a dashboard slicer.
- Record initial row count (45,593) vs final row count after cleaning in the case study methodology section.