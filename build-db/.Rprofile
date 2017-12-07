message("Hello world")

library(stats) # so it gets loaded before dplyr to avoid filter problems
library(RODBC)
library(dplyr)
library(openxlsx)
library(testthat)
library(stringr)
library(stringi)

# load in all the R functions in the 00-src directory, including the important
# sqlExecute which loads an SQL file into R and sends it to the database via ODBC.
# sqlExecute is used extensively in the below.  It also logs results directly in
# the database in IDI_Sandpit.dbo.pop_exp_build_log
scripts <- list.files("00-src", pattern = "\\.[Rr]$", full.names = TRUE)
devnull <- lapply(scripts, source)

# set up database connection
odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")
