# Runs all the tests in this folder
# Peter Ellis, 10 November 2017

all_tests <- function(test_schema){

  message(paste("Running tests on", test_schema, "schema"))
  
  
  test_idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                          Trusted_Connection=YES; 
                          Server=WTSTSQL35.stats.govt.nz,60000")
  
  filename <- "tests/sql/find-all-foreign-keys.sql"
  
  # this isn't good practice to alter the global environment from within a function
  # so don't copy this in other situations.  Only doing here because this is only
  # for use in this particular context
  
  test_schema <<- test_schema
  
  all_foreign_keys <<- sql_execute(channel  = idi, 
                                  filename = filename, 
                                  sub_in   = "pop_exp_test", 
                                  sub_out  = test_schema,
                                  fixed    = TRUE,
                                  stringsAsFactors = FALSE,
                                  verbose = FALSE)
  
  
  scripts <- list.files("tests", pattern = ".[Rr]$", full.name = TRUE)
    
  lapply(scripts, function(x){try(source(x))})
  
  odbcClose(test_idi)
  
  
}