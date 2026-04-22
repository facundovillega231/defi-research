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
│   ├── 01_chi_simulation.R      # chi accumulator simulation
│   ├── 02_surplus_buffer.R      # Surplus Buffer as DSR leading indicator
│   ├── 03_dsr_spread.R          # DSR/Aave USDC spread regression
│   ├── 04_cascade_regression.R  # cascade liquidations panel
│   ├── 05_tabla_a1.R            # δ robustness across fi thresholds (Table A1)
│   └── 06_flujos_p5.R           # net flows by agent class + DSR/SSR spread (P5 test)
├── plots/
└── results/
```

---

## Dune Analytics queries

All queries are public at [dune.com/facundovillega/dunedash](https://dune.com/facundovillega/dunedash).

### Core identification

| Query | Purpose | Output file | Paper section |
|---|---|---|---|
| `PIT_11_delta_por_umbral_v1` | δ robustness across fi ∈ {0.25, 0.50, 1.00} | `tabla_a1_delta.csv` | Table A1 / §9.1 |
| `PIT_A1_composicion_pot_v1` | Pot stock composition by agent class | — | §9.1, Cuadro 1 |
| `PIT_14_flujos_netos_DSR_SSR_v1` | Net daily flows by agent class + DSR/SSR spread | `flujos_p5.csv` | §9.3, P5 test |
| `PIT_13_flujos_por_clase_v1` | Daily flows disaggregated by agent class | — | §9.1 |

### Surplus Buffer and governance

| Query | Purpose | Output file | Paper section |
|---|---|---|---|
| `PIT_A5_ccf_flap_dsr_v1` | CCF: flap auctions vs DSR lag structure | — | §9.4 |
| `PIT_A4_datos_regresion_v1` | Weekly regression panel: flap_count + spread → DSR | `panel_regresion.csv` | §9.4, H4 |
| `PIT_A3_flujos_DSR_SSR_v2` | DSR/SSR dual rate divergence | — | §9.3, Cuadro 3 |
| `gsm_spells_por_anio` | Spell frequency by year (GSM activity) | — | §4.3, Tabla 4.1 |
| `gsm_black_thursday_2020` | Black Thursday spell forensics | — | §4.3 |

### Cascade liquidations

| Query | Purpose | Output file | Paper section |
|---|---|---|---|
| `clipper_eth_a_cascade_intensity` | Cascade intensity: kicks + DAI per period | `cascade_intensity.csv` | §9, Section V |
| `panel_submuestra_b_regression` | Weekly panel regression (Submuestra B, N=36) | — | §9.4 |
| `bt_01` – `bt_10ext` | Black Thursday auction forensics | — | Section V |

### Rates and stock

| Query | Purpose | Output file | Paper section |
|---|---|---|---|
| `pot_dsr_history` | DSR historical series 2023–2025 | `dsr_history.csv` | §9.2, §9.4 |
| `DAI in Pot: accumulated stock and net flow` | Daily stock + net flow | — | §5, §9.1 |

---

## Scripts

### `01_chi_simulation.R` — chi accumulator simulation

Simulates the chi accumulator dynamics under the Pot contract. Validates the continuous compounding logic of `drip()` and the normalization between pie (internal units) and DAI (external units).

### `02_surplus_buffer.R` — Surplus Buffer as DSR leading indicator

Analyzes whether weekly flap auction frequency (Surplus Buffer proxy) precedes DSR adjustments.

Period: 2020-01-27 to 2025-11-03 · 138 weeks · 28 DSR change events

| Metric | Value |
|---|---|
| Optimal lag | 1 week |
| Correlation | −0.2169 |
| Adjusted R² | 0.04 |
| p-value | 0.011 |

The flap count coefficient is negative and significant (β = −0.005, p = 0.011): higher flap auction activity is associated with lower future DSR, consistent with the hypothesis that monetary transmission requires governance action as intermediary.

### `03_dsr_spread.R` — DSR/Aave USDC spread as DSR predictor

Multiple regression of DSR on flap auction count and DSR–Aave USDC spread.

Period: July 2023 – April 2026 · 95 weeks

| Variable | Coefficient | p-value |
|---|---|---|
| flap_count | −0.0077 | < 0.001 |
| spread (DSR–Aave USDC) | 0.7337 | < 0.001 |
| Adjusted R² | 0.576 | — |

The model explains 57.6% of DSR variance. The DSR–Aave USDC spread has correlation 0.526 at lag 1 week, decaying to zero around week 9–10, consistent with a 2–3 month transmission window.

### `04_cascade_regression.R` — cascade liquidations panel

Panel regression on cascade liquidation intensity (Submuestra B: N=36, January 2023 – February 2026). Dependent variable: log kicks per period. HC3 robust standard errors. Two observations excluded as discretionary governance decisions (September 2024 anomaly; May 2025 peak: 28 kicks / 92M DAI).

### `05_tabla_a1.R` — δ robustness (Table A1)

Reads `tabla_a1_delta.csv` (exported from `PIT_11_delta_por_umbral_v1`) and produces Table A1 for the paper. Confirms δ = 0.570 invariant across fi ∈ {0.25, 0.50, 1.00}.

Input: `data/tabla_a1_delta.csv`  
Output: Table A1 (console + `results/tabla_a1.txt`)

### `06_flujos_p5.R` — P5 test: net flows by agent class

Reads `flujos_p5.csv` (exported from `PIT_14_flujos_netos_DSR_SSR_v1`) and runs three OLS models with Newey-West HAC standard errors (lag=5) on APD_formal net daily flows. Control group: Discrecional class.

Input: `data/flujos_p5.csv`  
Output: regression tables (console) + `plots/fig_p5_flujos_clase.png`

---

## Theoretical framework

The paper derives deposit persistence under negative spread as a predictable consequence of optimal APD design, formalized as an (S,s) inventory policy problem with asymmetric activation costs:

- **Lemma 1** (Asymmetric Irreversibility): θ_out < θ_in → endogenous inertia band
- **Lemma 2** (Marginal Insensitivity): ∂φ_i/∂r = 0 in the active region
- **Lemma 3** (Endogenous Concentration): n* ≤ D_total · r̄ / (ρK) → 2 APDs hold 86% of stock

Five falsifiable propositions follow, validated on MakerDAO Pot microdata (2023–2025).

---

## Replication

```r
# Install dependencies
install.packages(c("tidyverse", "sandwich", "lmtest", "knitr", "jsonlite", "httr"))

