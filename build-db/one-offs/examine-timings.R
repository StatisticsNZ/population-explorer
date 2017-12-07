library(ggplot2)

# set up database connection:
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

timings <- sql_execute(idi, "one-offs/sample-query-times.sql", stringsAsFactors = FALSE)

p <- timings %>%
  as_tibble() %>%
  mutate(script_name = gsub("tests/sql/", "", script_name),
         start_time = as.Date(start_time))  %>%
  ggplot(aes(y = script_name, x= duration, colour = target_schema)) +
  geom_jitter(height = 0.1, width = 0)

print(p)
print(p + facet_wrap(~target_schema, scales = "free_x"))
