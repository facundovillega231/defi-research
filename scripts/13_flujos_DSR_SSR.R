library(ggplot2)

# --- Preparar datos ---
df_plot <- df14 %>%
  filter(canal %in% c("DSR_sDAI", "SSR_Spark", "SSR_dai_distribution")) %>%
  mutate(canal = recode(canal,
                        "DSR_sDAI"            = "DSR (sDAI)",
                        "SSR_Spark"           = "SSR (Spark)",
                        "SSR_dai_distribution" = "SSR (dai_distribution)"
  ))

# MA 7 días por canal
df_plot <- df_plot %>%
  arrange(canal, day) %>%
  group_by(canal) %>%
  mutate(ma7 = zoo::rollmean(flujo_neto_M_DAI, 7, fill = NA, align = "right")) %>%
  ungroup()

# --- Figura [2.1] ---
p21 <- ggplot(df_plot, aes(x = day, y = ma7, color = canal)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  scale_color_manual(values = c(
    "DSR (sDAI)"            = "#2166ac",
    "SSR (Spark)"           = "#d6604d",
    "SSR (dai_distribution)" = "#f4a582"
  )) +
  labs(
    title    = "Flujos netos diarios al Pot por canal (MA 7 días)",
    subtitle = "Sep 2024 – Dic 2025 · DSR vs SSR",
    x        = NULL,
    y        = "Flujo neto (M DAI)",
    color    = NULL,
    caption  = "Fuente: Dune Analytics · PIT v16 [2.1]"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom")

ggsave("plots/13_flujos_DSR_SSR.png", p21,
       width = 10, height = 5, dpi = 300)
cat("Guardado.\n")