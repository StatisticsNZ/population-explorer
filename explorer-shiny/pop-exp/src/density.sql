SELECT
	var_0,
	d.short_name    AS var_1,
	d.var_val_sequence AS var_val_sequence
FROM
  (SELECT TOP min_dens_n
    CONT1 + (ROUND(seed, 0) * 0.2 - 0.1) * a.CONT1 AS var_0,
    CAT1_code  as var_1
  FROM  IDI_Sandpit.SCHEMA.vw_ye_mar_wide AS a
  INNER JOIN (SELECT snz_uid, seed FROM IDI_Sandpit.SCHEMA.dim_person) AS b
    ON a.snz_uid = b.snz_uid
  WHERE seed > SEEDTHRESH AND CONT1 != 0
    AND rest_of_filter_line
  ORDER by seed) AS c
INNER JOIN IDI_Sandpit.SCHEMA.dim_explorer_value AS d
  ON c.var_1 = d.value_code
  

