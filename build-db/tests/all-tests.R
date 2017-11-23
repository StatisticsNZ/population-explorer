# Runs all the tests in this folder
# Peter Ellis, 10 November 2017

library(RODBC)
library(dplyr)

source("src/sql_execute.r")
if(is.null(test_schema)){
  test_schema <- "pop_exp"
}

message(paste("Running tests on", test_schema, "schema"))

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

filename <- "tests/sql/find-all-foreign-keys.sql"
all_foreign_keys <- sql_execute(channel  = idi, 
                                filename = filename, 
                                sub_in   = "pop_exp_test", 
                                sub_out  = test_schema,
                                fixed    = TRUE,
                                stringsAsFactors = FALSE,
                                verbose = FALSE)


#--------------------------tests-----------------------------

# All variables should have at least 1000 observations in main fact table
source("tests/variable-observations.R")

# All value codes should have at least 2 observations in main fact table
source("tests/value-observations.R")

# fk1, fk2, fk3 and fk4 should all be present and have worked
source("tests/constraints-on-fact-tables.R")

# All columns with _code in their name in the main wide table, plus snz_uid, should have 
# foreign key constraints to dim_explorer_value
source("tests/constraints-on-vw-ye-table.R")

# All columns with _code in their name in the main wide table should have at least two values,
# and all columns without _code in their name have an average that is not zero (which would only
# plausibly happen if they were all 0 or NULL)
source("tests/check-values-invw-ye-table.R")


# Run some sample queries that should execute in a reasonable time
source("tests/reasonable-time-queries.R")
