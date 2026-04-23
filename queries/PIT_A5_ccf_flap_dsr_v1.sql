-- ============================================================
-- PIT_A5_ccf_flap_dsr_v1
-- Panel semanal: flap auctions vs DSR con lag structure
--
-- Propósito : Construye el panel para la función de correlación
--             cruzada (CCF) entre actividad de flap auctions
--             (proxy del Surplus Buffer) y el DSR.
--             Testea si el Surplus Buffer es leading indicator
--             del DSR con un lag de ~1 semana (H4).
--
-- Lógica:
--   flap_count     : número de flap() por semana desde Vow
--   dsr_pct        : DSR anualizado forward-filled desde Pot_call_file
--   flap_count_lag4w: flap_count con lag de 4 semanas (columna auxiliar)
--
-- Nota técnica:
--   DSR se filtra por what = hex('dsr') en Pot_call_file.
--   La conversión ray→anual usa 31557600 segundos/año (365.25 días).
--   Forward-fill: cada semana hereda el último DSR conocido.
--
-- Output:
--   week             : semana (truncada al lunes)
--   flap_count       : número de flap auctions esa semana
--   dsr_pct          : DSR anualizado (%)
--   flap_count_lag4w : flap_count de 4 semanas atrás
--
-- Script de análisis: 07_ccf_flap_dsr.R
-- Resultado principal (02_surplus_buffer.R):
--   lag óptimo = 1 semana · correlación = −0.2169 · p = 0.011
--
-- Período   : completo desde primer flap auction
-- Fuente    : maker_ethereum.Vow_call_flap, Pot_call_file (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Sección 9.4, H4
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Versión   : v1 · Abril 2026
-- ============================================================

WITH
-- Flap auctions agregadas por semana
flap AS (
  SELECT
    DATE_TRUNC('week', call_block_time)   AS week,
    COUNT(*)                              AS flap_count
  FROM maker_ethereum.Vow_call_flap
  WHERE call_success = TRUE
  GROUP BY 1
),

-- DSR desde Pot_call_file, convertido a tasa anual
dsr_changes AS (
  SELECT
    DATE_TRUNC('week', call_block_time)                                     AS week,
    (POWER(CAST(data AS DOUBLE) / 1e27, 31557600.0) - 1) * 100             AS dsr_annual_pct
  FROM maker_ethereum.Pot_call_file
  WHERE what = X'6473720000000000000000000000000000000000000000000000000000000000'
    AND call_success = TRUE
),

-- Serie de semanas completa desde flap
all_weeks AS (
  SELECT DISTINCT week FROM flap
),

-- Forward-fill DSR a cada semana
dsr_joined AS (
  SELECT
    w.week,
    d.dsr_annual_pct,
    ROW_NUMBER() OVER (PARTITION BY w.week ORDER BY d.week DESC) AS rn
  FROM all_weeks w
  LEFT JOIN dsr_changes d ON d.week <= w.week
),

dsr_filled AS (
  SELECT week, dsr_annual_pct AS dsr_pct
  FROM dsr_joined
  WHERE rn = 1
)

SELECT
  f.week,
  f.flap_count,
  d.dsr_pct,
  LAG(f.flap_count, 4) OVER (ORDER BY f.week)    AS flap_count_lag4w
FROM flap f
LEFT JOIN dsr_filled d ON f.week = d.week
ORDER BY f.week
