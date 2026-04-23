-- ============================================================
-- PIT_A3_flujos_DSR_SSR_v2
-- Flujos diarios de joins al Pot por canal + MA7
--
-- Propósito : Calcula flujos diarios de entradas (joins) al Pot
--             para los cuatro canales APD_formal principales,
--             con media móvil de 7 días por canal.
--             Insumo para el Cuadro 3 y la Figura 5.1 del paper.
--
-- Diferencia con PIT_14:
--   PIT_14 calcula flujo NETO (join - exit) por canal.
--   PIT_A3 calcula solo ENTRADAS (joins) con MA7 embebida en SQL.
--   Usar PIT_14 para regresiones, PIT_A3 para visualización
--   de flujos de entrada y comparación entre canales.
--
-- Canales:
--   DSR_sDAI            : 0x83f20f44975d03b1b09e64809b757c47f942beea (SavingsDai)
--   SSR_Spark           : 0x5803199f1085d52d1bb527f24dc1a2744e80a979 (SwapAndDeposit Spark)
--   SSR_dai_distribution: 0x6a1b588b0684dace1f53c5820111f400b3dbfebf (dai_distribution)
--   SSR_USDYieldManager : 0xa230285d5683c74935ad14c446e137c8c8828438 (USDYieldManager)
--
-- Output:
--   day          : fecha (truncada a día)
--   canal        : identificador del caller
--   flujo_M_DAI  : entradas brutas en M DAI
--   flujo_7d_ma  : media móvil 7 días (ventana hacia atrás)
--   n_txs        : número de transacciones
--
-- Período   : 2024-09-01 – presente
-- Fuente    : maker_ethereum.Pot_call_join (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Sección 9.3, Cuadro 3, Figura 5.1
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Versión   : v2 · Abril 2026
-- ============================================================

WITH
-- Paso 1: todos los join() al Pot desde sep 2024
joins AS (
  SELECT
    DATE_TRUNC('day', call_block_time)    AS day,
    call_tx_to                            AS caller,
    CAST(wad AS DOUBLE) / 1e18            AS amount_dai
  FROM maker_ethereum.Pot_call_join
  WHERE call_success = TRUE
    AND call_block_time >= TIMESTAMP '2024-09-01'
),

-- Paso 2: etiquetar por canal (solo los cuatro APD_formal principales)
labeled AS (
  SELECT
    day,
    amount_dai,
    CASE
      WHEN caller = 0x83f20f44975d03b1b09e64809b757c47f942beea THEN 'DSR_sDAI'
      WHEN caller = 0x5803199f1085d52d1bb527f24dc1a2744e80a979 THEN 'SSR_Spark'
      WHEN caller = 0x6a1b588b0684dace1f53c5820111f400b3dbfebf THEN 'SSR_dai_distribution'
      WHEN caller = 0xa230285d5683c74935ad14c446e137c8c8828438 THEN 'SSR_USDYieldManager'
    END AS canal
  FROM joins
  WHERE caller IN (
    0x83f20f44975d03b1b09e64809b757c47f942beea,
    0x5803199f1085d52d1bb527f24dc1a2744e80a979,
    0x6a1b588b0684dace1f53c5820111f400b3dbfebf,
    0xa230285d5683c74935ad14c446e137c8c8828438
  )
),

-- Paso 3: agregar por día y canal
daily AS (
  SELECT
    day,
    canal,
    SUM(amount_dai) / 1e6     AS flujo_M_DAI,
    COUNT(*)                  AS n_txs
  FROM labeled
  GROUP BY day, canal
)

-- Paso 4: agregar MA7 como ventana sobre el diario
SELECT
  day,
  canal,
  flujo_M_DAI,
  AVG(flujo_M_DAI) OVER (
    PARTITION BY canal
    ORDER BY day
    ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
  )                           AS flujo_7d_ma,
  n_txs
FROM daily
ORDER BY day ASC, canal ASC
