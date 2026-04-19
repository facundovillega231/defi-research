# ============================================================
# PIT v14 · Figura A1 · Sensibilidad Ein/Eout y sesgo P3 vs delta
# ============================================================

library(ggplot2)
library(dplyr)

# Parámetros fijos
lambda    <- 0.86
ratio_obs <- 8.44
delta_emp <- 0.549

# Despejar C = phi·f(theta_in)/alpha del ratio observado
# ratio = 1 + (1-delta)·C / (1-lambda)
# C = (ratio_obs - 1) · (1-lambda) / (1-delta_emp)
C <- (ratio_obs - 1) * (1 - lambda) / (1 - delta_emp)

# Grilla de delta
delta_seq <- seq(0.50, 0.85, by = 0.001)

# Calcular curvas
df <- tibble(
  delta    = delta_seq,
  ratio    = 1 + (1 - delta_seq) * C / (1 - lambda),
  sesgo_p3 = (1 - delta_seq) * C
)

# Escala para eje secundario
scale_factor <- max(df$sesgo_p3) / max(df$ratio)

# ── Figura A1 ──────────────────────────────────────────────
p <- ggplot(df, aes(x = delta)) +
  
  # Curva ratio Ein/Eout (eje izq)
  geom_line(aes(y = ratio, color = "Ein/Eout"),
            linewidth = 0.9) +
  
  # Curva sesgo P3 reescalada (eje der)
  geom_line(aes(y = sesgo_p3 / scale_factor, color = "Sesgo P3"),
            linewidth = 0.9, linetype = "dashed") +
  
  # Línea vertical delta empírico
  geom_vline(xintercept = delta_emp,
             linetype = "dotted", color = "gray40", linewidth = 0.7) +
  
  # Anotación delta empírico
  annotate("text",
           x     = delta_emp + 0.01,
           y     = max(df$ratio) * 0.95,
           label = "delta emp. = 0.549",
           hjust = 0, size = 3.5, color = "gray30") +
  
  # Ejes
  scale_y_continuous(
    name     = "Ratio Ein/Eout",
    sec.axis = sec_axis(
      ~ . * scale_factor,
      name = "Sesgo P3 (unidades de alpha)"
    )
  ) +
  
  scale_color_manual(
    values = c("Ein/Eout" = "#2166ac", "Sesgo P3" = "#d6604d")
  ) +
  
  scale_x_continuous(breaks = seq(0.50, 0.85, by = 0.05)) +
  
  labs(
    x       = "delta (fraccion programatica del Pot)",
    color   = NULL,
    title   = "Figura A1. Sensibilidad de Ein/Eout y sesgo P3 en funcion de delta",
    caption = "lambda = 0.86 fijo. Ratio observado = 8.44 (Cuadro 2). delta empirico = 0.549 (Tabla A1)."
  ) +
  
  theme_minimal(base_size = 11) +
  theme(
    legend.position    = "bottom",
    axis.title.y.right = element_text(color = "#d6604d"),
    axis.title.y.left  = element_text(color = "#2166ac"),
    plot.caption       = element_text(size = 8, color = "gray50")
  )

# Guardar
ggsave("figura_A1_sensibilidad_delta.pdf", p,
       width = 7, height = 4.5, device = cairo_pdf)

ggsave("figura_A1_sensibilidad_delta.png", p,
       width = 7, height = 4.5, dpi = 300)

print(p)
ggsave("figura_A1_sensibilidad_delta.pdf", p,
       width = 7, height = 4.5, device = "pdf")