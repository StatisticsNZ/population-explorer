# Count the number of observations for each value code in the main fact table.
# If there is only 1 in a row as a result of this query, it means that value code
# wasn't used, which is probably a mistake

filename <- "tests/sql/value-observation-counts.sql"
value_obs <- sql_execute(channel  = idi, 
                          filename = filename, 
                          sub_in   = "pop_exp_test", 
                          sub_out  = test_schema,
                          fixed    = TRUE,
                          stringsAsFactors = FALSE,
                          verbose = FALSE)

if(min(value_obs$observations < 2)){
  value_obs %>%
    filter(observations <2) %>%
    print()
  
  stop("Some codes in dim_explorer_value weren't used at all in the fact table.   Something probably gone wrong.")
}

print("Passed test on all values in dim_explorer_value being used in the fact table")