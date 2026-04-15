# =============================================================================
# 03_dsr_spread.R
# Spread DSR/AAVE como predictor del DSR — regresión múltiple
# =============================================================================
# Fuente de datos : Dune Analytics — query 6980514
# Columnas usadas : week, flap_count, dsr_pct, flap_count_lag4w
#                   (spread calculado en este script como dsr_pct - aave_rate,
#                    o bien como columna propia si la query la incluye)
# =============================================================================

library(conflicted)
library(tidyverse)
library(httr2)
library(jsonlite)

# Resolver conflictos entre paquetes
conflict_prefer("filter",  "dplyr")
conflict_prefer("lag",     "dplyr")
conflict_prefer("flatten", "purrr")


# -----------------------------------------------------------------------------
# 1. Configuración
# -----------------------------------------------------------------------------

DUNE_QUERY_ID <- "6980514"
CACHE_PATH     <- "data/cache_query_6980514.rds"   # comparte cache con 02
MAX_LAGS       <- 12


# -----------------------------------------------------------------------------
# 2. Función de descarga — Dune API v3 con polling
# (idéntica a 02_surplus_buffer.R; extraer a utils.R si el repo crece)
# -----------------------------------------------------------------------------

fetch_dune <- function(query_id, api_key = Sys.getenv("DUNE_API_KEY"),
                       cache_path = NULL, refresh = FALSE) {

  if (!is.null(cache_path) && file.exists(cache_path) && !refresh) {
    message("Cargando desde cache: ", cache_path)
    return(readRDS(cache_path))
  }

  base_url <- "https://api.dune.com/api/v1"

  resp_exec <- request(paste0(base_url, "/query/", query_id, "/execute")) |>
    req_headers("X-Dune-API-Key" = api_key) |>
    req_method("POST") |>
    req_perform()

  exec_id <- resp_body_json(resp_exec)$execution_id

  # Polling hasta completar
  MAX_WAIT_SEC <- 300   # 5 minutos máximo
  start_time   <- Sys.time()

  repeat {
    Sys.sleep(2)
    resp_status <- request(paste0(base_url, "/execution/", exec_id, "/status")) |>
      req_headers("X-Dune-API-Key" = api_key) |>
      req_perform()

    state <- resp_body_json(resp_status)$state
    message("Estado: ", state)
    if (state %in% c("QUERY_STATE_COMPLETED", "QUERY_STATE_FAILED")) break

    if (as.numeric(Sys.time() - start_time, units = "secs") > MAX_WAIT_SEC) {
      stop("Timeout: la query tardó más de ", MAX_WAIT_SEC, " segundos.")
    }
  }

  if (state == "QUERY_STATE_FAILED") stop("La query falló en Dune.")

  resp_results <- request(paste0(base_url, "/execution/", exec_id, "/results")) |>
    req_headers("X-Dune-API-Key" = api_key) |>
    req_perform()

  parsed <- resp_body_json(resp_results, simplifyVector = TRUE)
  df     <- as.data.frame(parsed$result$rows)

  if (!is.null(cache_path)) {
    dir.create(dirname(cache_path), showWarnings = FALSE, recursive = TRUE)
    saveRDS(df, cache_path)
    message("Cache guardado: ", cache_path)
  }

  df
}


# -----------------------------------------------------------------------------
# 3. Descarga y limpieza
# -----------------------------------------------------------------------------

df_raw <- fetch_dune(DUNE_QUERY_ID, cache_path = CACHE_PATH)

# Validación de columnas
cols_esperadas <- c("week", "flap_count", "dsr_pct", "flap_count_lag4w")
cols_faltantes <- setdiff(cols_esperadas, names(df_raw))
if (length(cols_faltantes) > 0) {
  warning("Columnas no encontradas: ", paste(cols_faltantes, collapse = ", "))
  message("Columnas disponibles: ", paste(names(df_raw), collapse = ", "))
}

df_base <- df_raw |>
  select(all_of(cols_esperadas)) |>
  mutate(week = as.Date(week)) |>
  arrange(week) |>
  filter(!is.na(dsr_pct), !is.na(flap_count))

# -----------------------------------------------------------------------------
# 3b. AAVE rate histórica — DeFi Llama (USDC supply rate, Ethereum)
# Pool ID: 747c1d2a-c668-4682-b9f9-296708a3dd90
# -----------------------------------------------------------------------------

message("Descargando AAVE rate desde DeFi Llama...")

