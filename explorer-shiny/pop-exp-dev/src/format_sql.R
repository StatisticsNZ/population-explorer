
format_sql <- function(sql){
  if(class(sql) != "character"){
    stop("sql should be of good character")
  }
  #sql <- gsub("\\n", "<br>", sql)
  
  sql <- paste("<pre>", sql, "</pre>")
  return(sql)
  
}