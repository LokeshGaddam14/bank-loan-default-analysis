-- ============================================================================
-- BANK LOAN DEFAULT RISK ANALYSIS — SQL ANALYTICS LAYER
-- Credit Risk Analytics | Advanced SQL | Window Functions | CTEs
-- Author  : Lokesh Gaddam
-- Dataset : Bank Loan Default Dataset (49,278 credit facilities)
-- Tools   : SQLite / MySQL / PostgreSQL compatible
-- Purpose : Regulatory reporting, portfolio monitoring, risk segmentation
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: DATABASE SETUP & SCHEMA
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS loan_portfolio (
    ID                        INTEGER PRIMARY KEY,
    year                      INTEGER,
    loan_limit                TEXT,
    Gender                    TEXT,
    approv_in_adv             TEXT,
    loan_type                 TEXT,
    loan_purpose              TEXT,
    Credit_Worthiness         TEXT,
    open_credit               TEXT,
    business_or_commercial    TEXT,
    loan_amount               REAL,
    rate_of_interest          REAL,
    Interest_rate_spread      REAL,
    Upfront_charges           REAL,
    term                      INTEGER,
    Neg_ammortization         TEXT,
    interest_only             TEXT,
    lump_sum_payment          TEXT,
    property_value            REAL,
    construction_type         TEXT,
    occupancy_type            TEXT,
    Secured_by                TEXT,
    total_units               TEXT,
    income                    REAL,
    credit_type               TEXT,
    Credit_Score              INTEGER,
    co_applicant_credit_type  TEXT,
    age                       TEXT,
    submission_of_application TEXT,
    LTV                       REAL,
    Region                    TEXT,
    Security_Type             TEXT,
    Status                    INTEGER,   -- 1=Default, 0=Performing
    dtir1                     REAL
);


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 1: PORTFOLIO-LEVEL DEFAULT RATE (KPI SUMMARY)
-- Business Use: Executive dashboard, regulatory capital reporting
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    COUNT(*)                                          AS total_facilities,
    SUM(Status)                                       AS total_defaults,
    COUNT(*) - SUM(Status)                            AS performing_facilities,
    ROUND(AVG(Status) * 100, 2)                       AS portfolio_default_rate_pct,
    ROUND(SUM(loan_amount), 0)                        AS total_exposure_usd,
    ROUND(SUM(CASE WHEN Status=1 THEN loan_amount END), 0) AS defaulted_exposure_usd,
    ROUND(
        SUM(CASE WHEN Status=1 THEN loan_amount END) /
        SUM(loan_amount) * 100, 2
    )                                                 AS exposure_weighted_default_rate_pct
FROM loan_portfolio;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 2: DEFAULT RATE BY LTV TIER (COLLATERAL RISK SEGMENTATION)
-- Business Use: Basel III RWA computation, collateral adequacy assessment
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    CASE
        WHEN LTV <= 60                     THEN '1. ≤60% — Low Risk (Prime Coverage)'
        WHEN LTV > 60  AND LTV <= 70       THEN '2. 60–70% — Moderate Coverage'
        WHEN LTV > 70  AND LTV <= 80       THEN '3. 70–80% — Standard Threshold'
        WHEN LTV > 80  AND LTV <= 90       THEN '4. 80–90% — Elevated Risk (PMI Zone)'
        WHEN LTV > 90  AND LTV <= 100      THEN '5. 90–100% — High Risk Tier'
        ELSE                                    '6. >100% — Underwater / Negative Equity'
    END                                          AS ltv_risk_tier,
    COUNT(*)                                     AS facility_count,
    ROUND(AVG(Status) * 100, 2)                  AS default_rate_pct,
    ROUND(AVG(loan_amount), 0)                   AS avg_exposure_usd,
    ROUND(SUM(loan_amount), 0)                   AS total_exposure_usd,
    ROUND(AVG(Credit_Score), 0)                  AS avg_credit_score,
    ROUND(AVG(income), 0)                        AS avg_borrower_income