resp_aave <- request("https://yields.llama.fi/chart/747c1d2a-c668-4682-b9f9-296708a3dd90") |>
  req_perform()

aave_raw <- resp_body_json(resp_aave, simplifyVector = TRUE)$data

df_aave <- as.data.frame(aave_raw) |>
  mutate(
    week      = lubridate::floor_date(as.Date(substr(timestamp, 1, 10)), "week", week_start = 1),
    aave_rate = as.numeric(apyBase)
  ) |>
  group_by(week) |>
  summarise(aave_rate = mean(aave_rate, na.rm = TRUE), .groups = "drop")

message("AAVE rate descargada: ", nrow(df_aave), " semanas")

# Join y cálculo de spread
df <- df_base |>
  left_join(df_aave, by = "week") |>
  mutate(spread = dsr_pct - aave_rate)

n_na_spread <- sum(is.na(df$spread))
if (n_na_spread > 0) {
  message("Advertencia: ", n_na_spread, " semanas sin AAVE rate (quedan como NA)")
}



# -----------------------------------------------------------------------------
# 4. Correlaciones spread × DSR por lag (1–12 semanas)
# -----------------------------------------------------------------------------

correlaciones_spread <- map_dfr(1:MAX_LAGS, function(k) {
  tibble(
    lag_semanas = k,
    correlacion = cor(
      lag(df$spread, k),
      df$dsr_pct,
      use = "complete.obs"
    )
  )
})

cat("\n--- Correlaciones spread DSR/AAVE × DSR por lag ---\n")
print(correlaciones_spread)


# -----------------------------------------------------------------------------
# 5. Regresión múltiple: dsr_pct ~ flap_count + spread
# -----------------------------------------------------------------------------

df_spread <- df |>
  filter(!is.na(spread))

modelo_multiple <- lm(dsr_pct ~ flap_count + spread, data = df_spread)

cat("\n--- Regresión múltiple: dsr_pct ~ flap_count + spread ---\n")
print(summary(modelo_multiple))

# Coeficientes esperados (del .txt de referencia):
#   (Intercept) =  6.541  | flap_count = -0.00773  | spread = 0.734
#   R² = 0.576  | F = 62.54 (2 y 92 gl)


# -----------------------------------------------------------------------------
# 6. Gráficos
# -----------------------------------------------------------------------------

dir.create("plots", showWarnings = FALSE)

# 6a. Correlación spread por lag
p_lags_spread <- ggplot(correlaciones_spread, aes(x = lag_semanas, y = correlacion)) +
  geom_col(fill = "#D7191C", alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  scale_x_continuous(breaks = 1:MAX_LAGS) +
  labs(
    title    = "Spread DSR/AAVE como predictor del DSR",
    subtitle = "Correlación por lag (semanas)",
    x        = "Lag (semanas)",
    y        = "Correlación de Pearson"
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/03_correlacion_spread_lags.png", p_lags_spread, width = 8, height = 5, dpi = 150)

# 6b. Scatter spread vs DSR
p_scatter <- ggplot(df_spread, aes(x = spread, y = dsr_pct)) +
  geom_point(alpha = 0.5, color = "#D7191C") +
  geom_smooth(method = "lm", se = TRUE, color = "gray30") +
  labs(
    title = "Spread DSR/AAVE vs DSR",
    x     = "Spread (pp)",
    y     = "DSR (%)"
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/03_scatter_spread_dsr.png", p_scatter, width = 7, height = 5, dpi = 150)

# 6c. Serie temporal spread
p_spread_ts <- ggplot(df, aes(x = week, y = spread)) +
  geom_line(color = "#D7191C") +
  labs(
    title = "Spread DSR/AAVE — serie temporal",
    x = NULL, y = "Spread (pp)"
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/03_spread_serie.png", p_spread_ts, width = 10, height = 4, dpi = 150)

message("Gráficos guardados en plots/")


# -----------------------------------------------------------------------------
# 7. Export de resultados
# -----------------------------------------------------------------------------

sink("resultados_regresion_03.txt")
cat("=== SPREAD DSR/AAVE COMO PREDICTOR DEL DSR ===\n")
cat("Fecha:", format(Sys.Date()), "\n\n")
cat("--- Regresión múltiple ---\n\n")
print(summary(modelo_multiple))
cat("\n--- Correlaciones spread por lag ---\n")
print(as.data.frame(correlaciones_spread))
sink()

message("Resultados exportados a resultados_regresion_03.txt")
