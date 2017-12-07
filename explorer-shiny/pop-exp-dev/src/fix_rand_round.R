# Peter Ellis, September 2017, based on method by Frances 

#' Fixed random rounding
#' 
#' 
#' Random rounding to base 3 based on Frances Krsinich's Noise for Counts and Magnitudes 
#' 
#' 
#' @param x vector of values to be rounded
#' @param s vector of sums of seeds to use to fix the rounding
#' @details This is the counts bit of "noise for counts and magnitudes".  When the sum of random seeds is <0.667,
#' it rounds x to the closest base 3 number; when it is >= 0.667, it rounds to the second closes base 3 number.
#' @examples
#' x <- sample(1:20, 20, replace = TRUE)
#' s <- runif(20)
#' fix_rand_round(x, s)
#' x
#' fix_rand_round(x, s)
fix_rand_round <- function(x, s = NULL){
  
  #-------------checks---------
  if(!is.numeric(x)){
    stop("x should be a numeric vector")
  }


  if(is.null(s)){
    warning("s (sum of random seeds) not provided so making them up...")
    set.seed(123)  
    s <- runif(length(x))
  }
  
  #---------------rounding-------------
  fl          <- floor(x / 3) * 3
  remainder   <- x - fl
  close_round <- ifelse(remainder %in% (0:1), fl, fl + 3)
  far_round   <- ifelse(remainder %in% (0:1), fl + 3, fl)
  rounded <- ifelse(s < 0.667, close_round, far_round)
  
  return(rounded)
  }
  
  