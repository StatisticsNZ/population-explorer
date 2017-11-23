# This R program explores linkage rates by table in the IDI.
# Note that the table intermediate.dim_idi_tables is created by one of the SQL scripts in the ./int folder
# Peter Ellis November 2017

library(RODBC)
library(dplyr)
library(Cairo)
library(ggplot2)
library(scales)
library(ggrepel)

odbcCloseAll()
idi = odbcDriverConnect("Driver=ODBC Driver 11 for SQL Server; 
                        Trusted_Connection=YES; 
                        Server=WTSTSQL35.stats.govt.nz,60000")

theme_set(theme_grey(base_family = "Source Sans Pro"))

sql <- "SELECT * FROM IDI_Sandpit.intermediate.dim_idi_tables"
tabs <- sqlQuery(idi, sql, stringsAsFactors = FALSE)

odbcCloseAll()

CairoPDF("output/link-rates.pdf", 21, 15)
  p1 <- tabs %>%
    mutate(lab = ifelse(proportion_snz_uid_on_spine < 0.7 | proportion_rows_on_spine < 0.7, table_name, "")) %>%
    ggplot(aes(x = proportion_snz_uid_on_spine, y = proportion_rows_on_spine)) +
    geom_point(aes(size = number_rows, colour =table_schema )) +
    geom_text_repel(aes(label = lab)) +
    scale_x_continuous(label = percent) +
    scale_y_continuous(label = percent) +
    ggtitle("Comparing link rates for rows of data with rates for people",
            "IDI production version as at November 2017")
    labs(caption = "[WTSTSQL35\\ILEED].IDI_Sandpit.intermediate.dim_idi_tables")
    
  
  p2 <- tabs %>%
    ggplot(aes(x = proportion_snz_uid_on_spine, y = table_name)) +
    facet_wrap(~ table_schema, scale = "free_y") +
    geom_point() +
    scale_x_continuous("Percentage of people that have been linked to the spine", label = percent) +
    ggtitle("Linking success by table from a people perspective",
            "IDI production version as at November 2017") +
    labs(caption = "[WTSTSQL35\\ILEED].IDI_Sandpit.intermediate.dim_idi_tables")
  
  p3 <- tabs %>%
    ggplot(aes(x = proportion_rows_on_spine, y = table_name)) +
    facet_wrap(~ table_schema, scale = "free_y") +
    geom_point() +
    scale_x_continuous("Percentage of rows of data with people that have been linked to the spine", label = percent) +
    ggtitle("Linking success by table from a rows of data perspective",
            "IDI production version as at November 2017") +
    labs(caption = "[WTSTSQL35\\ILEED].IDI_Sandpit.intermediate.dim_idi_tables")
  
  print(p1)
  print(p2)
  print(p3)
dev.off()
