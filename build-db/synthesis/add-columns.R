

#----------------getting ready------------------------------------
if(!exists("data_orig_w")){ load("synthesis/temp_data/original-data.rda")}
adding_order   <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "adding-order")
expl_variables <- read.xlsx("synthesis/variable-relationships.xlsx", sheet = "variables")


#---------------person grain----------------------

responses <-   filter(adding_order, response_grain == 'person')

for(i in 1:nrow(responses)){
  the_resp <- responses[i, ]
  the_x_vars <- filter(expl_variables, response == the_resp$response)$explanatory
  synthesise(the_resp$response, the_x_vars, the_resp$model_type)  
}


#----------------person-period grain--------------
# these are a bit more complex because we need to create variable names with numbers in them

responses <-   filter(adding_order, response_grain == 'person-period')

n1 <- names(data_orig_w)
#responses[,1:3]

for(i in 1:nrow(responses)){
  the_resp <- responses[i, ]
  resp_years <- n1[grepl(paste0("^", the_resp$response, "_[1-2][0-9][0-9][0-9]$"), n1)]
  
  the_x_vars <- filter(expl_variables, response == the_resp$response)
  
  for(j in 1:length(resp_years)){
    the_resp_year <- resp_years[j]
    the_year <- as.numeric(str_extract(the_resp_year, "[1-2][0-9][0-9][0-9]$"))
    
    # some of the x_vars have person grain, so we start with them
    expl_vars <- filter(the_x_vars, is.na(lags))$explanatory
    
    # some of them vary over time eg income_1990, income_1991 so we first get their root:
    time_variant_vars <- filter(the_x_vars, !is.na(lags))
    
    # ... then add the year to that
    for(k in 1:nrow(time_variant_vars)){
      expl_vars <- c(expl_vars,
                     paste0(time_variant_vars[k, "explanatory"], "_", 
                             the_year - eval(parse(text = time_variant_vars[k, "lags"]))))
    }
    
    # we only want explanatory variables that exist (if they don't it usually means no data for that year)
    expl_vars <- expl_vars[expl_vars %in% n1]
    
    # now we create the synthetic version of this variable for this year
    synthesise(resp_name = the_resp_year, expl = expl_vars, model_type = the_resp$model_type)
    
  }
  save(data_synth_w, file = paste0("synthesis/temp_data/data_synth_w_", i, ".rda"))
}


#----------------recoding some variables-------------
# Some variables like income were first put into bins, then had continuous
# versions estimated from those bins, but not strictly truncated.  So now some of the bins will be out.
# Those variables need to be reestimated.
# Note - the problem with doing this is it seems to make the categorical variables noticeably *worse* than
# they were when they were just from the neural net.  Basically the numerics are really tough to model and
# doing it this way adds quite a bit of noise.  Possibilities include dropping the numeric versions altogether,
# or finding better ways of modelling numeric values given a particular range.

responses <- responses %>%
  filter(response %in% c("income", "benefits", "acc_value", "victimisations", "mental_health", "hospital",
                         "income2", "self_employed", "rental_income", "wages", "days_nz", "employment"))

for(i in 1:nrow(responses)){
  the_resp <- paste0(responses[i, "response"], "_code")
  resp_years <- n1[grepl(paste0("^", the_resp, "_[1-2][0-9][0-9][0-9]$"), n1)]
  
  for(j in 1:length(resp_years)){
    the_resp_year <- resp_years[j]
    the_year <- as.numeric(str_extract(the_resp_year, "[1-2][0-9][0-9][0-9]$"))
    
    expl_vars <- paste0(responses[i, "response"], "_", the_year)
    
    # now we create the synthetic version of this variable for this year
    synthesise(resp_name = the_resp_year, expl = expl_vars, model_type = "tree_class")
    
  }
}
#================complete==================

save(data_synth_w, file = "synthesis/temp_data/data_synth_w.rda")





