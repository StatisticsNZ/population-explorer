
#' function to take basic html and turn it into a one line-at-a-time data frame to be pasted into Excel.
#' 
#' @details This is very specific to the particular bit of HTML we have to convert
#' @author Peter Ellis
html_to_df <- function(ht){
 
  ht <- paste(ht, collapse = "\n")
  
  # first remove any actual line breaks in the HTML which are probably there for convenience, not
  # because they want actual line breaks
  ht <- gsub("\n", " ", ht)
  ht <- gsub("<hr>", "\n", ht)

  # we used <em> for very particular purpose of indicating variables, so we'll replace with back ticks
  ht <- gsub("<em>", "`", ht)
  ht <- gsub("</em>", "`", ht)
  
  # paragraph ends should become line breaks
  ht <- gsub("</p>", "\n", ht)
  ht <- gsub("<p>", "\n", ht)
  
  # dot points should become line breaks with a sort of ASCII dot point
  ht <- gsub("<ul>", "\n", ht)
  ht <- gsub("</ul>", "\n", ht)
  ht <- gsub("<li>", " * ", ht)
  ht <- gsub("</li>", "\n", ht)
  
  # Any multiple spaces in a row should be collapsed into one space:
  ht <- gsub(" +", " ", ht)
  
  #ht <- str_wrap(ht, 100)
  
  # Headings will generally be on their own so replace with nothing:
  ht <- gsub("<h2>", " ", ht)
  ht <- gsub("</h2>", " ", ht)
  
  #Web address need to have the "http://" address removed and only keep the "www." address.  
  #Also removes the text string that is displayed in the place the "http://..." address.
  #This also puts the web address on its own line as I hope that this is enable it to be live one print out
  ht <- gsub("<a.*//", "", ht)
  ht <- gsub("'.*>.", ".\n", ht)

  
  # # split into a vector of one element for each line, including blanks
  paras <- str_split(ht, "\n")

  # now let's break into some reading length lines of our own
  paras <- sapply(paras, str_wrap, width = 100)
  paras <- unlist(str_split(paras, "\n"))
  return(as.data.frame(paras))
}



#' Make an Excel version of a data frame, with a sheet of the SQL that made it, and another
#' sheet of the textual explanation if there is one
#' @parameter x a data frame or similar to write as first tab of an Excel sheet
#' @author Peter Ellis
make_excel_version <- function(x, sql = NULL, explain = NULL, filename = "temp.xlsx"){
  wb <- createWorkbook()
  
  addWorksheet(wb, sheetName = "IDI Disclaimer", gridLines = FALSE, tabColour = snz_brand["yellow"])
  writeData(wb, "IDI Disclaimer", html_to_df(full_disclaimer), rowNames = FALSE, colNames = FALSE)
  
  addWorksheet(wb, sheetName = "Data", tabColour = snz_brand["purple"])
  writeData(wb, "Data", as.data.frame(x), rowNames = FALSE)
  setColWidths(wb, sheet = "Data", cols = 1:ncol(x), widths = "auto")
  
  if(!is.null(sql)){
    addWorksheet(wb, sheetName = "SQL", gridLines = FALSE, tabColour = snz_brand["blue"])
    sql_lines <- str_split(sql, "\n")
    writeData(wb, "SQL", as.data.frame(sql_lines), rowNames = FALSE, colNames = FALSE)
  } 
  
  if(!is.null(explain)){
    addWorksheet(wb, sheetName = "Description", gridLines = FALSE, tabColour = snz_brand["orange"])
    writeData(wb, "Description", html_to_df(explain), rowNames = FALSE, colNames = FALSE)
  }
  
  saveWorkbook(wb, file = filename)
  
}
