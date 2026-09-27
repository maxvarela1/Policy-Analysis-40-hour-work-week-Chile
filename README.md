# The Impact of Chile's Reduced Workweek Law (Ley 21.561) on Labor Outcomes

**Status:** Complete — balance test, event study, triple-difference, counterfactual extrapolation, and placebo-in-time test all finished. Scope currently covers the law's first implementation tranche (2024); extendable once 2026 ESI data becomes available.

## Summary

This project analyzes whether Chile's Ley 21.561, which reduced the legal maximum workweek from 45 to 44 hours starting April 2024, had a measurable effect on the labor outcomes of the population it targets. Using five years (2021–2025) of pooled cross-sectional data from Chile's Encuesta Suplementaria de Ingresos (ESI), I find a statistically significant decrease in hours worked among private-sector salaried workers, concentrated in 2025 rather than 2024 — consistent with a compliance lag — and no statistically significant change in income, consistent with the law's mandate that pay not be cut in response to reduced hours.

## Background

Chile's Ley 21.561 progressively reduces the legal maximum workweek from 45 to 40 hours in three steps: 45 to 44 hours (April 2024), 44 to 42 hours (April 2026), and 42 to 40 hours (April 2028). The law explicitly prohibits employers from cutting wages in response to the reduced hours. Coverage is defined by contract type: workers under a standard labor contract (Código del Trabajo) are subject to the law, while public-sector employees (governed by the separate Estatuto Administrativo) and honorarios contract workers (civil/service contracts) are not.

This project analyzes only the law's first step (45→44 hours), since the available data (through OND 2025) predates the second tranche (April 2026). The analysis is designed to be extended once later data becomes available.

## Data

Data comes from Chile's Encuesta Suplementaria de Ingresos (ESI), a supplementary income module fielded annually alongside the Encuesta Nacional de Empleo (ENE) by Chile's Instituto Nacional de Estadísticas (INE), collected during the October–November–December reference quarter each year. This project pools five years of cross-sectional data (2021–2025).

Because the ESI/ENE does not track the same individuals across years, this is a **repeated cross-section**, not a panel — comparisons rely on group-level (treated/control) structure rather than individual fixed effects.

