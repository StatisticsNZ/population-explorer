# server.R for the Population Explorer front end
# Peter Ellis, October 2017

# TODO - cohort modelling should be limited to people who are living in the country more than X days a year



#====================setup=========================
# Note that global.R is run first by shiny
# What we have in this chunk is set-up code specific to the server.R file


# minimum number of counts to not be suppressed:
sup_val <- 20
# ... and what to replace them with (alternatives include "Suppressed")
sup_repl <- NA

source("src/fix_rand_round.R")
source("src/statsnz-palette.R")
source("src/format_sql.R")
source("src/explain_cohort.R")

R2 <- function(x, y){cor(x, y) ^ 2}

# Import the skeleton of the SQL statements
line_sql     <- gsub("SCHEMA", schema, paste(readLines("src/continuous.sql"), collapse = "\n"))
bar_sql      <- gsub("SCHEMA", schema, paste(readLines("src/two-cat.sql"), collapse = "\n"))
density_sql  <- gsub("SCHEMA", schema, paste(readLines("src/density.sql"), collapse = "\n"))
heatmap_sql  <- gsub("SCHEMA", schema, paste(readLines("src/continuous-2-var.sql"), collapse = "\n"))
cohort_sql   <- gsub("SCHEMA", schema,  paste(readLines("src/cohort-model-data.sql"), collapse = "\n"))


