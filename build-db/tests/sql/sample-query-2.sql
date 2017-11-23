SELECT 
  cont_var_1,
  cont_var_2,
  d.short_name AS var_1,
  d.var_val_sequence AS var_1_sequence
FROM
  (SELECT TOP 500 
    a.benefits AS cont_var_1,
    a.acc_claims AS cont_var_2,
    a.age_code
  FROM  IDI_Sandpit.pop_exp_test.vw_year_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.pop_exp_test.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  WHERE seed > 0.5 AND benefits!= 0 AND acc_claims != 0) AS c
INNER JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value AS d
  ON c.age_code = d.value_code;