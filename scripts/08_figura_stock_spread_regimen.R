library(httr)
library(jsonlite)
library(ggplot2)
library(dplyr)
library(zoo)

api_key  <- "JVUbUaSzUTqymZZuBenlDkaICUdJfZ0Q"
query_id <- "6853568"

# --- Bajar datos stock ---
url_exec <- paste0("https://api.dune.com/api/v1/query/", query_id, "/execute")
res_exec <- POST(url_exec,
                 add_headers("X-Dune-API-Key" = api_key,
                             "Content-Type" = "application/json"),
                 body = "{}", encode = "raw")
execution_id <- content(res_exec)$execution_id
cat("Execution ID:", execution_id, "\n")
Sys.sleep(60)

url_res  <- paste0("https://api.dune.com/api/v1/execution/", execution_id, "/results")
res_data <- GET(url_res, add_headers("X-Dune-API-Key" = api_key))
parsed   <- fromJSON(content(res_data, "text"), flatten = TRUE)
df_stock <- as.data.frame(parsed$result$rows)

# --- Preparar stock ---
df_stock$fecha <- as.Date(df_stock$fecha)
all_dates <- data.frame(fecha = seq(min(df_stock$fecha),
                                    max(df_stock$fecha), by = "day"))
df_stock  <- merge(all_dates, df_stock, by = "fecha", all.x = TRUE)
df_stock$dai_en_pot_millones <- na.locf(df_stock$dai_en_pot_millones,
                                        na.rm = FALSE)

# --- Spread DSR/SSR por forward-fill ---
dsr_changes <- data.frame(
  fecha = as.Date(c("2024-09-25","2024-11-18","2024-12-08",
                    "2025-01-01","2025-03-01","2025-06-01",
                    "2025-09-01","2025-12-01")),
  dsr   = c(5.50, 4.50, 6.50, 4.50, 3.50, 2.00, 1.00, 1.00)
)
ssr_changes <- data.frame(
  fecha = as.Date(c("2024-09-25","2024-10-07","2024-11-18","2024-11-30",
                    "2024-12-08","2025-02-11","2025-02-25","2025-03-25",
                    "2025-08-04","2025-10-28","2025-11-08","2025-11-11",
                    "2025-12-03","2025-12-17")),
  ssr   = c(6.25, 6.50, 8.51, 9.51, 12.51, 8.76, 6.50, 4.50,
            4.75, 4.50, 4.25, 4.50, 4.25, 4.00)
)

all_days <- data.frame(fecha = seq(as.Date("2024-09-01"),
                                   as.Date("2025-12-31"), by = "day"))
all_days <- merge(all_days, dsr_changes, by = "fecha", all.x = TRUE)
all_days <- merge(all_days, ssr_changes, by = "fecha", all.x = TRUE)
all_days$dsr <- na.locf(all_days$dsr, na.rm = FALSE)
all_days$ssr <- na.locf(all_days$ssr, na.rm = FALSE)
all_days$dsr[is.na(all_days$dsr)] <- 5.50
all_days$ssr[is.na(all_days$ssr)] <- 6.25
all_days$spread     <- all_days$dsr - all_days$ssr
all_days$spread_neg <- as.integer(all_days$spread < 0)

# --- Merge stock + spread ---
df_stock2 <- df_stock %>%
  filter(fecha >= as.Date("2024-09-01")) %>%
  rename(day = fecha)

spread_completo <- all_days %>%
  filter(fecha >= as.Date("2024-09-01")) %>%
  rename(day = fecha)

df_plot3 <- merge(spread_completo, df_stock2, by = "day", all.x = TRUE)
df_plot3$dai_en_pot_millones <- na.locf(df_plot3$dai_en_pot_millones,
                                        na.rm = FALSE)

# --- Escala eje derecho ---
k  <- 1500
y0 <- 15300
df_plot3$spread_scaled <- df_plot3$spread * k + y0

# --- Plot ---
p51e <- ggplot(df_plot3, aes(x = day)) +
  geom_vline(xintercept = as.Date("2024-09-25"),
             linetype = "dashed", color = "grey50", linewidth = 0.6) +
  annotate("text", x = as.Date("2024-10-01"), y = 17000,
           label = "DSR < SSR", color = "grey40", hjust = 0, size = 3.5) +
  geom_line(aes(y = dai_en_pot_millones), color = "#2166ac",
            linewidth = 0.9) +
  geom_hline(yintercept = y0, linetype = "dotted",
             color = "#d6604d", linewidth = 0.5) +
  geom_line(aes(y = spread_scaled), color = "#d6604d",
            linewidth = 0.8, linetype = "dashed") +
  scale_y_continuous(
    name     = "Stock DAI en el Pot (M DAI)",
    limits   = c(3000, 18000),
    sec.axis = sec_axis(~ (. - y0) / k,
                        name = "Spread DSR/SSR (pp)")
  ) +
  scale_x_date(date_labels = "%b %Y", date_breaks = "2 months") +
  labs(
    title   = "Figura 5.1. Stock del Pot y spread DSR/SSR",
    x       = NULL,
    caption = "Sep 2024 – Dic 2025. Línea vertical: inicio spread negativo (DSR < SSR). Fuente: Dune Analytics."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.title.y.left  = element_text(color = "#2166ac"),
    axis.title.y.right = element_text(color = "#d6604d"),
    axis.text.x        = element_text(angle = 45, hjust = 1)
  )

ggsave("plots/08_figura_stock_spread_regimen_v2.png", p51e,
       width = 11, height = 6, dpi = 300)
cat("Guardado.\n")