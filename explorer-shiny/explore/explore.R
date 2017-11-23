library(RODBC)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)

odbcCloseAll()

idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; Trusted_Connection=YES; Server=WPRDSQL36.stats.govt.nz,49530")


sql <- "select top 5 * from IDI_Sandpit.[DL-IMR2017-05].vw_ye_mar"
vw <- sqlQuery(idi, sql)
head(vw)

variables <- sqlQuery(idi, "select * from IDI_Sandpit.[DL-IMR2017-05].dim_explorer_variable")
values <- sqlQuery(idi, "select * from IDI_Sandpit.[DL-IMR2017-05].dim_explorer_value")

base_sql <- "
SELECT 
  SUM(seed) - FLOOR(SUM(seed))						            as sum_seed,
	SUM(value + (round(seed, 0) * 0.2 - 0.1) * value)   as perturbed_total,
  SUM(value)                                          as total,
	sex,
  year_nbr,
  born_nz,
  variable
FROM  IDI_Sandpit.[DL-IMR2017-05].vw_ye_mar_res_pop
WHERE variable in ('XXXXX', 'Resident') 
GROUP BY sex, year_nbr, born_nz, variable"

the_variable <- "Age"

sql <- gsub("XXXXX", the_variable, base_sql)

data_orig <- sqlQuery(idi, sql)

data_orig %>%
  as_tibble() %>%
  mutate(x = ifelse(variable == "Resident", 
                    fix_rand_round(total, sum_seed), 
                    perturbed_total)) %>%
  select(-total, -perturbed_total, -sum_seed) %>%
  mutate(sex = ifelse(is.na(sex), "Unknown", as.character(sex))) %>%
  spread(variable, x) %>%
  rename_("value" = the_variable) %>%
  mutate(AvgValue = value / Resident) %>%
  ggplot(aes(x = year_nbr, y = AvgValue, colour = sex, size = Resident)) +
    geom_line() +
    facet_wrap(~born_nz) +
    scale_size("Number of residents", label = comma) +
    labs(x = "Year ending March",
         y = paste0("Average value of '", the_variable, "'\nper resident population."))




