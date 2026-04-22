-- ============================================================
-- PIT_14_flujos_netos_DSR_SSR_v1
-- Flujos netos diarios al Pot por canal + DSR/SSR
--
-- Propósito : Calcula flujos netos diarios (join - exit) para
--             los cuatro callers APD_formal principales,
--             desagregados por canal. Base empírica para el
--             test de la Proposición 5 (P5): fragmentación de
--             la palanca monetaria bajo spread DSR < SSR.
--
-- Canales identificados:
--   DSR_sDAI           : 0x83f20f44975d03b1b09e64809b757c47f942beea (SavingsDai)
--   SSR_Spark          : 0x5803199f1085d52d1bb527f24dc1a2744e80a979 (SwapAndDeposit Spark)
--   SSR_dai_distribution: 0x6a1b588b0684dace1f53c5820111f400b3dbfebf (dai_distribution)
--   SSR_USDYieldManager: 0xa230285d5683c74935ad14c446e137c8c8828438 (USDYieldManager)
--
-- Nota: estos cuatro callers son todos APD_formal según la
--       clasificación de PIT_11. La distinción DSR/SSR en el
--       nombre del canal refleja el instrumento de destino
--       económico, no una diferencia en clase de agente.
--
-- Output:
--   day           : fecha (truncada a día)
--   canal         : identificador del caller
--   flujo_neto_M_DAI : join - exit en millones de DAI
--   entradas_M_DAI   : solo joins
--   salidas_M_DAI    : solo exits (negativo)
--
-- Período   : 2024-09-01 – presente (desde primera divergencia DSR < SSR)
-- Fuente    : maker_ethereum.Pot_call_join / Pot_call_exit (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Sección 9.3, Proposición 5, Cuadro 3
-- Siguiente : exportar como data/flujos_p5.csv → script 06_flujos_p5.R
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Versión   : v1 · Abril 2026
-- ============================================================

WITH
joins AS (
  SELECT
    DATE_TRUNC('day', call_block_time) AS day,
    call_tx_to                         AS caller,
    CAST(wad AS DOUBLE) / 1e18         AS amount_dai,
    'join'                             AS tipo
  FROM maker_ethereum.Pot_call_join
  WHERE call_success = TRUE
    AND call_block_time >= TIMESTAMP '2024-09-01'
    AND call_tx_to IN (
      0x83f20f44975d03b1b09e64809b757c47f942beea,
      0x5803199f1085d52d1bb527f24dc1a2744e80a979,
      0x6a1b588b0684dace1f53c5820111f400b3dbfebf,
      0xa230285d5683c74935ad14c446e137c8c8828438
    )
),

exits AS (
  SELECT
    DATE_TRUNC('day', call_block_time) AS day,
    call_tx_to                         AS caller,
    CAST(wad AS DOUBLE) / 1e18         AS amount_dai,
    'exit'                             AS tipo
  FROM maker_ethereum.Pot_call_exit
  WHERE call_success = TRUE
    AND call_block_time >= TIMESTAMP '2024-09-01'
    AND call_tx_to IN (
      0x83f20f44975d03b1b09e64809b757c47f942beea,
      0x5803199f1085d52d1bb527f24dc1a2744e80a979,
      0x6a1b588b0684dace1f53c5820111f400b3dbfebf,
      0xa230285d5683c74935ad14c446e137c8c8828438
    )
),

all_flows AS (
  SELECT * FROM joins
  UNION ALL
  SELECT * FROM exits
),

labeled AS (
  SELECT
    day,
    CASE
      WHEN caller = 0x83f20f44975d03b1b09e64809b757c47f942beea THEN 'DSR_sDAI'
      WHEN caller = 0x5803199f1085d52d1bb527f24dc1a2744e80a979 THEN 'SSR_Spark'
      WHEN caller = 0x6a1b588b0684dace1f53c5820111f400b3dbfebf THEN 'SSR_dai_distribution'
      WHEN caller = 0xa230285d5683c74935ad14c446e137c8c8828438 THEN 'SSR_USDYieldManager'
    END AS canal,
    CASE WHEN tipo = 'join' THEN amount_dai ELSE -amount_dai END AS flujo_dai
  FROM all_flows
)

SELECT
  day,
  canal,
  ROUND(SUM(flujo_dai) / 1e6, 4)                                          AS flujo_neto_M_DAI,
  ROUND(SUM(CASE WHEN flujo_dai > 0 THEN flujo_dai ELSE 0 END) / 1e6, 4) AS entradas_M_DAI,
  ROUND(SUM(CASE WHEN flujo_dai < 0 THEN flujo_dai ELSE 0 END) / 1e6, 4) AS salidas_M_DAI
FROM labeled
GROUP BY day, canal
ORDER BY day ASC, canal ASC

-- Exportar como: data/flujos_p5.csv
-- Para el test P5 completo (con spread DSR/SSR y grupo control Discrecional)
-- ver script 06_flujos_p5.R y query PIT_A3_flujos_DSR_SSR_v2
