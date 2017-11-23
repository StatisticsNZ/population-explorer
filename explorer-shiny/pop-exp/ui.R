# define what would otherwise be a magic constant for the latest year to use for widgets in the UI
latest_year <- as.numeric(substring(Sys.Date(), 1, 4))

# size of the "waiting" spinner
twirly_size <- 1.5

shinyUI(fluidPage(
  tags$head(
    tags$link(rel = "stylesheet", type = "text/css", href = "styles.css")
  ),
  tags$body(
    div(img(src = 'SNZlogo1.png'), 
        style="position:absolute;text-align: center;top:20px;right:15px;background-color:white;height:100px;width:180px")
  ),
  
  # we need Shinyjs for, amongst other things, the twirlies to work:
  useShinyjs(),
  
    
  h1("Population Explorer prototype"),
  
  sidebarLayout(
    sidebarPanel(
      conditionalPanel("input.tabs != 'Cohort modelling'",
                       
        conditionalPanel("input.tabs == 'Line charts'" ,
          actionButton("action_line", "Update line chart data", icon("refresh"))
          ),               
        conditionalPanel("input.tabs == 'Cross tabs'",
                         actionButton("action_bar", "Update cross tab data", icon("refresh"))
        ),
        conditionalPanel("input.tabs == 'Distribution'" ,
          actionButton("action_density", "Update distribution data", icon("refresh"))
        ),               
        conditionalPanel("input.tabs == 'Heatmap'" ,
                         actionButton("action_heatmap", "Update heatmap data", icon("refresh"))
        ),               
        
        
        conditionalPanel("input.tabs == 'Line charts' | input.tabs == 'Distribution' | input.tabs == 'Heatmap'",  
          selectInput("cont_var",
                       "Continuous variable",
                       choices = variables[variables$var_type %in% c("continuous", "count"), "long_name"],
                      selected = "Income all sources")
        ),
         selectInput("cross_var_a", 
                     "Categorical variable",
                     choices = legit_cat_vars,
                     selected = "Maori"),
        conditionalPanel("input.tabs == 'Line charts' | input.tabs == 'Cross tabs'",
          uiOutput("cross_var_choice")
          ),
        
        conditionalPanel("input.tabs == 'Heatmap'",
           selectInput("cont_var_b",
                       "Second continuous variable",
                       choices = variables[variables$var_type %in% c("continuous", "count"), "long_name"],
                       selected = "Value of ACC injury claims")
        ),
        
         
        sliderInput("year", "Years to show", 1990, latest_year, value = c(2005, latest_year - 1), sep = "", step = 1),
        
        conditionalPanel("input.tabs == 'Distribution' | input.tabs == 'Heatmap'",  
           sliderInput("sample_size", "Sample size", 2000, 50000, value = 5000, step = 500)
        ),
        
        conditionalPanel("input.tabs == 'Heatmap'",  
           radioButtons("trend_line_method", "Trend line estimation method", 
                        choices = c("Smooth (LOESS or GAM)", "Robust linear regression"))
        ),
        
        
        checkboxInput("cohort_yn", "Filter to just people born in a given time period?"),
        conditionalPanel("input.cohort_yn",
          sliderInput("cohort_year", "Birth year", 1930, latest_year, value = c(1970, 1972), sep = "", step = 1)                       
                         
                         ),
        
        checkboxGroupInput("days_nz", "Filter by days people spent in New Zealand per year",
                            choices = filter(values, tolower(variable_short_name) == "days_nz")$value_short_name,
                            selected = filter(values, tolower(variable_short_name) == "days_nz")$value_short_name),
        
        
        selectInput("filt_var",
                     "Other filter variable",
                     choices = c("none", legit_cat_vars),
                     selected = "Region most lived in"),
           conditionalPanel("input.filt_var != 'none'", 
             uiOutput("filter_control")
           )
        ),
      conditionalPanel("input.tabs == 'Cohort modelling'",
          actionButton("action_cohort", "Update cohort analysis", icon("refresh")),
          selectInput("cohort_response",
                      "Response variable (continuous)",
                      choices = variables[variables$var_type %in% c("continuous", "count") & 
                                            variables$grain == "person-period" &
                                            variables$short_name != "Age", 
                                          "long_name"],
                      selected = "Income all sources"),
          sliderInput("cohort_birth_year", "Cohort's birth year", 1930, latest_year, value = 1980, sep = "", step = 1),
          sliderInput("cohort_year_1", "Year for explanatory data", 1990, latest_year - 1, value = 1990, sep = "", step = 1),
          sliderInput("cohort_year_2", "Year for response data", 1990, latest_year, value = 2015, sep = "", step = 1),
          htmlOutput("explain_cohort")
          
        )
      
      ),
    
    mainPanel(
      tabsetPanel(id = "tabs",
        tabPanel("Line charts",
          p(),
          withSpinner(plotOutput("line_plot", height = "600px"), 
                      color = snz_brand["blue"], color.background = snz_brand["orange"], 
                      size = twirly_size, type = 3),
          textOutput("message_lines"),
          downloadButton("download_lines", "Download"),
          radioButtons("line_precision", "Precision of rounded numbers", 
                       choices = c("Realistically approximate", "As precise as allowed"), inline = TRUE),
          p(),
          DT::dataTableOutput("line_data"),
          hr(),
          actionButton("show_sql_lines", "Hide/show SQL code"),
          htmlOutput("the_sql_lines")
        ),
        tabPanel("Cross tabs",
          p(),
          withSpinner(plotOutput("bar_plot", height = "600px"), 
                      color = snz_brand["blue"], color.background = snz_brand["orange"], size = twirly_size, type = 3),
          textOutput("message_bars"),
          downloadButton("download_bars", "Download"),
          radioButtons("bar_precision", "Precision of rounded numbers", 
                       choices = c("Realistically approximate", "As precise as allowed"), inline = TRUE),
          DT::dataTableOutput("bar_data"),
          hr(),
          actionButton("show_sql_bars", "Hide/show SQL code"),
          htmlOutput("the_sql_bars")
           
          ),
        tabPanel("Distribution",
          p(),
          withSpinner(plotOutput("density_plot"), 
                      color = snz_brand["blue"], color.background = snz_brand["orange"], size = twirly_size, type = 3),
           textOutput("message_density"),
           hr(),
           actionButton("show_sql_density", "Hide/show SQL code"),
           htmlOutput("the_sql_density")
          ),
        tabPanel("Heatmap",
            p(),
            withSpinner(plotOutput("heatmap_plot", height = "600px"), 
                        color = snz_brand["blue"], color.background = snz_brand["orange"], size = twirly_size, type = 3),
            textOutput("message_heatmap"),
            hr(),
            actionButton("show_sql_heatmap", "Hide/show SQL code"),
            htmlOutput("the_sql_heatmap")
            ),
        tabPanel("Cohort modelling",
             p(),
             h3("Variables with some predictive power"),
             withSpinner(plotOutput("ranger_plot", height = "600px"), 
                         color = snz_brand["blue"], color.background = snz_brand["orange"], 
                         size = twirly_size, type = 3),
             h3("Particular values of variables with some predictive power"),
             DT::dataTableOutput("glmnet_vars"),
             hr(),
             actionButton("show_sql_cohort", "Hide/show SQL code"),
             htmlOutput("the_sql_cohort")
                 
                 ),
        tabPanel("Variables",
            p("The variables used in this database, and their full descriptions, are listed below."),
            DT::dataTableOutput("variables")     
                 ),
        tabPanel("Disclaimer",
            HTML(full_disclaimer))
        ),
        hr(),
        p("Access to the data presented was managed by Statistics New Zealand under strict
micro-data access protocols and in accordance with the security and confidentiality
provisions of the Statistic Act 1975. These are not Official Statistics. Any
opinions, findings, recommendations, and conclusions expressed are not those of the
Statistics NZ. ")
    )
    )
    
  
)
)
    
  
