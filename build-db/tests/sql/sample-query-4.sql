/*
Calculate average value by year of student_loan for different combinations 
of mental health and sex

Author: Iddibot, 2017-11-27 16:21:56


*/


SELECT 
  SUM(b.seed) - FLOOR(SUM(b.seed)) AS sum_seed,
  SUM(a.student_loan + (ROUND(b.seed, 0) * 0.2 - 0.1) * a.student_loan)  AS perturbed_total,
  count(1)                     AS freq,
  mental_health_tab.short_name          AS var_1,
  sex_tab.short_name          AS var_2,
  -- var_val_sequence is for meaningful ordering of our binned categories for driver_licence and sex:
  mental_health_tab.var_val_sequence AS var_1_sequence,
  sex_tab.var_val_sequence AS var_2_sequence,
  a.year_nbr

FROM  IDI_Sandpit.pop_exp_test.vw_year_wide AS a
-- Join to this so we get the permanent random seed:
INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.pop_exp_test.dim_person) AS b
  ON a.snz_uid = b.snz_uid
-- Join to this so we can get acc_claims_code names to filter by: 
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS fil_tab
  ON fil_tab.value_code = a.acc_claims_code
-- Join to this so we can filter by meaningful names for days in NZ:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS days_tab
  ON days_tab.value_code = a.days_nz_code
-- Join to this so we can use meaningful names for mental_health:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS mental_health_tab
  ON a.mental_health_code = mental_health_tab.value_code
-- Join to this so we can use meaningful names for sex:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS sex_tab
  ON a.sex_code = sex_tab.value_code
-- Join to this so we can get resident/non resident to filter by:
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS res_tab
  ON res_tab.value_code = a.resident_code
    
WHERE res_tab.short_name = 'Resident on 30 June' 
    AND days_tab.short_name in ('1 to 90 days', '91 to 182 days', '183 or more days')
    AND fil_tab.short_name in (N'One claim', N'Two to five claims', N'Six or more claims') 
    AND year_nbr >= 2005 AND year_nbr <= 2016

GROUP BY 
  mental_health_tab.short_name, 
  sex_tab.short_name, 
  mental_health_tab.var_val_sequence, 
  sex_tab.var_val_sequence, 
  a.year_nbr