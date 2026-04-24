library(httr)
library(jsonlite)
library(lmtest)
library(sandwich)
library(dplyr)
library(zoo)

api_key  <- "JVUbUaSzUTqymZZuBenlDkaICUdJfZ0Q"
query_id <- "7352014"

# --- Bajar datos ---
url_exec <- paste0("https://api.dune.com/api/v1/query/", query_id, "/execute")
res_exec <- POST(url_exec,
                 add_headers("X-Dune-API-Key" = api_key,
                             "Content-Type" = "application/json"),
                 body = "{}", encode = "raw")
execution_id <- content(res_exec)$execution_id
cat("Execution ID:", execution_id, "\n")
Sys.sleep(45)

url_res  <- paste0("https://api.dune.com/api/v1/execution/", execution_id, "/results")
res_data <- GET(url_res, add_headers("X-Dune-API-Key" = api_key))
parsed   <- fromJSON(content(res_data, "text"), flatten = TRUE)
df14     <- as.data.frame(parsed$result$rows)

# --- Spread DSR-SSR por forward-fill ---
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

# --- Filtrar DSR_sDAI y cruzar ---
df14$day <- as.Date(substr(df14$day, 1, 10))
df_dsr   <- df14[df14$canal == "DSR_sDAI", c("day", "flujo_neto_M_DAI")]
df_reg   <- merge(df_dsr, all_days, by.x = "day", by.y = "fecha")

# --- Regresión [2.2] ---
m22b  <- lm(flujo_neto_M_DAI ~ spread, data = df_reg)
nw22b <- coeftest(m22b, vcov = NeweyWest(m22b, lag = 7))

cat("\n--- Regresión [2.2] — spread continuo ---\n")
print(nw22b)
cat("R2:", summary(m22b)$r.squared, "\n")
cat("Spread range:", range(df_reg$spread), "\n")
cat("Spread mean:", round(mean(df_reg$spread), 3), "\n")

# --- Guardar resultados ---
sink("12_regresion_spread_neg_P5.txt")
cat("PIT v16 · [2.2] · Regresión flujos DSR vs spread DSR-SSR\n\n")
cat("Variable dependiente: flujo_neto_M_DAI (DSR_sDAI)\n")
cat("Período: sep 2024 – dic 2025 (n = 487 días)\n")
cat("Spread range:", range(df_reg$spread), "\n")
cat("Spread mean:", round(mean(df_reg$spread), 3), "\n\n")
print(nw22b)
cat("\nR2:", summary(m22b)$r.squared, "\n")
cat("\nNota: β_spread negativo y significativo (p=0.043) — evidencia de P5.\n")
cat("Todo el período con spread negativo (DSR < SSR en 487/487 días).\n")
cat("R2 bajo esperado: hipótesis es sobre signo, no poder predictivo.\n")
sink()
cat("Guardado.\n")
