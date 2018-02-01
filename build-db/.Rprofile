message("Hello world")

packages_needed <- c("stats", "MASS", "nnet", "lubridate", "RODBC", "dplyr", "tidyr", "openxlsx", "testthat",
                     "stringr", "stringi", "rpart", "mice", "data.table", "rmarkdown", "ggraph", "DT", "betareg")

# load them up:
res <- lapply(packages_needed, require, character.only = TRUE)
if(length(res) < length(packages_needed)){
  stop("You need some more R packages.  Copy the code in 00-src/00-install-r-packages.R to the clipboard, close
       this R project (but leave R on), and paste the code into the console (or into a script and run a console).
       Or, just install.packages('whatever-package-you-just-got-warned-about')")
}

# clean up:
rm(res, packages_needed)


# load in all the R functions in the 00-src directory, including the important
# sqlExecute which loads an SQL file into R and sends it to the database via ODBC.
# sqlExecute is used extensively in the below.  It also logs results directly in
# the database in IDI_Sandpit.dbo.pop_exp_build_log
scripts <- list.files("00-src", pattern = "\\.[Rr]$", full.names = TRUE)
res <- lapply(scripts, source)
rm(res, scripts)

