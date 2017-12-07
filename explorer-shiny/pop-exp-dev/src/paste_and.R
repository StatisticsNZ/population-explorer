#' function for collapsing a string vector c("x", "y", "z") into "x, y and x"
#' 
#' @author Peter Ellis, 25 November 2017
paste_and <-function(x){
  n <- length(x)
  
  if(n == 1){
    y <- x
  } else {
    x[n - 1] <- paste(x[n - 1], "and", x[n])
    y <- paste(x[-n], collapse = ", ")
  }
  return(y)
  
}

expect_equal(paste_and(c("lions", "tigers", "bears")), "lions, tigers and bears")
