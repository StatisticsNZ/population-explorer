snz_brand <- c(
  black = "#272525",
  orange = "#ec6607",
  blue = "#004f9e",
  purple = "#5f2282",
  cyan = "#31b7bc",
  red = "#e4003a",
  yellow = "#fbb900",
  green = "#51ae32",
  grey = "#706f6e"
)

# This program saves five key columns from the dim_explorer_variable table as a CSV, doing a 
# bit of tidying up along the way for tabs and stuff
# usage is: 
# save_variables("pop_exp_test")

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

save_variables <- function(schema = "pop_exp"){
  require(RODBC)
  require(dplyr)
  
  odbcCloseAll()
  idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                          Trusted_Connection=YES; 
                          Server=WTSTSQL35.stats.govt.nz,60000")
  
  # it's tricky to import text fields that are more than 256 characters thanks to a flaw in Microsoft's ODBC driver,
  # so we have to explicitly CAST the full_description field
  variables <- sqlQuery(idi, 
                             paste0("SELECT *, 
                               CAST(measured_variable_description AS NVARCHAR(4000)) AS mvd,
                               CAST(target_variable_description AS NVARCHAR(4000)) AS tvd
                                    FROM IDI_Sandpit.", 
                                    schema, ".dim_explorer_variable order by short_name"), 
                             stringsAsFactors = FALSE) %>%
    mutate(measured_variable_description = make_nice(mvd),
           target_variable_description = make_nice(tvd),
           earliest_data = as.character(earliest_data),
           origin_tables = gsub("IDI_Sample", "IDI_Clean", origin_tables)
           ) %>%
    select(long_name, var_type, variable_class, grain, measured_variable_description, target_variable_description, origin_tables, earliest_data)
  
  nr <- nrow(variables) + 1
  nc <- ncol(variables)
  
  wb <- createWorkbook()
  
  addWorksheet(wb, sheetName = "Pop-Exp Variables")
  writeData(wb, "Pop-Exp Variables", as.data.frame(variables), rowNames = FALSE, colNames = TRUE, withFilter = TRUE)

  style_h <- createStyle(fontSize = 18, fontName = "Source Sans Pro", textDecoration = "bold", 
                         fontColour = snz_brand["orange"], valign = "center",
                         border = "bottom", borderColour = snz_brand["purple"], borderStyle = "double")
  addStyle(wb, "Pop-Exp Variables", style = style_h, rows = 1, cols = 1:nc)
  
  style_b <- createStyle(fontSize = 10, fontName = "Source Sans Pro", wrapText = TRUE, valign = "center")
  for(i in 1:nc){
    addStyle(wb, "Pop-Exp Variables", style = style_b, rows = 2:nr, cols = i) 
  } 
  setColWidths(wb, 
               sheet = "Pop-Exp Variables", 
               cols = 1:ncol(variables), 
               widths = c(32, 20, 25, "auto", 50, 32, 32, "auto"))
  
  
  setRowHeights(wb,
               sheet = "Pop-Exp Variables",
               rows = 1:nr,
               height = c(50, rep(75, nr-1)))
  
  freezePane(wb, sheet = "Pop-Exp Variables", firstRow = TRUE)
  
  pageSetup(wb, sheet = "Pop-Exp Variables", fitToWidth = TRUE, paperSize = 9, orientation = "landscape", printTitleRows = 1)
  
  saveWorkbook(wb, file = "doc/variables.xlsx", overwrite = TRUE)
  
}