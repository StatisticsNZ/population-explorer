library(RODBC)
library(stringr)
library(dplyr)

idi <- odbcConnect("ileed")

sql_queries <-
"SELECT TOP 1000 
statement,
datediff(second, start_time, end_time) as time_elapsed,
[session_server_principal_name],
[database_name],
[schema_name],
[object_name]
FROM [IDI_Audit].[dbo].[audit_tbl_XXXXXX]
ORDER BY time_elapsed DESC;"


dates <- c(paste0("20170", 1:10))

queries <- list()
for(i in 1:length(dates)){
  the_query <- gsub("XXXXXX", dates[i], sql_queries)
  queries[[i]]   <- sqlQuery(idi, the_query, stringsAsFactors = FALSE)
}


queries_df <- do.call(rbind, queries) %>%
  filter(!grepl("Invalid object name", statement)) %>%
  arrange(desc(time_elapsed)) %>%
  mutate(statement = gsub("\"", "", statement),
         contains_joins = grepl("join", statement, ignore.case = TRUE),
         contains_group = grepl("group", statement, ignore.case = TRUE),
         contains_temp_tables = grepl("#", statement),
         contains_where = grepl("where", statement, ignore.case = TRUE))

summary(queries_df)

write.csv(queries_df, "explore/longest_queries.csv", row.names = FALSE)

cat(paste(str_wrap(queries_df[1:5, "statement"], 80), collapse = "\n\n"))
