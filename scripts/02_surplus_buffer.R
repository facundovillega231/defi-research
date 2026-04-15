# =============================================================================
# 02_surplus_buffer.R
# Surplus buffer (flap count) como leading indicator del DSR
# =============================================================================
# Fuente de datos : Dune Analytics — query 6980514
# Columnas usadas : week, flap_count, dsr_pct, flap_count_lag4w
# Período         : 2020-01-27 a 2025-11-03
# Semanas         : 138 | Eventos de cambio DSR: 28
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
CACHE_PATH     <- "data/cache_query_6980514.rds"
MAX_LAGS       <- 12          # semanas de lag a evaluar en correlaciones
LAG_OPTIMO     <- 1           # lag con mayor correlación (absoluta)


# -----------------------------------------------------------------------------
# 2. Función de descarga — Dune API v3 con polling
# -----------------------------------------------------------------------------

fetch_dune <- function(query_id, api_key = Sys.getenv("DUNE_API_KEY"),
                       cache_path = NULL, refresh = FALSE) {

  # Usar cache si existe y no se pide refresh
  if (!is.null(cache_path) && file.exists(cache_path) && !refresh) {
    message("Cargando desde cache: ", cache_path)
    return(readRDS(cache_path))
  }

  base_url <- "https://api.dune.com/api/v1"

  # Ejecutar query
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

  # Descargar resultados
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

# Validación de columnas esperadas
cols_esperadas <- c("week", "flap_count", "dsr_pct", "flap_count_lag4w")
cols_faltantes <- setdiff(cols_esperadas, names(df_raw))
if (length(cols_faltantes) > 0) {
  warning("Columnas no encontradas: ", paste(cols_faltantes, collapse = ", "))
  message("Columnas disponibles: ", paste(names(df_raw), collapse = ", "))
}

df <- df_raw |>
  select(all_of(cols_esperadas)) |>
  mutate(week = as.Date(week)) |>
  arrange(week) |>
  filter(!is.na(dsr_pct), !is.na(flap_count))


# -----------------------------------------------------------------------------
# 4. Correlaciones por lag (1–12 semanas)
# -----------------------------------------------------------------------------

correlaciones <- map_dfr(1:MAX_LAGS, function(k) {
  tibble(
    lag_semanas = k,
    correlacion = cor(
      lag(df$flap_count, k),
      df$dsr_pct,
      use = "complete.obs"
    )
  )
})

cat("\n--- Correlaciones surplus buffer × DSR por lag ---\n")
print(correlaciones)

lag_optimo_calc <- correlaciones |>
  slice_max(abs(correlacion), n = 1) |>
  pull(lag_semanas)

cat("\nLag óptimo calculado:", lag_optimo_calc, "semanas\n")
cat("Correlación:         ", round(filter(correlaciones, lag_semanas == lag_optimo_calc)$correlacion, 4), "\n")


# -----------------------------------------------------------------------------
# 5. Regresión: dsr_pct ~ flap_count con lag óptimo
# -----------------------------------------------------------------------------

df_reg <- df |>
  mutate(flap_lag = lag(flap_count, LAG_OPTIMO)) |>
  filter(!is.na(flap_lag))

modelo <- lm(dsr_pct ~ flap_lag, data = df_reg)

cat("\n--- Regresión simple: dsr_pct ~ flap_lag ---\n")
print(summary(modelo))


# -----------------------------------------------------------------------------
# 6. Gráficos
# -----------------------------------------------------------------------------

dir.create("plots", showWarnings = FALSE)

# 6a. Correlación por lag
p_lags <- ggplot(correlaciones, aes(x = lag_semanas, y = correlacion)) +
  geom_col(fill = "#2C7BB6", alpha = 0.8) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray40") +
  scale_x_continuous(breaks = 1:MAX_LAGS) +
  labs(
    title    = "Surplus buffer como leading indicator del DSR",
    subtitle = "Correlación por lag (semanas)",
    x        = "Lag (semanas)",
    y        = "Correlación de Pearson"
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/02_correlacion_lags.png", p_lags, width = 8, height = 5, dpi = 150)

# 6b. Serie temporal
p_serie <- df |>
  select(week, flap_count, dsr_pct) |>
  pivot_longer(-week, names_to = "variable", values_to = "valor") |>
  mutate(variable = recode(variable,
    flap_count = "Flap count (surplus buffer)",
    dsr_pct    = "DSR (%)"
  )) |>
  ggplot(aes(x = week, y = valor)) +
  geom_line(color = "#2C7BB6") +
  facet_wrap(~variable, scales = "free_y", ncol = 1) +
  labs(
    title = "Surplus buffer y DSR — serie temporal",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 12)

ggsave("plots/02_serie_temporal.png", p_serie, width = 10, height = 6, dpi = 150)

message("Gráficos guardados en plots/")


# -----------------------------------------------------------------------------
# 7. Export de resultados
# -----------------------------------------------------------------------------

sink("resultados_regresion_02.txt")
cat("=== SURPLUS BUFFER COMO LEADING INDICATOR DEL DSR ===\n")
cat("Fecha:", format(Sys.Date()), "\n")
cat("Período:", format(min(df$week)), "a", format(max(df$week)), "\n")
cat("Semanas analizadas:", nrow(df), "\n")
cat("Eventos de cambio DSR:", sum(diff(df$dsr_pct) != 0, na.rm = TRUE), "\n\n")
cat("--- Correlaciones por lag ---\n")
print(as.data.frame(correlaciones))
cat("\nLag óptimo:", lag_optimo_calc, "semanas\n")
cat("Correlación:", round(filter(correlaciones, lag_semanas == lag_optimo_calc)$correlacion, 4), "\n\n")
cat("--- Regresión simple ---\n\n")
print(summary(modelo))
sink()

message("Resultados exportados a resultados_regresion_02.txt")
