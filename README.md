# 🏦 Bank Loan Default Risk Analysis
[![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](YOUR_NOTEBOOK_LINK)
### Credit Risk Analytics · PD Modeling · Basel III / IFRS 9 Framework

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python)](https://python.org)
[![XGBoost](https://img.shields.io/badge/XGBoost-Gradient%20Boosting-orange)](https://xgboost.readthedocs.io)
[![LightGBM](https://img.shields.io/badge/LightGBM-GBDT-green)](https://lightgbm.readthedocs.io)
[![SHAP](https://img.shields.io/badge/SHAP-Explainability-purple)](https://shap.readthedocs.io)
[![SQL](https://img.shields.io/badge/SQL-Advanced%20Queries-red)](https://sqlite.org)
[![Power BI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow?logo=powerbi)](https://powerbi.microsoft.com)

---

## Business Context

Credit risk management is the cornerstone of financial institution stability. Under the **Basel III Internal Ratings-Based (IRB) approach**, banks are mandated to estimate **Probability of Default (PD)**, **Loss Given Default (LGD)**, and **Exposure at Default (EAD)** to maintain adequate **Risk-Weighted Assets (RWA)** and capital buffers.

This project simulates a production-grade **credit risk analytics pipeline** as executed within a Risk Analytics or Decision Science function at a Tier-1 financial institution. The analysis covers **49,278 credit facilities** and delivers:

- Portfolio-level **Expected Credit Loss (ECL)** driver quantification  
- A **PD scoring model** using gradient boosting with full SHAP explainability  
- Borrower **risk tier segmentation** aligned with IFRS 9 staging (Stage 1/2/3)  
- Scorecard validation via **Gini Coefficient**, **KS Statistic**, and **ROC-AUC**  
- **12 advanced SQL queries** covering rolling aggregates, window functions, IFRS 9 provisioning  
- A **3-page Power BI dashboard** with DAX-driven risk KPIs  

---

## Key Risk Findings

| # | Finding | Metric | Business Impact |
|---|---------|--------|-----------------|
| 1 | **Portfolio Default Rate** | 24.39% PD | Subprime-tier portfolio; elevated ECL provisioning required |
| 2 | **LTV > 90% Facilities** | 35.2% default rate | Highest Expected Loss tier; PMI/credit enhancement required |
| 3 | **DTIR > 43% (above CFPB QM Cap)** | ~31% default rate | Breach of Qualified Mortgage standards; policy review needed |
| 4 | **Lowest Income Quintile Borrowers** | ~43% default rate | ~2× portfolio average PD; DSCR thresholds must tighten |
| 5 | **Loan Purpose Segment P2** | 33% default rate | Highest-risk credit utilization segment |
| 6 | **Credit Score Alone** | Weak monotonic PD relationship | Composite scorecard required over score-only underwriting |

---

## Model Performance — Scorecard Validation

| Model | AUC-ROC | Gini Coefficient | KS Statistic | SR 11-7 Status |
|-------|---------|-----------------|--------------|----------------|
| Logistic Regression (Baseline) | ~0.73 | ~0.46 | ~0.38 | ✅ Acceptable |
| **XGBoost (Primary PD Model)** | **~0.87** | **~0.74** | **~0.62** | **✅ Strong** |
| LightGBM (Decisioning Engine) | ~0.86 | ~0.72 | ~0.61 | ✅ Strong |

> **Benchmark:** Gini > 0.40 = Acceptable · Gini > 0.60 = Good · Gini > 0.70 = Strong  
> **Regulatory Alignment:** SR 11-7 Model Risk Management · ECOA Regulation B (adverse action)

---

## Project Architecture

```
loan-default-risk-analysis/
│
├── 📓 loan_default_analysis.ipynb    # Full Python notebook (7 phases)
├── 🗄️  loan_default_sql_queries.sql   # 12 advanced SQL queries
├── 📊 Power_BI_Dashboard.pbix        # 3-page interactive dashboard
├── 📄 Project_Report.docx            # Full technical report
├── 📁 charts/                        # All exported visualizations
│   ├── chart_01_portfolio_pd.png
│   ├── chart_02_ltv_default_rate.png
│   ├── chart_03_income_default_rate.png
│   ├── chart_04_purpose_default_rate.png
│   ├── chart_05_credit_score_analysis.png
│   ├── chart_06_dtir_default_rate.png
│   ├── chart_07_correlation_heatmap.png
│   ├── chart_08_composite_risk_score.png
│   ├── chart_09_roc_ks.png
│   ├── chart_10_shap_summary.png
│   ├── chart_11_shap_bar.png
│   ├── chart_12_shap_waterfall.png
│   └── chart_13_risk_tiers.png
└── README.md
```

---

## Analysis Pipeline (7 Phases)

### Phase 1 — Data Ingestion & Quality Assessment
- Schema audit with regulatory field mapping (Basel III terminology)
- Missing value analysis across 34 attributes
- Data lineage documentation (SR 11-7 model governance)

### Phase 2 — Exploratory Credit Risk Analysis
- Portfolio default rate benchmarking vs. industry (prime / subprime)
- Risk driver identification: LTV, DTIR, income, loan purpose, credit score
- Adverse selection diagnostics in origination pipeline

### Phase 3 — Feature Engineering
- **Derived financial ratios**: Loan-to-Income, Property-to-Income, Fee Loading Ratio
- **Binary stress flags**: High LTV (>90%), DTIR breach (>43%), subprime score (<620)
- **Composite Risk Score**: Additive 5-flag stress indicator validated against observed PD
- Label encoding + median imputation for regulatory-grade missing value treatment

### Phase 4 — PD Model Development
- **Logistic Regression** — interpretable baseline (regulatory scorecard standard)
- **XGBoost** — primary PD model (industry standard for retail credit)
- **LightGBM** — high-volume decisioning alternative
- Stratified K-Fold cross-validation; `scale_pos_weight` for class imbalance

### Phase 5 — Model Validation (SR 11-7)
- **Gini Coefficient** — standard discrimination metric in credit scorecards
- **KS Statistic** — score distribution separation (performing vs. default)
- **ROC-AUC** with threshold sensitivity analysis
- **PR-AUC** for imbalanced class performance

### Phase 6 — SHAP Explainability (ECOA / Reg B Compliance)
- `TreeExplainer` SHAP values for XGBoost PD model
- **Beeswarm plot** — portfolio-level feature attribution
- **Bar chart** — ranked feature importance for model governance
- **Waterfall plot** — individual facility adverse action explainability

### Phase 7 — Business Recommendations & Risk Appetite Framework
- Internal Rating Scale (IRS) mapping: Tier 1 (Prime) → Tier 4 (High Risk)
- Underwriting policy recommendations by risk tier
- IFRS 9 ECL staging assignment (Stage 1/2/3) with provisioning estimates

---

## SQL Analytics Layer (12 Queries)

| Query | Business Use | SQL Techniques |
|-------|-------------|----------------|
| Q1 — Portfolio KPI Summary | Executive dashboard | Aggregation, exposure-weighted PD |
| Q2 — LTV Risk Segmentation | RWA computation | CASE WHEN banding |
| Q3 — Vintage Default Trend | Origination quality | Window: SUM OVER, LAG, rolling AVG |
| Q4 — Composite Risk Driver | Scorecard validation | CTE, multi-flag risk scoring |
| Q5 — Percentile Risk Scoring | Internal rating scale | PERCENT_RANK, NTILE, RANK |
| Q6 — Income × Purpose Matrix | Two-way risk heat map | Cross-segment aggregation |
| Q7 — Cumulative Lift Table | Model validation | Lorenz curve, NTILE deciles |
| Q8 — Spread by Credit Tier | Risk-based pricing | Internal rating mapping, EL proxy |
| Q9 — Regional Concentration | Geographic risk limits | CROSS JOIN, concentration flags |
| Q10 — Management MIS Report | Monthly board pack | LAG, rolling window, risk flags |
| Q11 — Large Exposure Report | Single obligor limits | RANK OVER, LGD estimation |
| Q12 — IFRS 9 ECL Staging | Provisioning, audit | Stage 1/2/3 classification, ECL calc |

---

## Power BI Dashboard Structure

**Page 1 — Executive Credit Risk Summary**
- Portfolio default rate KPI card (vs. 12m target)
- Performing vs. Default donut chart (IFRS 9 stage proxy)
- Default rate trend line by origination vintage
- Top 5 risk region bar chart

**Page 2 — Risk Driver Deep Dive**
- LTV band default rate waterfall chart
- Income quintile vs. PD scatter
- DTIR distribution split by default status
- Composite risk score heat map

**Page 3 — Model Output & IFRS 9 Staging**
- Risk tier distribution (Tier 1–4 donut)
- Predicted vs. Observed PD calibration chart
- IFRS 9 Stage 1/2/3 exposure breakdown
- ECL provision estimate gauge by stage

**Key DAX Measures:**
```dax
Default Rate % = DIVIDE(CALCULATE(COUNT(loan[ID]), loan[Status]=1), COUNT(loan[ID]))

Exposure Weighted PD = 
    DIVIDE(SUMX(loan, loan[loan_amount] * loan[Status]), SUM(loan[loan_amount]))

ECL Provision Stage3 = SUMX(FILTER(loan, loan[IFRS9_Stage]=3), loan[loan_amount] * 0.65)

LTV Breach Flag = IF(loan[LTV] > 90, "High Risk", "Within Limit")

Gini Coefficient = 2 * [AUC_ROC] - 1
```

---

## Regulatory Framework Alignment

| Framework | Application in This Project |
|-----------|---------------------------|
| **Basel III IRB** | PD, LGD, EAD estimation; RWA-proxy segmentation |
| **IFRS 9** | ECL staging (Stage 1/2/3); lifetime vs. 12-month ECL |
| **SR 11-7** | Model governance; Gini/KS discrimination benchmarks |
| **ECOA / Reg B** | SHAP adverse action explainability; fair lending proxy |
| **CFPB QM Rule** | DTIR 43% cap enforcement in risk flag engineering |

---

## Tech Stack

```
Language   : Python 3.10+
ML Models  : XGBoost · LightGBM · Scikit-learn (Logistic Regression)
Explainability : SHAP (TreeExplainer)
Data       : Pandas · NumPy
Viz        : Matplotlib · Seaborn
SQL        : SQLite (compatible with MySQL / PostgreSQL)
BI Tool    : Power BI Desktop (DAX · Power Query)
Dataset    : Kaggle — yasserh/loan-default-dataset (49,278 records)
```

---

## Dataset

**Source:** [Bank Loan Default Dataset — Kaggle](https://www.kaggle.com/datasets/yasserh/loan-default-dataset)  
**Records:** 49,278 credit facilities · 34 attributes  
**Target:** `Status` (1 = Default, 0 = Performing)  
**Portfolio Default Rate:** 24.39%

---

## Author

**Lokesh Gaddam**  
Data Analyst | Credit Risk & Fintech Specialist  
🔗 [GitHub](https://github.com/LokeshGaddam14) · [Portfolio](https://lokeshgaddam14.github.io/Portofolio/index.html)

---

*This project demonstrates end-to-end credit risk analytics capability aligned with the workflows of Risk Analytics, Decision Science, and Model Risk teams at Tier-1 financial institutions including American Express, HSBC, Citi, and JP Morgan.*
