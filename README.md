# Inertial Deposits and Monetary Transmission: A Theory of Programmatic Intermediation

**An (S,s) Model of DeFi Deposit Markets with Non-Discretionary Agents**

Facundo Villega · Independent Research · On-chain Analysis · April 2026  
Working Paper v16 · JEL: E40 · E52 · G20 · G23 · O33

---

## Abstract

This repository contains the empirical analysis code for the paper *Inertial Deposits and Monetary Transmission*, which develops a formal theoretical framework for monetary markets in which a fraction λ of the deposit stock is managed by autonomous contracts — Programmatic Deposit Agents (APDs) — that execute predefined logic without continuous human intervention.

The empirical case is the MakerDAO Pot (2023–2025): 17.572 million DAI persistent under a negative DSR/Aave USDC spread sustained through 2H2025, with λ ≈ 0.86 and δ = 0.570 identified on Pot microdata (January 2023 – December 2025). δ is invariant to the frequency threshold fi ∈ {0.25, 0.50, 1.00} used to classify mixed agents (Table A1): the only ambiguous caller (Safe v1.1.1) has fi < 0.25 and falls deterministically into APD_formal under any threshold.

---

## Repository structure

```
defi-research/
├── README.md
├── .gitignore
├── data/                        # CSV exports from Dune (not versioned)
├── scripts/
│   ├── 01_chi_simulation.R
│   ├── 02_surplus_buffer.R
│   ├── 03_dsr_spread.R
│   ├── 04_cascade_regression.R
│   ├── 05_sensibilidad_delta.R
│   ├── 06_regresion_spread.R
│   ├── 07_ccf_flap_dsr.R
│   ├── 08_figura_stock_spread_regimen.R
│   ├── 09_regresion_elasticidades_clase.R
│   ├── 10_correlacion_spells_inercia.R
│   ├── 11_regresion_spread_neg_P5.R
│   └── 12_flujos_DSR_SSR.R
├── queries/
│   ├── PIT_11_delta_por_umbral_v1.sql
│   ├── PIT_13_flujos_por_clase_v1.sql
│   ├── PIT_14_flujos_netos_DSR_SSR_v1.sql
│   ├── PIT_A1_composicion_pot_v1.sql
│   ├── PIT_A3_flujos_DSR_SSR_v2.sql
│   ├── PIT_A4_datos_regresion_v1.sql
│   ├── PIT_A5_ccf_flap_dsr_v1.sql
│   ├── clipper_eth_a_cascade_intensity.sql
│   ├── gsm_spells_por_anio.sql
│   ├── panel_submuestra_b_regression.sql
│   └── pot_dsr_history.sql
├── plots/
│   ├── 01_surplus_dsr_eventos.png
│   ├── 02_correlacion_lags.png
│   ├── 03_spread_dsr_aave.png
│   ├── 04_cooks_d_m3.png
│   ├── 05_sensibilidad_delta.png
│   ├── 08_figura_stock_spread_regimen.png
│   └── 12_flujos_DSR_SSR.png
└── results/
```

---

## Dune Analytics queries

