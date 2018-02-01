# This script is here to run a bunch of sample queries against all the active versions of the datamart
# so we can collect some information on performance.  The idea is to do this a few times a day so
# we get a reasonable sample of times.  Because they seem to vary a lot.

# Peter Ellis 28 November 2017


# set up database connection:
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

# schemas that are currently alive and this is worth trying for
schemas <- paste0("pop_exp_", c("sample", "alpha", "bravo"))


fns <- list.files(path = "tests/sql/", pattern = "^sample-query")

for(j in 1:length(schemas)){
  for(i in 1:length(fns)){
    filename <- paste0("tests/sql/", fns[i])
    st <- system.time({
      sample_query <- sql_execute(channel  = idi, 
                                  filename = filename, 
                                  sub_in   = "pop_exp_test", 
                                  sub_out  = schemas[j],
                                  fixed    = TRUE,
                                  stringsAsFactors = FALSE,
                                  verbose = FALSE,
                                  error_action = "continue")
    })
  }
}