

tmp <- all_foreign_keys %>%
  filter(table_name == "fact_rollup_year") %>%
  left_join(data_frame(key_name = paste0("fk_y", 1:4)), by = "key_name")

if(nrow(tmp) != 4){
  print(tmp)
  stop("One of fk1, fk2, fk3, fk4 foreign constraints on fact_rollup_year is not present")
}

message("Passed test on the four foreign keys needed in the main fact table being present")