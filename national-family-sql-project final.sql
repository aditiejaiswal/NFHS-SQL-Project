-- ================================================================
-- PROJECT   : National Family Health Survey — SQL Analytics
-- ANALYST   : Aditi V Jaiswal
-- TOOL      : MySQL 8.0
-- DATASET   : NFHS-4 (2014-15) & NFHS-5 (2019-20)
-- SCOPE     : 636 Districts across India
-- OBJECTIVE : Track maternal & child health progress across
--             Indian districts between two survey rounds
-- ================================================================

USE health_db;

-- ================================================================
-- PHASE 1 : DATA UNDERSTANDING
-- Getting familiar with the dataset structure before analysis
-- ================================================================

-- ----------------------------------------------------------------
-- 1.1 Survey Coverage Check
-- How many districts and states are covered in each survey round?
-- ----------------------------------------------------------------

SELECT
    `year`                     AS survey_year,
    COUNT(*)                   AS total_districts,
    COUNT(DISTINCT state_name) AS total_states
FROM nfhs
GROUP BY `year`
ORDER BY `year`;

-- ----------------------------------------------------------------
-- 1.2 Single District Profile — Before vs After
-- Pulling Guntur (Andhra Pradesh) across both rounds
-- to understand what a typical district record looks like
-- ----------------------------------------------------------------

SELECT
    `year`                 AS survey_year,
    state_name,
    district_name,
    dc_insti_births        AS institutional_births_pct,
    mc_anc_4               AS anc_4plus_visits_pct,
    cv_12_23_full_vacc     AS full_vaccination_pct,
    child_5_stunted        AS stunting_pct,
    births_skill_personnel AS skilled_birth_pct
FROM nfhs
WHERE district_name = 'Guntur'
ORDER BY `year`;

-- ----------------------------------------------------------------
-- 1.3 Data Range Validation
-- All indicators are percentages — values must be between 0-100
-- Outliers here indicate potential data entry errors
-- ----------------------------------------------------------------

SELECT
    MIN(dc_insti_births)    AS min_insti_births,
    MAX(dc_insti_births)    AS max_insti_births,
    MIN(cv_12_23_full_vacc) AS min_vaccination,
    MAX(cv_12_23_full_vacc) AS max_vaccination,
    MIN(child_5_stunted)    AS min_stunting,
    MAX(child_5_stunted)    AS max_stunting,
    MIN(mc_anc_4)           AS min_anc4,
    MAX(mc_anc_4)           AS max_anc4
FROM nfhs;


-- ================================================================
-- PHASE 2 : DATA CLEANING
-- Checking data quality before drawing any conclusions
-- ================================================================

-- ----------------------------------------------------------------
-- 2.1 NULL Value Assessment
-- Counting missing values across key health indicators
-- High NULL counts may affect reliability of analysis
-- ----------------------------------------------------------------

SELECT
    COUNT(*)                                 AS total_rows,
    COUNT(*) - COUNT(dc_insti_births)        AS null_insti_births,
    COUNT(*) - COUNT(mc_anc_4)               AS null_anc4_visits,
    COUNT(*) - COUNT(cv_12_23_full_vacc)     AS null_full_vaccination,
    COUNT(*) - COUNT(child_5_stunted)        AS null_child_stunting,
    COUNT(*) - COUNT(births_skill_personnel) AS null_skilled_births
FROM nfhs;

-- ----------------------------------------------------------------
-- 2.2 Suspicious Zero Value Check
-- Districts with 0% institutional births in 2019-20
-- are flagged — zero deliveries in a district is unrealistic
-- ----------------------------------------------------------------

SELECT
    state_name,
    district_name,
    dc_insti_births        AS institutional_births_pct,
    births_skill_personnel AS skilled_birth_pct,
    mc_anc_4               AS anc4_visits_pct
FROM nfhs
WHERE `year` = '2019-20'
  AND (dc_insti_births = 0 OR births_skill_personnel = 0)
ORDER BY dc_insti_births;

-- ----------------------------------------------------------------
-- 2.3 District Count Balance Check
-- Verifying equal district coverage in both survey rounds
-- Imbalance between years could skew state-level comparisons
-- ----------------------------------------------------------------

SELECT
    state_name,
    COUNT(CASE WHEN `year` = '2014-15' THEN 1 END) AS districts_in_2014,
    COUNT(CASE WHEN `year` = '2019-20' THEN 1 END) AS districts_in_2019
FROM nfhs
GROUP BY state_name
ORDER BY state_name;


