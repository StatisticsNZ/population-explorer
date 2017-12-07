/*
Returns a cross tab of CAT1 and CAT2 by year

Author: Iddibot, TODAYSDATE

PRAISE

*/

SELECT 
  SUM(seed) - FLOOR(SUM(seed))   AS sum_seed,
  count(1)                       AS freq,
  year_nbr,
  CAT1_tab.short_name            AS var_1,
  CAT2_tab.short_name            AS var_2,
  -- var_val_sequence is so we can have meaningful order of categories in CAT1 and CAT2:
  CAT1_tab.var_val_sequence      AS var_1_sequence,
  CAT2_tab.var_val_sequence      AS var_2_sequence

FROM  SCHEMA.vw_year_wide AS a
-- Join to this so we can use meaningful names for CAT1:
INNER JOIN SCHEMA.dim_explorer_value_year AS CAT1_tab
  ON a.CAT1_code = CAT1_tab.value_code
-- Join to this so we can use meaningful names for CAT2:
INNER JOIN SCHEMA.dim_explorer_value_year AS CAT2_tab
  ON a.CAT2_code = CAT2_tab.value_code
filter_join_here
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN SCHEMA.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
resident_join_here

filter_line_here

GROUP BY 
  year_nbr, 
  CAT1_tab.short_name, 
  CAT2_tab.short_name, 
  CAT1_tab.var_val_sequence, 
  CAT2_tab.var_val_sequence