# Run in order
source("scripts/01_chi_simulation.R")
source("scripts/02_surplus_buffer.R")
source("scripts/03_dsr_spread.R")
source("scripts/04_cascade_regression.R")
source("scripts/05_tabla_a1.R")   # requires data/tabla_a1_delta.csv
source("scripts/06_flujos_p5.R")  # requires data/flujos_p5.csv
```

CSV exports from Dune are not versioned. To replicate, run the corresponding queries at [dune.com/facundovillega/dunedash](https://dune.com/facundovillega/dunedash) and export to `data/`.

---

## Key contracts

| Contract | Address |
|---|---|
| MakerDAO Pot | `0x197e90f9fad81970ba7976f33cbd77088e5d7cf7` |
| sDAI (SavingsDai) | `0x83f20f44975d03b1b09e64809b757c47f942beea` |
| sUSDS | `0xa3931d71877c0e7a3148cb7eb4463524fec27fbd` |
| DSPause (GSM) | `0xbE286431454714F511008713973d3B053A2d38f3` |

---

## Contact

Facundo Villega · facundovillega@proton.me  
Dashboard: [dune.com/facundovillega/dunedash](https://dune.com/facundovillega/dunedash)  
GitHub: [github.com/facundovillega231](https://github.com/facundovillega231)
EOF
