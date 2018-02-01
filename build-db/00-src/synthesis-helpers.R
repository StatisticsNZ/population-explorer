
#' see http://ellisp.github.io/blog/2015/09/05/creating-a-scale-transformation
power_mod <- function(x, lambda = 0.5){
  s <- sign(x)
  if(lambda != 0){
    y <- ((abs(x) + 1) ^ lambda - 1 )/ lambda * s  
  } else {
    y <- log(abs(x) + 1) * s
  }
  
  return(y)
}




#' Function with radical side effects, for synthesising a categorical variable in the **global environment** 
#' with a source dataframe called data_orig_w
#' and a target data frame called data_synth_w
#' @param resp_name character string of column to be synthesised
#' @param expl character vector of columns to use in predicting it
#' @examples
#' synthesis_cat(resp_name = "acc_claims_code_1995", expl = c("sex", "born_nz", "birth_year_nbr"))
#' synthesis_cat(resp_name = "income_code_2005", expl = c("sex", "born_nz", "birth_year_nbr"))
synthesis_nnet <- function(resp_name, expl){
  
  form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a neural network multinomial model."))
  print(form)
  model <- nnet::multinom(form, data = data_orig_w, MaxNWts = 10000) # 10000 is very slow... only needed for TA
  
  y <- predict(model, type = "probs", newdata = data_synth_w)  
  
  if(class(y) != "matrix"){
    # if there were 3 or more categories, this works out fine as matrix of probabilities with nice column names, but if not
    # but if there were only two, we just get a single vector of probabilities.  Covnert to a matrix
    y <- cbind(y, 1 - y)
    colnames(y) <- sort(unique(data_orig_w[ , resp_name]), decreasing = TRUE)
    
  }
  
  levs <- colnames(y)  
  
  # Sometimes y has an NA in every column.  When that happens we will replace with the average
  if(sum(is.na(y)) > 0){
    averages <- apply(y, 2, mean, na.rm = TRUE)  
    y[is.na(y[ , 1]), ] <- averages
  }
  
  
  imputed <- apply(y, 1, function(x){
    sample(levs, 1, prob = x)
  })
  
  # sometimes we use this function to estimate values, not just value codes, when there is a small
  # number of options (eg number of abuse events) and this fits better than negative binomial. So
  # we need to detect those cases and turn them from characters into numbers before attaching them:
  if(!grepl("_code", resp_name) && grepl("[12][0-9][0-9][0-9]$", resp_name)){
    imputed <- as.numeric(imputed)
  }
  
  
  data_synth_w[ , resp_name] <<- imputed
  
  cat("\n\nOriginal distribution:\n")
  print(table(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(table(data_synth_w[ , resp_name]))
  
}

#' Synthesise data using a negative binomial model
#' 
#' @details A common occurance for many of our data is counts, with excessive numbers of
#' zeroes.  We don't really know if they are real zeroes or have just gone missing.  I wanted
#' to use a zero-inflated poisson model but it was too slow and unstable (tried from pscl).  But it
#' would definitely be better :( in our particular case.
#' @param resp_name character name of response variable
#' @param expl character vector of explanatory variables
#' @references https://cran.r-project.org/web/packages/pscl/vignettes/countreg.pdf,
#' https://stats.stackexchange.com/questions/189005/simulate-from-a-zero-inflated-poisson-distribution 
#' https://statisticalhorizons.com/zero-inflated-models
#' 
#' @examples
#' synthesis_nb(resp_name = "acc_claims_1995", expl = c("sex", "born_nz", "birth_year_nbr"))
#' 
synthesis_nb <- function(resp_name, expl){
  expl <- ifelse(grepl("[1-2][0-9][0-9][0-9]$", expl) & !grepl("_code_", expl),
                 paste0("power_mod(", expl, ")"),
                 expl)
  
  form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a negative binomial model"))
  print(form)
  model <- mgcv::gam(form, data = data_orig_w, family = "nb")
  
  mu <- exp(predict(model, newdata = data_synth_w))
  theta <- model$family$getTheta(TRUE)
  y <- MASS::rnegbin(mu, theta = theta)
  
  data_synth_w[ , resp_name] <<- y
  
  cat("\n\nOriginal distribution:\n")
  print(summary(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(summary(data_synth_w[ , resp_name]))

}

#' synthesis with a simple tree - used for "no brainers" like going from numeric variable
#' to its categorical equivalent
#' synthesis_tree(resp_name = "acc_claims_code_1995", expl = c("acc_claims_1995"), type = "class")
#' @param type to pass to predict
synthesis_tree <- function(resp_name, expl, type){
  
  form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a classification or regression tree"))
  print(form)
  
  model <- rpart::rpart(form, data = data_orig_w, control = rpart.control(minsplit = 2, cp = 0.0001))
  
  y <- predict(model, newdata = data_synth_w, type = type)
  
  data_synth_w[ , resp_name] <<- y
  
  cat("\n\nOriginal distribution:\n")
  print(table(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(table(data_synth_w[ , resp_name]))
  
}

#' Synthesise data where the response has a log-normal distribution of the absolute value
#' 
#' This is designed for income, where we have separately estimated the income_code (ie binned categories) and just
#' want a numeric equivalent  It is a fair overall fit but doesn't produce enough outliers in either direction.
#' @examples
#' synthesis_sign_log_gauss(resp_name = "income_2005", expl = "income_code_2005") # ok except outliers
#' synthesis_sign_log_gauss(resp_name = "income_2005", expl = c("sex", "europ")) # unsatisfactory - all zeroes
synthesis_sign_log_gauss <- function(resp_name, expl){
  
  expl <- ifelse(grepl("[1-2][0-9][0-9][0-9]$", expl) & !grepl("_code_", expl),
                 paste0("power_mod(", expl, ")"),
                 expl)
    form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a regression based on both sign and sqrt"))
  print(form)
  
  the_sign <- sign(data_orig_w[ , resp_name])
  
  y <- log(abs(data_orig_w[ , resp_name]) + 0.01) 
  
  # we have a revised `form` - we sneak in our y instead of the original
  form1 <- as.formula(paste("y ~", paste(expl, collapse = " + ")))
  model1 <- lm(form1, data = data_orig_w)
  
  # we separately model the chance of being negative
  form2 <- as.formula(paste("the_sign ~",  paste(expl, collapse = " + ")))
  model2 <- rpart(form2, data = data_orig_w)
  
  y_hat <- exp(rnorm(n    = nrow(data_synth_w), 
                     mean = predict(model1, newdata = data_synth_w), 
                     sd   = summary(model1)$sigma))
  
  sign_hat <- round(predict(model2, newdata = data_synth_w))
  
  data_synth_w[ , resp_name] <<- round(sign_hat * y_hat)
  
  cat("\n\nOriginal distribution:\n")
  print(summary(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(summary(data_synth_w[ , resp_name]))
}

#' Really simple linear regression - for use with things like modelling age, given birth year number
#' Excludes zero values from the modelling altogether.
#' @examples
#' synthesis_linear(resp_name = "age_2005", expl = c("birth_year_nbr", "birth_month_nbr")) 
synthesis_linear <- function(resp_name, expl){
  
  
  form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a simple linear regression"))
  print(form)
  
    model <- lm(form, data = data_orig_w[data_orig_w[ , resp_name] != 0, ])
  
  y_hat <-  rnorm(n    = nrow(data_synth_w), 
                     mean = predict(model, newdata = data_synth_w), 
                     sd   = summary(model)$sigma)
  
  data_synth_w[ , resp_name] <<- round(y_hat)
  
  cat("\n\nOriginal distribution:\n")
  print(summary(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(summary(data_synth_w[ , resp_name]))
}

#'
#' @examples
#' synthesis_betareg366(resp_name = "education_1993", expl = c("age_1993", "education_code_1993"))
#' synthesis_betareg366(resp_name = "education_1993", expl = c("education_code_1993"))
synthesis_betareg366 <- function(resp_name, expl){
  expl <- ifelse(grepl("[1-2][0-9][0-9][0-9]$", expl) & !grepl("_code_", expl),
                 paste0("power_mod(", expl, ")"),
                 expl)
  
  form <- as.formula(paste(resp_name, "~", paste(expl, collapse = " + ")))
  message(paste("Synthesising", resp_name, "with a beta regression using 'proportion of year' as response"))
  print(form)
  
  # this next line was to deal with the problem of some people being in the country for more than 366 days
  # in the year, a bug in the int-tables/12-days-in-nz.sql script that has been since fixed.
  data_orig_w[ ,resp_name] <- pmin(366, data_orig_w[ ,resp_name])
  
  y <- (data_orig_w[ , resp_name] + 1) / 368
  
  # we have a revised `form` - we sneak in our y instead of the original
  form1 <- as.formula(paste("y ~", paste(expl, collapse = " + ")))
  model <- betareg(form1, data = data_orig_w)
  
  # see https://stats.stackexchange.com/questions/12232/calculating-the-parameters-of-a-beta-distribution-using-the-mean-and-variance
  est_beta_params <- function(mu, var) {
    alpha <- ((1 - mu) / var - 1 / mu) * mu ^ 2
    beta <- alpha * (1 / mu - 1)
    return(params = data.frame(alpha = alpha, beta = beta))
  }
  
  means <- predict(model, newdata = data_synth_w, type = "response") 
  vars <- predict(model, newdata = data_synth_w , type = "variance")
  shapes <- est_beta_params(means, vars)
  
  y_hat <- rbeta(nrow(data_synth_w), shapes$alpha, shapes$beta) * 365
  
  y_hat <- ifelse(y_hat <= ceiling(min(y_hat)), 0, y_hat)
  
  data_synth_w[ , resp_name] <<- round(y_hat)
  
  cat("\n\nOriginal distribution:\n")
  print(summary(data_orig_w[ , resp_name]))
  cat("\nSynthesised distribution:\n")
  print(summary(data_synth_w[ , resp_name]))
}


#' Traffic-directing function for choosing between the various synthesis functions
synthesise <- function(resp_name, expl, model_type){
  
  if(model_type == "multinomial"){
    synthesis_nnet(resp_name = resp_name, expl = expl)   
  } else {
    if(model_type == 'negative-binomial')  {
      synthesis_nb(resp_name = resp_name, expl = expl)   
    } else {
      if(model_type == 'tree_class') {
        synthesis_tree(resp_name = resp_name, expl = expl, type = "class")
      } else {
        if(model_type == 'tree_num') {
          synthesis_tree(resp_name = resp_name, expl = expl, type = "vector")
        } else
        if(model_type == 'sign-log-gaussian')  {
          synthesis_sign_log_gauss(resp_name = resp_name, expl = expl)
        } else 
          if(model_type == 'linear') {
            synthesis_linear(resp_name = resp_name, expl = expl)
          } else 
            if(model_type == 'beta-reg-366') {
              synthesis_betareg366(resp_name = resp_name, expl = expl)
            } else 
            warning(paste("Don't know how to fit model_type", model_type, "so skipping."))
      }
      
      
    }
  }
}