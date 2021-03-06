# This little utility installs any packages needed for the shiny app that new users might not have
# on their system.

ip <- installed.packages()

install <- function(pkg, installed = row.names(ip)){
  if(!pkg %in% installed){
    install.packages(pkg)
  }
}

packages_needed <- c("shiny", "shinyjs", "DT", "dplyr", "ggplot2", "scales", "RODBC", "tidyr", "forcats", 
                     "viridis", "extrafont", "colorspace", "knitr", "rmarkdown", "ranger", "glmnet",
                     "broom", "shinycssloaders", "stringr", "praise", "openxlsx", "testthat", "thankr", "english")
res <- lapply(packages_needed, install)
rm(res, ip, packages_needed)


# On RStudio01 there is a funny problem, probably with Rcpp, causing an encoding error with dplyr::mutate
# Only way to be sure of getting round it is to force installation of all of dplyr's dependencies.
if(Sys.info()["nodename"] == "wprdrstudio01"){
  install.packages(c("assertthat", "bindrcpp", "glue", "magrittr", "pkgconfig", "Rcpp", "tibble", 
                   "BH", "bindrcpp", "plogr"))
}