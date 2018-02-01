# this script gets R to run lots of SQL scripts in a sequence... This means we can build the entire database
# with a single click by sourcing this script, which is good practice (to avoid finnicky instructions of run this script,
# then that script, and so on).  It also means we can run it overnight by starting the job on the R server and leaving
# it running even when we have to log off the network and take our client Surface Pro home

# There are two main things that trip us up in running this:
# * if a script has syntactically correct SQL but returns an error from the data it does not return an error.
# * if a script has a SELECT ... statement that returns a table of data and doesn't insert it anywhere, the rest
#   of the script is not executed.

# Peter Ellis 30-31 October 2017 and extensively revised and added to since

# parameters for this build: 
create_procedures     <- FALSE                      # Set to FALSE if you're worried about mucking up other people using those procedures
build_intermediate    <- FALSE                      # set to FALSE if you're fine with using the existing version of the intermediate tables
build_quarterly       <- FALSE             
target_schema         <- "pop_exp_bravo"                  # can be pop_exp_alpha, pop_exp_bravo, pop_exp_charlie, pop_exp_dev or pop_exp_sample
source_database         <- "IDI_Clean"                # can be IDI_Clean (very slow eg 40 hours) or IDI_Sample (15 minutes)
target_schema_int     <- "intermediate"             # can be intermediate or intermediate_sample
spine_to_sample_ratio <- 20                         # can be any number.  1 means full spine is used; 10 means one tenth

# set up database connection:
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


#-----------------------create stored procedures------------------
if(create_procedures){
  sql_execute_all("00-src")
}


#-----------------------build the tables in the `intermediate` schema------------------
# some of these scripts depend on pop_exp_dev.dim_date being in existence, hence need to run 
# that script (./build-db/02-setup/03-create-dim_date.sql) manually in Management Studio if doing a 
# clean build from nothing.

if(build_intermediate){
    sql_execute_all("01-int-tables", type = "intermediate", error_action = "continue")
}


# to run just one, with no search-and-replace text substitutions:
# sql_execute(idi, "01-int-tables/29_days_in_employment.sql", 
#             sub_in = "intermediate", sub_out = target_schema_int, source_database = source_database)
# sql_execute(idi, "01-int-tables/32_neet.sql", 
#             sub_in = "intermediate", sub_out = target_schema_int, source_database = source_database)


# should do some checks here that all the intermediate tables with snz_uid in them
# are limited to the spine - a common problem being that they have gotten confused
# with the old snz_uid from the last refresh.



#----------------clear the decks, and build just the dimension tables-------------
sql_execute_all("02-setup")

# test that we got the right number of people

test_people <- sqlQuery(idi, paste0("SELECT COUNT(1) AS n FROM IDI_Sandpit.", target_schema, ".dim_person"))
if((test_people$n < 9000000 / spine_to_sample_ratio && source_database != "IDI_Sample") 
   || (test_people$n != 100000 / spine_to_sample_ratio && source_database == "IDI_Sample")){
  stop("Less than expected number of people in the person dimension table, so quitting until you fix it.")
}


#-----------------------add the data to the fact table in the [pop_exp_XXX] schema-----------------
sql_execute_all("03-year-facts")

message(paste("Finished adding annual variables", Sys.time()))


nrows <- sql_execute(idi, "tests/sql/variable-observation-counts.sql", sub_in = "pop_exp_test", sub_out = target_schema)
if(min(nrows$observations) < 1000 / spine_to_sample_ratio){
  print(nrows)
  stop("At least one variable had less than 1000 observations.")
}

# Note if this has happened, which indicates one of the variable-adding scripts in the build has failed silently, 
# most likely there is a SELECT statement in the SQL script, left in by us as a "let's check what this looks like", 
# that returns some table.  That seems to confuse odbcQuery, it stops when it gets to that point.  So we need to 
# remember *not* to leave any statements like:
#
# SELECT * from dim_explorer_variable -- check all ok
#
# in the .sql files at it makes them fail silently when run in this process.
# it seems ok if such statements are at the *end* of the .sql script.

#-----------------------do the indexing and pivoting to make it ready for the Shiny app and analysis-----------------
# sql_execute_all("04-year-pivot", upto = "72c", error_action = "continue")
sql_execute_all("04-year-pivot")
# inspect progress by looking at dim_explorer_variable.loaded_into_wide_table, which is populated as we go

# script 74 takes a long long time to add in the columns of the wide table and the system often goes down with it 
# incomplete.  So the next section is setup so you can run from here if that situation arises:

unloaded <- sqlQuery(idi, paste0("SELECT * FROM IDI_Sandpit.", target_schema, 
                                 ".dim_explorer_variable WHERE loaded_into_wide_table IS NULL AND use_in_front_end = 'use'"),
                     stringsAsFactors = FALSE)
if(nrow(unloaded) > 0){
  message(paste("Loading the remaining", nrow(unloaded), "of columns of the wide table that missed out when system went down."))
  print(unloaded$short_name)
  scripts <- paste0("04-year-pivot/", list.files("04-year-pivot", pattern = "\\.sql$"))
  scripts <- scripts[scripts >= "04-year-pivot/74"]
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    
    res <- sql_execute(channel  = idi, 
                       filename = scripts[j], 
                       sub_in   = "pop_exp_dev", 
                       sub_out  = target_schema,
                       fixed    = TRUE,
                       source_database = source_database)
  }
  
}

message(paste("Finished build", Sys.time()))

# run tests
all_tests(target_schema)
#all_tests("pop_exp_bravo")

# save Excel version of the variables (is wrapped in `try` in case someone else has it open, in which
# case it will *not* save the variables):
try(save_variables(target_schema))

#-------------------------quarterly version----------------------
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

if(build_quarterly){
  sql_execute_all("06-qtr-facts")
}