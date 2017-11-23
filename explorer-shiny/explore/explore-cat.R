# aim here is to explore cross tabs where we choose two variables and look at them by region
library(forcats)
library(viridis)



base_sql <- "
SELECT 
  SUM(seed) - FLOOR(SUM(seed))	 AS sum_seed,
  count(1)                       AS freq,
	year_nbr,
  XXXXX,
  YYYYY
FROM  IDI_Sandpit.[DL-IMR2017-05].vw_ye_mar_cat_wide a
INNER JOIN IDI_Sandpit.[DL-IMR2017-05].dim_person b
ON a.snz_uid = b.snz_uid
WHERE Region = 14
GROUP BY year_nbr, XXXXX, YYYYY"

# v <- sqlQuery(idi, "select top 5 * from IDI_Sandpit.pop_exp.vw_ye_mar_wide")

variable_1 <- "Age"
variable_2 <- "Income"

sql <- gsub("XXXXX", variable_1, base_sql)
sql <- gsub("YYYYY", variable_2, sql)
cat(sql)

# 104s, 308s, 332s when the view is unindexed; 3 seconds when it is indexed; 4 seconds even with the join
system.time(data_orig <- sqlQuery(idi, sql, stringsAsFactors = FALSE)) 



d <- data_orig %>%
  as_tibble() %>%
  
  # replace variable 1 codes with actual categories:
  rename_("key" = variable_1) %>%
  left_join(values[ , c("value_code", "short_name", "var_val_sequence")], by = c("key" = "value_code")) %>%
  select(-key) %>%
  mutate(var_val_sequence = ifelse(is.na(var_val_sequence), 99999, var_val_sequence)) %>%
  mutate(short_name = fct_reorder(short_name, var_val_sequence)) %>%
  rename(var_1 = short_name) %>%
  select(-var_val_sequence) %>%
  
  # replace variable 2 codes with actual categories:
  rename_("key" = variable_2) %>%
  left_join(values[ , c("value_code", "short_name", "var_val_sequence")], by = c("key" = "value_code")) %>%
  select(-key) %>%
  mutate(var_val_sequence = ifelse(is.na(var_val_sequence), 99999, var_val_sequence)) %>%
  mutate(short_name = fct_reorder(short_name, var_val_sequence)) %>%
  rename(var_2 = short_name) %>%
  select(-var_val_sequence) %>%
  
  # random round, and change year to being an ordered factor:
  mutate(freq_frr = fix_rand_round(freq, s = sum_seed),
         freq_frr = ifelse(freq < 10, NA, freq_frr),
         year_nbr = as.ordered(year_nbr))

# this can look good with scales either as free_x or fixed
d %>%
  ggplot(aes(x = var_2, weight = freq_frr / 1000, fill = year_nbr)) +
  geom_bar(position = "dodge") +
  facet_wrap(~var_1) +
  scale_fill_viridis("Year ending\nMarch", discrete = TRUE, direction = -1, option = "magma") +
  coord_flip() +
  scale_y_continuous("Thousands of residents for this combination of age and income", 
                     label = comma) +
  guides(fill = guide_legend(reverse = TRUE)) +
  labs(caption = "Fixed random rounding; values below 10 are suppressed") +
  ggtitle("Age group x income x year in Bay of Plenty")
