library(ggplot2)

# --- Parámetros ---
lambda     <- 0.86
delta_emp  <- 0.549
ratio_obs  <- 8.44

# --- Grilla de delta ---
delta_seq <- seq(0.50, 0.85, by = 0.001)

# Fórmulas derivadas del modelo
ein_eout <- (1 / (1 - lambda * delta_seq))
sesgo_p3 <- 1 - (1 - delta_seq)  # = delta_seq, escalado a unidades de alpha

# Escalar sesgo para eje derecho
sesgo_scaled <- sesgo_p3 * (max(ein_eout) - min(ein_eout)) /
  (max(sesgo_p3) - min(sesgo_p3)) *
  (1/1.25) + min(ein_eout) - 0.5

df_sens <- data.frame(
  delta    = delta_seq,
  ein_eout = ein_eout,
  sesgo    = sesgo_scaled
)

# --- Plot ---
p05 <- ggplot(df_sens, aes(x = delta)) +
  geom_line(aes(y = ein_eout, color = "Ein/Eout"), linewidth = 1.0) +
  geom_line(aes(y = sesgo,    color = "Sesgo P3"), linewidth = 1.0,
            linetype = "dashed") +
  geom_vline(xintercept = delta_emp, linetype = "dotted", color = "grey40") +
  annotate("text", x = delta_emp + 0.005, y = 8.5,
           label = paste("delta emp. =", delta_emp),
           color = "grey40", hjust = 0, size = 3.5) +
  scale_color_manual(values = c("Ein/Eout" = "#2166ac",
                                "Sesgo P3" = "#d6604d")) +
  scale_y_continuous(
    name = "Ratio Ein/Eout",
    sec.axis = sec_axis(~ (. - min(df_sens$sesgo)) /
                          (max(df_sens$sesgo) - min(df_sens$sesgo)) *
                          (1.00 - 0.40) + 0.40,
                        name = "Sesgo P3 (unidades de alpha)")
  ) +
  labs(
    title   = "Figura A1. Sensibilidad de Ein/Eout y sesgo P3 en funcion de delta",
    x       = "delta (fraccion programatica del Pot)",
    color   = NULL,
    caption = paste0("lambda = ", lambda, " fijo. ",
                     "Ratio observado = ", ratio_obs,
                     " (Cuadro 2). delta empirico = ", delta_emp,
                     " (Tabla A1).")
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position   = "bottom",
    axis.title.y.left  = element_text(color = "#2166ac"),
    axis.title.y.right = element_text(color = "#d6604d")
  )

ggsave("plots/05_sensibilidad_delta.png", p05,
       width = 9, height = 5.5, dpi = 300)
cat("Guardado.\n")
