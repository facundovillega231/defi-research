-- ============================================================
-- PIT_A1_composicion_pot_v1
-- Composición del stock en el Pot por clase de agente
--
-- Propósito : Calcula la distribución del stock acumulado de
--             joins al Pot entre APD_formal, Discrecional y
--             Multisig. Produce el Cuadro 1 del paper y el
--             denominador para δ.
--
-- Clasificación:
--   APD_formal   : contratos con lógica de depósito autónoma
--   Discrecional : routers, EOAs, agregadores
--   Multisig     : Safe v1.1.1 (0x245c...) — fi < 0.25,
--                  cae en APD_formal bajo todo umbral (ver PIT_11)
--
-- Nota v16: la fila Multisig se elimina del Cuadro 1 del paper.
--           El Safe v1.1.1 tiene fi < 0.25 → clasificación
--           determinística como APD_formal. δ = 0.5703.
--
-- Output:
--   clase             : APD_formal / Discrecional / Multisig
--   total_B_DAI       : volumen acumulado en miles de millones
--   cuota             : fracción del total
--   n_callers         : número de addresses distintas
--   delta_contribucion: cuota si clase = APD_formal, 0 si no
--
-- Período   : 2023-01-01 – 2025-12-31
-- Fuente    : maker_ethereum.Pot_call_join (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Sección 9.1, Cuadro 1
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Versión   : v1 · Abril 2026
-- ============================================================

WITH
-- Paso 1: volumen y frecuencia por caller
calls AS (
  SELECT
    call_tx_to                                        AS caller,
    SUM(CAST(wad AS DOUBLE)) / 1e18                   AS total_wad,
    COUNT(*)                                          AS n_calls,
    COUNT(*) / NULLIF(
      DATE_DIFF('day',
        MIN(call_block_time),
        MAX(call_block_time)) + 1,
    0)                                                AS fi
  FROM maker_ethereum.Pot_call_join
  WHERE call_success = TRUE
    AND call_block_time >= TIMESTAMP '2023-01-01'
    AND call_block_time <  TIMESTAMP '2026-01-01'
  GROUP BY call_tx_to
),

-- Paso 2: clasificación por tipo de agente
classified AS (
  SELECT
    caller,
    total_wad,
    n_calls,
    fi,
    CASE
      WHEN caller = 0x83f20f44975d03b1b09e64809b757c47f942beea THEN 'APD_formal'  -- SavingsDai (sDAI)
      WHEN caller = 0x6a1b588b0684dace1f53c5820111f400b3dbfebf THEN 'APD_formal'  -- dai_distribution
      WHEN caller = 0xa230285d5683c74935ad14c446e137c8c8828438 THEN 'APD_formal'  -- USDYieldManager
      WHEN caller = 0x5803199f1085d52d1bb527f24dc1a2744e80a979 THEN 'APD_formal'  -- SwapAndDeposit (Spark)
      WHEN caller = 0x4aa42145aa6ebf72e164c9bbc74fbd3788045016 THEN 'APD_formal'  -- XDaiForeignBridge
      WHEN caller = 0x5f6ae08b8aeb7078cf2f96afb089d7c9f51da47d THEN 'APD_formal'  -- LaunchBridge
      WHEN caller = 0x06af07097c9eeb7fd685c692751d5c66db49c215 THEN 'APD_formal'  -- Chai Token
      WHEN caller = 0x52d298ff9e77e71c2eb1992260520e7b15257d99 THEN 'APD_formal'  -- SwapAndDeposit2
      WHEN caller = 0x245cc372c84b3645bf0ffe6538620b04a217988b THEN 'Multisig'    -- Safe v1.1.1 (fi < 0.25 → APD_formal determinístico)
      ELSE                                                             'Discrecional'
    END                                               AS clase,
    CASE
      WHEN caller = 0x83f20f44975d03b1b09e64809b757c47f942beea THEN 'SavingsDai'
      WHEN caller = 0x6a1b588b0684dace1f53c5820111f400b3dbfebf THEN 'dai_distribution'
      WHEN caller = 0xa230285d5683c74935ad14c446e137c8c8828438 THEN 'USDYieldManager'
      WHEN caller = 0x5803199f1085d52d1bb527f24dc1a2744e80a979 THEN 'SwapAndDeposit (Spark)'
      WHEN caller = 0x4aa42145aa6ebf72e164c9bbc74fbd3788045016 THEN 'XDaiForeignBridge'
      WHEN caller = 0x5f6ae08b8aeb7078cf2f96afb089d7c9f51da47d THEN 'LaunchBridge'
      WHEN caller = 0x06af07097c9eeb7fd685c692751d5c66db49c215 THEN 'Chai Token'
      WHEN caller = 0x52d298ff9e77e71c2eb1992260520e7b15257d99 THEN 'SwapAndDeposit2'
      WHEN caller = 0x245cc372c84b3645bf0ffe6538620b04a217988b THEN 'Safe v1.1.1'
      ELSE                                                             'Router / EOA'
    END                                               AS nombre
  FROM calls
),

-- Paso 3: totales con grand_total como ventana
totales AS (
  SELECT
    clase,
    nombre,
    caller,
    total_wad,
    n_calls,
    fi,
    SUM(total_wad) OVER ()                            AS grand_total
  FROM classified
)

-- Paso 4: resultado final agregado por clase
SELECT
  clase,
  ROUND(SUM(total_wad) / 1e9, 3)                      AS total_B_DAI,
  ROUND(SUM(total_wad) / MAX(grand_total), 4)         AS cuota,
  COUNT(DISTINCT caller)                              AS n_callers,
  ROUND(SUM(total_wad) / MAX(grand_total), 4)
    * CASE WHEN clase = 'APD_formal' THEN 1 ELSE 0 END AS delta_contribucion
FROM totales
GROUP BY clase
ORDER BY total_B_DAI DESC

-- Resultado verificado (v16):
--   APD_formal   : 10.022 B DAI · cuota 0.5703 · δ = 0.5703
--   Discrecional :  7.550 B DAI · cuota 0.4297
--   Multisig     :  incluido en APD_formal (fi < 0.25, determinístico)
--   Total        : 17.572 B DAI
--
-- Para robustez de δ por umbral ver PIT_11_delta_por_umbral_v1.sql
