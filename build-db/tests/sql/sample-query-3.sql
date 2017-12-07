/*
4 seconds with sample on 27/11/2017 (single file,fgw1 partition)
127, 84, 74, 37, 27 seconds with test on 27/11/2017 (single file, PRIMARY partition)
60, 43, 42, 42, seconds seconds with bak on 27/11/2017 (multiple files over several partitions)

42 seconds
*/

SELECT 
  SUM(b.seed) - FLOOR(SUM(b.seed)) AS sum_seed,
  SUM(a.income + (ROUND(b.seed, 0) * 0.2 - 0.1) * a.income)  AS perturbed_total,
  count(1)                     AS freq,
  maori_tab.short_name          AS var_1,
  sex_tab.short_name          AS var_2,
  -- var_val_sequence is for meaningful ordering of our binned categories for maori and sex:
  maori_tab.var_val_sequence AS var_1_sequence,
  sex_tab.var_val_sequence AS var_2_sequence,
  a.year_nbr

FROM  IDI_Sandpit.pop_exp_test.vw_year_wide AS a
-- Join to this so we get the permanent random seed:
INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.pop_exp_test.dim_person) AS b
  ON a.snz_uid = b.snz_uid
-- Join to this so we can get region_code names to filter by: 
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS fil_tab
  ON fil_tab.value_code = a.region_code
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
-- Join to this so we can use meaningful names for maori:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS maori_tab
  ON a.maori_code = maori_tab.value_code
-- Join to this so we can use meaningful names for sex:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS sex_tab
  ON a.sex_code = sex_tab.value_code
-- Join to this so we can get resident/non resident to filter by:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS res_tab
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