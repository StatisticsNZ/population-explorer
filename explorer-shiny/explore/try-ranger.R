# This is a reproducible version of the error that was crashing the app at the moment
# Turns out the problem was when num.threads was not specified in the call to ranger.
# This meant ranger tried to access all the processors available, and this led to some
# kind of resource clash with other users on the RStudio server, which led to the breakdown.
# Peter Ellis, 15 November 2017

library(RODBC)
library(ranger)
library(forcats)

sql <-"SELECT 
x.*,
ISNULL(y.Income, 0) AS response
FROM
(SELECT top 20000 *
FROM IDI_Sandpit.pop_exp.vw_ye_mar_wide
WHERE birth_year_nbr = 1980
AND year_nbr = 1990) AS x
LEFT JOIN
(SELECT 
SQRT(ABS(CAST(Income AS FLOAT))) * SIGN(Income) AS Income, 
snz_uid
FROM IDI_Sandpit.pop_exp.vw_ye_mar_wide
WHERE birth_year_nbr = 1980
AND year_nbr = 2015) as y
ON x.snz_uid = y.snz_uid 
ORDER by response"

                   idi <- odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server;
                                  Trusted_Connection=YES; Server=WTSTSQL35.stats.govt.nz,60000")
                   
# 29, 23, 13, 10, 10  seconds when done with full dataset (which is about 51,000)
# 14, 10, 5, 3, 3 3 seconds when done with 10,000
# 8, 7, 7, 8, 7, 5   seconds when done with 20,000
system.time(cd <- sqlQuery(idi, sql)) 
# Unfortunately, if you add an ORDER BY NEWID() to the query in order to get a random sample,
# it adds as much time as you save from downloading.  So long as it's only 50,000 or so it's
# just as easy to download the full thing.

vars <- names(cd)


# we only want a certain number of columns to be explanatory variables
expl_variables <- vars[grepl("_code$", vars)]
expl_variables <- expl_variables[expl_variables != "iwi_code"]

# relevel so the reference level is the most frequent for each
for(i in expl_variables){
  cd[ , i] <- fct_infreq(as.character(cd[ , i]))
}

# we need to remove variables with only one variable
enough_variation <- apply(cd[ , expl_variables], 2, function(x){length(unique(x)) > 1})

cohort_form <- as.formula(paste("response ~", paste(expl_variables[enough_variation], collapse = " + ")))
cohort_form

system.time(mod <- ranger(cohort_form, data = cd, num.threads = 10)) # 1.5 seconds


#-------------------glmnet experiment-------------
# original versions of the modelling used cv.glmnet, which is nice, but is it necessary?
library(glmnet)
library(broom)

X <- model.matrix(cohort_form, data = cd)
head(X)

system.time(mod2 <- cv.glmnet(X, cd$response, alpha = 0.5)) # 1.4 seconds
system.time(mod3 <- glmnet(X, cd$response, alpha = 0.5)) # 0 seconds
 # cv.glmnet takes 1.4 seconds, versus 0.01 seconds.  So very small time difference
# and its worth it, given the download is quite a bit more than that

tidy(coef(mod2))
tidy(coef(mod3))
