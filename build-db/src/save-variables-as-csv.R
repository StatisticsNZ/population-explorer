# This program saves five key columns from the dim_explorer_variable table as a CSV, doing a 
# bit of tidying up along the way for tabs and stuff
# usage is: 
# save_variables("pop_exp_test")

#' R function to strip out excess tabs, spaces and returns from a character string so it looks ok to print
make_nice <- function(x){
  if(!class(x) %in% c("character", "factor")){
    stop("x should be a character or a factor")
  }
  y <- gsub("\\t", " ", x)
  y <- gsub("\\n", " ", y)
  y <- gsub(" +", " ", y)
  return(y)
            
}

save_variables <- function(schema = "pop_exp"){
  require(RODBC)
  require(dplyr)
  
  odbcCloseAll()
  idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                          Trusted_Connection=YES; 
                          Server=WTSTSQL35.stats.govt.nz,60000")
  
  # it's tricky to import text fields that are more than 256 characters thanks to a flaw in Microsoft's ODBC driver,
  # so we have to explicitly CAST the full_description field
  variables <- sqlQuery(idi, 
                             paste0("SELECT *, 
                               CAST(measured_variable_description AS NVARCHAR(4000)) AS mvd,
                               CAST(target_variable_description AS NVARCHAR(4000)) AS tvd
                                    FROM IDI_Sandpit.", 
                                    schema, ".dim_explorer_variable order by short_name"), 
                             stringsAsFactors = FALSE) %>%
    mutate(measured_variable_description = make_nice(mvd),
           target_variable_description = make_nice(tvd)
           ) %>%
    select(long_name, var_type, grain, measured_variable_description, target_variable_description, origin_tables)
  
  write.csv(variables, file = "doc/variables.csv", row.names = FALSE)
}