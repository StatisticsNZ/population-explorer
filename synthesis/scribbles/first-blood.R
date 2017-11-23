library(RODBC)
library(dplyr)

idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; Trusted_Connection=YES; Server=WTSTSQL35.stats.govt.nz,60000")


set.seed(123)
seed_thresh <- runif(1, 0, 0.5)

sql <- "
SELECT  * 
FROM IDI_Sandpit.pop_exp.vw_ye_mar_wide v
INNER JOIN 
  (SELECT top 100000 snz_uid
   FROM IDI_Sandpit.pop_exp.dim_person
   WHERE seed > XXXX
   ORDER BY seed) p
ON v.snz_uid = p.snz_uid"
# important to order by seed as otherwise they come out in the order they are stored in the dim_person table - which happens to be by sex so you only get one sex.
 
sql <- gsub("XXXX", seed_thresh, sql)

# takes about 10 seconds for 100000 people sampled from the dim_person (which translates to less than that in the sample as not all have observations)
system.time(vw_ye_mar_wide <- sqlQuery(idi, sql))

value_codes <- sqlQuery(idi, "SELECT * FROM IDI_Sandpit.pop_exp.dim_explorer_value")


#======================tidy/munge the original data=============
sample_snz_uid <- unique(vw_ye_mar_wide$snz_uid)
uid_lookup <- data_frame(snz_uid = sample_snz_uid,
                         synth_uid = sample(1:length(sample_snz_uid), replace = FALSE))

X <- vw_ye_mar_wide %>%
  left_join(uid_lookup, by = "snz_uid") %>%
  select(-snz_uid, -snz_uid.1)

code_vars <- which(grepl("_code$", names(X)))
for(i in code_vars){
  X[ , i] <- ifelse(is.na(X[, i]) |  X[, i] == 0, "no data", X[, i])
}

# Is 0 a zero or an NA?  Currently I think it's a zero, and we just need to use zero-inflated statistical models for it
# cont_vars <- which(!grepl("_code$", names(X)))
# for(i in cont_vars){
#   X[ , i] <- ifelse(X[, i] == 0, "no data", X[, i])
# }


#==================non-changing person dimensions============
# first step is to model any non-selected unchanging variables
# We'll take for granted these variables:
# year_nbr, birth year, age, sex, Europ, born_nz
# ... so this is really a pseudo-synthetic data set.  That leaves us 

# First we want the actual data for these people.  Note there may be less here than we sampled for, because if there are no observations
# they won't be in the main view.
X_person <- X %>%
  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code, Maori_code, Pacif_code, Asian_code, MELAA_code, Other_code, iwi_code) %>%
  distinct()

X_person_synth <- X_person %>%  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code)

#===========================modelling===============================
# I tried a random forest (with ranger) but there wasn't enough individual level variability,
# even when took people at random from one of the 500 trees predicting them.  So a more parametric method needed.

#' Function for synthesising data in the global environment called X_synth
synthesis_cat <- function(var, expl = NULL, newdata){
  
  form <- as.formula(paste(var, "~ sex_code + birth_year_nbr + Europ_code", expl))
  model <- nnet::multinom(form, data = X_person, MaxNWts = 20000)
  
  y <- predict(model, type = "probs", newdata = newdata)  
  levs <- colnames(y)
  imputed <- apply(y, 1, function(x){
    sample(levs, 1, prob = x)
  })
  
  X_person_synth[ , var] <<- imputed
}


synthesis_cat(var = "Maori_code", expl = NULL, X_person_synth)
synthesis_cat(var = "Asian_code", expl = "* Maori_code", X_person_synth)
synthesis_cat(var = "Pacif_code", expl = "* Maori_code + Asian_code", X_person_synth)
synthesis_cat(var = "MELAA_code", expl = "* Maori_code + Asian_code + Pacif_code", X_person_synth)
synthesis_cat(var = "Other_code", expl = "* Maori_code + Asian_code + Pacif_code + MELAA_code", X_person_synth)
# iwi has too many weights unless we lump it up

 
# proportions should be similar
table(X_person_synth$MELAA_code, useNA = 'always')
table(X_person$MELAA_code, useNA = 'always')

table(X_person_synth$Maori_code, useNA = 'always')
table(X_person$Maori_code, useNA = 'always')


#------------modelling changing categorical variables-----------------
# eg region, TA, CYF contact, are you a single mother?
# might want to do this as modelling transitions rather than straight states.  In any event, need to 
# somehow deal with autocorrelation (tricky when it's a category).
form_so_far <- "* Maori_code + Asian_code + Pacif_code + MELAA_code + Other_code"

this_year <- min(X$year_nbr)

for(this_year in min(X$year_nbr):max(X$year_nbr)){
  X_this_year <- X %>% filter(year_nbr == this_year)
  
  X_person <- X_person %>%
    left_join(X_this_year[ , c("synth_uid", "Region_code")], by = "synth_uid") %>%
    rename(new_var = Region_code) %>%
    mutate(new_var = ifelse(is.na(new_var), "no data", new_var))
  
  var_name <- paste0("Region_code_", this_year)
  names(X_person) <- gsub("^new_var$", var_name, names(X_person))
  
  synthesis_cat(var = var_name, expl = form_so_far, newdata = X_person_synth)
  form_so_far <- paste(form_so_far, "+", var_name)
}

head(X_person_synth)
#---------------------modelling continuous variables-------------------
# options here are some kind of zero-inflated GLM out of the box and then allocating codes; 
# or doing the z-i modelling (and more) explicitly ourselves, modelling people's *codes* first, and then
# their continuous values given those categorical codes (ie put them in an "Income" box, then just model where they are within that box)

# points to consider