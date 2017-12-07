
#' convenience function for removing macrons
#' 
#' @param character string
#' @author Peter Ellis
#' @examples
#' remove_macron("ā")
remove_macron <- function(x){
  if(!is.character(x)){stop("x should be a character")}
    x <- gsub("ā", "a", x)
    return(x)
}


