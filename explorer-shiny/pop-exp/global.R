# The global.R file is run before either server.R or ui.R so is a good place to do things that
# we want to be in the environment for both of those files - eg the variables and values used
# to create drop down boxes.
# Peter Ellis, 12 October 2017

#===============global parameters=============
schema <- "IDI_Sandpit.pop_exp_bravo"

# minimum number of counts to not be suppressed:
sup_val <- 20

# ... and what to replace them with (alternatives include "Suppressed", but this means the variables are no longer numeric)
sup_repl <- NA


# height in pixels of images on the screen
img_ht <- "500px"

# Title of the application
app_title <- "Population Explorer 0.1.0.9000"

#===============setup=============================


library(MASS) # load this before dplyr so select() comes from dplyr
library(shiny)
library(shinyjs)
library(dplyr)
library(ggplot2)
library(scales)
library(RODBC)
library(tidyr)
library(forcats)
library(viridis)
library(DT)
library(colorspace)
# library(extrafont)
library(stringr)
library(glmnet)
library(ranger)
library(broom)
library(shinycssloaders)
library(praise)
library(openxlsx)
library(testthat)
library(thankr)
library(english)

scripts <- list.files("src", pattern = "\\.R$", full.name = TRUE)
devnull <- lapply(scripts, source)

# connection to database:
idi <- odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server;
                                  Trusted_Connection=YES; Server=WTSTSQL35.stats.govt.nz,60000")
# caution, see https://stackoverflow.com/questions/31191962/disconnect-from-postgresql-when-close-r-shiny-app
# I think this approach *might* use a global database connection for all users.  So when we have multiple users,
# they will all get kicked off when anyone's session ends.

#==============================create R version of the variables and values dimension tab les
#' R function to strip out excess tabs, spaces and returns from a character string so it looks ok to print
make_nice <- function(x){
  if(!class(x) %in% c("character", "factor")){
    stop("x should be a character or a factor")
  }
  y <- gsub("\\t", " ", x)
  y <- gsub("\\n", " ", y)
  y <- gsub(" +", " ", y)
  return(y)
  
}

orig_variables <- sqlQuery(idi, 
                           paste0("SELECT *, 
                               CAST(measured_variable_description AS NVARCHAR(4000)) AS mvd,
                               CAST(target_variable_description AS NVARCHAR(4000)) AS tvd
                                    FROM ", schema, ".dim_explorer_variable 
                                  ORDER BY variable_class, short_name"), 
                           stringsAsFactors = FALSE) %>%
                    mutate(measured_variable_description = make_nice(mvd),
                           target_variable_description = make_nice(tvd),
                           # tecnically the number of observations is output from the IDI, although the SDC 
                           # risk is surely precisely zero.  To be safe we'll only show four significant figures:
                           number_observations = signif(number_observations, 4)
                    ) %>%
                    select(-mvd, -tvd) %>%
  select(variable_class, short_name, long_name, measured_variable_description, target_variable_description, 
         data_linked_to_spine, number_observations, everything()) %>%
  arrange(variable_class, short_name)



values <- sqlQuery(idi, 
                   paste0("SELECT * FROM ", schema, ".dim_explorer_value_year"), 
                   stringsAsFactors = FALSE)

values <- values %>%
  left_join(orig_variables, by = c("fk_variable_code" = "variable_code")) %>%
  filter(use_in_front_end == "Use" | short_name.x == "No data") %>%
  rename(value_short_name = short_name.x,
         variable_short_name = short_name.y)

variables <- orig_variables %>%
  filter(use_in_front_end == "Use") %>%
  arrange(desc(var_type)) 

date_built <- min(variables$date_built)

#========================spine to sample ratio and text=============

rat <- sqlQuery(idi, paste0("SELECT spine_to_sample_ratio FROM ", schema, 
                                              ".dim_explorer_variable where short_name = 'Generic'"))

# older databases didn't have this so we assume they are 1:
if(is.character(rat)){
  spine_to_sample_ratio <- 1
} else {
  spine_to_sample_ratio <- rat$spine_to_sample_ratio
}

rm(rat)

if(schema == "IDI_Sandpit.pop_exp_sample"){
  spine_to_sample_ratio <- spine_to_sample_ratio * 100
}

sample_text <- ifelse(spine_to_sample_ratio == 1,
                      "This version of the Population Explorer datamart contains all individuals on the IDI spine.",
                      paste0("This version of the Population Explorer datamart contains a <b>one in ",
                             english(spine_to_sample_ratio), "</b> simple random sample of the IDI spine.  
                             All values have been weighted accordingly (after random rounding) to represent the full spine."))

#=====================turn variables into list for drop down boxes=============
legit_cat_vars  <- filter(variables, tolower(grain) == "person-period" | var_type == "category")
legit_cont_vars <- filter(variables, var_type %in% c("continuous", "count"))


# we turn these into lists, with names as the headings for each group of options.  Each element
# of the list is a vector of long_name choices.  The name of each element is a unique value of 
# variable_class.  This gives the "sub-heading" look and feel when used in ui.R for drop-down boxes.
legit_cat_vars_list <- tapply(legit_cat_vars$long_name, legit_cat_vars$variable_class, 
                              function(x){sort(x)}, simplify = FALSE)

legit_cont_vars_list <- tapply(legit_cont_vars$long_name, legit_cont_vars$variable_class, 
                               function(x){sort(x)}, simplify = FALSE)



#===================all the variables with _code in their name (ie all the discrete ones)===============
# this next object is used in the Cohort modelling - it's the column names with _code in them, basically:
all_code_vars <- paste0(legit_cat_vars$short_name, "_code") %>%
  tolower() %>%
  remove_macron()

#==================other miscellaneous imports===================
full_disclaimer <- readLines("src/full-disclaimer.html")

credits <- readLines("src/credits.html")
faq <- readLines("src/faq.html")

welcome_message <- readLines("src/welcome-message.html")
welcome_message <- gsub("SAMPLERATIO", sample_text, welcome_message)
welcome_message <- gsub("DATEBUILT", date_built, welcome_message)
                       



