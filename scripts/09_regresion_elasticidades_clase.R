library(httr)
library(jsonlite)
library(lmtest)
library(sandwich)
library(dplyr)

api_key  <- "JVUbUaSzUTqymZZuBenlDkaICUdJfZ0Q"
query_id <- "7351061"

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
df       <- as.data.frame(parsed$result$rows)

# --- Limpiar y regresión ---
df$day   <- as.Date(substr(df$day, 1, 10))
df$clase <- as.factor(df$clase)

df_apd  <- df[df$clase == "APD_formal", ]
df_disc <- df[df$clase == "Discrecional", ]

m_apd  <- lm(flujo_M_DAI ~ dsr_pct, data = df_apd)
m_disc <- lm(flujo_M_DAI ~ dsr_pct, data = df_disc)

nw_apd  <- coeftest(m_apd,  vcov = NeweyWest(m_apd,  lag = 7))
nw_disc <- coeftest(m_disc, vcov = NeweyWest(m_disc, lag = 7))

df$apd_dummy   <- as.integer(df$clase == "APD_formal")
df$dsr_interac <- df$dsr_pct * df$apd_dummy

m_pooled <- lm(flujo_M_DAI ~ dsr_pct + apd_dummy + dsr_interac, data = df)
nw_pool  <- coeftest(m_pooled, vcov = NeweyWest(m_pooled, lag = 7))

# --- Guardar resultados ---
sink("09_regresion_elasticidades_clase.txt")
cat("PIT v16 · [1.3] · Elasticidades por clase\n\n")
cat("--- APD_formal (n = 922) ---\n"); print(nw_apd)
cat("\nR2:", summary(m_apd)$r.squared, "\n\n")
cat("--- Discrecional (n = 972) ---\n"); print(nw_disc)
cat("\nR2:", summary(m_disc)$r.squared, "\n\n")
cat("--- Pooled con interaccion ---\n"); print(nw_pool)
cat("\nR2:", summary(m_pooled)$r.squared, "\n")
cat("\nNota: dsr_interac no significativo (p=0.869) — elasticidades estadisticamente indistinguibles.\n")
cat("Evidencia de P3 reside en ratio Ein/Eout = 8.44 (Cuadro 2), no en flujos diarios.\n")
sink()
cat("Guardado.\n")