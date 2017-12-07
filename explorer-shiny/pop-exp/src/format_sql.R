
#' function for formatting SQL into HTML so it works with the syntax highlighting
#' @author Peter Ellis
format_sql <- function(sql){
  if(class(sql) != "character"){
    stop("sql should be of good character")
  }
  
  sql <- paste("<pre><code class='language-sql'>", sql, "</code></pre>")
  return(prism_code_block(sql))
  
}