-- ================================================================
-- PHASE 3 : EXPLORATORY DATA ANALYSIS — STATE LEVEL
-- Understanding performance and trends at the state level
-- ================================================================

-- ----------------------------------------------------------------
-- 3.1 State Performance Snapshot — 2019-20
-- Ranking all states by institutional birth rate
-- alongside key maternal and child health indicators
-- ----------------------------------------------------------------

SELECT
    state_name,
    COUNT(DISTINCT district_name)          AS total_districts,
    ROUND(AVG(dc_insti_births), 1)         AS avg_institutional_births,
    ROUND(AVG(mc_anc_4), 1)               AS avg_anc4_visits,
    ROUND(AVG(cv_12_23_full_vacc), 1)     AS avg_full_vaccination,
    ROUND(AVG(child_5_stunted), 1)        AS avg_child_stunting,
    ROUND(AVG(births_skill_personnel), 1) AS avg_skilled_birth_attendance
FROM nfhs
WHERE `year` = '2019-20'
GROUP BY state_name
ORDER BY avg_institutional_births DESC;

-- ----------------------------------------------------------------
-- 3.2 State Progress — 2014 to 2019
-- Measuring improvement in institutional birth rates
-- Higher improvement points = stronger policy impact
-- ----------------------------------------------------------------

SELECT
    state_name,
    ROUND(AVG(CASE WHEN `year` = '2014-15'
              THEN dc_insti_births END), 1) AS institutional_birth_2014,
    ROUND(AVG(CASE WHEN `year` = '2019-20'
              THEN dc_insti_births END), 1) AS institutional_birth_2019,
    ROUND(
        AVG(CASE WHEN `year` = '2019-20' THEN dc_insti_births END) -
        AVG(CASE WHEN `year` = '2014-15' THEN dc_insti_births END),
    1) AS improvement_points
FROM nfhs
GROUP BY state_name
ORDER BY improvement_points DESC;

-- ----------------------------------------------------------------
-- 3.3 Anomaly Detection — High Births but High Stunting
-- States with over 80% institutional births but
-- still reporting over 35% child stunting
-- Finding: Hospital delivery alone does not guarantee
-- good nutritional outcomes — post-natal care is the gap
-- ----------------------------------------------------------------

SELECT
    state_name,
    ROUND(AVG(dc_insti_births), 1)    AS avg_institutional_births,
    ROUND(AVG(child_5_stunted), 1)    AS avg_child_stunting,
    ROUND(AVG(child_5_underweight),1) AS avg_child_underweight,
    ROUND(AVG(cfp_bf_6mon), 1)        AS avg_exclusive_breastfeeding_6m,
    ROUND(AVG(bf_6_23_ad_deit), 1)   AS avg_adequate_diet_6_23m
FROM nfhs
WHERE `year` = '2019-20'
GROUP BY state_name
HAVING AVG(dc_insti_births) > 80
   AND AVG(child_5_stunted)  > 35
ORDER BY avg_child_stunting DESC;

-- ----------------------------------------------------------------
-- 3.4 Women Anaemia Trend — 2014 to 2019
-- Tracking whether anaemia among women aged 15-49
-- improved or worsened between the two survey rounds
-- Positive value = improvement | Negative = worsened
-- ----------------------------------------------------------------

SELECT
    state_name,
    ROUND(AVG(CASE WHEN `year` = '2014-15'
              THEN wom_15_49_anaemic END), 1) AS anaemia_rate_2014,
    ROUND(AVG(CASE WHEN `year` = '2019-20'
              THEN wom_15_49_anaemic END), 1) AS anaemia_rate_2019,
    ROUND(
        AVG(CASE WHEN `year` = '2014-15' THEN wom_15_49_anaemic END) -
        AVG(CASE WHEN `year` = '2019-20' THEN wom_15_49_anaemic END),
    1) AS improvement_points
FROM nfhs
GROUP BY state_name
ORDER BY improvement_points DESC;


-- ================================================================
-- PHASE 4 : DISTRICT LEVEL DEEP DIVE
-- Granular analysis at the district level
-- ================================================================

-- ----------------------------------------------------------------
-- 4.1 Top 10 Most Improved Districts — 2014 to 2019
-- Composite score = average gain across 4 indicators:
-- institutional births, ANC visits, vaccination, stunting
-- These districts are the success stories worth studying
-- ----------------------------------------------------------------

SELECT
    state_name,
    district_name,
    insti_births_gain,
    anc4_gain,
    vacc_gain,
    stunted_reduction,
    ROUND(
        (insti_births_gain + anc4_gain + vacc_gain + stunted_reduction) / 4.0,
    2) AS composite_score
