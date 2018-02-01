if(!exists("source_schema")){
  load("synthesis/temp_data/original-data.rda") # has the source_schema
}


# create (and drop old versions) the target tables as pop_exp_synth.  Make sure source_schema here
# is the same as used in prep.R, so the variable codes and so forth are correct!
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

# we need to know the source schema that was used, so we use the correct copies of pop_exp_xxx.dim_explorer_variable
# and dim_explorer_value_year as basis for our copy in the database
sql_execute(idi, "synthesis/base-tables.sql",
            sub_in = "pop_exp_dev",
            sub_out = source_schema)




message("Taking the data from dbo.dim_person and dbo.fact_rollup_year and INSERTing into pop_exp_synth.")
sql_execute(idi, "synthesis/insert-person-and-facts.sql")

# now we do all the pivoting, observation counting and final indexing just as though we were building this schema
# from IDI_Clean rather than synthesising it:
source_database <- "IDI_Clean" # used by sql_execute_all() for things like estimating the spine to sample ratio
target_schema <- "pop_exp_synth"
spine_to_sample_ratio <- 1 # correct number gets fixed in the SQL, we just need a placeholder for sql_execute_all

sql_execute_all("04-year-pivot", error_action = "continue")

# tests - the synthetic data will fail some tests eg iwi doesn't have any variety, and there aren't 25 variables
all_tests("pop_exp_synth")

