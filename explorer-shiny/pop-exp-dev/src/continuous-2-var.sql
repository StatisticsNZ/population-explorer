/*
Return random sample of min_dens_n points for a scatter plot of CONT1 and CONT2,
plus the CAT1 dimension. 

Author: Iddibot, TODAYSDATE

PRAISE

*/
SELECT TOP min_dens_n 
  a.CONT1                 AS cont_var_1,
  a.CONT2                 AS cont_var_2,
  CAT1_tab.short_name       AS var_1,
  -- var_val_sequence is so we can have meaningful order of categories in CAT1:
  CAT1_tab.var_val_sequence AS var_1_sequence

FROM  SCHEMA.vw_year_wide AS a
filter_join_here
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN SCHEMA.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
-- Join to this so we can use meaningful names for CAT1:  
INNER JOIN SCHEMA.dim_explorer_value_year AS CAT1_tab
  ON a.CAT1_code = CAT1_tab.value_code
resident_join_here
-- note that we are knocking out all zero values.  Take this into account!:
WHERE CONT1 != 0 AND CONT2 != 0
AND rest_of_filter_line

-- random order so we get different sample each time:
ORDER BY NEWID();

