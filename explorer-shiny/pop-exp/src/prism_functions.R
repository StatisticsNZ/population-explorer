# Thanks to https://stackoverflow.com/questions/47445260/how-to-enable-syntax-highlighting-in-r-shiny-app-with-htmloutput/47445785#47445785
# These functions are used to activate the prism highlighting every time new SQL is generated - by default prism only runs once when the
# page is loaded, so we need it to run each time there is new SQL to highlight
#
# By StackOverflow user `@greg L`, 23 November 2017, adapted minimally by Peter Ellis

prism_code_block <- function(code) {
  tagList(
    HTML(code),
    tags$script("Prism.highlightAll()")
  )
}

prism_dependencies <- tags$head(
  tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.8.4/prism.min.js"),
  tags$link(rel = "stylesheet", type = "text/css",
            href = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.8.4/themes/prism.min.css")
)

prism_sql_dependency <- tags$head(
  tags$script(src = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.8.4/components/prism-sql.min.js")
)