# =============================================================================
# 01_chi_simulation.R
# Semana 1 — Simulación del acumulador chi del contrato Pot (MakerDAO)
#
# Contrato Pot: 0x197e90f9fad81970ba7976f33cbd77088e5d7cf7
# Función consultada: dsr() — Read Contract en Etherscan
# Valor obtenido: 1000000000393915525145987602 (uint256, en RAY = 1e27)
# Fecha de consulta: Abril 2026
#
# Verificación directa:
# https://etherscan.io/address/0x197e90f9fad81970ba7976f33cbd77088e5d7cf7#readContract
#
# Especificación del mecanismo:
#   chi_nuevo = chi_viejo * (dsr_por_segundo ^ segundos_transcurridos)
#   DAI_real  = pie * (chi / RAY)
#   pie       = DAI_depositado / (chi_inicial / RAY)
# =============================================================================

library(tidyverse)

# =============================================================================
# BLOQUE 1 — PARÁMETROS DEL CONTRATO
# =============================================================================

# RAY: unidad de precisión del contrato Pot — base 10^27
RAY <- 1e27

# dsr: tasa de acumulación por segundo, expresada en RAY
# Obtenido directamente de dsr() en Etherscan — Read Contract
# Valor: 1000000000393915525145987602
dsr_ray <- 1000000000393915525145987602

# Convertir a factor por segundo (dividir por RAY)
dsr_por_segundo <- dsr_ray / RAY

cat("=== Parámetros del contrato ===\n")
cat("dsr en RAY:        ", dsr_ray, "\n")
cat("dsr por segundo:   ", sprintf("%.27f", dsr_por_segundo), "\n")

# =============================================================================
# BLOQUE 2 — TASA ANUAL IMPLÍCITA
# Verificar qué tasa anual corresponde al dsr por segundo
# Fórmula: tasa_anual = (dsr_por_segundo ^ segundos_en_año) - 1
# =============================================================================

segundos_anio <- 365 * 24 * 3600  # 31,536,000 segundos

tasa_anual <- (dsr_por_segundo ^ segundos_anio) - 1

cat("\n=== Tasa anual implícita ===\n")
cat("Segundos en un año:", segundos_anio, "\n")
cat("Tasa anual:        ", sprintf("%.4f%%", tasa_anual * 100), "\n")

# =============================================================================
# BLOQUE 3 — SIMULACIÓN DEL ACUMULADOR chi
#
# chi NO arranca en 1.0 — ese era el valor al deployment en 2019
# El valor actual se obtiene de chi() en Etherscan — Read Contract
# Función consultada: chi() — Read Contract en Etherscan
# Valor obtenido: 1173958181238644208971857679 (uint256, en RAY = 1e27)
# Fecha de consulta: Abril 2026
#
# Interpretación: desde el deployment el Pot acumuló ~17.39% de interés total
# Tasa promedio histórica implícita: ~2.5-3% anual (períodos en 0%, 8%, 1.24%)
#
# Crece cada vez que se llama drip()
# En la simulación asumimos que drip() se llama cada segundo — caso continuo
# En la práctica drip() se llama con menor frecuencia pero el resultado es
# matemáticamente equivalente por la propiedad de exponenciación
# =============================================================================

chi_ray_actual <- 1173958181238644208971857679  # Valor on-chain consultado en Etherscan
chi_inicial    <- chi_ray_actual / RAY           # Convertir a unidades humanas = 1.1739...

cat("\n=== Chi actual on-chain ===\n")
cat("chi en RAY:     ", chi_ray_actual, "\n")
cat("chi en unidades:", sprintf("%.6f", chi_inicial), "\n")
cat("Interés acumulado desde deployment:", sprintf("%.2f%%", (chi_inicial - 1) * 100), "\n")

# Simular chi para horizontes de tiempo distintos
horizontes <- tibble(
  periodo     = c("1 día", "1 mes", "3 meses", "6 meses", "1 año", "2 años"),
  segundos    = c(86400, 2592000, 7776000, 15552000, 31536000, 63072000),
  chi         = chi_inicial * (dsr_por_segundo ^ segundos),
  acumulacion = chi - chi_inicial
)

