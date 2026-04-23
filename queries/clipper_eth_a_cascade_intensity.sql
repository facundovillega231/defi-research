-- ============================================================
-- clipper_eth_a_cascade_intensity
-- Intensidad mensual de cascade liquidations en Clipper ETH-A
--
-- Proposito : Agrega el evento Kick() del Clipper ETH-A por mes,
--             calculando numero de kicks, deuda total liquidada
--             (tab en DAI) y colateral capturado (lot en ETH).
--             Insumo para el analisis de cascade liquidations
--             en Section V del paper.
--
-- Decodificacion del evento Kick():
--   event Kick(uint256 indexed id, uint256 top, uint256 tab,
--              uint256 lot, address indexed usr,
--              address indexed kpr, uint256 coin)
--   data layout: top[0:32] | tab[32:64] | lot[64:96] | coin[96:128]
--   tab en RAD (1e45) → dividir por 1e45 para obtener DAI
--   lot en WAD (1e18) → dividir por 1e18 para obtener ETH
--
-- Contrato Clipper ETH-A : 0xc67963a226eddd77B91aD8c421630A1b0AdFF270
-- topic0 Kick()          : 0x7c5bfdc0a5e8192f6cd4972f382cec69116862fb62e6abff8003874c58e064b8
--
-- Fuente    : ethereum.logs (Dune Analytics)
-- Dashboard : dune.com/facundovillega/dunedash
-- Paper     : Section V, cascade liquidations
-- Autor     : Facundo Villega · github.com/facundovillega231
-- Version   : v1 · Abril 2026
-- ============================================================

SELECT
    DATE_TRUNC('month', block_time)                                             AS period,
    COUNT(*)                                                                    AS n_kicks,
    SUM(CAST(bytearray_to_uint256(substr(data, 33, 32)) AS DOUBLE) / 1e45)     AS tab_dai,
    SUM(CAST(bytearray_to_uint256(substr(data, 65, 32)) AS DOUBLE) / 1e18)     AS lot_eth
FROM ethereum.logs
WHERE contract_address = 0xc67963a226eddd77B91aD8c421630A1b0AdFF270
  AND topic0           = 0x7c5bfdc0a5e8192f6cd4972f382cec69116862fb62e6abff8003874c58e064b8
GROUP BY DATE_TRUNC('month', block_time)
ORDER BY 1 ASC
