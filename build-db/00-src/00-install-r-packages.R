library(utils)
ip <- installed.packages()

install <- function(pkg, installed = row.names(ip)){
  if(!pkg %in% installed){
    install.packages(pkg)
  }
}

packages_needed <- c("stats", "MASS", "nnet", "lubridate", "RODBC", "dplyr", "tidyr", "openxlsx", "testthat",
                     "stringr", "stringi", "rpart", "mice", "data.table", "rmarkdown", "ggraph", "DT", "betareg")

# install packages if not present:
res <- lapply(packages_needed, install)