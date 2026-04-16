# =============================================================================
# ANÁLISIS DE REGRESIÓN — SUBMUESTRA B
# Período: ene 2023 – feb 2026 | N = 36
# Obs. excluidas: 2024-03 (delta_dsr = +8.0) y 2025-02 (delta_dsr = -6.5)
# Motivo: governance discrecional sin cascade previo (outliers estructurales)
# =============================================================================

library(tidyverse)
library(sandwich)
library(lmtest)
library(MASS)
library(stargazer)
library(pscl)

# =============================================================================
# 1. DATOS
# =============================================================================

panel <- tribble(
  ~period,    ~delta_dsr, ~log_tab_lag1, ~log_tab_lag2, ~n_kicks_lag1,
  "2023-01",   0,          1.00,          10.49,          0,
  "2023-02",   0,          0.00,          10.49,          0,
  "2023-03",   0,          0.00,           0.00,          0,
  "2023-04",   0,         10.34,           0.00,          2,
  "2023-05",   0,          0.00,          10.34,          0,
  "2023-06",   2.49,       9.86,           0.00,          1,
  "2023-07",  -0.30,       0.00,           9.86,          0,
  "2023-08",   1.81,       0.00,           0.00,          0,
  "2023-09",   0,         14.25,           0.00,          2,
  "2023-10",   0,          9.12,          14.25,          1,
  "2023-11",   0,          0.00,           9.12,          0,
  "2023-12",   0,          0.00,           0.00,          0,
  "2024-01",   0,          0.00,           0.00,          0,
  "2024-02",   0,          0.00,           0.00,          0,
  # "2024-03" EXCLUIDO — governance discrecional (+8.0, sin cascade previo)
  "2024-04",  -3.00,      10.50,           0.00,          1,
  "2024-05",  -2.00,      15.12,          10.50,          3,
  "2024-06",   0,         10.55,          15.12,          1,
  "2024-07",  -1.00,       0.00,          10.55,          0,
  "2024-08",  -1.00,      14.93,           0.00,          3,
  "2024-09",   0,         14.59,          14.93,         10,
  "2024-10",  -0.50,      11.72,          14.59,          2,
  "2024-11",   3.00,       0.00,          11.72,          0,
  "2024-12",   3.00,       0.00,           0.00,          0,
  "2025-01",  -0.25,      14.72,           0.00,          1,
  # "2025-02" EXCLUIDO — governance discrecional (-6.5, sin cascade previo)
  "2025-03",  -1.25,      15.54,           0.00,          6,
  "2025-04",  -0.50,      14.33,          15.54,          8,
  "2025-05",  -0.75,      18.34,          14.33,         28,
  "2025-06",  -0.25,      14.52,          18.34,          1,
  "2025-07",   0,         11.03,          14.52,          1,
  "2025-08",  -0.25,       0.00,          11.03,          0,
  "2025-09",  -0.25,       0.00,           0.00,          0,
  "2025-10",  -0.25,       0.00,           0.00,          0,
  "2025-11",   0,         11.65,           0.00,          1,
  "2025-12",   0,         14.29,          11.65,          8,
  "2026-01",   0,         13.20,          14.29,          2,
  "2026-02",   0,         12.48,          13.20,          2
) %>%
  mutate(
    hubo_cambio   = as.integer(delta_dsr != 0),
    delta_dsr_abs = abs(delta_dsr),
    q_lag1        = cut(log_tab_lag1,
                        breaks = c(-Inf, 0, 10, 14, Inf),
                        labels = c("0 (inactivo)", "1–10", "10–14", ">14"))
  )

cat("N =", nrow(panel), "\n")
cat("Obs excluidas: 2024-03 (delta_dsr=+8.0) y 2025-02 (delta_dsr=-6.5)\n\n")

# =============================================================================
# 2. MODELOS OLS PRINCIPALES (sobre toda la submuestra)
# =============================================================================

m1 <- lm(delta_dsr ~ log_tab_lag1 + log_tab_lag2,                data = panel)
m2 <- lm(delta_dsr ~ log_tab_lag1 + log_tab_lag2 + n_kicks_lag1, data = panel)
m3 <- lm(delta_dsr ~ log_tab_lag1,                               data = panel)

# Función auxiliar: SE y p-values HC3
hc3      <- function(m) coeftest(m, vcov = vcovHC(m, type = "HC3"))
se_hc3   <- function(m) sqrt(diag(vcovHC(m, type = "HC3")))
p_hc3    <- function(m) coeftest(m, vcov = vcovHC(m, type = "HC3"))[, 4]

# =============================================================================
# 3. TABLA STARGAZER
# =============================================================================

