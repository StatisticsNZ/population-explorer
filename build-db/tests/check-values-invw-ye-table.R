# Checks that all the columns ending with _code in the main vw_ye_mar_wide table have at least
# two values in them.  Most likely reason for this not being the case is they are all "No data",
# which means something wrong somewhere
#
# Peter Ellis 10 November 2017


sql <- paste0("select top 0 * from IDI_Sandpit.", test_schema, ".vw_year_wide")
vw_cols <- names(sqlQuery(idi, sql))

error <- 0

#--------------------check coded variables------------------------------
vars <- vw_cols[grepl("_code$", vw_cols)]

for(var in vars){
  sql <- paste0("SELECT COUNT(1) AS n, ", var, " FROM
                IDI_Sandpit.", test_schema, ".vw_year_wide
                GROUP BY ", var)
  
  tab <- sqlQuery(idi, sql, stringsAsFactors = FALSE)
  if(class(tab) != "data.frame"){
	stop("something wrong with a basic query checking the values in wv_year_wide")
  }
  if(nrow(tab) < 2){
    print(tab)
    error <- error + 1
    }
}



#-----------------check numeric variables--------------------------
vars <- vw_cols[!grepl("_code$", vw_cols)]
vars <- vars[! vars %in% c("snz_uid", "number_observations", "date_period_ending")]

for(var in vars){
  sql <- paste0("SELECT AVG(CAST(", var, " AS FLOAT)) AS x FROM
                  IDI_Sandpit.", test_schema, ".vw_year_wide")

  avg <- sqlQuery(idi, sql, stringsAsFactors = FALSE)
  if(avg$x == 0){
    print(paste("Column ", var, " in vw_ye_mar_wide has an average of zero"))
    error <- error + 1
  }
}
  
if(error > 0){
  stop(paste(error, "problematic variables in vw_ye_mar_wide, see above"))
} else {
  message("Passed test of categorical variables all having a range of values")
  message("Passed test of continuous variables all having a range of values (ie not all zero)")  
}