cat("\n=== Evolución de chi ===\n")
print(horizontes, n = Inf)

# =============================================================================
# BLOQUE 4 — CASO PRÁCTICO: DEPÓSITO DE 1000 DAI
#
# Flujo del contrato:
#   join(1000 DAI) → el contrato calcula pie = wad / chi_actual
#   exit()         → el contrato devuelve pie * chi_nuevo en DAI
#
# En el momento del depósito chi = chi_inicial = 1.0
# pie queda fijo — no cambia aunque chi suba
# Al retirar, DAI_real = pie * chi_nuevo
# =============================================================================

deposito_dai <- 1000

# pie calculado al momento del depósito con chi actual (no es 1.0 — ya acumuló 17.39%)
# pie = wad / chi_actual — el contrato divide por chi en el momento del join()
pie <- deposito_dai / chi_inicial

cat("\n=== Simulación de depósito de", deposito_dai, "DAI ===\n")
cat("chi actual al depósito:  ", sprintf("%.6f", chi_inicial), "\n")
cat("pie calculado:           ", sprintf("%.4f", pie), "\n")
cat("Nota: pie < 1000 porque chi ya subió desde el deployment\n\n")

resultados <- horizontes |>
  mutate(
    dai_al_retirar = pie * chi,
    interes_ganado = dai_al_retirar - deposito_dai
  ) |>
  select(periodo, chi, dai_al_retirar, interes_ganado)

print(resultados, n = Inf)

# =============================================================================
# BLOQUE 5 — VERIFICACIÓN: CONSISTENCIA CON EL CONTRATO
#
# El contrato usa aritmética de punto fijo en RAY (enteros de 27 dígitos)
# La simulación en R usa punto flotante — hay diferencia mínima de precisión
# Esta diferencia es aceptable para análisis económico
# Para replicación exacta del contrato se necesitaría aritmética entera en RAY
#
# Verificación: con dsr = 1.0 (tasa cero), chi no debe cambiar
# =============================================================================

dsr_cero <- 1.0  # tasa cero — chi debe permanecer en 1.0
chi_cero  <- chi_inicial * (dsr_cero ^ segundos_anio)

cat("\n=== Verificación de consistencia ===\n")
cat("Con dsr = 1.0 (tasa cero), chi después de 1 año:", chi_cero, "\n")
cat("Esperado: 1.0 — diferencia:", chi_cero - 1.0, "\n")

# =============================================================================
# BLOQUE 6 — GRÁFICO: EVOLUCIÓN DE chi EN EL TIEMPO
# =============================================================================

dias <- seq(0, 730, by = 1)  # 2 años día a día

chi_serie <- tibble(
  dia       = dias,
  segundos  = dias * 86400,
  chi       = chi_inicial * (dsr_por_segundo ^ segundos),
  dai_1000  = pie * chi
)

ggplot(chi_serie, aes(x = dia, y = dai_1000)) +
  geom_line(color = "#1F3864", linewidth = 1) +
  geom_hline(yintercept = deposito_dai, linetype = "dashed", color = "gray50") +
  labs(
    title    = "Evolución de 1000 DAI depositados en el Pot",
    subtitle = sprintf("DSR actual: %.2f%% anual | Contrato Pot 0x197e...cf7 | Abril 2026", tasa_anual * 100),
    x        = "Días desde el depósito",
    y        = "DAI acumulado",
    caption  = "Fuente: dsr() consultado directamente en Etherscan — Read Contract"
  ) +
  theme_minimal() +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    plot.caption  = element_text(size = 8,  color = "gray60")
  )

ggsave("chi_simulacion.png", width = 9, height = 5, dpi = 150)

cat("\n✓ Gráfico guardado: chi_simulacion.png\n")
cat("\n--- RESUMEN ---\n")
cat("DSR actual (Abril 2026):", sprintf("%.4f%%", tasa_anual * 100), "anual\n")
cat("Fuente: dsr() en Etherscan — valor uint256:", dsr_ray, "\n")
cat("Script listo para reproducción.\n")