# — LaTeX (para el paper) —
stargazer(
  m1, m2, m3,
  type             = "latex",
  title            = "Regresión OLS — Submuestra B (ene 2023–feb 2026, N=36)",
  label            = "tab:reg_submuestraB",
  dep.var.labels   = "\\Delta DSR\\textsubscript{t} (pp)",
  covariate.labels = c(
    "log(tab\\textsubscript{t-1} + 1)",
    "log(tab\\textsubscript{t-2} + 1)",
    "n\\_kicks\\textsubscript{t-1}",
    "Constante"
  ),
  se           = list(se_hc3(m1), se_hc3(m2), se_hc3(m3)),
  p            = list(p_hc3(m1),  p_hc3(m2),  p_hc3(m3)),
  omit.stat    = c("f", "ser"),
  add.lines    = list(
    c("SE robustos", "HC3", "HC3", "HC3"),
    c("Obs. excluidas", "mar-2024, feb-2025", "mar-2024, feb-2025", "mar-2024, feb-2025")
  ),
  star.cutoffs = c(0.10, 0.05, 0.01),
  notes        = "Errores estándar HC3 entre paréntesis. Se excluyen dos episodios de governance discrecional sin cascade previo (mar-2024: $\\Delta$DSR=+8.0; feb-2025: $\\Delta$DSR=-6.5).",
  notes.append = FALSE,
  out          = "tabla_regresion_submuestraB.tex"
)
cat("Tabla LaTeX guardada en tabla_regresion_submuestraB.tex\n")

# — Texto (verificación rápida) —
stargazer(
  m1, m2, m3,
  type         = "text",
  se           = list(se_hc3(m1), se_hc3(m2), se_hc3(m3)),
  p            = list(p_hc3(m1),  p_hc3(m2),  p_hc3(m3)),
  star.cutoffs = c(0.10, 0.05, 0.01)
)

# =============================================================================
# 4. DIAGNÓSTICO: HETEROCEDASTICIDAD
# =============================================================================

cat("\n=== Breusch-Pagan Test (H0: homocedasticidad) ===\n")
for (pair in list(list("M1", m1), list("M2", m2), list("M3", m3))) {
  bp <- bptest(pair[[2]])
  cat(pair[[1]], ": BP =", round(bp$statistic, 4), "| p =", round(bp$p.value, 4), "\n")
}

cat("\n=== White Test (términos cuadráticos e interacciones) ===\n")
white_m1 <- bptest(m1, ~ log_tab_lag1 * log_tab_lag2 + I(log_tab_lag1^2) + I(log_tab_lag2^2), data = panel)
white_m3 <- bptest(m3, ~ log_tab_lag1 + I(log_tab_lag1^2), data = panel)
cat("M1: W =", round(white_m1$statistic, 4), "| p =", round(white_m1$p.value, 4), "\n")
cat("M3: W =", round(white_m3$statistic, 4), "| p =", round(white_m3$p.value, 4), "\n")

# =============================================================================
# 5. DIAGNÓSTICO: AUTOCORRELACIÓN SERIAL (Breusch-Godfrey)
# =============================================================================

cat("\n=== Breusch-Godfrey Test (lag=2) ===\n")
for (pair in list(list("M1", m1), list("M2", m2), list("M3", m3))) {
  bg <- bgtest(pair[[2]], order = 2)
  cat(pair[[1]], ": BG =", round(bg$statistic, 4), "| p =", round(bg$p.value, 4), "\n")
}

# Si hay autocorrelación → SE Newey-West (HAC) como alternativa
cat("\n=== Coeficientes con SE Newey-West (HAC, lag=2) ===\n")
cat("M1:\n"); print(coeftest(m1, vcov = NeweyWest(m1, lag = 2)))
cat("M3:\n"); print(coeftest(m3, vcov = NeweyWest(m3, lag = 2)))

# =============================================================================
# 6. DIAGNÓSTICO: OBSERVACIONES INFLUYENTES (Cook's D)
# =============================================================================

cat("\n=== Distancia de Cook — M3 ===\n")
cook   <- cooks.distance(m3)
umbral <- 4 / nrow(panel)
infl   <- which(cook > umbral)
cat("Umbral (4/N):", round(umbral, 4), "\n")
cat("Observaciones influyentes:", panel$period[infl], "\n")
print(round(cook[infl], 4))

plot(cook, type = "h", main = "Distancia de Cook — M3",
     ylab = "Cook's D", xlab = "Observación")
abline(h = umbral, col = "red", lty = 2)
text(infl, cook[infl], labels = panel$period[infl], pos = 3, cex = 0.7)

# Regresión robusta M-estimator como contraste
cat("\n=== Regresión robusta RLM (M-estimator) — M3 ===\n")
rlm_m3 <- rlm(delta_dsr ~ log_tab_lag1, data = panel)
print(summary(rlm_m3))
cat("\nComparación coeficiente log_tab_lag1:\n")
cat("  OLS:", round(coef(m3)["log_tab_lag1"],    5), "\n")
cat("  RLM:", round(coef(rlm_m3)["log_tab_lag1"], 5), "\n")