FROM (
    SELECT
        n5.state_name,
        n5.district_name,
        ROUND((n5.dc_insti_births    - n4.dc_insti_births),    2) AS insti_births_gain,
        ROUND((n5.mc_anc_4           - n4.mc_anc_4),           2) AS anc4_gain,
        ROUND((n5.cv_12_23_full_vacc - n4.cv_12_23_full_vacc), 2) AS vacc_gain,
        ROUND((n4.child_5_stunted    - n5.child_5_stunted),    2) AS stunted_reduction
    FROM nfhs n5
    JOIN nfhs n4
        ON  n5.district_code = n4.district_code
        AND n5.`year` = '2019-20'
        AND n4.`year` = '2014-15'
) AS delta_table
ORDER BY composite_score DESC
LIMIT 10;

-- ----------------------------------------------------------------
-- 4.2 Districts That Regressed — Red Flag Analysis
-- Districts where composite score is negative
-- meaning health outcomes worsened between 2014 and 2019
-- These require urgent investigation and policy attention
-- ----------------------------------------------------------------

SELECT
    state_name,
    district_name,
    insti_births_gain,
    anc4_gain,
    vacc_gain,
    stunted_reduction,
    ROUND(
        (insti_births_gain + anc4_gain + vacc_gain + stunted_reduction) / 4.0,
    2) AS composite_score
FROM (
    SELECT
        n5.state_name,
        n5.district_name,
        ROUND((n5.dc_insti_births    - n4.dc_insti_births),    2) AS insti_births_gain,
        ROUND((n5.mc_anc_4           - n4.mc_anc_4),           2) AS anc4_gain,
        ROUND((n5.cv_12_23_full_vacc - n4.cv_12_23_full_vacc), 2) AS vacc_gain,
        ROUND((n4.child_5_stunted    - n5.child_5_stunted),    2) AS stunted_reduction
    FROM nfhs n5
    JOIN nfhs n4
        ON  n5.district_code = n4.district_code
        AND n5.`year` = '2019-20'
        AND n4.`year` = '2014-15'
) AS delta_table
WHERE (insti_births_gain + anc4_gain + vacc_gain + stunted_reduction) / 4.0 < 0
ORDER BY composite_score ASC
LIMIT 10;

-- ----------------------------------------------------------------
-- 4.3 Multi-Indicator Risk Flagging
-- Districts failing on 3 or more out of 5 health indicators
-- This simulates a real government priority targeting exercise
-- Risk score 5 = failing on all indicators = highest priority
-- ----------------------------------------------------------------

SELECT
    state_name,
    district_name,
    ROUND(dc_insti_births, 1)     AS institutional_births_pct,
    ROUND(mc_anc_4, 1)            AS anc4_visits_pct,
    ROUND(cv_12_23_full_vacc, 1)  AS full_vaccination_pct,
    ROUND(child_5_stunted, 1)     AS child_stunting_pct,
    ROUND(child_5_underweight, 1) AS child_underweight_pct,
    (
        CASE WHEN dc_insti_births     < 70 THEN 1 ELSE 0 END +
        CASE WHEN mc_anc_4            < 50 THEN 1 ELSE 0 END +
        CASE WHEN cv_12_23_full_vacc  < 60 THEN 1 ELSE 0 END +
        CASE WHEN child_5_stunted     > 40 THEN 1 ELSE 0 END +
        CASE WHEN child_5_underweight > 35 THEN 1 ELSE 0 END
    ) AS risk_score
FROM nfhs
WHERE `year` = '2019-20'
HAVING risk_score >= 3
ORDER BY risk_score DESC
LIMIT 15;

-- ----------------------------------------------------------------
-- 4.4 District Coverage Tier Distribution
-- Grouping districts into 4 tiers by institutional birth rate
-- Comparing 2014 vs 2019 to see how the landscape shifted
-- ----------------------------------------------------------------

SELECT
    `year`                     AS survey_year,
    CASE
        WHEN dc_insti_births < 50 THEN '1 - Low        (Below 50%)'
        WHEN dc_insti_births < 75 THEN '2 - Medium     (50% - 75%)'
        WHEN dc_insti_births < 90 THEN '3 - High       (75% - 90%)'
        ELSE                           '4 - Very High  (Above 90%)'
    END                        AS coverage_tier,
    COUNT(*)                   AS district_count
FROM nfhs
WHERE dc_insti_births IS NOT NULL
GROUP BY `year`, coverage_tier
ORDER BY `year`, coverage_tier;


