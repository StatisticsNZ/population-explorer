should <- read.csv("tests/should-have-these-variables.csv", stringsAsFactors = FALSE)


sql <- paste0("SELECT short_name FROM IDI_Sandpit.", test_schema, ".dim_explorer_variable")
in_vars <- sqlQuery(idi, sql)

missing_vars <- should[!should$short_name %in% in_vars$short_name, "short_name"]
if(length(missing_vars) > 1){
  stop(paste("we should have", paste(missing_vars, collapse = " and "), "but they have gone missing"))
}

message("Passed test of all expected variables turned up")