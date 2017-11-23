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
    SUM(seed) - FLOOR(SUM(seed)) AS sum_seed,
    SUM(a.CONT1 + (ROUND(seed, 0) * 0.2 - 0.1) * a.CONT1)  AS perturbed_total,
    count(1) AS freq,
    a.CAT1_code,
    a.CAT2_code,
    a.year_nbr
  FROM  IDI_Sandpit.SCHEMA.vw_ye_mar_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.SCHEMA.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  filter_line_here
  GROUP BY a.CAT1_code, a.CAT2_code, a.year_nbr) AS c
LEFT JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS d
  ON c.CAT1_code = d.value_code
LEFT JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS e
  ON c.CAT2_code = e.value_code
