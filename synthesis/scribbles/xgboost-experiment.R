library(xgboost)
library(twidlr) # includes formula interface to xgboost

X_person <- X %>%
  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code, Maori_code, Pacif_code, Asian_code, MELAA_code, Other_code, iwi_code) %>%
  distinct()

X_person_synth <- X_person %>%  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code)

head(X_person)

mod <- xgboost(X_person, Maori_code ~ sex_code + birth_year_nbr + Europ_code, nrounds = 10)

mod
y <- predict(mod, data = X_person_synth)

# not convinced this is going anywhere........................