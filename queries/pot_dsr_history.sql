-- ============================================================
-- pot_dsr_history
-- Serie historica completa del DSR desde pot.sol
--
-- Proposito : Extrae todos los cambios del DSR desde el contrato
--             Pot de MakerDAO, con conversion de RAY a tasa anual.
--             Serie historica completa desde el primer ajuste.
--             Insumo para graficos de series temporales y
--             regresiones de spread DSR/AAVE y DSR/SSR.
--
-- Decodificacion:
--   evento: file(bytes32 what, uint256 data) donde what = "dsr"
--   topic0 = selector file()
--   topic2 = "dsr" en bytes32
--   topic3 = valor del DSR en RAY (1e27)
--   Conversion RAY → APY: (ray^31536000 - 1) * 100
--   Nota: 31536000 = 365 * 24 * 3600 segundos/año (sin leap year)
--
-- Contrato MakerDAO Pot : 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7
-- topic0 file()         : 0x29ae811400000000000000000000000000000000000000000000000000000000
-- topic2 "dsr"          : 0x6473720000000000000000000000000000000000000000000000000000000000
--
-- Fuente    : ethereum.logs (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Seccion 9.2, 9.4
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Version   : v1 · Abril 2026
-- ============================================================

SELECT
    block_time,
    tx_hash,
    bytearray_to_uint256(topic3)                                                        AS dsr_raw,
    CAST(bytearray_to_uint256(topic3) AS DOUBLE) / 1e27                                AS dsr_ray,
    (POWER(CAST(bytearray_to_uint256(topic3) AS DOUBLE) / 1e27, 31536000) - 1) * 100   AS dsr_apy
FROM ethereum.logs
WHERE contract_address = 0x197E90f9FAD81970bA7976f33CbD77088E5D7cf7
  AND topic0           = 0x29ae811400000000000000000000000000000000000000000000000000000000
  AND topic2           = 0x6473720000000000000000000000000000000000000000000000000000000000
ORDER BY block_time ASC
