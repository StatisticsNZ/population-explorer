

filename <- "tests/sql/variable-observation-counts.sql"
res <- sql_execute(channel  = idi, 
                   filename = filename, 
                   sub_in   = "pop_exp_test", 
                   sub_out  = test_schema,
                   fixed    = TRUE,
                   verbose = FALSE)

if(min(res$observations) < 1000){
  res %>%
    filter(observations < 1000) %>%
    print()
  stop("At least one person-period variable had implausibly few observations")
}

message("Passed test on all variables having a decent number of observations")