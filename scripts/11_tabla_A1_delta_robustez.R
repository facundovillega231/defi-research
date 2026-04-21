# [1.1] Tabla A1 — δ por criterio de clasificación
total_DAI <- 4.569 + 3.095 + 0.321 + 0.071 + 1.251 + 
  0.130 + 0.172 + 0.000 + 1.568 + 0.000 + 
  6.379 + 0.006 + 0.000 + 0.001 + 0.000 + 
  0.006 + 0.004

# fi >= 1 (excluye fi=0)
vol_fi1 <- total_DAI - 4.569

# fi >= 2 (excluye fi=0 y fi=1)
vol_fi2 <- total_DAI - 4.569 - 3.095

delta_hardcoded <- 0.549
delta_fi1 <- vol_fi1 / total_DAI
delta_fi2 <- vol_fi2 / total_DAI

tabla_A1 <- data.frame(
  criterio = c("Hardcoded (direcciones APD conocidas)",
               "fi >= 1 (frecuencia diaria)",
               "fi >= 2 (alta frecuencia)"),
  delta = round(c(delta_hardcoded, delta_fi1, delta_fi2), 3)
)

print(tabla_A1)
sink("11_tabla_A1_delta_robustez.txt")
cat("PIT v16 · [1.1] · Tabla A1 — δ por criterio de clasificación\n\n")
print(tabla_A1)
cat("\nNota: fi>=2 (0.564) replica casi exactamente el criterio hardcoded (0.549).\n")
cat("fi>=1 sobreestima δ al incluir operadores discrecionales de alta frecuencia.\n")
cat("Rango estimado: 0.549–0.564 excluyendo fi>=1.\n")
sink()
cat("Guardado.\n")