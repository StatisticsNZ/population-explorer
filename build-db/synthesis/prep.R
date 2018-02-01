


#===============Import data===============
source_schema <- "pop_exp_charlie"

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; Trusted_Connection=YES; Server=WTSTSQL35.stats.govt.nz,60000")

# by pulling people out on the basis of their seed, we get a reproducible example:
set.seed(123)
seed_thresh <- runif(1, 0, 0.5)
sql1 <- paste0("
   SELECT top 100000 *
   INTO #sample
   FROM IDI_Sandpit.", source_schema, ".dim_person
   WHERE seed > XXXX
   ORDER BY seed")
# important to order by seed as otherwise they come out in the order they are stored in the dim_person table - which happens to be by sex so you only get one sex.

sql1 <- gsub("XXXX", seed_thresh, sql1)

sqlQuery(idi, sql1)
dim_person       <- sqlQuery(idi, "SELECT * FROM #sample") %>%
  select(-seed, -iwi) 

sql2 <- paste0("
  SELECT fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code 
  FROM IDI_Sandpit.", source_schema, ".fact_rollup_year
  WHERE fk_snz_uid IN (SELECT snz_uid FROM #sample)
    AND fk_date_period_ending >= '19800101'")
system.time({fact_rollup_year <- sqlQuery(idi, sql2)}) # 44 seconds

#sqlQuery(idi, "drop table #sample")


dim_value <- sqlQuery(idi, paste0("SELECT * FROM IDI_Sandpit.", source_schema, ".dim_explorer_value_year"))
dim_variable <- sqlQuery(idi, paste0("SELECT * FROM IDI_Sandpit.", source_schema, ".dim_explorer_variable"))

#========================impute some missing data in a small number of variables in dim_person==================
# birth_year_nbr, birth_month_nbr and parents_income_birth are quite serious problems of being NA in the dim_person table.
# We don't generally have NA in a dimension table, normally it is explicitly coded, but if we did this
# we would lose the numeric state of it (which is important too)

# we're going to impute these during the simulation and modelling, and then make a random selection of these 
# three variables NA again just before the final load.  So we note down who is missing:

the_missing_dims <- as.data.frame(is.na(dim_person[ , c("birth_year_nbr", "birth_month_nbr", "parents_income_birth_year")]) )
names(the_missing_dims) <- c("m_birth_year_nbr", "m_birth_month_nbr", "m_parents_income_birth_year")
the_missing_dims$random_id <- 1:nrow(the_missing_dims)

# we do the imputation based on a subset of explanatory variables
imputed <- mice(dim_person[ , c("birth_year_nbr", "birth_month_nbr", "parents_income_birth_year",
                            "sex", "born_nz", "europ", "maori", "pacif", "number_known_parents")], 
                m = 1)
# rm(data_orig_w_codes, data_orig_w_values, data_orig, fact_rollup_year)
completed <- complete(imputed)

dim_person_imputed <- dim_person %>%
  mutate(birth_year_nbr            = completed$birth_year_nbr,
         birth_month_nbr           = completed$birth_month_nbr,
         parents_income_birth_year = completed $parents_income_birth_year)

#========================turn into a wide version====================
data_orig <- fact_rollup_year %>%
  mutate(year_nbr = year(fk_date_period_ending)) %>%
  left_join(dim_variable[ , c("variable_code", "short_name")], by = c("fk_variable_code" = "variable_code")) %>%
  mutate(var_year = tolower(paste(short_name, year_nbr, sep = "_"))) %>%
  dplyr::select(-fk_variable_code, -fk_date_period_ending, -year_nbr, -short_name) 
  

# make two weird wide tables, one for the codes:
data_orig_w_codes <- data_orig %>%
  dplyr::select(-value) %>%
  # insert "_code" in front of the year number in what is going to become column names 
  # (assumes year number begins with 1 or 2, so will fail in the year 3000):
  mutate(var_year = gsub("_1", "_code_1", var_year),
         var_year = gsub("_2", "_code_2", var_year)) %>%
  # we don't want these codes to be misinterpreted by numbers, so force them to be characters:
  mutate(fk_value_code = as.character(fk_value_code)) %>%
  spread(var_year, fk_value_code, fill = filter(dim_value, short_name == "No data")[1, "value_code"])

# and one for the values:
data_orig_w_values <- data_orig %>%
  dplyr::select(-fk_value_code) %>%
  spread(var_year, value, fill = 0)

# check they came out the same size:
expect_equal(dim(data_orig_w_codes), dim(data_orig_w_values))

# combine those two, plus the original person dimension into one massive wide table with one row per person:
data_orig_w <- data_orig_w_codes %>%
  rename(snz_uid = fk_snz_uid) %>%
  left_join(data_orig_w_values, by = c("snz_uid" = "fk_snz_uid")) %>%
  left_join(dim_person_imputed, by = "snz_uid") 


# some last minut adjustments to data types
data_orig_w$number_known_parents <- as.character(data_orig_w$number_known_parents)
data_orig_w$sex <- as.character(data_orig_w$sex)
data_orig_w$born_nz <- as.character(data_orig_w$born_nz)
data_orig_w$europ <- as.character(data_orig_w$europ)
data_orig_w$maori <- as.character(data_orig_w$maori)
data_orig_w$asian <- as.character(data_orig_w$asian)
data_orig_w$melaa <- as.character(data_orig_w$melaa)
data_orig_w$pacif <- as.character(data_orig_w$pacif)
data_orig_w$other <- as.character(data_orig_w$other)

# so now we have a data frame with more than 1,000 columns to simulate and nearly 100,000 rows
# note - if doing for real would be nice to have a million rows.
dim(data_orig_w)
object.size(data_orig_w) # 640MB when value_code is int, 872 when it is character (which we need)




# create a skeleton of the left hand side of the table which we can then start adding to 
# one column at a time
data_synth_w <- data_orig_w %>%
  dplyr::select(snz_uid, sex, born_nz, birth_year_nbr, birth_month_nbr) %>%
  # give them new, made-up snz_uids for remote chance that snz_uid means anything to anyone:
  mutate(snz_uid = 1:n())


  
save(data_synth_w, data_orig_w, the_missing_dims, dim_variable, dim_value, source_schema,
     file = "synthesis/temp_data/original-data.rda")
