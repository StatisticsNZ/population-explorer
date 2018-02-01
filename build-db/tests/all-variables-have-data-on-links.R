



test_that("All variables have data on their linkage to the spine", {
  sql <- paste0("SELECT COUNT(1) AS FREQ FROM IDI_Sandpit.", test_schema, 
                ".dim_explorer_variable WHERE short_name != 'Generic' AND 
              (data_linked_to_spine IS NULL OR snz_uid_linked_to_spine IS NULL)")
  
  x <- sqlQuery(idi, sql)
  expect_equal(x$FREQ, 0)    
})


print("passed test of all variables having data on linkage to spine")

