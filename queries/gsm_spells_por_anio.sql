-- ============================================================
-- gsm_spells_por_anio
-- Frecuencia anual de spells ejecutados desde el GSM (DSPause)
--
-- Proposito : Cuenta spells ejecutados por ano desde el contrato
--             DSPause. Insumo para la correlacion spells/inercia
--             y la Tabla 4.1 del paper (P3).
--
-- Logica:
--   Un spell es una llamada a exec() en DSPause identificada
--   por el selector 0x168ccd67 en los primeros 4 bytes del input.
--   Se agregan por ano calendario desde 2020.
--
-- Resultado verificado (10_correlacion_spells_inercia.R):
--   2020: 67 spells · 2021: 48 · 2022: 42 · 2023: 30
--   2024: 28 · 2025: 26 · 2026: 7 (parcial a abril 2026)
--   Pearson r = -0.997, p < 0.001
--   Spearman rho = -1.000, p < 0.001
--
-- Contrato DSPause: 0xbE286431454714F511008713973d3B053A2d38f3
-- Selector exec() : 0x168ccd67
--
-- Fuente    : ethereum.traces (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Seccion 4.3, Tabla 4.1, P3
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Version   : v1 · Abril 2026
-- ============================================================

SELECT
    DATE_TRUNC('year', block_time)              AS anio,
    COUNT(*)                                    AS spells_ejecutados,
    MIN(block_time)                             AS primer_spell,
    MAX(block_time)                             AS ultimo_spell
FROM ethereum.traces
WHERE to        = 0xbE286431454714F511008713973d3B053A2d38f3
  AND bytearray_substring(input, 1, 4) = 0x168ccd67
  AND block_time >= TIMESTAMP '2020-01-01 00:00:00'
GROUP BY 1
ORDER BY 1