**Sample restrictions:**
- Ages 15–65
- `ocup_ref == 1` (employed, with at least one month's tenure in current job), per INE's own guidance for official ESI estimates

**Survey design:** All estimates use the ESI's complex survey design (`fact_cal_esi` weights, stratification, clustering) via R's `survey` package. Because cluster and stratum identifiers are assigned independently each year, stratum and cluster IDs were made unique across years (`year_stratum`, `year_cluster`) before constructing the survey design object, to avoid incorrectly treating unrelated clusters from different years as identical.

## Research Design

In this project I analyze whether Chile's new reduced-workweek policy (Ley 21.561) had a measurable impact on the labor outcomes of the population it targets. The treated population is formal-contract salaried workers in the private sector, who are directly subject to the law's 44-hour cap. The control group is the population of workers not affected by this policy — those not subject to working contracts under the Código del Trabajo, but governed under different rules: public-sector employees (Estatuto Administrativo) as the primary control, and honorarios contract workers (civil service contracts) as a robustness check. Using years of data both before and after the policy's implementation, I estimate its effect via difference-in-differences, comparing how outcomes changed for treated workers relative to control workers around the April 2024 implementation date. Furthermore, within the treated population, I separately test whether formal workers show a different response than informal workers (measured by pension/health contribution status), to check whether the policy's effect depended on employer compliance and enforcement — a triple-difference extension. My prediction is a not-noticeable change in monthly salary and an actual decrease in hours worked among the formal, private-salaried population, with the effect potentially concentrated among formally-employed (contribution-paying) workers if enforcement drives compliance.

## Results

### 1. Baseline Balance Test (Normalized Difference)

The first calculation done was to see if the control variables would be used at all to compare them to the treated variable. To do this, I ran a normalized difference calculation, with common variables such as age and sex to see if there are any big discrepancies between the demographics of the samples of each group. When comparing both control groups to the treated group, there was a substantial difference in sex when comparing the public sector to the private sector, with all years above the pre-established threshold of |x| < 0.25. However, this only confirmed the already known discrepancy of sex across job fields in the country. Furthermore, the honorarios control group showed a notable deviation in age in some years, showing inconsistency with the overall demographic pattern, possibly due to its lower sample size (~900 observations per year).

### 2. Event Study (Dynamic Difference-in-Differences)

During the second calculation of the experiment, I completed event-study regressions, comparing the treated group (private workers) to control groups (public workers and honorarios) across years, for two outcomes: hours worked and salary. To conserve consistency, for these equations I decided to have 2023 as the base year, as it was the last full year before the implementation of Ley 21.561.

For hours, there was a significant shift for private workers only during 2025, one year after the implementation of the policy, when comparing them to public-sector workers. The insignificance for 2024 (p = 0.68) shows a possible lag of implementation for private companies, which was later noticed in 2025 (p = 0.02). When comparing private workers to honorarios, we could not see a significant change in hours, and the estimated direction of the effect pointed the opposite way from the public-sector comparison — raising further suspicions regarding the trustability of honorarios for this test, given its low sample size (~900 observations per year).

When observing salary, similar findings remained somewhat correlated to the policy. When comparing the treated group to public workers, the year 2022 saw a disparity of significance (p = 0.03). To test the robustness of this finding and account for a year of unusually high inflation, I normalized all incomes using changes in the Consumer Price Index (CPI) in Chile, using the Banco Central de Chile's IPC empalme (linked) series. After normalizing wages, the significance of the 2022 change disappeared (p = 0.10), and the results showed no significant changes in wages across any year, staying consistent with the policy's no-pay-cut mandate. I repeated the process for honorarios: this comparison showed a significant change in wages in 2022 (p = 0.02), which persisted — and slightly strengthened — after normalizing for inflation (p = 0.01), suggesting this divergence is structural to the honorarios comparison rather than an artifact of inflation timing.

All in all, results showed trends consistent with the expected outcomes of Ley 21.561: a reduction in hours worked for private salaried workers after a year of lag, likely due to delayed implementation, alongside no significant change in wages after the policy's implementation.

### 3. Triple-Difference (DDD)

The third calculation, the triple-difference, sought to identify whether the policy's effect on hours worked differed between formal and informal workers within the private sector. Honorarios workers were excluded from this calculation because the nature of their contract doesn't align with how the `ocup_form` variable is defined; that variable measures formality specifically for dependent workers, a concept that doesn't cleanly apply to honorarios, whose civil-service contracts fall outside that framework. This is in addition to the already small sample size (roughly 900 observations per year) noted earlier.

To ensure results were consistent, I ran two specifications: one collapsing time into a single pre-policy/post-policy period, and one treating each year as a separate factor. In the collapsed specification, formal private-sector workers showed a significant decrease in hours worked (p = 0.000352); the year-as-factor specification found a consistent result for 2025 specifically (p = 0.045), the same year the main event study identified as the point where the policy's effect became significant. However, the coefficient that actually tests whether this effect differed between formal and informal workers — the triple-interaction term — was not statistically significant in either specification (p = 0.523 collapsed; p = 0.276 for 2025), and its estimated direction was not even consistent across the two models. This indicates the data cannot confidently establish whether formality moderated the policy's effect.

### 4. Counterfactual Extrapolation

The fourth calculation used a counterfactual extrapolation to forecast changes in hours worked and salary, using movements in our primary control group, public-sector workers, as a benchmark. Although not perfect, this approach lets me simulate how the treated population's outcomes might have evolved under nearly every condition except Ley 21.561's implementation. After visualizing them, the counterfactual (no-policy) scenario showed a slight increase in average hours worked after 2024, while actual hours for treated workers continued to decline over the same period, widening the gap between the two lines and visually reinforcing the event study's finding of a significant hours reduction by 2025. Salary showed a smaller, not statistically meaningful gap between the actual and counterfactual lines, consistent with the event study's finding of no significant wage effect. Both figures are included to make the event study's regression-based findings more visually intuitive for a general audience.

*Note: the counterfactual extrapolation is mathematically equivalent to the event study's interaction coefficients, re-expressed in levels rather than coefficients; it is included as an intuitive visualization of the same estimated effect, not as independent evidence.*

### 5. Placebo-in-Time Test

Lastly, to confirm the significant 2025 hours effect reflects the actual policy rather than a methodological artifact, I ran a placebo test assuming a fake treatment date of 2022, restricted to genuinely pre-policy data (2021–2023) only, to ensure no real policy effect could contaminate the test. The treated-control interaction coefficient was small and statistically insignificant (-0.10, p = 0.67), indicating the method does not manufacture false effects when no real policy change exists — supporting the credibility of the actual 2025 finding.

## Limitations

- **Repeated cross-sections, not a panel:** individuals cannot be tracked across years, so all comparisons rely on group-level structure rather than individual fixed effects.
- **Honorarios as a control group:** limited by a small sample (~900 observations/year), a structurally different relationship to "usual hours worked" (project-based vs. scheduled), and an inconsistent definition of `ocup_form` for this population (confirmed against INE's official informality methodology, 2020) — for these reasons, honorarios was excluded from the triple-difference and treated as a secondary robustness check elsewhere.
- **Scope limited to the first policy tranche:** data through OND 2025 predates the law's second step (April 2026, 44→42 hours); findings speak only to the initial 45→44 hour reduction.
- **DDD specification instability:** the formality-based triple-interaction term was not significant in either specification tested, and its sign was not stable across them — the data cannot confirm whether enforcement/formality moderated the policy's effect.
- **Public-sector control group imbalance:** significantly different gender composition from the treated group in every year (pre- and post-policy), reflecting a well-documented, pre-existing structural difference between public- and private-sector employment in Chile.

## How to Reproduce

- **Data:** ESI/ENE microdata (2021–2025), publicly available from INE's website (ine.gob.cl). Raw microdata is not included in this repository; download directly from INE to reproduce.
- **Tools:** R, using the `survey`, `dplyr`, `tidyr`, `purrr`, and `ggplot2` packages.
- **Scripts:** see `/scripts` for data cleaning, sample construction, and each of the five calculations, organized sequentially.

## Citation

Data: Instituto Nacional de Estadísticas de Chile (2025). Encuesta Suplementaria de Ingresos (ESI).
Inflation series: Banco Central de Chile, IPC empalme (linked series).
