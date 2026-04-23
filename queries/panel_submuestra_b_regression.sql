-- ============================================================
-- panel_submuestra_b_regression
-- Panel mensual Submuestra B: cascade liquidations + DSR
--
-- Proposito : Construye el panel de regresion para la Submuestra B
--             (regimen DSR activo: dic 2022 - feb 2026, N=36).
--             Variables dependiente: n_kicks (liquidaciones cascade)
--             Variables independientes: delta_dsr, log_tab_lag1,
--             log_tab_lag2, cascade_dummy_lag1, n_kicks_lag1.
--
-- Logica:
--   kicks     : evento Kick() en Clipper ETH-A (0xc679...)
--               tab = deuda en RAD (1e45), lot = colateral en WAD (1e18)
--   dsr_raw   : evento file(dsr) en Pot (0x197E...)
--               topic3 = valor en RAY (1e27), convertido a APY
--   cascade_dummy_lag1: 1 si tab_dai del mes anterior >= 10M DAI
--
-- Resultado principal (04_cascade_regression.R):
--   HC3 robust standard errors. N=36 (2 obs excluidas:
--   sep 2024 anomalia governance, may 2025 pico 28 kicks/92M DAI).
--
-- Contratos:
--   Clipper ETH-A : 0xc67963a226eddd77B91aD8c421630A1b0AdFF270
--   MakerDAO Pot  : 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7
--   topic0 Kick() : 0x7c5bfdc0a5e8192f6cd4972f382cec69116862fb62e6abff8003874c58e064b8
--   topic0 file() : 0x29ae811400000000000000000000000000000000000000000000000000000000
--   topic2 dsr    : 0x6473720000000000000000000000000000000000000000000000000000000000
--
-- Periodo   : 2022-12-01 - 2026-02-01
-- Fuente    : ethereum.logs (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Seccion 9.4, Section V
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Version   : v1 · Abril 2026
-- ============================================================

WITH kicks AS (
    SELECT
        DATE_TRUNC('month', block_time)                                         AS period,
        COUNT(*)                                                                AS n_kicks,
        SUM(CAST(bytearray_to_uint256(substr(data, 33, 32)) AS DOUBLE) / 1e45) AS tab_dai,
        SUM(CAST(bytearray_to_uint256(substr(data, 65, 32)) AS DOUBLE) / 1e18) AS lot_eth
    FROM ethereum.logs
    WHERE contract_address = 0xc67963a226eddd77B91aD8c421630A1b0AdFF270
      AND topic0 = 0x7c5bfdc0a5e8192f6cd4972f382cec69116862fb62e6abff8003874c58e064b8
    GROUP BY 1
),
dsr_raw AS (
    SELECT
        DATE_TRUNC('month', block_time)                                                       AS period,
        MAX_BY(
            (POWER(CAST(bytearray_to_uint256(topic3) AS DOUBLE) / 1e27, 31536000) - 1) * 100,
            block_time
        ) AS dsr_apy
    FROM ethereum.logs
    WHERE contract_address = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7
      AND topic0 = 0x29ae811400000000000000000000000000000000000000000000000000000000
      AND topic2 = 0x6473720000000000000000000000000000000000000000000000000000000000
    GROUP BY 1
),
calendar AS (
    SELECT DATE_TRUNC('month', t.m) AS period
    FROM UNNEST(
        SEQUENCE(
            TIMESTAMP '2022-12-01',
            TIMESTAMP '2026-02-01',
            INTERVAL '1' MONTH
        )
    ) AS t(m)
),
dsr_filled AS (
    SELECT
        c.period,
        MAX_BY(d.dsr_apy, d.period) OVER (
            ORDER BY c.period
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS dsr_apy
    FROM calendar c
    LEFT JOIN dsr_raw d ON d.period = c.period
),
dsr_with_delta AS (
    SELECT
        period,
        dsr_apy,
        dsr_apy - LAG(dsr_apy) OVER (ORDER BY period) AS delta_dsr
    FROM dsr_filled
),
base AS (
    SELECT
        c.period,
        COALESCE(k.n_kicks, 0)                                                          AS n_kicks,
        COALESCE(k.tab_dai, 0)                                                          AS tab_dai,
        COALESCE(k.lot_eth, 0)                                                          AS lot_eth,
        d.dsr_apy,
        d.delta_dsr,
        LAG(COALESCE(k.tab_dai, 0), 1) OVER (ORDER BY c.period)                        AS tab_dai_lag1,
        LAG(COALESCE(k.tab_dai, 0), 2) OVER (ORDER BY c.period)                        AS tab_dai_lag2,
        LAG(COALESCE(k.n_kicks,  0), 1) OVER (ORDER BY c.period)                       AS n_kicks_lag1,
        LN(LAG(COALESCE(k.tab_dai, 0), 1) OVER (ORDER BY c.period) + 1)                AS log_tab_lag1,
        LN(LAG(COALESCE(k.tab_dai, 0), 2) OVER (ORDER BY c.period) + 1)                AS log_tab_lag2,
        CASE WHEN LAG(COALESCE(k.tab_dai, 0), 1) OVER (ORDER BY c.period) >= 10000000
             THEN 1 ELSE 0 END                                                          AS cascade_dummy_lag1
    FROM calendar c
    LEFT JOIN kicks          k ON k.period = c.period
    LEFT JOIN dsr_with_delta d ON d.period = c.period
)
SELECT
    period,
    n_kicks,
    tab_dai,
    lot_eth,
    dsr_apy,
    delta_dsr,
    tab_dai_lag1,
    tab_dai_lag2,
    log_tab_lag1,
    log_tab_lag2,
    n_kicks_lag1,
    cascade_dummy_lag1
FROM base
WHERE delta_dsr IS NOT NULL
ORDER BY period ASC
