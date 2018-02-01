
var_count <- sqlQuery(idi, paste0("select count(1) as n from IDI_Sandpit.", test_schema, ".dim_explorer_variable 
                     where grain = 'person-period'"))$n

if(var_count <25){
  stop("Less than 25 person-period variables.  I thought we had at least 25 variables.")
}
print("Passed test of at least 25 person-period variables")