FROM loan_portfolio
WHERE LTV IS NOT NULL
GROUP BY ltv_risk_tier
ORDER BY ltv_risk_tier;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 3: ROLLING 12-MONTH DEFAULT RATE TREND (VINTAGE ANALYSIS)
-- Business Use: Portfolio vintage monitoring, origination quality tracking
-- Window Function: SUM() OVER with ROWS BETWEEN
-- ─────────────────────────────────────────────────────────────────────────────

WITH yearly_defaults AS (
    SELECT
        year,
        COUNT(*)                              AS originations,
        SUM(Status)                           AS defaults,
        ROUND(AVG(Status) * 100, 2)           AS default_rate_pct,
        ROUND(SUM(loan_amount) / 1e6, 2)      AS total_exposure_musd
    FROM loan_portfolio
    WHERE year IS NOT NULL
    GROUP BY year
),
rolling_metrics AS (
    SELECT
        year,
        originations,
        defaults,
        default_rate_pct,
        total_exposure_musd,
        -- Cumulative defaults (all vintages up to this year)
        SUM(defaults) OVER (
            ORDER BY year
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                     AS cumulative_defaults,
        -- 3-year rolling average default rate
        ROUND(AVG(default_rate_pct) OVER (
            ORDER BY year
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2)                                 AS rolling_3yr_avg_pd_pct,
        -- Year-over-year change in default rate
        default_rate_pct - LAG(default_rate_pct, 1) OVER (ORDER BY year)
                                              AS yoy_pd_change_pp
    FROM yearly_defaults
)
SELECT * FROM rolling_metrics ORDER BY year;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 4: RISK DRIVER DECOMPOSITION — MULTI-FACTOR DEFAULT RATE
-- Business Use: Composite risk scoring validation, underwriting policy review
-- ─────────────────────────────────────────────────────────────────────────────

WITH risk_flags AS (
    SELECT
        *,
        CASE WHEN LTV > 90        THEN 1 ELSE 0 END AS flag_high_ltv,
        CASE WHEN dtir1 > 43      THEN 1 ELSE 0 END AS flag_high_dtir,
        CASE WHEN Credit_Score < 620 THEN 1 ELSE 0 END AS flag_low_score,
        CASE WHEN income < (
            SELECT PERCENTILE_25 FROM (
                SELECT income,
                       NTILE(4) OVER (ORDER BY income) AS quartile
                FROM loan_portfolio WHERE income IS NOT NULL
            ) q WHERE quartile = 1 LIMIT 1
        )                         THEN 1 ELSE 0 END AS flag_low_income
    FROM loan_portfolio
    WHERE LTV IS NOT NULL AND dtir1 IS NOT NULL AND Credit_Score IS NOT NULL
),
composite AS (
    SELECT
        *,
        (flag_high_ltv + flag_high_dtir + flag_low_score + flag_low_income)
                                                   AS composite_risk_score
    FROM risk_flags
)
SELECT
    composite_risk_score                            AS stress_flags_triggered,
    COUNT(*)                                        AS facility_count,
    ROUND(AVG(Status) * 100, 2)                     AS default_rate_pct,
    ROUND(AVG(loan_amount), 0)                      AS avg_exposure_usd,
    ROUND(AVG(LTV), 2)                              AS avg_ltv_pct,
    ROUND(AVG(Credit_Score), 0)                     AS avg_credit_score,
    ROUND(AVG(income), 0)                           AS avg_income_usd,
    CASE composite_risk_score
        WHEN 0 THEN 'Prime — Auto-Approve'
        WHEN 1 THEN 'Near-Prime — Standard Review'
        WHEN 2 THEN 'Elevated — Enhanced Underwriting'
        WHEN 3 THEN 'Subprime — Manual Override Required'
        ELSE       'High-Risk — Decline / Collateral Required'
    END                                             AS underwriting_recommendation
FROM composite
GROUP BY composite_risk_score
ORDER BY composite_risk_score;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 5: PERCENTILE RANK & RISK DECILE SCORING
-- Business Use: Internal rating scale (IRS) construction, scorecard banding
-- Window Function: PERCENT_RANK(), NTILE()
-- ─────────────────────────────────────────────────────────────────────────────

WITH facility_scoring AS (
    SELECT
        ID,
        loan_amount,
        Credit_Score,
        LTV,
        dtir1,
        income,
        Status,
        -- Percentile rank of credit score (higher = better)
        ROUND(PERCENT_RANK() OVER (ORDER BY Credit_Score) * 100, 2)
                                                    AS credit_score_percentile,
        -- LTV risk decile (higher decile = worse LTV)
        NTILE(10) OVER (ORDER BY LTV DESC)          AS ltv_risk_decile,
        -- Income percentile (higher = better capacity)
        NTILE(5) OVER (ORDER BY income)             AS income_quintile,
        -- Composite exposure rank
        RANK() OVER (ORDER BY loan_amount DESC)     AS exposure_rank
    FROM loan_portfolio
    WHERE Credit_Score IS NOT NULL
      AND LTV IS NOT NULL
      AND income IS NOT NULL
)
SELECT
    ltv_risk_decile,
    COUNT(*)                                        AS facilities,
    ROUND(AVG(Status) * 100, 2)                     AS default_rate_pct,
    ROUND(AVG(credit_score_percentile), 1)          AS avg_score_percentile,
    ROUND(AVG(LTV), 2)                              AS avg_ltv,
    ROUND(AVG(loan_amount), 0)                      AS avg_exposure_usd
FROM facility_scoring
GROUP BY ltv_risk_decile
ORDER BY ltv_risk_decile;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 6: INCOME-SEGMENT × LOAN PURPOSE CROSS-RISK MATRIX
-- Business Use: Two-dimensional risk heat map, segment-level pricing
-- ─────────────────────────────────────────────────────────────────────────────

WITH income_bands AS (
    SELECT
        *,
        CASE
            WHEN income <= 30000  THEN '1. Low Income (<$30K)'
            WHEN income <= 60000  THEN '2. Moderate ($30–60K)'
            WHEN income <= 100000 THEN '3. Middle ($60–100K)'
            WHEN income <= 150000 THEN '4. Upper-Middle ($100–150K)'
            ELSE                       '5. High Income (>$150K)'
        END AS income_segment
    FROM loan_portfolio
    WHERE income IS NOT NULL
)
SELECT
    income_segment,
    loan_purpose                                    AS credit_utilization_purpose,
    COUNT(*)                                        AS facility_count,
    ROUND(AVG(Status) * 100, 2)                     AS default_rate_pct,
    ROUND(AVG(loan_amount), 0)                      AS avg_exposure_usd,
    ROUND(AVG(LTV), 2)                              AS avg_ltv,
    ROUND(AVG(dtir1), 2)                            AS avg_dtir_pct,
    -- Relative risk vs portfolio average
    ROUND(
        (AVG(Status) - (SELECT AVG(Status) FROM loan_portfolio)) /
        (SELECT AVG(Status) FROM loan_portfolio) * 100, 1
    )                                               AS relative_risk_vs_portfolio_pct
FROM income_bands
GROUP BY income_segment, loan_purpose
HAVING COUNT(*) >= 50   -- Minimum sample size for statistical reliability
ORDER BY default_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 7: CUMULATIVE LIFT TABLE (MODEL VALIDATION)
-- Business Use: Model discrimination assessment, Lorenz curve data
-- Equivalent to: Cumulative gains chart used in scorecard validation
-- ─────────────────────────────────────────────────────────────────────────────

-- NOTE: Run this after generating predicted PD scores from Python model
-- Assumes a table: model_scores (ID, predicted_pd, actual_status)

/*
WITH decile_scores AS (
    SELECT
        actual_status,
        predicted_pd,
        NTILE(10) OVER (ORDER BY predicted_pd DESC) AS pd_decile
    FROM model_scores
),
decile_agg AS (
    SELECT
        pd_decile,
        COUNT(*)                                    AS total,
        SUM(actual_status)                          AS defaults_captured,
        ROUND(AVG(predicted_pd) * 100, 2)           AS avg_predicted_pd_pct,
        ROUND(AVG(actual_status) * 100, 2)          AS observed_default_rate_pct
    FROM decile_scores
    GROUP BY pd_decile
),
cumulative AS (
    SELECT
        pd_decile,
        total,
        defaults_captured,
        avg_predicted_pd_pct,
        observed_default_rate_pct,
        SUM(total) OVER (ORDER BY pd_decile)        AS cumulative_facilities,
        SUM(defaults_captured) OVER (ORDER BY pd_decile) AS cumulative_defaults,
        ROUND(
            SUM(defaults_captured) OVER (ORDER BY pd_decile) /
            (SELECT SUM(actual_status) FROM model_scores) * 100, 2
        )                                           AS cumulative_default_capture_pct,
        -- Lift = cumulative capture % / % of portfolio reviewed
        ROUND(
            (SUM(defaults_captured) OVER (ORDER BY pd_decile) /
             (SELECT SUM(actual_status) FROM model_scores)) /
            (SUM(total) OVER (ORDER BY pd_decile) /
             (SELECT COUNT(*) FROM model_scores)), 2
        )                                           AS lift
    FROM decile_agg
)
SELECT * FROM cumulative ORDER BY pd_decile;
*/


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 8: INTEREST RATE SPREAD ANALYSIS BY RISK TIER
-- Business Use: Risk-based pricing validation, margin compression monitoring
-- ─────────────────────────────────────────────────────────────────────────────

WITH credit_tiers AS (
    SELECT
        *,
        CASE
            WHEN Credit_Score >= 740              THEN 'AAA–AA (740+)'
            WHEN Credit_Score >= 700              THEN 'A (700–739)'
            WHEN Credit_Score >= 660              THEN 'BBB (660–699)'
            WHEN Credit_Score >= 620              THEN 'BB (620–659)'
            ELSE                                       'B and Below (<620)'
        END AS internal_rating
    FROM loan_portfolio
    WHERE Credit_Score IS NOT NULL
)
SELECT
    internal_rating,
    COUNT(*)                                        AS facility_count,
    ROUND(AVG(Status) * 100, 2)                     AS observed_pd_pct,
    ROUND(AVG(rate_of_interest), 3)                 AS avg_interest_rate_pct,
    ROUND(AVG(Interest_rate_spread), 3)             AS avg_spread_bps_proxy,
    ROUND(AVG(Upfront_charges), 0)                  AS avg_origination_fee_usd,
    ROUND(AVG(loan_amount), 0)                      AS avg_exposure_usd,
    ROUND(AVG(LTV), 2)                              AS avg_ltv_pct,
    -- Expected Loss proxy: PD × LGD (assuming 45% LGD per Basel II standard)
    ROUND(AVG(Status) * 0.45 * 100, 3)             AS expected_loss_proxy_pct
FROM credit_tiers
GROUP BY internal_rating
ORDER BY observed_pd_pct DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 9: REGIONAL PORTFOLIO CONCENTRATION RISK
-- Business Use: Geographic risk diversification, concentration limit monitoring
-- ─────────────────────────────────────────────────────────────────────────────

WITH regional_stats AS (
    SELECT
        Region,
        COUNT(*)                                    AS facility_count,
        SUM(Status)                                 AS total_defaults,
        ROUND(AVG(Status) * 100, 2)                 AS default_rate_pct,
        ROUND(SUM(loan_amount) / 1e6, 2)            AS total_exposure_musd,
        ROUND(AVG(LTV), 2)                          AS avg_ltv,
        ROUND(AVG(Credit_Score), 0)                 AS avg_credit_score,
        ROUND(AVG(income), 0)                       AS avg_income_usd
    FROM loan_portfolio
    WHERE Region IS NOT NULL
    GROUP BY Region
),
portfolio_totals AS (
    SELECT
        SUM(facility_count)                         AS port_total_count,
        SUM(total_exposure_musd)                    AS port_total_exposure_musd
    FROM regional_stats
)
SELECT
    r.Region,
    r.facility_count,
    r.default_rate_pct,
    r.total_exposure_musd,
    -- Concentration ratio
    ROUND(r.facility_count * 100.0 / p.port_total_count, 2)
                                                    AS portfolio_concentration_pct,
    ROUND(r.total_exposure_musd * 100.0 / p.port_total_exposure_musd, 2)
                                                    AS exposure_concentration_pct,
    r.avg_ltv,
    r.avg_credit_score,
    r.avg_income_usd,
    -- Flag if region exceeds 30% portfolio concentration (risk limit)
    CASE WHEN r.facility_count * 100.0 / p.port_total_count > 30
         THEN '⚠️ Concentration Limit Breach'
         ELSE '✅ Within Limit'
    END                                             AS concentration_flag
FROM regional_stats r
CROSS JOIN portfolio_totals p
ORDER BY r.default_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 10: MONTH-END PORTFOLIO MONITORING DASHBOARD (MANAGEMENT REPORTING)
-- Business Use: Monthly credit risk MIS report, board pack data feed
-- Window Functions: LAG, SUM OVER, AVG OVER
-- ─────────────────────────────────────────────────────────────────────────────

WITH portfolio_kpis AS (
    SELECT
        year                                         AS reporting_year,
        COUNT(*)                                     AS total_facilities,
        SUM(Status)                                  AS new_defaults,
        ROUND(AVG(Status) * 100, 2)                  AS default_rate_pct,
        ROUND(AVG(LTV), 2)                           AS avg_portfolio_ltv,
        ROUND(AVG(Credit_Score), 0)                  AS avg_credit_score,
        ROUND(AVG(dtir1), 2)                         AS avg_dtir_pct,
        ROUND(AVG(income), 0)                        AS avg_borrower_income,
        ROUND(SUM(loan_amount) / 1e6, 2)             AS total_origination_musd,
        ROUND(AVG(rate_of_interest), 3)              AS avg_interest_rate_pct,
        -- LTV > 90% concentration
        ROUND(AVG(CASE WHEN LTV > 90 THEN 1.0 ELSE 0 END) * 100, 2)
                                                     AS high_ltv_concentration_pct,
        -- DTIR > 43% concentration
        ROUND(AVG(CASE WHEN dtir1 > 43 THEN 1.0 ELSE 0 END) * 100, 2)
                                                     AS high_dtir_concentration_pct
    FROM loan_portfolio
    WHERE year IS NOT NULL
    GROUP BY year
)
SELECT
    reporting_year,
    total_facilities,
    new_defaults,
    default_rate_pct,
    -- YoY movement in default rate (basis points)
    ROUND(
        (default_rate_pct - LAG(default_rate_pct) OVER (ORDER BY reporting_year)) * 100, 1
    )                                                AS pd_change_bps,
    avg_portfolio_ltv,
    avg_credit_score,
    avg_dtir_pct,
    total_origination_musd,
    avg_interest_rate_pct,
    high_ltv_concentration_pct,
    high_dtir_concentration_pct,
    -- 3-year rolling average PD
    ROUND(AVG(default_rate_pct) OVER (
        ORDER BY reporting_year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                            AS rolling_3yr_avg_pd_pct,
    -- Cumulative portfolio growth
    SUM(total_facilities) OVER (ORDER BY reporting_year)
                                                     AS cumulative_facilities,
    -- Risk classification flag
    CASE
        WHEN default_rate_pct > 30 THEN '🔴 High Risk — Escalate to CRO'
        WHEN default_rate_pct > 20 THEN '🟡 Elevated — Enhanced Monitoring'
        ELSE                            '🟢 Within Appetite'
    END                                              AS portfolio_risk_flag
FROM portfolio_kpis
ORDER BY reporting_year;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 11: TOP 10 HIGHEST EXPOSURE DEFAULT FACILITIES
-- Business Use: Large exposure reporting (Single Obligor Limit monitoring)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    ID                                              AS facility_id,
    loan_amount                                     AS exposure_usd,
    RANK() OVER (ORDER BY loan_amount DESC)         AS exposure_rank,
    loan_purpose                                    AS credit_purpose,
    Status                                          AS default_status,
    LTV                                             AS ltv_pct,
    Credit_Score                                    AS credit_score,
    dtir1                                           AS dtir_pct,
    income                                          AS annual_income_usd,
    Region                                          AS geographic_region,
    rate_of_interest                                AS contractual_rate_pct,
    -- Estimated outstanding loss (EAD × assumed 45% LGD)
    ROUND(loan_amount * 0.45, 0)                    AS estimated_lgd_usd
FROM loan_portfolio
WHERE Status = 1   -- Defaulted facilities only
ORDER BY loan_amount DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────────────────────
-- QUERY 12: IFRS 9 ECL STAGING CLASSIFICATION
-- Business Use: Provisioning calculation, auditor reporting, capital adequacy
-- Stage 1: Performing | Stage 2: SICR | Stage 3: Defaulted
-- ─────────────────────────────────────────────────────────────────────────────

WITH ifrs9_staging AS (
    SELECT
        *,
        CASE
            -- Stage 3: Credit-impaired (defaulted)
            WHEN Status = 1                                      THEN 3
            -- Stage 2: Significant Increase in Credit Risk (SICR)
            WHEN LTV > 90 OR dtir1 > 43 OR Credit_Score < 580   THEN 2
            -- Stage 1: Performing — 12-month ECL
            ELSE                                                      1
        END AS ifrs9_stage,
        CASE
            WHEN Status = 1                                      THEN 'Lifetime ECL (Default)'
            WHEN LTV > 90 OR dtir1 > 43 OR Credit_Score < 580   THEN 'Lifetime ECL (SICR)'
            ELSE                                                      '12-Month ECL'
        END AS ecl_measurement_basis
    FROM loan_portfolio
    WHERE LTV IS NOT NULL AND dtir1 IS NOT NULL AND Credit_Score IS NOT NULL
)
SELECT
    ifrs9_stage                                      AS stage,
    ecl_measurement_basis,
    COUNT(*)                                         AS facility_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)
                                                     AS portfolio_pct,
    ROUND(SUM(loan_amount) / 1e6, 2)                 AS exposure_musd,
    ROUND(AVG(LTV), 2)                               AS avg_ltv,
    ROUND(AVG(Credit_Score), 0)                      AS avg_credit_score,
    ROUND(AVG(dtir1), 2)                             AS avg_dtir,
    -- ECL provision estimate:
    -- Stage 1: 12m PD × LGD × EAD  (assume 12m PD = 5%, LGD=45%)
    -- Stage 2: Lifetime PD × LGD × EAD  (assume lifetime PD = 30%, LGD=45%)
    -- Stage 3: LGD × EAD  (assume LGD=65% for defaulted)
    ROUND(
        SUM(loan_amount) *
        CASE ifrs9_stage
            WHEN 1 THEN 0.05 * 0.45
            WHEN 2 THEN 0.30 * 0.45
            WHEN 3 THEN 0.65
        END / 1e6, 3
    )                                                AS ecl_provision_estimate_musd
FROM ifrs9_staging
GROUP BY ifrs9_stage, ecl_measurement_basis
ORDER BY ifrs9_stage;

-- ============================================================================
-- END OF SQL ANALYTICS LAYER
-- For Power BI integration: Each query above maps to a report page/visual
-- Portfolio KPI → Executive Summary | LTV/DTIR → Risk Deep Dive
-- IFRS9 Staging → Provisioning Report | Regional → Geographic Heat Map
-- ============================================================================
