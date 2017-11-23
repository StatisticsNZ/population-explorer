library(ggplot2)
library(scales)
library(forcats)
library(dplyr)

sql <- "
SELECT 
	count(1) as observations,
	year_nbr,
	b.short_name AS Iwi
FROM IDI_Sandpit.pop_exp.vw_ye_mar_wide AS a
INNER JOIN IDI_Sandpit.pop_exp.dim_explorer_value AS b
ON a.Iwi_Code = b.value_code
GROUP BY short_name, year_nbr
ORDER by observations DESC"


# about 6 minutes, nearly all on the server:
iwi <- sqlQuery(idi, sql) 
head(iwi)


pdf("output/iwi_observations.pdf", 22, 17)
iwi %>%
  mutate(Iwi = fct_reorder(Iwi, observations)) %>%
  ggplot(aes(x = year_nbr, y = observations)) +
  facet_wrap(~Iwi, scales = "free_y") +
  geom_line() +
  ggtitle("Observations in the Population Explorer of individuals with Iwi noted in the census")
dev.off()

