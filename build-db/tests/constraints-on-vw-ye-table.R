# Check that all the foreign keys there should be are on the main reporting table
# Peter Ellis, 10 November 2017

tmp <- dplyr::filter(all_foreign_keys, table_name == "vw_year_wide")

sql <- paste0("select top 0 * from IDI_Sandpit.", test_schema, ".vw_year_wide")
vw_cols <- names(sqlQuery(idi, sql))
sum(grepl("_code$", vw_cols))

d <- sum(grepl("_code$", vw_cols)) + 1
if(nrow(tmp) != d){
  message(paste("vw_year_wide should have", d, "foreign keys and it has", nrow(tmp)))
  message("There should be one for snz_uid to dim_person, plus one for every column with '_code' in its name 
          to dim_explorer_value")
  stop("vw_year_wide doesn't the correct number of foreign keys constraining it.")
}

print("Passed check on foreign keys on main reporting table")