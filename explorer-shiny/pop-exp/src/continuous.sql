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