# =============================================================================
# 7. MODELO HURDLE (dos etapas)
#    Etapa 1: ¿hubo cambio? (logit)
#    Etapa 2: magnitud del cambio | hubo cambio (OLS condicional)
# =============================================================================

panel_cambio <- panel %>% filter(hubo_cambio == 1)
cat("\n\nN total:", nrow(panel), "| N con cambio:", nrow(panel_cambio), "\n")
cat("Períodos con cambio:", paste(panel_cambio$period, collapse = ", "), "\n\n")

# ── Etapa 1: Logit ──────────────────────────────────────────────────────────

cat("=== DISTRIBUCIÓN hubo_cambio ===\n")
print(table(panel$hubo_cambio))
cat("Proporción con cambio:", round(mean(panel$hubo_cambio), 3), "\n\n")

e1_m1 <- glm(hubo_cambio ~ log_tab_lag1 + log_tab_lag2,               data = panel, family = binomial)
e1_m2 <- glm(hubo_cambio ~ log_tab_lag1 + log_tab_lag2 + n_kicks_lag1, data = panel, family = binomial)
e1_m3 <- glm(hubo_cambio ~ log_tab_lag1,                               data = panel, family = binomial)

cat("=== ETAPA 1: Logit — ¿hubo cambio? ===\n")
for (pair in list(list("E1-M1", e1_m1), list("E1-M2", e1_m2), list("E1-M3", e1_m3))) {
  s <- summary(pair[[2]])
  cat("\n---", pair[[1]], "---\n")
  cat("AIC:", round(s$aic, 2),
      "| McFadden R²:", round(1 - s$deviance / s$null.deviance, 4), "\n")
  print(coeftest(pair[[2]]))
}

cat("\n=== ODDS RATIOS — E1-M1 ===\n")
print(round(exp(cbind(OR = coef(e1_m1), confint.default(e1_m1))), 3))

cat("\n=== PROBABILIDAD PREDICHA por cuartil de log_tab_lag1 ===\n")
pred_logit <- panel %>%
  group_by(q_lag1) %>%
  summarise(
    n      = n(),
    p_obs  = round(mean(hubo_cambio), 3),
    p_pred = round(mean(predict(e1_m1, type = "response")), 3),
    .groups = "drop"
  )
print(pred_logit)

# ── Etapa 2: OLS condicional ─────────────────────────────────────────────────

e2_m1 <- lm(delta_dsr ~ log_tab_lag1 + log_tab_lag2,               data = panel_cambio)
e2_m2 <- lm(delta_dsr ~ log_tab_lag1 + log_tab_lag2 + n_kicks_lag1, data = panel_cambio)
e2_m3 <- lm(delta_dsr ~ log_tab_lag1,                               data = panel_cambio)

cat("\n=== ETAPA 2: OLS condicional — magnitud del cambio ===\n")
for (pair in list(list("E2-M1", e2_m1), list("E2-M2", e2_m2), list("E2-M3", e2_m3))) {
  s <- summary(pair[[2]])
  cat("\n---", pair[[1]], "---\n")
  cat("R²:", round(s$r.squared, 4), "| R² adj:", round(s$adj.r.squared, 4), "\n")
  print(hc3(pair[[2]]))
}

# Robustez RLM en etapa 2
cat("\n=== RLM condicional (M-estimator) — E2-M3 ===\n")
rlm_e2 <- rlm(delta_dsr ~ log_tab_lag1, data = panel_cambio)
print(summary(rlm_e2))
cat("\nComparación E2 coef. log_tab_lag1:\n")
cat("  OLS cond.:", round(coef(e2_m3)["log_tab_lag1"],  5), "\n")
cat("  RLM cond.:", round(coef(rlm_e2)["log_tab_lag1"], 5), "\n")

# Cook's D en etapa 2
cat("\n=== Cook's D — E2-M3 ===\n")
cook2   <- cooks.distance(e2_m3)
umbral2 <- 4 / nrow(panel_cambio)
infl2   <- which(cook2 > umbral2)
cat("Umbral (4/N):", round(umbral2, 4), "\n")
cat("Influyentes:", panel_cambio$period[infl2], "\n")
print(round(cook2[infl2], 4))

# Breusch-Godfrey en etapa 2
cat("\n=== Breusch-Godfrey — Etapa 2 ===\n")
for (pair in list(list("E2-M1", e2_m1), list("E2-M3", e2_m3))) {
  bg <- bgtest(pair[[2]], order = 2)
  cat(pair[[1]], "p =", round(bg$p.value, 4), "\n")
}
