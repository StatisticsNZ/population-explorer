# Functions in this script put together explanatory text for the line chart and crosstabs analysis
# in the main app.  They only get called once each, they are just abstracted out here to keep
# server.R down to a reasonable size.

# This text is produced in HTML by these functions.  When it gets downloaded later into spreadsheets,
# another function strips out the HTML and makes it more text-like.

# bit messy here I'm afraid.  Also lots of opportunities to add in more interpretive stuff.
# Peter Ellis 24 November 2017


#' Function for return some text on what percent of a variable's source tables was linked to the spine
#' Needs variables in the global environment
data_link <- function(var){
  if(is.character(var)){
    my_row <- filter(variables, long_name == var)
    
    if(my_row$grain == "person-period"){
      x <- my_row$data_linked_to_spine * 100
      txt <- paste0(round(x), "%", " of the data in the table or tables behind <em>", var, 
                    "</em> was successfully linked to the spine. ")
    } else {
      txt <-paste0("<em>", var, "</em> is an enduring personal characteristic of an individual 
                   on the spine and is estimated with fair reliability. ")
    }
  }
}


#' function for explaining the output from under the "lines" tab
explain_lines <- function(cont_var, cross_var_a, cross_var_b, resident, days_nz, filt_var, filt_val, year, cohort_yn, cohort_year){
  cont_var_h <- paste0("<em>", cont_var, "</em>")
  cross_var_a_h <- paste0("<em>", cross_var_a, "</em>")
  cross_var_b_h <- paste0("<em>", cross_var_b, "</em>")
  
    txt <- paste0(
"<hr><p>This shows the average values of ", cont_var_h,
" for different combinations of ", cross_var_a_h, " and ", cross_var_b_h, " each year from ", year[1], " to ", year[2], ".</p>")
    
    txt <- paste0(txt, "<p>The data included those people estimated to be in New Zealand for ",
paste_and(days_nz), " in each year")
    if(resident){
      txt <- paste0(txt, " and people that are included in the <em>Estimated Resident Population</em> for 30 June of each year.</p>")
    } else {
      txt <- paste0(txt, ".</p>")
    }
    
    if(cohort_yn){
      if(cohort_year[1] == cohort_year[2]){
        txt <- paste0(txt, "<p>Only people born in ", cohort_year[1], " are included.</p>")  
      } else {
        txt <- paste0(txt, "<p>Only people born between ", cohort_year[1], " and ",
                    cohort_year[2], " are included.</p>")  
      }
      
    }
    
    if(filt_var != "none") {
      txt <- paste0(txt, "<p>The data has been further restricted to people thought to be in the ",
                    paste_and(filt_val), " categories of <em>", filt_var, "</em>.</p>")
    }
    
 txt <- paste0(txt,                  
    
"<ul><li>", data_link(cont_var), "</li><li>", data_link(cross_var_a), "</li><li>", 
data_link(cross_var_b), "</li></ul>",
"<p>Data from the IDI should be used with caution, not least because of the data that
went 'missing' during the linking process; many totals and counts will be underestimates in 
ways that could be systematically materially biased (eg certain types of people may be more 
likely to have some missing data).</p>
<p>The database this comes from was last built on ", date_built, " and used the 'refresh' of the IDI 
that was current at that time.<p>")
 
  return(txt)
}

#' Explanatory text for the cross tabs
explain_bars <- function(cross_var_a, cross_var_b, resident, days_nz, filt_var, filt_val, year, cohort_yn, cohort_year){
  cross_var_a_h <- paste0("<em>", cross_var_a, "</em>")
  cross_var_b_h <- paste0("<em>", cross_var_b, "</em>")
  
  txt <- paste0(
    "<hr><p>This shows the random-rounded counts of people for different combinations of, ", 
    cross_var_a_h, " and ", cross_var_b_h, " each year from ", year[1], " to ", year[2], ".</p>")
  
  if(cohort_yn){
    if(cohort_year[1] == cohort_year[2]){
      txt <- paste0(txt, "<p>Only people born in ", cohort_year[1], " are included.</p>")  
    } else {
      txt <- paste0(txt, "<p>Only people born between ", cohort_year[1], " and ",
                    cohort_year[2], " are included.</p>")  
    }
    
  }
  
  txt <- paste0(txt, "<p>The data included those people estimated to be in New Zealand for ",
                paste_and(days_nz), " in each year")
  if(resident){
    txt <- paste0(txt, " and people that are included in the <em>Estimated Resident Population</em> for 30 June of each year.</p>")
  } else {
    txt <- paste0(txt, ".</p>")
  }
  
  if(filt_var != "none") {
    txt <- paste0(txt, "<p>The data has been further restricted to people thought to be in the ",
                  paste_and(filt_val), " categories of <em>", filt_var, "</em>.</p>")
  }
  
  
txt <- paste0(txt, "<ul><li>", data_link(cross_var_a), "</li><li>",  data_link(cross_var_b), "</li></ul>",
    "<p>Data from the IDI should be used with caution, not least because of the data that
went 'missing' during the linking process; many totals and counts will be underestimates in 
ways that could be systematically materially biased (eg certain types of people may be more 
likely to have some missing data).</p>
<p>The database this comes from was last built on ", date_built, " and used the 'refresh' of the IDI 
that was current at that time.<p>")
  return(txt)
}

