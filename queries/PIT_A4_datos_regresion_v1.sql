-- ============================================================
-- PIT_A4_datos_regresion_v1
-- Panel diario: flujo DSR_sDAI + tasas DSR/SSR + spread
--
-- Propósito : Construye el panel de regresión para el test P5.
--             Une flujos diarios de DSR_sDAI con tasas DSR y SSR
--             forward-filled, calcula el spread DSR-SSR y la
--             dummy de spread negativo.
--
-- Lógica de tasas:
--   DSR : extraído de maker_ethereum.Pot_call_file (on-chain),
--         convertido de ray (1e27) a tasa anual porcentual.
--         Forward-fill: cada día hereda el último valor conocido.
--   SSR : hardcodeado con fechas de cambio verificadas on-chain
--         (sky_ethereum). Forward-fill igual que DSR.
--
-- Output:
--   day        : fecha
--   flujo_dsr  : joins diarios de DSR_sDAI al Pot (DAI)
--   dsr_pct    : DSR anualizado (%)
--   ssr_pct    : SSR anualizado (%)
--   spread     : DSR - SSR (pp) — negativo desde sep 2024
--   spread_neg : dummy = 1 si spread < 0
--
-- Exportar como: data/panel_regresion_p5.csv → script 12_regresion_spread_neg_P5.R
--
-- Período   : 2024-09-01 – presente
-- Fuente    : maker_ethereum.Pot_call_join, Pot_call_file (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Sección 9.3, Proposición 5
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Versión   : v1 · Abril 2026
-- ============================================================

SELECT
  f.day,
  ROUND(f.flujo_dsr, 2)                                                   AS flujo_dsr,
  ROUND(d.dsr_pct, 4)                                                     AS dsr_pct,
  ROUND(s.ssr_pct, 4)                                                     AS ssr_pct,
  ROUND(d.dsr_pct - s.ssr_pct, 4)                                        AS spread,
  CASE WHEN d.dsr_pct - s.ssr_pct < 0 THEN 1 ELSE 0 END                  AS spread_neg

FROM (
  -- Flujos diarios DSR_sDAI
  SELECT
    DATE_TRUNC('day', call_block_time)   AS day,
    SUM(wad) / 1e18                      AS flujo_dsr
  FROM maker_ethereum.Pot_call_join
  WHERE call_success = TRUE
    AND call_tx_to = 0x83f20f44975d03b1b09e64809b757c47f942beea
    AND call_block_time >= TIMESTAMP '2024-09-01'
  GROUP BY 1
) f

LEFT JOIN (
  -- DSR forward-filled desde Pot_call_file
  SELECT day, dsr_pct
  FROM (
    SELECT
      d.day,
      e.dsr_pct,
      ROW_NUMBER() OVER (PARTITION BY d.day ORDER BY e.day DESC) AS rn
    FROM (
      SELECT DATE_TRUNC('day', call_block_time) AS day
      FROM maker_ethereum.Pot_call_join
      WHERE call_success = TRUE
        AND call_tx_to = 0x83f20f44975d03b1b09e64809b757c47f942beea
        AND call_block_time >= TIMESTAMP '2024-09-01'
      GROUP BY 1
    ) d
    LEFT JOIN (
      SELECT
        DATE_TRUNC('day', call_block_time)                                          AS day,
        (POWER(CAST(data AS DOUBLE) / 1e27, 365.25 * 24 * 3600) - 1) * 100        AS dsr_pct
      FROM maker_ethereum.Pot_call_file
      WHERE call_success = TRUE
    ) e ON e.day <= d.day
  ) t
  WHERE rn = 1
) d ON f.day = d.day

LEFT JOIN (
  -- SSR hardcodeado con fechas de cambio verificadas
  -- Fuente: sky_ethereum governance transactions
  SELECT day, ssr_pct
  FROM (
    SELECT
      d.day,
      e.ssr_pct,
      ROW_NUMBER() OVER (PARTITION BY d.day ORDER BY e.day DESC) AS rn
    FROM (
      SELECT DATE_TRUNC('day', call_block_time) AS day
      FROM maker_ethereum.Pot_call_join
      WHERE call_success = TRUE
        AND call_tx_to = 0x83f20f44975d03b1b09e64809b757c47f942beea
        AND call_block_time >= TIMESTAMP '2024-09-01'
      GROUP BY 1
    ) d
    LEFT JOIN (
      SELECT * FROM (
        VALUES
          (DATE '2024-09-25',  6.25),
          (DATE '2024-10-07',  6.50),
          (DATE '2024-11-18',  8.51),
          (DATE '2024-11-30',  9.51),
          (DATE '2024-12-08', 12.51),
          (DATE '2025-02-11',  8.76),
          (DATE '2025-02-25',  6.50),
          (DATE '2025-03-25',  4.50),
          (DATE '2025-08-04',  4.75),
          (DATE '2025-10-28',  4.50),
          (DATE '2025-11-08',  4.25),
          (DATE '2025-11-11',  4.50),
          (DATE '2025-12-03',  4.25),
          (DATE '2025-12-17',  4.00)
      ) AS t(day, ssr_pct)
    ) e ON e.day <= d.day
  ) t
  WHERE rn = 1
) s ON f.day = s.day

ORDER BY f.day ASC

-- Nota: todo el período sep 2024–presente tiene spread < 0 (spread_neg = 1).
-- La variación identificante para la regresión es el spread en niveles,
-- no la dummy. Ver script 12_regresion_spread_neg_P5.R.