-- ================================================================
-- PHASE 5 : ADVANCED ANALYSIS
-- Window functions, lifestyle correlations, infrastructure
-- ================================================================

-- ----------------------------------------------------------------
-- 5.1 Vaccination Coverage by State — 2019-20
-- Comparing full vaccination alongside individual vaccines
-- BCG, Polio, DPT — to find which vaccines are lagging
-- ----------------------------------------------------------------

SELECT
    state_name,
    ROUND(AVG(cv_12_23_full_vacc), 1) AS full_vaccination_pct,
    ROUND(AVG(cv_12_23_bcg), 1)       AS bcg_pct,
    ROUND(AVG(cv_12_23_polio), 1)     AS polio_pct,
    ROUND(AVG(cv_12_23_dpt), 1)       AS dpt_pct
FROM nfhs
WHERE `year` = '2019-20'
GROUP BY state_name
ORDER BY full_vaccination_pct DESC;

-- ----------------------------------------------------------------
-- 5.2 Best vs Worst Vaccination District Per State
-- Using RANK window function to find top and bottom
-- performing district within each state
-- Large gap = high intra-state inequality in healthcare access
-- ----------------------------------------------------------------

SELECT
    state_name,
    MAX(CASE WHEN vacc_rank_best  = 1 THEN district_name      END) AS best_district,
    MAX(CASE WHEN vacc_rank_best  = 1 THEN cv_12_23_full_vacc END) AS best_vacc_pct,
    MAX(CASE WHEN vacc_rank_worst = 1 THEN district_name      END) AS worst_district,
    MAX(CASE WHEN vacc_rank_worst = 1 THEN cv_12_23_full_vacc END) AS worst_vacc_pct,
    ROUND(
        MAX(CASE WHEN vacc_rank_best  = 1 THEN cv_12_23_full_vacc END) -
        MAX(CASE WHEN vacc_rank_worst = 1 THEN cv_12_23_full_vacc END),
    1) AS gap_within_state
FROM (
    SELECT
        state_name,
        district_name,
        cv_12_23_full_vacc,
        RANK() OVER (PARTITION BY state_name
                     ORDER BY cv_12_23_full_vacc DESC) AS vacc_rank_best,
        RANK() OVER (PARTITION BY state_name
                     ORDER BY cv_12_23_full_vacc ASC)  AS vacc_rank_worst
    FROM nfhs
    WHERE `year` = '2019-20'
      AND cv_12_23_full_vacc IS NOT NULL
) AS ranked_data
GROUP BY state_name
ORDER BY gap_within_state DESC;

-- ----------------------------------------------------------------
-- 5.3 Lifestyle Risk vs Blood Pressure — Correlation Check
-- Do states with higher tobacco and alcohol use among men
-- also report higher blood pressure rates?
-- Note: This is observational — not a causal claim
-- ----------------------------------------------------------------

SELECT
    state_name,
    ROUND(AVG(tobaco_men_15), 1)  AS tobacco_use_pct,
    ROUND(AVG(alcohol_men_15), 1) AS alcohol_use_pct,
    ROUND(AVG(men_bp_mild), 1)    AS bp_mild_pct,
    ROUND(AVG(men_bp_sev), 1)     AS bp_severe_pct,
    ROUND(AVG(men_bp_ele_med), 1) AS bp_on_medication_pct
FROM nfhs
WHERE `year` = '2019-20'
GROUP BY state_name
ORDER BY tobacco_use_pct DESC;

-- ----------------------------------------------------------------
-- 5.4 Household Infrastructure Score
-- Weighted composite score from 5 amenity indicators:
-- Electricity (25%), Drinking Water (30%),
-- Sanitation (25%), Iodized Salt (10%), Health Insurance (10%)
-- Used to explore whether better infrastructure
-- correlates with better health outcomes
-- ----------------------------------------------------------------

SELECT
    `year`         AS survey_year,
    state_name,
    district_name,
    ROUND(
        COALESCE(pop_hh_elec, 0)     * 0.25 +
        COALESCE(pop_hh_dw, 0)       * 0.30 +
        COALESCE(pop_hh_sf, 0)       * 0.25 +
        COALESCE(hh_iodized_salt, 0) * 0.10 +
        COALESCE(hh_hlth_ins_fs, 0)  * 0.10,
    2) AS infrastructure_score
FROM nfhs
ORDER BY infrastructure_score DESC
LIMIT 20;

-- ================================================================
-- END OF PROJECT
-- Key Finding: States with high institutional birth rates
-- still report high child stunting — revealing a critical
-- post-natal nutrition gap that delivery infrastructure
-- alone cannot solve.
-- ================================================================