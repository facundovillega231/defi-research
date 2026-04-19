# ============================================================
# PIT v14 · A5 · CCF flap_count vs DSR
# Figura A3 — lag optimo explicito
# ============================================================

library(httr)
library(jsonlite)
library(ggplot2)

api_key  <- "dJFldd1nrd3H7xhVAphZsZV7Bq0QhQ"
query_id <- "7340706"

# Bajar datos
url_exec <- paste0("https://api.dune.com/api/v1/query/", query_id, "/execute")
res_exec <- POST(url_exec,
                 add_headers("X-Dune-API-Key" = api_key,
                             "Content-Type" = "application/json"),
                 body = "{}", encode = "raw")
execution_id <- content(res_exec)$execution_id
cat("Execution ID:", execution_id, "\n")
Sys.sleep(30)

url_res  <- paste0("https://api.dune.com/api/v1/execution/", execution_id, "/results")
res_data <- GET(url_res, add_headers("X-Dune-API-Key" = api_key))
df_ccf   <- as.data.frame(fromJSON(content(res_data, "text"))$result$rows)

# Limpiar
df_ccf$week    <- as.Date(substr(df_ccf$week, 1, 10))
df_ccf$dsr_pct <- as.numeric(df_ccf$dsr_pct)
df_ccf2        <- df_ccf[!is.na(df_ccf$dsr_pct) & !is.na(df_ccf$flap_count), ]
cat("n semanas:", nrow(df_ccf2), "\n")

# CCF
ccf_result <- ccf(df_ccf2$flap_count, df_ccf2$dsr_pct,
                  lag.max = 16,
                  plot    = FALSE)

# Dataframe para ggplot
df_plot <- data.frame(
  lag = as.numeric(ccf_result$lag),
  acf = as.numeric(ccf_result$acf)
)

# Lag optimo
lag_opt <- df_plot$lag[which.max(abs(df_plot$acf))]
acf_opt <- df_plot$acf[which.max(abs(df_plot$acf))]
cat("Lag optimo:", lag_opt, "semanas\n")
cat("CCF en lag optimo:", round(acf_opt, 4), "\n")

# Significancia IC 95%
n   <- nrow(df_ccf2)
sig <- 1.96 / sqrt(n)

# Figura A3
p_ccf <- ggplot(df_plot, aes(x = lag, y = acf)) +
  geom_hline(yintercept =  0,   color = "gray50") +
  geom_hline(yintercept =  sig, linetype = "dashed", color = "gray60") +
  geom_hline(yintercept = -sig, linetype = "dashed", color = "gray60") +
  geom_segment(aes(xend = lag, yend = 0),
               color = "#2166ac", linewidth = 0.8) +
  geom_point(color = "#2166ac", size = 2) +
  geom_point(data = subset(df_plot, lag == lag_opt),
             color = "#d6604d", size = 3.5) +
  annotate("text",
           x     = lag_opt + 0.5,
           y     = acf_opt + 0.03,
           label = paste0("lag opt. = ", lag_opt, "w"),
           hjust = 0, size = 3.5, color = "#d6604d") +
  scale_x_continuous(breaks = seq(-16, 16, by = 2)) +
  labs(
    x       = "Lag (semanas) — negativo: flap precede DSR",
    y       = "Correlacion cruzada",
    title   = "Figura A3. CCF: flap_count vs DSR",
    caption = paste0("n = ", n, " semanas. ",
                     "Lineas punteadas: IC 95% (+/-1.96/sqrt(n)). ",
                     "Lag optimo = ", lag_opt, " semanas.")
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.caption = element_text(size = 8, color = "gray50"))

print(p_ccf)

ggsave("07_ccf_flap_dsr.png", p_ccf,
       width = 7, height = 4.5, dpi = 300)
ggsave("07_ccf_flap_dsr.pdf", p_ccf,
       width = 7, height = 4.5, device = "pdf")

cat("\nGuardado: 07_ccf_flap_dsr.png y 07_ccf_flap_dsr.pdf\n")