All queries are public at [dune.com/facundovillega/dunedash](https://dune.com/facundovillega/dunedash).

### Core identification

| Query | Purpose | Paper section |
|---|---|---|
| `PIT_11_delta_por_umbral_v1.sql` | delta robustness across fi in {0.25, 0.50, 1.00} | Table A1 / §9.1 |
| `PIT_A1_composicion_pot_v1.sql` | Pot stock composition by agent class | §9.1, Cuadro 1 |
| `PIT_13_flujos_por_clase_v1.sql` | Daily flows by agent class + DSR | §9.1, P3 |

### DSR/SSR flows and spread

| Query | Purpose | Paper section |
|---|---|---|
| `PIT_14_flujos_netos_DSR_SSR_v1.sql` | Net daily flows by canal + DSR/SSR | §9.3, P5 |
| `PIT_A3_flujos_DSR_SSR_v2.sql` | Daily join flows by canal + MA7 | §9.3, Cuadro 3 |
| `PIT_A4_datos_regresion_v1.sql` | Regression panel: flow + DSR/SSR spread | §9.3, P5 |

### Surplus Buffer and governance

| Query | Purpose | Paper section |
|---|---|---|
| `PIT_A5_ccf_flap_dsr_v1.sql` | CCF: flap auctions vs DSR lag structure | §9.4 |
| `gsm_spells_por_anio.sql` | Spell frequency by year (GSM activity) | §4.3, Tabla 4.1 |

### Cascade liquidations

| Query | Purpose | Paper section |
|---|---|---|
| `panel_submuestra_b_regression.sql` | Monthly panel Submuestra B (N=36) | §9.4, Section V |
| `clipper_eth_a_cascade_intensity.sql` | Cascade intensity: kicks + DAI per month | Section V |

### Rates and stock

| Query | Purpose | Paper section |
|---|---|---|
| `pot_dsr_history.sql` | DSR historical series (complete) | §9.2, §9.4 |

---

## Scripts

### `01_chi_simulation.R` — chi accumulator simulation
Simulates chi accumulator dynamics under the Pot contract. Validates the continuous compounding logic of `drip()` and the normalization between pie (internal units) and DAI (external units).

### `02_surplus_buffer.R` — Surplus Buffer as DSR leading indicator
Analyzes whether weekly flap auction frequency precedes DSR adjustments.

Period: 2020-01-27 to 2025-11-03 · 138 weeks · 28 DSR change events

| Metric | Value |
|---|---|
| Optimal lag | 1 week |
| Correlation | -0.2169 |
| Adjusted R2 | 0.04 |
| p-value | 0.011 |

### `03_dsr_spread.R` — DSR/Aave USDC spread as DSR predictor
Multiple regression of DSR on flap auction count and DSR–Aave USDC spread.

Period: July 2023 – April 2026 · 95 weeks

| Variable | Coefficient | p-value |
|---|---|---|
| flap_count | -0.0077 | < 0.001 |
| spread (DSR–Aave USDC) | 0.7337 | < 0.001 |
| Adjusted R2 | 0.576 | — |

### `04_cascade_regression.R` — cascade liquidations panel
Panel regression on cascade liquidation intensity (Submuestra B: N=36, January 2023 – February 2026). Dependent variable: log kicks per period. HC3 robust standard errors. Two observations excluded as discretionary governance decisions (September 2024 anomaly; May 2025 peak: 28 kicks / 92M DAI).

### `05_sensibilidad_delta.R` — sensitivity of Ein/Eout and P3 bias
Plots Figure A1: sensitivity of the Ein/Eout ratio and P3 bias as a function of delta, with lambda = 0.86 fixed. Marks the empirical delta = 0.570 on the curve.

Output: `plots/05_sensibilidad_delta.png`

### `06_regresion_spread.R` — regression flow_dsr ~ spread
OLS regression of daily DSR_sDAI flows on DSR/SSR spread with Newey-West HAC standard errors (lag=7). Two models: spread only (M3), spread + controls (M4).

Input: Dune query 7338580  
Output: `results/06_regresion_spread_resultados.txt`

### `07_ccf_flap_dsr.R` — CCF flap auctions vs DSR
Downloads weekly panel from Dune (query 6980514) and computes cross-correlation function between flap auction count and DSR for lags 1–12 weeks.

Output: `plots/02_correlacion_lags.png`

### `08_figura_stock_spread_regimen.R` — Figure 5.1: Pot stock + spread
Downloads daily Pot stock from Dune (query 6853568), merges with hardcoded DSR/SSR change dates, and plots Figure 5.1 with dual y-axis (stock left, spread right).

Input: Dune query 6853568  
Output: `plots/08_figura_stock_spread_regimen.png`

### `09_regresion_elasticidades_clase.R` — elasticities by agent class
Downloads daily flows by class from Dune (query 7351061) and runs three OLS models with Newey-West HAC (lag=7): APD_formal only, Discrecional only, and pooled with interaction term.

Key result: dsr_interac not significant (p=0.869) — elasticities statistically indistinguishable between classes in daily flows. Evidence for P3 resides in Ein/Eout ratio = 8.44 (Cuadro 2).

Output: `results/09_regresion_elasticidades_clase.txt`

### `10_correlacion_spells_inercia.R` — spells/year vs inertia duration
Computes Pearson and Spearman correlations between annual spell count and average inertia duration (2020–2026).

Key result: Spearman rho = -1.000, p < 0.001 — monotonic correlation, direct evidence for P3.

Output: `results/10_correlacion_spells_inercia.txt`

### `11_regresion_spread_neg_P5.R` — P5 test: flow DSR_sDAI ~ spread DSR-SSR
Downloads daily panel from Dune (query 7352014), merges with hardcoded DSR/SSR series, and runs OLS regression of DSR_sDAI net flows on spread (continuous). Newey-West HAC (lag=7).

Period: September 2024 – December 2025 (n=487 days, all with spread < 0)  
Key result: beta_spread negative and significant (p=0.043) — empirical evidence for P5.

Output: `results/11_regresion_spread_neg_P5.txt`

### `12_flujos_DSR_SSR.R` — Figure 2.1: net daily flows by canal
Downloads daily net flows by canal from Dune (query 7358680) and plots 7-day moving average for all four APD_formal canals (DSR_sDAI, SSR_Spark, SSR_dai_distribution, SSR_USDYieldManager).

Note: SSR_USDYieldManager included — 32.8% of cumulative absolute volume (verified with PIT_14_volume_check_v1.sql).

Input: Dune query 7358680  
Output: `plots/12_flujos_DSR_SSR.png`

---

## Theoretical framework

The paper derives deposit persistence under negative spread as a predictable consequence of optimal APD design, formalized as an (S,s) inventory policy problem with asymmetric activation costs:

- **Lemma 1** (Asymmetric Irreversibility): theta_out < theta_in → endogenous inertia band
- **Lemma 2** (Marginal Insensitivity): d(phi_i)/d(r) = 0 in the active region
- **Lemma 3** (Endogenous Concentration): n* ≤ D_total · r_bar / (rho·K) → 2 APDs hold 86% of stock

Five falsifiable propositions follow, validated on MakerDAO Pot microdata (2023–2025).

---

## Replication

```r
# Install dependencies
install.packages(c("tidyverse", "sandwich", "lmtest", "knitr",
                   "jsonlite", "httr", "zoo", "ggplot2"))

# Set working directory to repo root
setwd("path/to/defi-research")

# Run in order — each script is autonomous (loads data via Dune API)
source("scripts/01_chi_simulation.R")
source("scripts/02_surplus_buffer.R")
source("scripts/03_dsr_spread.R")
source("scripts/04_cascade_regression.R")
source("scripts/05_sensibilidad_delta.R")
source("scripts/06_regresion_spread.R")
source("scripts/07_ccf_flap_dsr.R")
source("scripts/08_figura_stock_spread_regimen.R")
source("scripts/09_regresion_elasticidades_clase.R")
source("scripts/10_correlacion_spells_inercia.R")
source("scripts/11_regresion_spread_neg_P5.R")
source("scripts/12_flujos_DSR_SSR.R")
```

Each script loads data autonomously via the Dune Analytics API. Set `api_key` in each script before running. Dune query IDs are documented in each script header and in the queries table above.

---

## Key contracts

| Contract | Address |
|---|---|
| MakerDAO Pot | `0x197e90f9fad81970ba7976f33cbd77088e5d7cf7` |
| sDAI (SavingsDai) | `0x83f20f44975d03b1b09e64809b757c47f942beea` |
| sUSDS | `0xa3931d71877c0e7a3148cb7eb4463524fec27fbd` |
| Clipper ETH-A | `0xc67963a226eddd77b91ad8c421630a1b0adff270` |
| DSPause (GSM) | `0xbE286431454714F511008713973d3B053A2d38f3` |

---

## Contact

Facundo Villega · facundovillega@proton.me  
Dashboard: [dune.com/facundovillega/dunedash](https://dune.com/facundovillega/dunedash)  
GitHub: [github.com/facundovillega231](https://github.com/facundovillega231)
