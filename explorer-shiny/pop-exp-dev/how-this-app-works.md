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

- `src` holds two types of source code:
    - `*.R` files create functionality that has been abstracted out of `server.R` for maintainability purposes.  All these files are run by `global.R` during application initiation by the two lines of code that look like: `scripts <- list.files("src", pattern = "\\.R$", full.name = TRUE); devnull <- lapply(scripts, source)`
	- `*.sql` files are skeletons of SQL queries that are used by `server.R` as the basis for constructing actual legitimate queries.
- `www` holds assets for the web page and in particular:
    - `styles.css` is a cascading style sheet to give a Stats NZ look and feel to the web page.  Edit this to control things like fonts, heading sizes and colours for text other than that which is part of images.
	- `prism.css` controls the look of the SQL syntax highlighting in the browser.  Don't edit this file directly (well you can, but it's probably not worth the effort), but you can replace the file altogether with a different version from [http://prismjs.com/](http://prismjs.com/).  The currently chosen theme is "Solarized Light"
	- 'prism.js' is a JavaScript program that performs the actual syntax highlighting and has been downloaded from the same location.  
	- `SNZlogo1.png` is self-explanatory

## The user interface

This section describes how steps 1 and 4 (as described under "what the application does") are performed:

- user choices to control the analysis
- rendering results on the screen

### Structure of `ui.R`


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
| `year` | A vector of two values, used for filtering the data to only observations that applied between those two years (inclusive). | 1990 to today's year minus 1 (as it is assumed today's year is going to have incomplete data - as indeed even year minus 1 normally does).  |
| `cohort_yn` | Should the data be limited to people just born in a particular range of years? | Logical |
| `cohort_year` | If `cohort_yn` is true, which two years should be the birth range for the cohort? | 1930 to today's year minus 1|
| `days_nz` | Multiple choice, filter by number of days spent in the country | The three choices of categorical value for days_nz |
| `resident` | Should the data be limited to those estimated to be resident on 30 June? | Logical |
| `filt_var` | Which variable should be used for further filtering in addition to years of observations, cohort birth year, days in New Zealand, and estimated residency? | `legit_cat_vars_list` plus "none" |

The variables `line_precision` and `bar_precision` should be self-evident from looking at the code and comparing to the app.

#### Variables used for the cohort modelling tab:

The widgets to choose these variables only appear when the user has selected the "cohort modelling" tab

| Variable | Use | Choices | 
|--------|------|-------|
| `cohort_response | What is the response variable to be in the regression? | `legit_cont_vars_list` |
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
	

## Building the SQL

This section describes how step 2  (as described under "what the application does") is performed:

- dynamically create a valid and nicely formatted SQL query to retrieve data from the datamart

## Analysis

This section describes how step 3 (as described under "what the application does") is performed:

- analysis including confidentialisation, and create summary tables, graphics and explanatory text





