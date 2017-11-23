SELECT 
  cont_var_1,
  cont_var_2,
  d.short_name AS var_1,
  d.var_val_sequence AS var_1_sequence
FROM
  (SELECT TOP min_dens_n 
    a.CONT1 AS cont_var_1,
    a.CONT2 AS cont_var_2,
    a.CAT1_code
  FROM  IDI_Sandpit.SCHEMA.vw_ye_mar_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.SCHEMA.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  WHERE seed > SEEDTHRESH AND CONT1 != 0 AND CONT2 != 0
  AND rest_of_filter_line) AS c
INNER JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS d
  ON c.CAT1_code = d.value_code;

