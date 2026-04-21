# [3.1] Spells/año vs duración inercia
df31 <- data.frame(
  anio    = 2020:2026,
  spells  = c(67, 48, 42, 30, 28, 26, 7),
  dias_prom = c(5.0, 6.7, 8.3, 11.4, 12.9, 13.8, 16.7)
)

cor_pearson  <- cor.test(df31$spells, df31$dias_prom, method = "pearson")
cor_spearman <- cor.test(df31$spells, df31$dias_prom, method = "spearman")

cat("Pearson r:", round(cor_pearson$estimate, 3),
    "p =", round(cor_pearson$p.value, 4), "\n")
cat("Spearman rho:", round(cor_spearman$estimate, 3),
    "p =", round(cor_spearman$p.value, 4), "\n")
sink("10_correlacion_spells_inercia.txt")
cat("PIT v16 · [3.1] · Spells/año vs duración inercia\n\n")
print(df31)
cat("\nPearson r:", round(cor_pearson$estimate, 3),
    "p =", round(cor_pearson$p.value, 4), "\n")
cat("Spearman rho:", round(cor_spearman$estimate, 3),
    "p =", round(cor_spearman$p.value, 4), "\n")
cat("\nNota: correlación monotónica perfecta (rho=-1) — evidencia directa de P3.\n")
sink()
cat("Guardado.\n")