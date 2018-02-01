

#' Execute T-SQL in a script
#' 
#' Reads a script of SQL Server SQL on a database, splits it into separate commands on the basis of where "GO" is
#' in the script, and executes it
#' 
#' @param channel connection handle as returned by RODBC::odbcConnect() of class RODBC
#' @param filename file name of an SQL script
#' @param sub_in character string that you want to be replaced with sub_out.  Useful if you want to do a bulk search
#' and replace eg change all pop_exp_dev. with pop_exp.  This is useful if you have a bunch of scripts that you maybe want
#' to run on one schema sometimes, and on another schema other times - just automate the search and replace.  Use with caution.
#' @param sub_out character string that you want to replace sub_in
#' @param fixed logical.  If TRUE, sub_in is a string to be matched as is.  Otherwise it is treated as a regular expression 
#' (eg if fixed = FALSE, then . is a wild card)
#' @param error_action should you stop with an error if a batch gets an error message back from the database?  Any alternative
#' to "stop" means we just keep ploughing on, which may or may not be a bad idea.  Use "stop" unless you know that failure
#' in one part of a script isn't fatal.
#' @param log_table table in the database to record a log of what happened.  Set to NULL if no log table available.  The log_table
#' needs to have (at least) th following columns: event_time, target_schema, script_name, batch_number, result, and err_mess. 
#' @author Peter Ellis
sql_execute <- function(channel, filename, sub_in = NULL, sub_out = NULL, fixed = TRUE, 
                        error_action = "stop", source_database = "IDI_Clean", log_table = "IDI_Sandpit.dbo.pop_exp_build_log", 
                        verbose = TRUE, spine_to_sample_ratio = 1, ...){
  
  # we can't tell in advance what encoding the .sql files are in, so we read it in
  # in two ways (one of which is certain to return gibberish) and choose the version that is recognised as a proper string:
  
  # encoding method 1 (weird Windows encoding):
  file_con <- file(filename, encoding = "UCS-2LE")
  sql1 <- paste(readLines(file_con, warn = FALSE), collapse = "\n")
  close(file_con)
  
  # encoding method 2 (let R work it out - works in most cases):
  file_con <- file(filename)
  sql2 <- paste(readLines(file_con, warn = FALSE), collapse = "\n")
  close(file_con)
  
  # choose between the two encodings:
  suppressWarnings({
    if(is.na(str_length(sql2))){
      sql <- sql1
    } else {
      sql <- sql2
    }
  })
  
  # do the find and replace that are needed
  if(!is.null(sub_in)){
    sql <- gsub(sub_in, sub_out, sql, fixed = fixed)
  }
  
  if(source_database != "IDI_Clean"){
    sql <- gsub("IDI_Clean", source_database, sql)
  }
  
  if(source_database == "IDI_Clean"){
    sql <- gsub("IDI_Sample", source_database, sql)
  }
  
  sql <- gsub("SET spine_to_sample_ratio = [0-9]+",
              paste("SET spine_to_sample_ratio = ", spine_to_sample_ratio), sql)
  
  # split the SQL into separate commands wherever there is a "GO" at the beginning of a line
  # ("GO" is not ANSI SQL, only works for SQL Server - it indicates the lines above are a batch)
  sql_split <- str_split(sql, "\\n *[Gg][Oo]", simplify = TRUE)
  
  base_log_entry <- data.frame(
    target_schema = ifelse(is.null(sub_out), "none", sub_out),
    script_name   = filename,
    stringsAsFactors = FALSE
  )
  
  # execute the various separate commands
  for(i in 1:length(sql_split)){
     log_entry              <- base_log_entry
     log_entry$batch_number <- i
     log_entry$result       <- "no error"
     log_entry$err_mess     <- ""
     log_entry$start_time   <- as.character(Sys.time())
     
     
     duration <- system.time({res <- sqlQuery(channel, sql_split[[i]], ...)})
     log_entry$duration <- duration[3]
     
     if(class(res) == "data.frame"){
       txt <- paste("Downloaded a data.frame with", nrow(res), "rows and",
                    ncol(res), "columns.")
       if(verbose){message(txt)}
       log_entry$result <- "data.frame"
       
     } 
       if(class(res) == "character" & length(res) > 0){
         message("\n\nI got this error message:")
         cat(res)
         log_entry$result <- "error"
         log_entry$err_mess <- paste(gsub("'", "", res), collapse = "\n")
         message(paste0("\n\nSomething went wrong with the SQL execution of batch ", i, 
                                   " in ", filename, ". \n\nError message from the database is shown above\n\n"))
       }
     
     log_entry$end_time <- as.character(Sys.time())
     
     # Update the log in the database, if we have been given one:
     if(!is.null(log_table)){
       # couldn't get sqlSave to append to a table even when append = TRUE... 
       # see https://stackoverflow.com/questions/36913664/rodbc-error-sqlsave-unable-to-append-to-table
       # so am writing the SQL to update the log by hand:
       sql <- with(log_entry, paste0("INSERT INTO ", 
                                     log_table, 
                                     "(start_time, end_time, target_schema, script_name, batch_number, result, err_mess, duration)",
                    " VALUES ('", start_time, "', '", end_time, "', '", 
                    target_schema, "', '", script_name, "', ", batch_number, ", '", result, "', '",
                    err_mess, "', ", duration, ");"))
       
       log_res <- sqlQuery(channel, sql)
       
     }
     if(error_action == "stop" && log_entry$result == "error"){
       stop(paste("Stopping due to an error in", filename))
     }
     if(class(res) == "data.frame"){
       return(res)
     }
  }
}
  


# sqlQuery(idi, sql_split[[1]])
# sqlQuery(idi, sql_split[[2]])

# sqlQuery(idi, sql_split[[3]])
# sqlQuery(idi, sql_split[[4]])
# cat(sql_split[[1]])
# cat(sql_split[[2]])
# cat(sql_split[[3]])
# cat(sql_split[[4]])
