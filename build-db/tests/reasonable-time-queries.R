# runs all the scripts with a name sample-query and compares them to some arbitrary "reasonable time" benchmarks
# Peter Ellis NOvember 2017

fns <- list.files(path = "tests/sql/", pattern = "^sample-query")
expected_times <- c(30, 10, 30, 15) # these are a bit of a judgement call!

for(i in 1:length(fns)){
  filename <- paste0("tests/sql/", fns[i])
  st <- system.time({
    sample_query <- sql_execute(channel  = idi, 
                                filename = filename, 
                                sub_in   = "pop_exp_test", 
                                sub_out  = test_schema,
                                fixed    = TRUE,
                                stringsAsFactors = FALSE,
                                verbose = FALSE)
  })
  
  if(st[3] > expected_times[i]){
    warning(paste("It took", st[3], "which is more than the expected", expected_times[i], "seconds to do a query that should be quicker than that"))
  }
  
  print(paste("Passed reasonable length of", fns[i]))
}
