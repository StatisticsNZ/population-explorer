# Function for taking various output from the cohort modelling 
# Random Forest and elastic net regularisation models
# Peter Ellis early November 2017

explain_cohort <- function(response, n, birth_year, year_1, year_2, 
                           ranger_model, ranger_gof, elr_model, elr_gof,
                           form, unused, non_sig_vars){
  form[3] <- gsub("_code", "", form[3])
  unused <- gsub("_code", "", unused)
  best_pred <- as.character(ranger_model[1, "variable_ch"])
  # best_pred <- "hello world"
  respvar <- paste0("<em>", tolower(response), "</em>")
  
  
  txt <- "<h2>Approach</h2>"
  txt <- paste(txt, "<p>This page investigates the approximately", format(n, big.mark = ","), " people born in", birth_year, ". ")
  txt <- paste0(txt, "The aim is to understand if it is possible to predict their value of '", respvar, "' ")
  txt <- paste0(txt, "in ", year_2, " by looking at a range of available data in ", year_1, ".</p><p>")
  txt <- paste(txt, "<p>We use two different statistical modelling techniques to fit 
               models with this stylised formula:</p>")
  txt <- paste(txt, "<p class = 'formula'>", response, "~", form[3], "</p>")
  txt <- paste0(txt, "<p>The first model explains ", round(ranger_gof * 100), "% of variation in ", respvar, 
                ". The second explains ", round(elr_gof * 100), "%. This should be carefully taken into account 
                in interpreting any apparent effects; there are clearly many important factors not taken into 
                account in this model with the data available to us.</p>")
  
  
  txt <- paste(txt, "<h2>Interpretation</h2>")
  txt <- paste0(txt, "<p>In the chart on the right, the relative effectiveness of the variables used to predict ", 
               respvar, " in ", year_2, " is indicated by how far the red dot is to the right.  The variables have been ordered
               by their importance; so this means that the <em>", best_pred, "</em> in ", year_1, " variable is the most useful for this 
                 prediction.  The model behind this chart doesn't tell us what particular values of <em>",
               best_pred, "</em> lead to which values of ", respvar, " in ", year_2, ", however.</p>")
  txt <- paste0(txt, "<p>Instead, the impact of particular <i>values</i> of a predictor variable can be seen in the table
                below the chart.  These results come from a different type of modelling.  
                Only the characteristics that are found to be useful parts of the model are included in this table.  
                Positive values indicate a positive link to ", respvar, "; so we can see
                that having a value of '", elr_model[1, "level"], "' for ", elr_model[1, "variable"], " has a material ",
                ifelse(elr_model[1, "impact"] > 0, "positive", "negative"), " impact on expected ", respvar,
                " in ", year_2, ".</p>")
  txt <- paste0(txt, "<p>In addition to the variables shown in the graph, we tried these variables: <em>",
                paste(non_sig_vars, collapse = ", "), "</em>. They didn't seem to be helpful in predicting ", respvar, "</p>")
  
  
  txt <- paste0(txt, "<h3>Technical details</h3>")
  txt <- paste0(txt, "<p>The first model is a random forest, fit with the <em>ranger</em> package in the 
                <em>R</em> statistical computing environment.  The second is a linear regression with estimates 
                shrunk towards zero to avoid overfitting, using elastic net regularisation with the <em>glmnet</em>
                R package.  These methods are fairly robust 
                and safe in this situation.  These models should be interpreted with extreme 
                caution, and the results used as indicative of areas for future research.</p>")
  txt <- paste0(txt, "<p>The response variable is numeric, and the explanatory variables are all categorical.
                The response variable has been transformed by taking the square root of its absolute value 
                (and then restoring the original sign).  This method is very appropriate for counts 
                (most of the data in this case), and arguably 
                appropriate for magnitudes such as income; unlike a logarithm transform, it is appropriate for 
                variables like income with values of zero or negative numbers.</p>")
  txt <- paste0(txt, "<p>Data that is missing for ", respvar, " in ", year_2, " has been coded as zero.  Usually
                this is appropriate, but don't forget this is what happened.  Data that is missing for explanatory 
                variables is given its own explicit code of <em>no data</em>.")
  txt <- paste0(txt, "<p>We also would have used the following variables if we could, but there wasn't enough data
                     or variation in their ", year_1, " data: <em>", 
                paste(unused, collapse = ", "), "</em>.</p>")
  
  
  return(txt)
}