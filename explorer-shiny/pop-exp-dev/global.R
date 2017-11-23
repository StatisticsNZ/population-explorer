# The global.R file is run before either server.R or ui.R so is a good place to do things that
# we want to be in the environment for both of those files - eg the variables and values used
# to create drop down boxes.
# Peter Ellis, 12 October 2017


#===============setup=============================


library(MASS)
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

source("src/statsnz-palette.R")

# connection to database:
idi <- odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server;
                                  Trusted_Connection=YES; Server=WTSTSQL35.stats.govt.nz,60000")
# caution, see https://stackoverflow.com/questions/31191962/disconnect-from-postgresql-when-close-r-shiny-app
# I think this approach *might* use a global database connection for all users.  So when we have multiple users,
# they will all get kicked off when anyone's session ends.

schema <- "pop_exp_test"

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
                                    FROM IDI_Sandpit.", 
                                  schema, ".dim_explorer_variable order by short_name"), 
                           stringsAsFactors = FALSE) %>%
                    mutate(measured_variable_description = make_nice(mvd),
                           target_variable_description = make_nice(tvd)
                    ) %>%
                    select(-mvd, -tvd)


values <- sqlQuery(idi, 
                   paste0("select * from IDI_Sandpit.", schema, ".dim_explorer_value"), 
                   stringsAsFactors = FALSE)

values <- values %>%
  left_join(orig_variables, by = c("fk_variable_code" = "variable_code")) %>%
  rename(value_short_name = short_name.x,
         variable_short_name = short_name.y)

variables <- orig_variables %>%
  filter(! short_name %in% c('Resident', 'Generic')) %>%
  arrange(desc(var_type))

legit_cat_vars <- filter(variables, tolower(grain) == "person-period" | var_type == "category")$long_name

#==================other miscellaneous imports===================
full_disclaimer <- readLines("src/full-disclaimer.html")

