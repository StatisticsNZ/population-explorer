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
                     "broom", "shinycssloaders", "stringr")
res <- lapply(packages_needed, install)
rm(res, ip, packages_needed)


