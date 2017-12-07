

sql1 <- paste0("select * from IDI_Sandpit.", test_schema, ".vw_year_wide where 1 = 2")
cn <- names(sqlQuery(idi, sql1))
cn

sql2 <- paste0("select short_name from IDI_Sandpit.", test_schema, ".dim_explorer_variable 
                     where use_in_front_end = 'Use'")

vars <- sqlQuery(idi, sql2, stringsAsFactors = FALSE)$short_name %>% tolower()
vars <-  gsub("m.ori", "maori", vars)

missing_vars <- vars[!tolower(paste0(vars, "_code")) %in% tolower(cn)]

if(length(missing_vars) > 0){
  print(paste("The following variables do not have _code versions in vw_year_wide"))  
  print(missing_vars)
  if(length(missing_vars) > 3){
    stop("That's more than the three I expected.")
  }
}
message("Passed test of all but three variables listed in dim_explorer_variable appearing in vw_year_wide")

