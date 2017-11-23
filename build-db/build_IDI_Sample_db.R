# This script  runs in succession all the SQL scripts needed to make
# a sample copy of the IDI_Clean database.  It is presumed that you have a connection
# to a server with an actual copy of IDI_Clean, and CRUD permissions to a database
# called IDI_Sample.  Running this R script under the correct RStudio project
# should look after all the rest for you.
# November 2017, Peter Ellis



source("src/sql_execute.R")

scripts <- list.files("../create-sample-IDI", pattern = "\\.sql$")
scripts <- paste0("../create-sample-IDI/", scripts)

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

system.time({
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                       filename = scripts[j],
                       sub_out = "IDI_Sample")
  }
})