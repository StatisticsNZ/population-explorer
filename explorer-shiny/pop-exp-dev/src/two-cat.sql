SELECT
  sum_seed,
  freq,
  year_nbr,
  d.short_name AS var_1,
  e.short_name AS var_2,
  d.var_val_sequence AS var_1_sequence,
  e.var_val_sequence AS var_2_sequence
FROM
  (SELECT 
    SUM(seed) - FLOOR(SUM(seed))   AS sum_seed,
    count(1)                       AS freq,
    a.year_nbr,
    a.CAT1_code,
    a.CAT2_code
  FROM  IDI_Sandpit.SCHEMA.vw_year_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.SCHEMA.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  filter_line_here
  GROUP BY a.year_nbr, a.CAT1_code, a.CAT2_code) AS c
LEFT JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS d
  ON c.CAT1_code = d.value_code
LEFT JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS e
  ON c.CAT2_code = e.value_code
