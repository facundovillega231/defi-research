library(httr)
library(jsonlite)
library(lmtest)
library(sandwich)

api_key  <- "EIiiHAxbPYbsDnZwLTUIwVhja2q8b2Om"
query_id <- "7338580"

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
df       <- as.data.frame(fromJSON(content(res_data, "text"))$result$rows)

df$day       <- as.Date(substr(df$day, 1, 10))
df$ssr_pct   <- as.numeric(df$ssr_pct)
df$spread    <- as.numeric(df$spread)
df$flujo_dsr <- df$flujo_dsr / 1e6
df_reg       <- na.omit(df)

m3  <- lm(flujo_dsr ~ spread,                     data = df_reg)
m4  <- lm(flujo_dsr ~ spread + dsr_pct + ssr_pct, data = df_reg)
nw3 <- coeftest(m3, vcov = NeweyWest(m3, lag = 7))
nw4 <- coeftest(m4, vcov = NeweyWest(m4, lag = 7))

print(nw3); cat("R2:", summary(m3)$r.squared, "\n")
print(nw4); cat("R2:", summary(m4)$r.squared, "\n")

sink("06_regresion_spread_resultados.txt")
cat("PIT v14 · A4\nn =", nrow(df_reg), "\n\n")
cat("M3: flujo_dsr ~ spread\n");             print(nw3)
cat("\nR2:", summary(m3)$r.squared, "\n\n")
cat("M4: flujo_dsr ~ spread + controles\n"); print(nw4)
cat("\nR2:", summary(m4)$r.squared, "\n")
sink()