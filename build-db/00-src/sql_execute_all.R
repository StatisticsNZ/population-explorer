
#' This function picks up the following from the global environment:
#' source_database, target_schema, target_schema_int, spine_sample_ratio, idi
sql_execute_all <- function(folder, type = "main", error_action = "stop", upto = NULL){
  # start a fresh connection to the database for this folder
  
  my_idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server;
                          Trusted_Connection=YES;
                          Server=WTSTSQL35.stats.govt.nz,60000")
  
  
  # load in the names of all the scripts to run:
  scripts <- paste0(folder, "/", list.files(folder, pattern = "\\.sql$"))
  
  # and ignore those that are under development:
  scripts <- scripts[!grepl("progress", scripts, ignore.case = TRUE)]
  
  # and those that are less than the upto parameter (useful for only running up to file X in a folder)
  if(!is.null(upto)){
    scripts <- scripts[scripts < paste0(folder, "/", upto)]
  }

  
  if(type == "intermediate"){
    # building the "intermediate" schema
    sub_in <- "intermediate"
    sub_out <- target_schema_int
  } else {
    sub_in <- "pop_exp_dev"
    sub_out <- target_schema
  }
  
  for(j in 1:length(scripts)){
    message(paste("Executing", scripts[j], Sys.time()))
    res <- sql_execute(channel  = idi, 
                       filename = scripts[j], 
                       sub_in = sub_in,
                       sub_out = sub_out,
                       fixed    = TRUE,
                       error_action = error_action,
                       source_database = source_database,
                       spine_to_sample_ratio = spine_to_sample_ratio)
    
    if(class(res) == "data.frame"){
      warning(paste(scripts[j], "returned a data.frame.  That's a bad sign it might not have finished what it was meant to do."))
    }
    
  }
  odbcClose(my_idi)
  
}