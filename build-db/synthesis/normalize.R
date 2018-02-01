# If you're not running all this in a smooth single sequence of all the scripts in one session, 
# need to load in the data from last time:
if(!exists("data_synth_w")){
  load("synthesis/temp_data/original-data.rda") # has things like the original dim_value and dim_variable and the source_schema
  load("synthesis/temp_data/data_synth_w.rda")
}

dim_person_synth <- data_synth_w %>%
  select(snz_uid, sex, born_nz,
         birth_year_nbr, birth_month_nbr, parents_income_birth_year, number_known_parents,
         europ, maori, pacif, asian, melaa, other) %>%
  mutate(seed = sample(0:300, n(), replace = TRUE) / 300)

# This next chunk would make some of the data missing, in the same pattern as three columns had missing data in the original
# But this causes major complications in uploading to the database so I've left it out.  Options include making it NULL in
# the database, or leaving misleadingly complete.
# dim_person_synth <- dim_person_synth %>%
# left_join(the_missing_dims, by = c("snz_uid" = "random_id")) %>%
# mutate(birth_year_nbr            = ifelse(m_birth_year_nbr, NA, birth_year_nbr),
#        birth_month_nbr           = ifelse(m_birth_month_nbr, NA, birth_month_nbr),
#        parents_income_birth_year = ifelse(m_parents_income_birth_year, NA, parents_income_birth_year)) %>%
# select(-m_birth_year_nbr, -m_birth_month_nbr, -m_parents_income_birth_year)

# this unpivoting operation is a little lengthy ( 6 minutes), but nothing like on SQL Server:
system.time({
  fact_rollup_synth <- data_synth_w %>%
    as_tibble() %>%
    select(fk_snz_uid = snz_uid, dplyr::matches("_[1-2][0-9][0-9][0-9]$")) %>%
    gather(var_year, both_values, -fk_snz_uid) %>%
    mutate(year = str_extract( var_year, "[1-2][0-9][0-9][0-9]$"),
           fk_date_period_ending = paste0(year, "-12-31"),
           val_type = ifelse(grepl("_code_", var_year), "fk_value_code", "value"),
           var_name = gsub("_[1-2][0-9][0-9][0-9]$", "", var_year),
           var_name = gsub("_code", "", var_name)) %>%
    select(-var_year, -year)  %>%
    spread(val_type, both_values) %>%
    left_join(dim_variable %>% select(variable_code, short_name) %>% mutate(short_name = tolower(short_name)), 
              by = c("var_name" = "short_name")) %>%
    rename(fk_variable_code = variable_code) %>%
    mutate(value = round(as.numeric(value)),
           value = ifelse(is.na(value), 0, value)) %>%
    select(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code) %>%
    # remove the "no data" cases.  This takes a long time but drastically reduces
    # the size of the object (from about 50m to 10m observations), and makes it more
    # consistent with the actual version in the database:
    filter(!(value == 0 & fk_value_code == filter(dim_value, short_name == "No data")$value_code))
})

# Now we remove all person-year combinations where their age is negative.
# It might be more efficient computationally if we could eliminate these earlier (ie 
# not model people before they are born in the first place) but it's not obvious to
# me how we would do this
age_vc <- filter(dim_variable, short_name == "Age")$variable_code
bad_combos <- fact_rollup_synth %>%
  filter(fk_variable_code == age_vc & value < 0) %>%
  select(fk_snz_uid, fk_date_period_ending)


tmp <- fact_rollup_synth %>%
  anti_join(bad_combos, by = c("fk_date_period_ending", "fk_snz_uid"))

message(paste("Removing", nrow(fact_rollup_synth) - nrow(tmp), "observations when people were < 0 years old"))

fact_rollup_synth <- tmp
rm(tmp)

# we only want the variables we synthesised in the variable dimension:
dim_variable_synth <- dim_variable %>%
  filter(variable_code %in% unique(fact_rollup_synth$fk_variable_code) | grain == 'person')

# and we only want the values of the variables we synthesised
dim_value_synth <- dim_value %>%
  filter(fk_variable_code %in% unique(dim_variable_synth$variable_code))

# we save all four core tables as text files so they will be adequate for someone creating the database from scratch.
# But for our own SQL Server database, we only upload two of these tables, and the other two we adapt from the genuine one
# read.table() is too slow so we use fwrite() from the data.table package.
message("Writing text files in the synthesis/upload/ folder")
fwrite(dim_person_synth, file = "synthesis/upload/dim_person.txt", sep = "|", quote = FALSE, row.names = FALSE)
fwrite(dim_variable_synth, file = "synthesis/upload/dim_explorer_variable.txt", sep = "|", quote = FALSE, row.names = FALSE) 
fwrite(dim_value_synth, file = "synthesis/upload/dim_explorer_value_year.txt", sep = "|", quote = FALSE, row.names = FALSE) 
fwrite(fact_rollup_synth, file = "synthesis/upload/fact_rollup_year.txt", sep = "|", quote = FALSE, row.names = FALSE) 

# zipping up a version takes a while:
message("Creating a deflated zip version")
projdir <- setwd("synthesis/upload")
unlink("pop_exp_synth.zip")
zip("pop_exp_synth.zip", list.files(pattern = "\\.txt$"))
setwd(projdir)

#===============setup database=================

# remove previous versions from the staging area (which we are using the dbo schema for)
# try(sqlDrop(idi, "IDI_Sandpit.dbo.dim_person"))
# try(sqlDrop(idi, "IDI_Sandpit.dbo.fact_rollup_year"))



# Final step in this stage requires importing the data into SQL Server by hand.  Go to Management Studio,
# right click on the target database (IDI_Sandpit at the moment), select "tasks", "import data", choose 
# flatfile, and select the data.  We need to do this once for dim_person and once for fact_rollup_year.
# when you get the chance to edit mappings, you need to do this or they default to VARCHAR which causes
# problems.    For dim_person, change maori from VARCHAR to NVARCHAR.  Change birth year, birth month, 
# parents' income at birth to INT.  Change the file encoding in the "Code page:" drop down box 
# (not the Unicode tick box) to "65001 (UTF-8)" so it accepts macrons.
# For fact_rollup_year change date to DATE and everything else to INT.  Default encoding is ok.

# We do this by hand because sqlSave is way too slow (would take weeks), and I couldn't get BULK INSERT to see
# the file server.