
# This is a temporary location for this bit of functionality.  It builds the quarterly database
# on the assumption an annual version has already been made.  ie you need to have run build.R first, at least up to where 
# the annual fact table has been populated.  The quarterly fact-adding scripts depend on the variable having already
# been added to dim_explorer_variable
# Peter Ellis 20 November 2017

source("src/sql_execute.R")

target_schema <- "pop_exp_test"

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")


#-------------add the quarterly facts----------------------

# all the quarterly facts tables scripts:
scripts <- paste0("qtr-facts/", list.files("qtr-facts", pattern = "\\.sql$"))

system.time({
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                       filename = scripts[j], 
                       sub_in   = "pop_exp_dev", 
                       sub_out  = target_schema,
                       fixed    = TRUE,
                       error_action = "stop")
  }
})  
