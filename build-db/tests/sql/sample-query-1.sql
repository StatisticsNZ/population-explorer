


SELECT 
  sum_seed,
  perturbed_total,
  freq,
  d.short_name AS var_1, 
  e.short_name AS var_2,
  d.var_val_sequence AS var_1_sequence,
  e.var_val_sequence AS var_2_sequence,
  year_nbr
FROM
  (SELECT 
    SUM(b.seed) - FLOOR(SUM(b.seed)) AS sum_seed,
    SUM(a.income + (ROUND(b.seed, 0) * 0.2 - 0.1) * a.income)  AS perturbed_total,
    count(1) AS freq,
    a.sex_code,
    a.maori_code,
    a.year_nbr
  FROM  IDI_Sandpit.pop_exp_test.vw_year_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.pop_exp_test.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  --WHERE days_nz > 120
  GROUP BY a.sex_code, a.maori_code, a.year_nbr) AS c
LEFT JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS d
  ON c.sex_code = d.value_code
LEFT JOIN IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS e
  ON c.maori_code = e.value_code