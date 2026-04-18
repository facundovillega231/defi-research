# defi-research

**Inertial Deposits and Monetary Transmission: A Theory of Programmatic Intermediation**  
*An (S,s) Model of DeFi Deposit Markets with Non-Discretionary Agents*

Facundo Villega · Investigación Independiente · Análisis On-chain · Abril 2026  
Working Paper v10 · JEL: E40 · E52 · G20 · G23 · O33

---

## Resumen

Este repositorio contiene el código de análisis empírico del paper *Inertial Deposits and Monetary Transmission*, que desarrolla un marco teórico formal para mercados monetarios en los que una fracción λ del stock de depósitos es gestionada por contratos autónomos —Agentes Programáticos de Depósito (APD)— que ejecutan lógica predefinida sin intervención humana continua.

El caso empírico es el **Pot de MakerDAO (2023–2025)**: 17.144 millones de DAI persistentes bajo un spread DSR–Fed de −283 puntos básicos en 2H2025, con λ ≈ 0.86 y δ = 0.696 identificado sobre depósitos de sDAI.

---

## Estructura

```
defi-research/
├── README.md
├── .gitignore
├── data/
├── scripts/
│   ├── 01_chi_simulation.R
│   ├── 02_surplus_buffer.R
│   ├── 03_dsr_spread_9.R
│   └── 04_cascade_regression.R
├── plots/
└── results/
```

---

## Scripts

### `02_surplus_buffer.R` — Surplus Buffer como Leading Indicator del DSR

Analiza si la frecuencia semanal de **flap auctions** (proxy del Surplus Buffer) precede los ajustes del DSR.

**Período:** 2020-01-27 a 2025-11-03 · 138 semanas · 28 eventos de cambio DSR

**Resultados principales:**

| Métrica | Valor |
|--------|-------|
| Lag óptimo | 1 semana |
| Correlación | −0.2169 |
| R² ajustado | 0.04 |
| p-value | 0.011 |

El coeficiente del surplus buffer es negativo y significativo (β = −0.005, p = 0.011): mayor actividad de flap auctions se asocia a menor DSR futuro, consistente con la hipótesis de que la transmisión monetaria requiere acción de governance como intermediario.

---

### `03_dsr_spread_9.R` — Spread DSR/AAVE como Predictor del DSR

Regresión múltiple del DSR sobre el conteo de flap auctions y el spread DSR–AAVE.

**Resultados principales:**

| Variable | Coeficiente | p-value |
|----------|------------|---------|
| flap_count | −0.0077 | < 0.001 |
| spread | 0.7337 | < 0.001 |
| R² ajustado | 0.567 | — |

El modelo explica el **56.7% de la varianza** del DSR. El spread DSR–AAVE tiene correlación 0.526 con lag de 1 semana, que decae a cero alrededor de la semana 9–10, consistente con una ventana de transmisión de 2–3 meses.

---

## Marco teórico

El paper demuestra que la persistencia de depósitos bajo spread negativo es consecuencia predecible del diseño óptimo de un APD, formalizado como un problema de política de inventario tipo **(S,s)** con costos asimétricos de activación:

- **Lema 1 (Irreversibilidad Asimétrica):** θ_out < θ_in → banda de inercia endógena
- **Lema 2 (Insensibilidad Marginal):** ∂φ_i/∂r = 0 en región activa
- **Lema 3 (Concentración Endógena):** n* ≤ D_total · r̄ / (ρK) → 2 APDs dominan el 86% del stock

---

## Contacto

Facundo Villega · [facundovillega@proton.me](mailto:facundovillega@proton.me)
