library(httr)
library(jsonlite)
library(ggplot2)
library(dplyr)

api_key  <- "JVUbUaSzUTqymZZuBenlDkaICUdJfZ0Q"
query_id <- "6980514"

# --- Bajar datos ---
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
df_ccf   <- as.data.frame(parsed$result$rows)

cat("nrow:", nrow(df_ccf), "\n")
head(df_ccf)
str(df_ccf)