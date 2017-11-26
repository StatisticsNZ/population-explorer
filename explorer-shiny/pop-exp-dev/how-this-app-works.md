# How the Population Explorer front end works

Author: Peter Ellis
Date:   27 November 2017

## Overview

### Introduction

The Population Explorer consists of three products, all of them experimental at the time of writing:

1. A [dimensionally modelled](http://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/) datamart of annual and quarterly "rolled up" data with one observation per person-period-variable combination
2. An interactive web tool to explore the annual data in the datamart
3. A synthetic version 

This document explains the source code for the **interactive web tool** or web application, referred to as "the application" in this document.  The application is written in the [Shiny framework](https://shiny.rstudio.com/), an extension of the R statistical computing environment.

### What the application does

The application has four key steps:

1. The user interacts with widgets on a web page to select a type of analysis, variables to analyse and filter the data by, and hits a "refresh" button
2. The R server uses the user inputs to create an SQL query and sends it to the database to retrieve data, with as much aggregation occurring in the database as possible to minimise data transfers between servers
3. The R server performs analysis on the data including confidentialisation for [statistical disclosure control](https://en.wikipedia.org/wiki/Statistical_disclosure_control) as necessary, and generates summary graphics, tables, and explanatory text
4. These results are returned to the client an rendered in the web page.  The user can download a release-ready Excel version of tables, data and metadata, copy a PNG image to the clipboard, copy SQL for re-use in their own queries, or re-initiate the whole process.

The aim is to facilitate exploration of the data in the IDI.

### How the source code is structured

The codebase consists of a small number of files in R, SQL, CSS and JavaScript held in a single folder.

In the root directory, we have:

- `global.R` is run first, when a user initiates the application.  It loads necessary R packages and functionality, sets parameters such as which copy of the database to use, what minimum cell size of counts before suppressing them, and how high to make graphics in pixels.  It also creates appropriately structured R objects with information on the variables available in the database (which it interrogates to create those objects), for use in the user's widgets and in the server-side analysis.
- `ui.R` creates the user interface and performs steps 1 and 4 as described above under "What the application does"
- `server.R` runs server-side operations and performs steps 2 and 3

There are also two sub-directories:

- `src` holds three types of source code:
    - `*.R` files create functionality that has been abstracted out of `server.R` for maintainability purposes.  All these files are run by `global.R` during application initiation by the two lines of code that look like: `scripts <- list.files("src", pattern = "\\.R$", full.name = TRUE); devnull <- lapply(scripts, source)`
	- `*.sql` files are skeletons of SQL queries that are used by `server.R` as the basis for constructing actual legitimate queries.
	- `*.html` snippets (eg 'full-disclaimer.html') designed to be imported by R and used in `ui.R` as part of the applications' user-facing web page
- `www` holds assets for the web page and in particular:
    - `styles.css` is a cascading style sheet to give a Stats NZ look and feel to the web page.  Edit this to control things like fonts, heading sizes and colours for text other than that which is part of images.
	- `prism.css` controls the look of the SQL syntax highlighting in the browser.  Don't edit this file directly (well you can, but it's probably not worth the effort), but you can replace the file altogether with a different version from [http://prismjs.com/](http://prismjs.com/).  The currently chosen theme is "Solarized Light"
	- 'prism.js' is a JavaScript program that performs the actual syntax highlighting and has been downloaded from the same location.  
	- `SNZlogo1.png` is self-explanatory

## Structure of `ui.R`

This section describes how steps 1 and 4 (as described under "what the application does") are performed:

- user choices to control the analysis
- rendering results on the screen

This functionality is controlled by the `ui.R` script.

The bulk of `ui.R` script in a Shiny app is a single set of nested functions under of which the first is `shinyUI()`.  This makes for a lot of brackets... On the plus side, the layout of the script intuitively follows the hierarchy of the page.  Here is how the `ui.R` script is structured:

- `shinyUI` establishes this as a user interface
	- `navbarPage` says everything that follows is part of a bootstrap navbar page ie those tabs along the top
		- `tabPanel("Welcome")` - welcoming image and text
		- `tabPanel("Explore")` - the guts of the app
			- `sidebarLayout()` - the Explore page is going to have a side bar and a main panel
				- `sidebarPanel()` - definition of all the widgets and text that appears in the sidebar ie nearly all the drop down boxes.  There is some straightforward logic in this part with the use of `conditionalPanel()` so that some of the widgets only appear when needed eg the option to choose a second continuous variable only appears when the heatmap tab (see below) is select
				-  `mainPanel()` - the panel that holds the results		
					- `tabsetPanel()` - this main panel is going to have tabs itself
						- `tabPanel("Line Charts")`
						- `tabPanel("Cross tabs")`
						- `tabPanel("Distribution")`
						- `tabPanel("Heatmap")`
						- `tabPanel("Cohort modelling")`
					- some generic text (eg the short disclaimer) that appears under everything in the main panel, regardless of which tab is selected
		- `tabPanel("Variables")`
		- `tabPanel("Disclaimer")`
		- `tabPanel("FAQ")`
		- `tabPanel("Credits")`


### Choices made by the user and returned as variables

The `ui.R` file generates a number of variables.  These are then available to `server.R` as elements of the list named `input` (for example, as `input$cross_var_a`) or for JavaScript operations on the user interface itself (as `input.cross_var_a`).

The user is presented widgets to choose the variables that are relevant for their particular analysis.  For example, the drop-down box for `cont_var_b` (see below) only appears when the "Heatmap" tab has been selected


#### Variables used for the line chart, cross tab, distribution, and heat map tabs:

| Variable | Use | Choices | 
|--------|------|-------|
| `cont_var` | This stands for "continuous variable".  The average of this is the vertical axis of the line chart.  The raw value is used as the vertical axis of the "heatmap" (ie which would be a scatter plot except for confidentialisation needs). The raw value is also used as the horizontal axis of the density plot in the "distribution" tab.  | `legit_cont_vars_list` ie the list of legitimate continuous variables (those marked in the data base as "Use") |
| `cross_var_a` | This stands for "cross tab variable A", and is the first of two choices of a categorical variable.  It is mapped to colour in the line chart page and the distribution page, and is used to split the data into facets in the cross tabs page. | `legit_cat_vars_list` |
| `cross_var_b` | Mapped to colour in the cross tabs page.  Some of the code creating the widget to choose `cross_var_b` takes place on the server, because it needs to be created dynamically (it depends on the value chosen for `cross_var_a`) | `legit_cat_vars_list`, *except* for the option already chosen for `cross_var_a`.
| `cont_var_b` | A second continuous variable, used for the horizontal axis in the Heatmap. | `legit_cont_vars_list` |
| `sample_size` | For the Distribution and Heatmap tabs, how many data points to download at random | 2,000 to 50,000 (default is 5,000)|
| `trend_line_method` | For the Heatmap tab, which statistical method to use to draw the trend line? | "Smooth (LOESS or GAM)" (which is the default for `ggplot2::geom_smooth`), "Robust linear regression" (which is the `rlm` function from the MASS R package) |
| `year` | A vector of two values, used for filtering the data to only observations that applied between those two years (inclusive). | 1990 to `latest_year - 1` (`latest_year` is created by `ui.R` itself and is just today's year - as it is assumed today's year is going to have incomplete data - as indeed even `latest_year - 1` normally does).  |
| `cohort_yn` | Should the data be limited to people just born in a particular range of years? | Logical |
| `cohort_year` | If `cohort_yn` is true, which two years should be the birth range for the cohort? | 1930 to `latest_year - 1`|
| `days_nz` | Multiple choice, filter by number of days spent in the country | The three choices of categorical value for days_nz |
| `resident` | Should the data be limited to those estimated to be resident on 30 June? | Logical |
| `filt_var` | Which variable should be used for further filtering in addition to years of observations, cohort birth year, days in New Zealand, and estimated residency? | `legit_cat_vars_list` plus "none" |

The variables `line_precision` and `bar_precision` control whether to show the data in those two tabs as fixed random rounded, or fixed random rounded and then rounded further to just two significant digits.

#### Variables used for the cohort modelling tab:

The widgets to choose these variables only appear when the user has selected the "cohort modelling" tab

| Variable | Use | Choices | 
|--------|------|-------|
| `cohort_response` | What is the response variable to be in the regression? | `legit_cont_vars_list` |
| `cohort_birth_year` | birth year | 1930 to `latest_year` |
| `cohort_year_1` | Year of observations for explanatory variables | 1990 to `latest_year` |
| `cohort_year_2` | Year for response data | 1990 to `latest_year` |


### Other variables

In addition to the variables listed above, variables can be generated in `ui.R` and used only in the user interface, not by the server side.  These are:

| Variable | Use | Choices |
|--------|------|-------------|
| `tabs` | Used to control which widgets to present to the user so only those relevant for their analysis are available | "Line charts", "Cross tabs", "Distribution", "Heatmap", "Cohort modelling", "Variables", "Disclaimer" |
| `download_lines` | Should the data for the Line chart be downloaded as an Excel document? | action button only |
| `download_bar` | Should the data for the cross tab (or bar chart) be downloaded as an Excel document? | action button only |

There are also these other, self-explanatory single purpose variables used to control whether the SQL is shown to the screen on each tab:

- `show_sql_lines`
- `show_sql_bar`
- `show_sql_density`
- `show_sql_heatmap`
- `show_sql_cohort`

### Objects coming back from the server

The following objects are generated in the server and made available to the user interface for rendering to the screen via functions such as `htmlOutput` and `plotOutput`.  Their nature is usually fairly evident and should be straightforward to understand by comparing the code in `ui.R` to the output of the application itself

- Used under the Line chart tab
	- "line_plot"
	- "explain_lines"
	- "message_lines"
	- "line_data"
	- "the_sql_lines"
- Used under the Crosstabs tab
	- "bar_plot"
	- "explain_bars"
	- "message_bars"
	- "bar_data"
	- "the sql_bars"
- Used under the Distribution tab
	- "density_plot"
	- "explain_density"
	- "message_density"
	- "the_sql_density
- Used under the Heatmap tab	
	- "heatmap_plot"
	- "message_heatmap"
	- "explain_heatmap"
	- "the_sql_heatmap"
- Used under the Cohort modelling tab
	- "ranger_plot"
	- "glmnet_vars"
	- "the_sql_cohort"
	- "explain_cohort" (note that unlike the first four, "explain_cohort" is rendered in the side panel, not the main panel)

In `server.R`, these objects for transmitting back to `ui.R` are created as (for example) `output$ranger_plot`.	

## Structure of the `server.R` file

The `server.R` file is the most substantial part of the application (around 800 lines at the time of writing), even though some code have been abstracted into other functions that are stored in the `./src/` directory.

In the `server.R` file, main sections are started with comments like this:

```R
#======================dynamic code and UI generation===============
```

Subsections are started with comments like this:

```R
#------------------dynamic creation of pick box for filter options-------------
```

The overall structure, as marked by those types of section separators, is as follows:

- Setup
- The Server Side of the App
- Dynamic code and UI generation
	- work out line of code doing filtering (ie "WHERE"), to put into SQL
	- dynamic creation of pick box for filter options
	- other dynamic choices for the UI
- Main analysis code for each of the analysis-type tabs starts here	
	- Line chart
	- bar chart ("Crosstabs")
	- density plot ("Distribution")
	- heatmap
	- cohort modelling
	- SQL output
	
	


## Building the SQL

This section describes how step 2  (as described under "what the application does") is performed:

- dynamically create a valid and nicely formatted SQL query to retrieve data from the datamart

### The skeletons

A skeleton for each of the five analysis types is stored in `./src` of the application directory system.  As an example, here is the file `./src/continuous.sql`, which is used as the basis of the query getting data for the Line chart tab

```SQL
/*
Calculate average value by year of CONT1 for different combinations 
of CAT1 and CAT2

Author: Iddibot, TODAYSDATE

PRAISE

*/


SELECT 
  SUM(seed) - FLOOR(SUM(seed)) AS sum_seed,
  SUM(a.CONT1 + (ROUND(seed, 0) * 0.2 - 0.1) * a.CONT1)  AS perturbed_total,
  count(1)                     AS freq,
  CAT1_tab.short_name          AS var_1,
  CAT2_tab.short_name          AS var_2,
  -- var_val_sequence is for meaningful ordering of our binned categories for CAT1 and CAT2:
  CAT1_tab.var_val_sequence AS var_1_sequence,
  CAT2_tab.var_val_sequence AS var_2_sequence,
  a.year_nbr

FROM  SCHEMA.vw_year_wide AS a
-- Join to this so we get the permanent random seed:
INNER JOIN (SELECT snz_uid, seed FROM SCHEMA.dim_person) AS b
  ON a.snz_uid = b.snz_uid
filter_join_here
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN SCHEMA.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
-- Join to this so we can use meaningful names for CAT1:
INNER JOIN SCHEMA.dim_explorer_value_year AS CAT1_tab
  ON a.CAT1_code = CAT1_tab.value_code
-- Join to this so we can use meaningful names for CAT2:
INNER JOIN SCHEMA.dim_explorer_value_year AS CAT2_tab
  ON a.CAT2_code = CAT2_tab.value_code
resident_join_here  
filter_line_here

GROUP BY 
  CAT1_tab.short_name, 
  CAT2_tab.short_name, 
  CAT1_tab.var_val_sequence, 
  CAT2_tab.var_val_sequence, 
  a.year_nbr



```

These skeletons are not yet legitimate SQL.  To turn the above into legitimate SQL the process is basically:

- substitute the correct database and schema for 'SCHEMA' (during development we use something like `IDI_Sandpit.pop_exp_test`; in the Data Lab it will be 'IDI_RnD.pop_exp', as well as on a different server, which was connected to in `global.R`)
- substitute the correct column name (default is `maori`) for `CAT1`
- substitute the correct column name (default is `sex`) for `CAT2`
- substitute the correct column name (default is `income`) for `CONT1`
- substitute appropriate things for Iddibot to say for `TODAYSDATE` and `PRAISE`
- replace `filter_join_here` with either a blank line or a correct `INNER JOIN ... ON` STATEMENT for the optional variable the user is choosing to filter by
- replace `resident_join_here` with either a blank line or a correct `INNER JOIN ... ON` STATEMENT if the user has chosen to filter to just estimated residents
- replace `filter_line_here` with an appropriate `WHERE` clause (which can be quite complex, as there are up to five variables the user can filter by - year of observation, year of birth, days in New Zealand, residency, and one of their own choice).

A typical end result is as follows (which is what the user sees if they "Update line chart data" with the opening settings)

```SQL
/*
Calculate average value by year of income for different combinations 
of maori and sex

Author: Iddibot, 2017-11-25 09:45:04

Mhm. The IDI is tremendous!  You're enormously initiating this.

*/


SELECT 
  SUM(seed) - FLOOR(SUM(seed)) AS sum_seed,
  SUM(a.income + (ROUND(seed, 0) * 0.2 - 0.1) * a.income)  AS perturbed_total,
  count(1)                     AS freq,
  maori_tab.short_name          AS var_1,
  sex_tab.short_name          AS var_2,
  -- var_val_sequence is for meaningful ordering of our binned categories for maori and sex:
  maori_tab.var_val_sequence AS var_1_sequence,
  sex_tab.var_val_sequence AS var_2_sequence,
  a.year_nbr

FROM  IDI_Sandpit.pop_exp_sample.vw_year_wide AS a
-- Join to this so we get the permanent random seed:
INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.pop_exp_sample.dim_person) AS b
  ON a.snz_uid = b.snz_uid
-- Join to this so we can get region_code names to filter by: 
INNER JOIN IDI_Sandpit.pop_exp_sample.dim_explorer_value_year AS fil_tab
  ON fil_tab.value_code = a.region_code
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN IDI_Sandpit.pop_exp_sample.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
-- Join to this so we can use meaningful names for maori:
INNER JOIN IDI_Sandpit.pop_exp_sample.dim_explorer_value_year AS maori_tab
  ON a.maori_code = maori_tab.value_code
-- Join to this so we can use meaningful names for sex:
INNER JOIN IDI_Sandpit.pop_exp_sample.dim_explorer_value_year AS sex_tab
  ON a.sex_code = sex_tab.value_code
-- Join to this so we can get resident/non resident to filter by:
INNER JOIN IDI_Sandpit.pop_exp_sample.dim_explorer_value_year AS res_tab
  ON res_tab.value_code = a.resident_code
    
WHERE res_tab.short_name = 'Resident on 30 June' 
    AND days_tab.short_name in ('1 to 90 days', '91 to 182 days', '183 or more days')
    AND fil_tab.short_name in (N'Waikato Region') 
    AND year_nbr >= 2005 AND year_nbr <= 2016

GROUP BY 
  maori_tab.short_name, 
  sex_tab.short_name, 
  maori_tab.var_val_sequence, 
  sex_tab.var_val_sequence, 
  a.year_nbr

```


A few things to note here:

- the substitutions eg of `maori` for `CAT1` take place through the comments as well as the actual query, so Iddibot can explain why it is doing all those joins to the `dim_explorer_value_year` table. - we do all those joins we can have a query that reads nicely in English in the `WHERE` clause, rather than making cryptic references to codes.  Iddibot knows the codes and could use the `maori_code` in the original view instead of the value `short_name` and hence save all those joins, but then queries wouldn't necessarily work on future versions of the database as the `value_code` is made up during the build process.  The joins work fairly fast; every column in `vw_year_wide` with a name ending in `_code` has a foreign key joining it to `dim_explorer_value_code` so the query optimizer knows there are no mismatches, and the columnstore index on `vw_year_wide` seems to work very well.
- the use of `N'Waikato Region` is because some of the values of `short_name` can have macrons in them, so we need to force SQL Server to recognise that string as NVARCHAR (which the original database column it refers to is)
- although the values of `short_name` may have macrons, the column name `maori_code` in `vw_year_wide` doesn't (by design), so one of the tasks in constructing the SQL is to handle that issue
- the user chose a `long_name` for their variables from the widgets in `ui.R` (eg "Income from all sources"), so we need to translate that into `short_name` for the query ("Income" or `income`).  This is partly for readability of the end SQL, and partly because the categorical columns in `vw_year_wide` all have a name in the format `short_name_code` eg `maori_code`, even though the `long_name` chosen by the user was "Māori ethnicity"
- In the example above, the `days_tab.short_name in ('1 to 90 days', '91 to 182 days', '183 or more days')` is redundant because all the data in `vw_year_wide` is only for people recorded as being in the country at least one day per year.  It's left in to be explicit and to make it easier to change if the user opts for a different combination of filtering on days in NZ

The R code in `server.R` looks after all the above, in two stages:

1. generic creation of `filter_line_here`, `filter_join_here` and `resident_join_here` which is used for all four of the Line chart, Crosstabs, Distribution, and Heatmap tabs.  This is done in the section marked `#--------work out line of code doing filtering (ie "WHERE"), to put into SQL--------`.
2. substitution of those three elements (or modified versions of them), the analysis-specific variables, andother miscellany like the date into the relevant SQL skeleton.  This is done in the the relevant section for each

Here is an excerpt from the R code that does some of that first step - create a text string that can be substituted into the query to replace the `filter_join_here` in the original

```R

  # filt_var_name is the name of a variable eg region_code to be used in WHERE statements later on
  filt_var_name <- reactive({
    paste0(variables[variables$long_name == input$filt_var, "short_name"], "_code") %>%
      remove_macron() %>%
      tolower()
  })
  
    # join to value dimension table on basis of variable chosen for filtering:
  filter_join <- reactive({
    if(input$filt_var != "none"){
      txt <-  paste0("-- Join to this so we can get ", filt_var_name(), " names to filter by: \nINNER JOIN ", schema, ".dim_explorer_value_year AS fil_tab
  ON fil_tab.value_code = a.", filt_var_name())
      } else 
    txt <- ""
  })

```
A few things to note:
- in the `server.R` file of a Shiny app, much of the work is done through the creation of reactive objects - these are objects that change when user inputs (in this case `input$filt_var`) are changed.
- `remove_macron()` is a utility function defined earlier for self-explanatory purpose
- the `filter_join()` reactive object includes in-line comments in the SQL it is writing for Iddibot (by starting with a line that starts with `-- Join to...`).  If we can't get the bots to comment their code nicely, how can we expect researchers to?

And here is an excerpt from R code performing the second step - substituting user-modified text into the SQL skeleton:

```R
  the_sql_lines <- reactive({
    if(input$action_line == 0){return("")}
    isolate({
      sql <- gsub("CONT1", tolower(y_variable()), line_sql)
      sql <- gsub("PRAISE", praise("${Exclamation}. The IDI is ${adjective}!  You're ${adverb_manner} ${creating} this."), sql)
      sql <- gsub("TODAYSDATE", Sys.time(), sql)
      sql <- gsub("CAT1", tolower(bar_variables()[1]), sql)
      sql <- remove_macron(gsub("CAT2", tolower(bar_variables()[2]), sql))
      sql <- gsub("FILTVAR", filt_var_name(), sql)
      sql <- gsub("filter_join_here", filter_join(), sql)
      sql <- gsub("filter_line_here", filter_line(), sql)
      sql <- gsub("resident_join_here", resident_join(), sql)
      return(sql)
    })
  })
```

Note:

- `line_sql` is basically original skeleton referred to earlier, imported via line_sql     <- gsub("SCHEMA", schema, paste(readLines("src/continuous.sql"), collapse = "\n"))
- the use of `isolate({})` around the main operative code means that it doesn't re-write itself whenever a user plays around with a widget, but only when they push the "Update line data" button
- `input$action_line` is attached to that "Update line data" button.  As it is outside of the `isolate({})` function, it will activate the entire `the_sql_lines()` reactive object when that button is pushed.
- When the button has been pushed zero times ie on application start up, we return an empty string rather than SQL.  

## Analysis

This section describes how step 3 (as described under "what the application does") is performed:

- analysis including confidentialisation, and create summary tables, graphics and explanatory text

This part is fairly straightforward.  There are five subsections in this part of the `server.R` file, which starts with:

```R
#============================Main analysis code for each of the analysis-type tabs starts here===================
```

Each of those follows basically the same pattern:

- Complete the tab-specific SQL definition as described above
- Create an object with a name like `output$message_lines` that tells how many rows of data have been downloaded (this is handy both for developers and end users; it's not a confidentiality problem because it never refers to an actual count of people, just of rows)
- Send the query to the database and save the results in a reactive object with a name like `data_orig_lines()`
- Perform any necessary manipulation on that data such as fixed random rounding (using the `fix_rand_round()` function defined in `./src/fix_rand_round.R`) and ordering the levels in categorical factors according to their relevant entries in the `var_val_sequence` column of the `dim_explorer_value_year` table in the database (so for example the character labels of income bands are rendered in the correct order in graphics). The results of this stage are typically stored in a reactive object with a name like `data_line()`
- Where relevant ("Line chart", and "Crosstabs"), create a table to be downloaded and rendered on the screen, with even further rounding if asked for (which is the default).  Typically stored in a object with a name like `data_line_table()
- Create the graphic
- Create the explanatory text, calling on a custom function for the purpose
- "render" all the necessary objects as part of the `output` list, which is passed back to the user interface (for example, by `output$explain_lines <- renderText({explanatory_text_lines()})`)


Details vary of course, and the "cohort modelling" is the most complex of the five as it fits two fairly sophisticated statistical models (a random forest from `ranger` and a generalized linear model with elastic net regularisation from `glmnet`) and has a more complex and unpredictable graphic and table to draw.  But the basic pattern is as used five times.

## Helper functions located in `src`

In addition to the SQL templates, these functions are defined in src

| Function | Script defined in | Purpose
|----------|---------|
|  `data_link()` | `explain_bars_and_lines.R` |  For a given variable, a short sentence on its linkage rates |
|  `explain_lines()` | `explain_bars_and_lines.R` | Create explanatory text for the line chart tab |
|  `explain_bars()` | `explain_bars_and_lines.R` | Create explanatory text for the cross tabs tab |
| `explain_cohort()` | `explain_cohort.R` | Create explanatory text for the cohort modelling tab |
| `fix_rand_round()` | `fix_rand_round.R` | For a given modulus of sum of random seeds and raw total, return the fixed random rounding base three total |
| `format_sql()`  | `format_sql.R` | Take an SQL query and surround it with HTML tags so it will by syntax highlighted, and in a reactive function that will activate the JavaScript needed to do the highlighting |
| `html_to_df()` | `make_excel_version.R` | Take an HTML explanation (like that returned by `explain_lines()`, convert from HTML to reasonably formatted plain text |
| `make_excel_version()` | `make_excel_version.R` | Save a formatted Excel workbook of three tabs with data, the SQL that created it, and an English description |
| `paste_and()` | `paste_and.R` | Convert `c("lions", "tigers", "bears")` to `"lions, tigers and bears"` |
| `prism_code_block()` | `prism_functions.R` | Function to surround a code block in so when it is created by the server it activates the prism.js syntax highlighting JavaScript program |
| `remove_macron()` | `remove_macron.R` | Remove macrons from the letter a in any text |
| - | `statsnz-pallete.R` | Various objects such as `snz_brand` and `snz_graph` holding the colours used by Stats NZ |
