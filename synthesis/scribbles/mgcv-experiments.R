library(mgcv)
library(glmnet)
library(glmnetUtils)

X_person <- X %>%
  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code, Maori_code, Pacif_code, Asian_code, MELAA_code, Other_code, iwi_code) %>%
  distinct()

X_person_synth <- X_person %>%  select(synth_uid, sex_code, born_nz_code, birth_year_nbr, Europ_code)


# there's people missing data because they've got no data in any given year; and people with some data but not in the particular variable.
# so we should actually model it in *3* steps.  First, do we have any data for this person at all in year Y; then do we have data on this
# particular variable; then what is the value of the variable

latest_expl_vars <- "~ sex_code + birth_year_nbr + Europ_code"

#' Function for synthesising data in the global environment called X_synth
synthesis_cat <- function(resp_name){
  codes <- data.frame(resp_name = unique(X_person[ , resp_name]), stringsAsFactors = FALSE) %>%
    mutate(resp_code = 0:(n() - 1)) 
  names(codes)[1] <- resp_name
  
  X_person_recoded <- X_person %>% left_join(codes, by = resp_name)
  
  K <- nrow(codes) - 1
  print(latest_expl_vars)
  form <- list(as.formula(paste("resp_code", latest_expl_vars)))
  for(i in 1:(K - 1)){
    form[[i + 1]] <- as.formula(latest_expl_vars)
  }
  model <- gam(form, data = X_person_recoded, family = multinom(K = K))
  
  y <- predict(model, type = "response", data = X_person_synth)  
  levs <- codes[ , resp_name, drop = TRUE]
  imputed <- apply(y, 1, function(x){
    sample(levs, 1, prob = x)
  })
  
  X_person_synth[ , resp_name] <<- imputed
  latest_expl_vars <<- paste(latest_expl_vars, "+", resp_name)
}


synthesis_cat("Maori_code")
synthesis_cat("Asian_code")
synthesis_cat("Pacif_code")
synthesis_cat("MELAA_code")
synthesis_cat("Other_code")
system.time(synthesis_cat("iwi_code")) # atakes much longer


table(X_person_synth$Maori_code)
table(X_person$Maori_code)
table(X_person_synth$Asian_code)
table(X_person$Asian_code)

table(X_person$iwi)



#------------modelling changing categorical variables-----------------
# eg region, TA, CYF contact, are you a single mother?
# might want to do this as modelling transitions rather than straight states.  In any event, need to 
# somehow deal with autocorrelation (tricky when it's a category).

# this will work but takes too long - 60+ minutes perhaps per extra variable, with only 100,000 people sampled (and 50,000 actually with data)

for(this_year in min(X$year_nbr):2009){
  X_this_year <- X %>% filter(year_nbr == this_year)
  
  X_person <- X_person %>%
    left_join(X_this_year[ , c("synth_uid", "Region_code")], by = "synth_uid") %>%
    rename(new_var = Region_code) %>%
    mutate(new_var = ifelse(is.na(new_var), "no data", new_var))
  
  var_name <- paste0("Region_code_", this_year)
  names(X_person) <- gsub("^new_var$", var_name, names(X_person))
  
  synthesis_cat(var_name)
  
}

#------------modelling changing continuous variables

this_year <- 2008
X_this_year <- X %>% filter(year_nbr == this_year)

X_person <- X_person %>%
  left_join(X_this_year[ , c("synth_uid", "Income")], by = "synth_uid") 
head(X_person)
var_name <- paste0("Income_", this_year)
names(X_person) <- gsub("^new_var$", var_name, names(X_person))

X_person$missing <- is.na(X_person$Income) * 1


model_missing <- glm(missing ~ sex_code, data = X_person, family = "binomial")

model_missing <- glm(missing ~ sex_code + Region_code_2008, data = X_person, family = "binomial")
summary(model_missing)

table(X_person$Region_code_2008, X_person$missing)
y <- predict(model_missing, data = X_person, type = "response")

sum(X_person$Income == 0, na.rm = TRUE)

# this is tricky because we need to be able to model negative income as well as positive.  But for now:
model_value <- lm(log(Income) ~ sex_code + Region_code_2008, data = subset(X_person, Income > 0))
summary(model_value)

filter(X_person, Income == 0) %>% head
filter(X_person, is.na(Income)) %>% head

par(mfrow=c(2,2))
plot(model_value)
