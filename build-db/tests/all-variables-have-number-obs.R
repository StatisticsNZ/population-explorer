test_that("All variables have data on their number of observations", {
  sql <- paste0("SELECT COUNT(1) AS FREQ FROM IDI_Sandpit.", test_schema, 
                ".dim_explorer_variable WHERE short_name != 'Generic' AND 
              number_observations IS NULL")
  
  x <- sqlQuery(idi, sql)
  expect_equal(x$FREQ, 0)
})



print("passed test of all variables having data on their number of observations")