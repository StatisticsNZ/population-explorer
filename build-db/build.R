# this script gets R to run lots of SQL scripts in a sequence... This means we can build the entire database
# with a single click by sourcing this script, which is good practice (to avoid finnicky instructions of run this script,
# then that script, and so on).  It also means we can run it overnight by starting the job on the R server and leaving
# it running even when we have to log off the network and take our client Surface Pro home

# we assume that the scripts in /src/ have already been run and hence the stored procedures
# in the lib schema already exist TODO - why not add that in to here?

# There are two main things that trip us up in running this:
# * if a script has syntactically correct SQL but returns an error from the data eg "ambiguous column", it does not 
#   return an error.
# * if a script has a SELECT ... statement that returns a table of data and doesn't insert it anywhere, the rest
#   of the script is not executed.

# Peter Ellis 30-31 October 2017

# change this to build_derived <- TRUE if you want to build all the original intermediate tables too (takes many hours)
build_intermediate <- FALSE
target_schema <- "pop_exp_test"


source("src/sql_execute.R")
source("src/save-variables-as-csv.R")

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


#-------------build the very first "permanent seed" table----------------------
# This is the very first table needed in a completely clean build

if(build_intermediate){
  message("Building the permanent seeds, and the parents table, in the 'intermediate' schema")
  res <- sql_execute(channel = idi, filename = "int-tables/00-permanent_seed.sql")
  res <- sql_execute(channel = idi, filename = "int-tables/00-parents.sql")
}

#----------------clear the decks, and build just the dimension tables-------------
scripts <- list.files(pattern = "\\.sql$")
scripts <- scripts[scripts < "05"] 

system.time({
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                filename = scripts[j], 
                sub_in   = "pop_exp_dev", 
                sub_out  = target_schema,
                fixed    = TRUE)
  }
})

sql <- paste0("SELECT COUNT(1) AS n FROM IDI_Sandpit.", target_schema, ".dim_person")
test_people <- sqlQuery(idi, sql)
if(test_people$n < 9000000){
  stop("Less than 9 million people in the person dimension table, so quitting until you fix it.")
}

#-----------------------build the tables in the `intermediate` schema------------------
# some of these scripts actually depend on the dimension tables being set up first eg dim_date,
# hence need to run the previous chunk before you get to here if you're doing a clean build

if(build_intermediate){
  # all the intermediate tables scripts:
  scripts <- paste0("int-tables/", list.files("int-tables", pattern = "\\.sql$"))
  
  # exclude those that begin with "00" as they should have 
  scripts <- scripts[scripts >= "int-tables/01"]
  
  system.time({
    for(j in 1:length(scripts)){
      message(paste("Executing", scripts[j], Sys.time()))
      res <- sql_execute(channel  = idi, 
                  filename = scripts[j], 
                  sub_in   = "pop_exp_dev", 
                  sub_out  = target_schema,
                  fixed    = TRUE,
                  error_action = "continue")
    }
  })  
}

# should do some checks here that all the intermediate tables with snz_uid in them
# are limited to the spine - a common problem being that they have gotten confused
# with the old snz_uid from the last refresh.

#-----------------------build the tables in the [pop_exp_XXX] schema-----------------
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


scripts <- list.files(pattern = "\\.sql$")
scripts <- scripts[scripts >= "05" & scripts < "60"] 

system.time({
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                filename = scripts[j], 
                sub_in   = "pop_exp_dev", 
                sub_out  = target_schema,
                fixed    = TRUE,
                error_action = "continue")
    if(class(res) == "data.frame"){
      warning(paste(scripts[j], "returned a data.frame.  That's a bad sign it might not have finished what it was meant to do."))
    }
  }
})

message(paste("Finished adding variables", Sys.time()))

# check how many rows we have per variable before we go on
sql <- paste0(
  "SELECT COUNT(1) AS observations, fk_variable_code, variable_code, short_name
  FROM IDI_Sandpit.", target_schema, ".fact_rollup_year AS a
  RIGHT JOIN IDI_Sandpit.", target_schema, ".dim_explorer_variable AS b
  ON a.fk_variable_code = b.variable_code
  WHERE grain = 'person-period'
  group by fk_variable_code, short_name, variable_code
  order by variable_code DESC;"
  )

nrows <- sqlQuery(idi, sql)
if(min(nrows$observations) < 1000){
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

# save a CSV version of the variables:
save_variables(target_schema)

#-----------------------do the indexing and pivoting to make it ready for the Shiny app and analysis-----------------
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


scripts <- list.files(pattern = "\\.sql$")
scripts <- scripts[scripts >= "60"] 

system.time({
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                filename = scripts[j], 
                sub_in   = "pop_exp_dev", 
                sub_out  = target_schema,
                fixed    = TRUE)
  }
})

message(paste("Finished build", Sys.time()))

# run tests
test_schema <- target_schema
source("tests/all-tests.R")

# save a CSV version of the variables:
save_variables(target_schema)

