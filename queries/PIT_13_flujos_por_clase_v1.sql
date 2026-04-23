-- PIT_13_flujos_por_clase_v1
-- Flujos diarios al Pot por clase de agente + DSR
--
-- Proposito : Calcula flujos diarios de joins al Pot separados
--             por clase de agente (APD_formal vs Discrecional)
--             con DSR forward-filled. Insumo para el test de
--             elasticidades diferenciales entre clases (P3).
--
-- Resultado principal (09_regresion_elasticidades_clase.R):
--   dsr_interac no significativo (p=0.869)
--   Evidencia de P3 reside en ratio Ein/Eout = 8.44 (Cuadro 2).
--
-- Periodo   : 2023-01-01 - 2025-12-31
-- Fuente    : maker_ethereum.Pot_call_join, Pot_call_file
-- Paper     : Seccion 9.1, P3
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Version   : v1 · Abril 2026

WITH
joins AS (
  SELECT
    DATE_TRUNC('day', call_block_time)    AS day,
    call_tx_to                            AS caller,
    CAST(wad AS DOUBLE) / 1e18            AS amount_dai
  FROM maker_ethereum.Pot_call_join
  WHERE call_success = TRUE
    AND call_block_time >= TIMESTAMP '2023-01-01'
    AND call_block_time <  TIMESTAMP '2026-01-01'
),
classified AS (
  SELECT
    day,
    amount_dai,
    CASE
      WHEN caller IN (
        0x83f20f44975d03b1b09e64809b757c47f942beea,
        0x6a1b588b0684dace1f53c5820111f400b3dbfebf,
        0xa230285d5683c74935ad14c446e137c8c8828438,
        0x5803199f1085d52d1bb527f24dc1a2744e80a979,
        0x4aa42145aa6ebf72e164c9bbc74fbd3788045016,
        0x5f6ae08b8aeb7078cf2f96afb089d7c9f51da47d,
        0x06af07097c9eeb7fd685c692751d5c66db49c215,
        0x52d298ff9e77e71c2eb1992260520e7b15257d99
      ) THEN 'APD_formal'
      ELSE 'Discrecional'
    END AS clase
  FROM joins
),
daily AS (
  SELECT
    day,
    clase,
    SUM(amount_dai) / 1e6     AS flujo_M_DAI
  FROM classified
  GROUP BY day, clase
),
dsr_events AS (
  SELECT
    DATE_TRUNC('day', call_block_time)                                      AS day,
    (POWER(CAST(data AS DOUBLE) / 1e27, 365.25 * 24 * 3600) - 1) * 100    AS dsr_pct
  FROM maker_ethereum.Pot_call_file
  WHERE call_success = TRUE
),
all_days AS (
  SELECT DISTINCT day FROM daily
),
dsr_filled AS (
  SELECT day, dsr_pct
  FROM (
    SELECT
      d.day,
      e.dsr_pct,
      ROW_NUMBER() OVER (PARTITION BY d.day ORDER BY e.day DESC) AS rn
    FROM all_days d
    LEFT JOIN dsr_events e ON e.day <= d.day
  ) t
  WHERE rn = 1
)
SELECT
  d.day,
  d.clase,
  ROUND(d.flujo_M_DAI, 4)               AS flujo_M_DAI,
  ROUND(f.dsr_pct, 4)                   AS dsr_pct
FROM daily d
LEFT JOIN dsr_filled f ON d.day = f.day
ORDER BY d.day ASC, d.clase ASC