shinyServer(function(input, output, session) {
  
  
  session$onSessionEnded(function(){
    message("goodbye!")
    odbcClose(idi)
  })
  
  #------------------------work out line of code doing filtering (ie "WHERE"), to put into SQL--------------------
  #' This is the text that will replace filter_line_here in the SQL
  #' eg WHERE Region = 14 for Bay of Plenty (note that numbers change with each database rebuild)
  #' @value returns two text strings; second element is the one for the line chart sql; first is for the cross tab / bar chart sql.
  filter_line <- reactive({
    days_codes <- values[values$value_short_name %in% input$days_nz, "value_code"]
    days_filt <- paste("WHERE Days_NZ_code in (", paste(days_codes, collapse = ","), ")")
    
    if(input$filt_var != "none"){
      
      variable_name <- variables[variables$long_name == input$filt_var, "short_name"]
      value_code <- values[values$value_short_name %in% input$filt_val, "value_code"]
      txt <- paste0(days_filt, " AND ", variable_name, "_code in ( ", paste(value_code, collapse = ","), ")")
    } else {
      txt <- days_filt
    }
    
    txt <- paste(txt, "\n    AND year_nbr >=", input$year[1], "AND year_nbr <=", input$year[2])
    
    if(input$cohort_yn){
      txt <- paste(txt, "\n    AND a.birth_year_nbr >=", input$cohort_year[1], 
                   " AND a.birth_year_nbr <=", input$cohort_year[2])
    }
    
    return(txt)
  })
  
  filter_subtitle <- reactive({
    tmp <- paste(input$filt_val, collapse = ", ")
    txt <- ifelse(input$filt_var != "none", paste0("Filtered to people recorded as ", tmp), "")
    return(txt)
    
  })
  
  #------------------dynamic creation of pick box for filter options-------------
  # this is the dynamic check box input for choices of things to filter by.
  # This has to be in the server side because what options of values you have
  # to filter by obviously depends on what variable you chose for filtering.
  output$filter_control <- renderUI({
    if(tolower(input$filt_var) != "none"){
      vc <- variables[variables$long_name == input$filt_var, "variable_code"]
      v <- values %>%
        filter(fk_variable_code == vc) %>%
        arrange(var_val_sequence)
        
      checkboxGroupInput("filt_val",
                "Values to filter to",
                choices = v$value_short_name,
                selected = sample(v$value_short_name, 1))
    }
  })
  
  #--------------------Other dynamic choices for the UI------------------
  # we want to dynamically define the choice of the second categorical variable
  # to make sure it isn't the same as the first, which causes problems (cross tab
  # of a variable by itself confuses the SQL group by clauses)
  output$cross_var_choice <- renderUI({
    choices <- legit_cat_vars
    choices <- choices[choices != input$cross_var_a]
    
    selectInput("cross_var_b", 
                "Second categorical variable",
                choices = choices,
                selected = "sex")
  })
  #------------------------------line chart------------------------------------- 
  # line chart of a single continuous variable over time
  y_variable <- reactive({
    tmp <- as.character(variables[variables$long_name == input$cont_var, "short_name"])
    return(tmp)
  })
  
  the_sql_lines <- reactive({
    sql <- gsub("CONT1", y_variable(), line_sql)
    sql <- gsub("CAT1", bar_variables()[1], sql)
    sql <- gsub("CAT2", bar_variables()[2], sql)
    sql <- gsub("filter_line_here", filter_line(), sql)
    return(sql)
  })
  
  
  output$message_lines <- renderText({paste(max(0, nrow(data_orig_lines())), "rows of summary data.")})
  #output$message_lines <- renderText({data_orig_lines()})
  
  data_orig_lines <- reactive({
    input$action_line
    isolate(sqlQuery(idi, the_sql_lines()))
    })
  
  data_line <- reactive({
    input$action_line
    isolate({
      if(class(data_orig_lines()) != "character"){
        data_orig_lines() %>%
          mutate(people = fix_rand_round(freq, sum_seed),
                 people = ifelse(freq < sup_val, NA, people)) %>%
          mutate(avg_value = signif(perturbed_total / people, 3)) %>%
          mutate(people = ifelse(freq < sup_val, sup_repl, people),
                 avg_value = ifelse(freq < sup_val, sup_repl, avg_value)) %>%
          mutate(var_1 = fct_reorder(var_1, var_1_sequence)) %>%
          mutate(var_2 = fct_reorder(var_2, var_2_sequence)) %>%
          select(year_nbr, var_1, var_2, people, avg_value) %>%
          arrange(desc(year_nbr), var_1, var_2)
      }
    })
  })
  
  data_line_table <- reactive({
    input$action_line
    
    isolate({
      if(!is.null(data_line())){
        tmp <- data_line()
        
        if(input$line_precision == "Realistically approximate"){
          tmp[ , 4] <- signif(tmp[ , 4], 2)
          tmp[ , 5] <- signif(tmp[ , 5], 2)
        }
        
        names(tmp) <- c("Year ending March", input$cross_var_a, input$cross_var_b, "Number of people (random rounded)", 
                        paste0("Average value of ", input$cont_var))
        return(tmp)  
      }
      
      
    })
  })
  
  line_colours <- reactive({
    n <- length(unique(data_line()$var_1))
    if(n > 6){
      tmp <- rainbow_hcl(n)
    } else {
      tmp <- snz_graph_colour[c(6, 1, 3, 4, 2, 5)]
    }
    return(tmp)
  })
  
  p_lines <- reactive({
    input$action_line
    isolate(
      if(!is.null(data_line())){
        data_line() %>%
          # convert back to numeric (coercing 'Suppressed' to be zero):
          mutate(avg_value = as.numeric(avg_value),
                 people = as.numeric(people)) %>%
          ggplot(aes(x = year_nbr, y = avg_value, colour = var_1, size = people)) +
          geom_line() +
          geom_point() +
          facet_wrap(~var_2) +
          scale_size("Number of people", label = comma) +
          scale_y_continuous(label= comma) +
          scale_colour_manual(bar_variables()[1], values = line_colours()) +
          labs(x = "Year ending March",
               y = paste0("Average value per person of\n'", input$cont_var, "'."),
               caption = "Individual values are perturbed and counts are fixed random rounded") +
            ggtitle(paste(input$cont_var, "by", input$cross_var_b),
                    filter_subtitle())
      }
     )
  })

  
       
  output$line_plot <- renderPlot({p_lines()})
  output$line_data <- DT::renderDataTable(data_line_table(), rownames = FALSE)
  output$the_sql_lines <- renderText(format_sql(the_sql_lines()))
  output$download_lines <- downloadHandler(
    filename = function() {
      paste0(input$cont_var, "-by-`", input$cross_var_a,
            "`-by-`", input$cross_var_b, "`-", filter_subtitle(),
            ".csv")
    },
    content = function(file) {
      write.csv(data_line_table(), file, row.names = FALSE)
    }
  )
  
  
  
  
  #---------------------------------bar chart----------------------------------------
  # bar chart showing cross tab of two categorical variables
  bar_variables <- reactive({
    tmp1 <- as.character(variables[variables$long_name == input$cross_var_a, "short_name"])
    tmp2 <- as.character(variables[variables$long_name == input$cross_var_b, "short_name"])
    return(c("A" = tmp1, "B" = tmp2))
    
  })
  
  
  the_sql_bars <- reactive({
    sql <- gsub("CAT1", bar_variables()[1], bar_sql)
    sql <- gsub("CAT2", bar_variables()[2], sql)  
    sql <- gsub("filter_line_here", filter_line(), sql)
    return(sql)
  })
  
  data_orig_bars <- reactive({
    input$action_bar
    isolate({
      tmp <- sqlQuery(idi, the_sql_bars()) 
      return(tmp)
    })
  })
  
   output$message_bars <- renderText({paste(nrow(data_orig_bars()), "rows of summary data.")})
  # output$message_bars <- renderText({data_orig_bars()})
  
  data_bars <- reactive({
    input$action_bar
    isolate({
      tmp <- data_orig_bars() %>%
        as_tibble() %>%
        
        # random round, and change year to being an ordered factor:
        mutate(freq_frr = fix_rand_round(freq, s = sum_seed),
               freq_frr = ifelse(freq < sup_val, sup_repl, freq_frr),
               year_nbr = as.ordered(year_nbr)) %>%
        
        mutate(var_1 = fct_reorder(var_1, var_1_sequence)) %>%
        mutate(var_2 = fct_reorder(var_2, var_2_sequence)) %>%
        
        select(year_nbr, var_1, var_2, freq_frr) %>%
        arrange(desc(year_nbr), var_1, var_2)
      return(tmp)
      
    })
  })
  
  data_bars_table <- reactive({
    # version of the data for the bar charts for the DT data table and CSV export
    input$action_bar
    isolate({
      tmp <- data_bars()
      
      if(input$bar_precision == "Realistically approximate"){
        tmp[ , 4] <- signif(tmp[ , 4], 2)
      }
      
      
      names(tmp) <- c("Year ending March", input$cross_var_a, input$cross_var_b, "Number people (random rounded)")
      return(tmp)
    })
  })
  
  p_bars <- reactive({
    input$action_bar
    isolate({
      data_bars() %>%
        mutate(freq_frr = as.numeric(freq_frr)) %>%
        ggplot(aes(x = var_2, weight = freq_frr / 1000, fill = year_nbr)) +
        geom_bar(position = "dodge") +
        facet_wrap(~var_1) +
        scale_fill_viridis("Year ending\nMarch", discrete = TRUE, direction = -1, option = "magma") +
        coord_flip() +
        scale_y_continuous(paste0("Thousands of people for this combination of ",
                                  bar_variables()[1], " and ", bar_variables()[2]),
                           label = comma) +
        guides(fill = guide_legend(reverse = TRUE)) +
        labs(caption = paste("Fixed random rounding; values below", sup_val, "are suppressed"),
             x = input$cross_var_b) +
        ggtitle(paste0(bar_variables()[1], " group x ", bar_variables()[2], " x year ending March"),
                filter_subtitle())
      })
    })
  
  output$bar_plot <- renderPlot({p_bars()})
  output$bar_data <- DT::renderDataTable({data_bars_table()}, rownames = FALSE)
  output$the_sql_bars <- renderText(format_sql(the_sql_bars()))
  output$download_bars <- downloadHandler(
    filename = function() {
      paste0(input$cross_var_a, "`-by-`", input$cross_var_b, "`-", filter_subtitle(),
             ".csv")
    },
    content = function(file) {
      write.csv(data_bars_table(), file, row.names = FALSE)
    }
  )
  
  #---------------------------density plot------------------------
  the_sql_dens <- reactive({
    sql <- gsub("CAT1", bar_variables()[1], density_sql)
    sql <- gsub("CONT1", y_variable(), sql)
    sql <- gsub("SEEDTHRESH", round(runif(1, 0, 0.8), 4), sql)
    sql <- gsub("min_dens_n", input$sample_size, sql)
    dens_filter <- gsub("WHERE", "", filter_line())
    sql <- gsub("rest_of_filter_line", dens_filter, sql)
    return(sql)
  })
  
  data_dens_orig <- reactive({
    input$action_density
    isolate({
      tmp <- sqlQuery(idi, the_sql_dens(), stringsAsFactors = FALSE) %>%
        mutate(var_1 = fct_reorder(var_1, var_val_sequence)) %>%
        select(-var_val_sequence) 
        
      return(tmp)
    })
  })
  
  mess_dens <- reactive({
    input$action_density
    isolate({
      n <- nrow(data_dens_orig())
      if(n >= input$sample_size){
        mess <- paste(n, "rows of sample data")
      } else {
        mess <- "Too few observations to show a density plot"
      }
      return(mess)
    })
  })
  
  output$message_density <- renderText({mess_dens()})
  
  
  fill_colours <- reactive({
    n <- length(unique(data_dens_orig()$var_1))
    if(n > 6){
      tmp <- rainbow_hcl(n)
    } else {
      tmp <- snz_graph_colour[c(6, 1, 3, 4, 2, 5)]
    }
    return(tmp)
  })
  
  p_density <- reactive({
    input$action_density
    isolate({
      n <- nrow(data_dens_orig())
      if(n >= input$sample_size){
      p <- data_dens_orig() %>%
        ggplot(aes(x = var_0, fill = as.factor(var_1))) +
          geom_density(alpha = 0.3, colour = NA) +
          scale_x_continuous(input$cont_var, label = comma) +
          coord_cartesian(xlim = quantile(data_dens_orig()$var_0, c(0.1, 0.9))) +
          scale_fill_manual(input$cross_var_a, values = fill_colours()) +
          ggtitle(paste0("Distribution of ", input$cont_var, " by ",input$cross_var_a),
                  filter_subtitle()) +
          labs(caption = "Truncated to not show the bottom and top 10%")
    } else {
      p <- NULL  
    }
    
    })
    return(p)
  })
    
    output$density_plot <- renderPlot({p_density()})
    output$the_sql_density <- renderText(format_sql(the_sql_dens()))

    
    #------------------------heatmap--------------------
    # heatmap of two continuous variables - basically instead of a scatter plot
    
    x_variable <- reactive({
      tmp <- as.character(variables[variables$long_name == input$cont_var_b, "short_name"])
      return(tmp)
    })
    
    
    the_sql_heatmap <- reactive({
      sql <- gsub("CONT1", y_variable(), heatmap_sql)
      sql <- gsub("CONT2", x_variable(), sql)
      sql <- gsub("CAT1", bar_variables()[1], sql)
      dens_filter <- gsub("WHERE", "", filter_line())
      sql <- gsub("rest_of_filter_line", dens_filter, sql)
      sql <- gsub("SEEDTHRESH", round(runif(1, 0, 0.8), 4), sql)
      sql <- gsub("min_dens_n", input$sample_size, sql)
      
      return(sql)
    })
    
    data_heat_orig <- reactive({
      input$action_heatmap
      isolate({
        tmp <- sqlQuery(idi, the_sql_heatmap(), stringsAsFactors = FALSE) 
        if(nrow(tmp) > 0){
          tmp <- tmp %>%  mutate(var_1 = fct_reorder(var_1, var_1_sequence)) 
        }
        return(tmp)
      })
    })
    
    mess_heat <- reactive({
      input$action_heatmap
      isolate({
        n <- nrow(data_heat_orig())
        if(n >= input$sample_size){
          mess <- paste(n, "rows of sample data")
        } else {
          mess <- "Too few observations to show a heatmap"
        }
        return(mess)
      })
    })
    
    output$message_heatmap <- renderText({mess_heat()})
    
    p_heatmap <- reactive({
      
      input$action_heatmap
      isolate({
        meth <- ifelse(input$trend_line_method == "Robust linear regression", "rlm", "auto")
        
        n <- nrow(data_heat_orig())
        if(n >= input$sample_size){
          p <- data_heat_orig() %>%
            ggplot(aes(x = cont_var_2, y = cont_var_1)) +
            # geom_jitter(shape = 1) +
            stat_density_2d(aes(fill = ..level..), geom = "polygon", alpha = 0.55) +
            geom_smooth(method = meth, colour = snz_graph_colour[4], fill = "grey80") +
            scale_x_continuous(input$cont_var_b, label = comma) +
            scale_y_continuous(input$cont_var, label = comma) +
            facet_wrap(~var_1) +
            coord_cartesian(xlim = quantile(data_heat_orig()$cont_var_2, c(0.1, 0.9)),
                            ylim = quantile(data_heat_orig()$cont_var_1, c(0.1, 0.9))) +
            ggtitle(paste0("Distribution of ", input$cont_var, " by ",input$cont_var_b, ", by ", input$cross_var_a),
                    filter_subtitle()) +
            labs(caption = "Truncated to not show the bottom and top 10%") +
            scale_fill_viridis() +
            theme(legend.position = "none")
          
        } else {
          p <- NULL  
        }
        
      })
      return(p)
    })
    
    output$heatmap_plot <- renderPlot({p_heatmap()})
    
    output$the_sql_heatmap <- renderText(format_sql(the_sql_heatmap()))
    
    #----------------------------SQL output------------
    # This section just groups together the chunk of code that toggles
    # the SQL code in the UI on and off at the push of the Hide/show button
    # Having all the code here is helpful if we want to change it all at
    # once (eg if we decide we don't want the animation)
    observeEvent(input$show_sql_lines,{
      toggle("the_sql_lines", anim = TRUE, animType = "slide")
    })
    
    observeEvent(input$show_sql_bars,{
      toggle("the_sql_bars", anim = TRUE, animType = "slide")
    })
    
    observeEvent(input$show_sql_density,{
      toggle("the_sql_density", anim = TRUE, animType = "slide")
    })
    
    observeEvent(input$show_sql_heatmap,{
      toggle("the_sql_heatmap", anim = TRUE, animType = "slide")
    })
    
    observeEvent(input$show_sql_cohort,{
      toggle("the_sql_cohort", anim = TRUE, animType = "slide")
    })
    
    
    #----------------cohort modelling-----------------------------
    resp_variable <- reactive({
      if(input$action_cohort == 0){ return() }
      isolate({
        tmp <- as.character(variables[variables$long_name == input$cohort_response, "short_name"])
        return(tmp)
      })
    })
    
    the_sql_cohort <- reactive({
      if(input$action_cohort == 0){ return("select 1 WHERE 1=2") }
      isolate({
        sql <- gsub("RESPVAR", resp_variable(), cohort_sql)
        sql <- gsub("BIRTHYEAR", input$cohort_birth_year, sql)
        sql <- gsub("YEAR1", input$cohort_year_1, sql)
        sql <- gsub("YEAR2", input$cohort_year_2, sql)
  
        return(sql)
      })
    })
    
    cohort_data <- reactive({
      if(input$action_cohort == 0){ return()}
      isolate({
        cat("downloading data\n\n")
        cd <- sqlQuery(idi, the_sql_cohort(), stringsAsFactors = FALSE) 
        cat(paste("downloaded", nrow(cd), "rows of data\n\n"))
        vars <- names(cd)
        
        
        # we only want a certain number of columns to be explanatory variables
        expl_variables <- vars[grepl("_code$", vars)]
        
        # we don't want to include Iwi as an explanatory variable as it's too sensitive
        expl_variables <- expl_variables[expl_variables != "iwi_code"]
        
        # relevel so the reference level is the most frequent for each
        for(i in expl_variables){
          cd[ , i] <- fct_infreq(as.character(cd[ , i]))
        }
        
        # we need to remove variables with only one variable
        enough_variation <- apply(cd[ , expl_variables], 2, function(x){length(unique(x)) > 1})
        
        cohort_form <- as.formula(paste("response ~", paste(expl_variables[enough_variation], collapse = " + ")))
        
        return(list(data = cd, form = cohort_form, unused = expl_variables[!enough_variation]))
      })
    })
    
  
     ranger_model <- reactive({
      if(input$action_cohort == 0){ return() }
      isolate({
        # the num.threads is important in the below, otherwise it tries to use all the CPUs
        # and that leads to crashes
        model_rf <- ranger(cohort_data()$form, data = cohort_data()$data, 
                           importance = "impurity", num.threads = 10)

        # we need a lower case version of the variables data frame for matching
        # with the lower case variable names that were in the column names of the wide view.
        vars2 <- variables[ , c("short_name", "long_name")]
        vars2$short_name <- tolower(vars2$short_name)
        
        # extract the "importance" of the explanatory variables
        imp <- tidy(importance(model_rf))  %>%
            mutate(variable = gsub("_code$", "", names)) %>%
            left_join(vars2, by = c("variable" = "short_name")) %>%
            mutate(variable = fct_reorder(variable, x),
                   variable_ch = as.character(variable),
                   long_name_ch = as.character(long_name)) %>%
            arrange(desc(x))
        
        
        # estimate goodness of fit
        gof <- R2(cohort_data()$data$response, model_rf$predictions)
        
        # we're only going to show the variables that are at least as important in the random forest
        # as the least important variable included in the elastic net regularisation model.  We
        # save this limited version of the variables as imp_limited:
        min_import <- min(filter(imp, variable_ch %in% elr_model()$coefs[, "variable"])$x)
        imp_limited <- filter(imp, x >= min_import)
        non_sig_vars <- imp$variable_ch[!imp$variable_ch %in% imp_limited$variable_ch]
        
        return(list(imp = imp, gof = gof, imp_limited = imp_limited, non_sig_vars = non_sig_vars))
      })
     })


    ranger_plot <- reactive({
      if(input$action_cohort == 0){ return() }
      isolate({
        ranger_title <- str_wrap(paste0("Characteristics of people born in ",
                                        input$cohort_birth_year,
                                        " at age ", input$cohort_year_1 - input$cohort_birth_year,
                                        " that are helpful for predicting ", input$cohort_response,
                                        " at age ",  input$cohort_year_2 - input$cohort_birth_year),
                                 70)
      lollipop_col <- snz_graph_colour[2]
      

      

        ranger_model()$imp_limited %>%
          ggplot(aes(x = x, y = variable, label = str_wrap(long_name, 40))) +
          geom_segment(xend = 0, aes(yend = variable), size = 1.5,
                       alpha = 0.3, colour = lollipop_col) +
          geom_point(colour = lollipop_col, size = 6, alpha = 0.2) +
          geom_text(hjust = 0, lineheight = 0.8) +
          xlim(c(0, max(ranger_model()$imp$x) * 1.2)) +
          labs(y = paste0("Variable observed in ", input$cohort_year_1),
               x = paste0("Importance in predicting ", input$cohort_response, " in ", input$cohort_year_2)) +
          ggtitle(ranger_title)
        
      })
    })
    
    
    elr_model <- reactive({
      if(input$action_cohort == 0){ return() }
      isolate({
        X <- model.matrix(cohort_data()$form, data = cohort_data()$data)
        elr_mod <- cv.glmnet(X, cohort_data()$data$response, alpha = 0.5)
        coefs <- tidy(coef(elr_mod)) %>%
          mutate(value_code = as.integer(str_extract(row, "[0-9]*$"))) %>%
          left_join(values, by = "value_code") %>%
          mutate(variable = gsub("[0-9]+", "", row),
                 variable = gsub("_code", "", variable),
                 level = value_short_name,
                 impact = signif(value, 3)) %>%
          select(variable, level, impact) %>%
          filter(variable != "(Intercept)") %>%
          arrange(desc(abs(impact)))
        
        gof <- R2(cohort_data()$data$response, predict(elr_mod, newx = X))
      
        return(list(coefs = coefs, gof = gof))
      })
        
    })
    
    explanatory_text <- reactive({
      if(input$action_cohort == 0){
              return("<p>Choose some settings and click 'Update cohort analysis'
                    to run model (can take a few minutes)</p>")
      }
      isolate({
        tmp <- explain_cohort(
          response     = resp_variable(),
          n            = round(nrow(cohort_data()$data), -3),
          birth_year   = input$cohort_birth_year,
          year_1       = input$cohort_year_1,
          year_2       = input$cohort_year_2,
          ranger_model = ranger_model()$imp_limited,
          ranger_gof   = ranger_model()$gof,
          elr_model    = elr_model()$coefs,
          elr_gof      = elr_model()$gof,
          form         = cohort_data()$form,
          unused       = cohort_data()$unused,
          non_sig_vars = ranger_model()$non_sig_vars)
        return(tmp)
      })
    })

    output$ranger_plot <- renderPlot({ranger_plot()})
    output$glmnet_vars <- DT::renderDataTable({elr_model()$coefs}, rownames = FALSE)
    output$the_sql_cohort <- renderText({format_sql(the_sql_cohort())})
    output$explain_cohort <- renderText({explanatory_text()})
            
    #-----------------------variables table----------------------------
    
    output$variables <- DT::renderDataTable({
      orig_variables %>%
        dplyr::select(-variable_code) %>%
        filter(short_name != "Generic")},
      rownames = FALSE)
      
    
})
