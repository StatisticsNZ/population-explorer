SELECT 
  COUNT(1) AS observations, 
  fk_variable_code, 
  variable_code, 
  short_name
FROM IDI_Sandpit.pop_exp_test.fact_rollup_year AS a
RIGHT JOIN IDI_Sandpit.pop_exp_test.dim_explorer_variable AS b
  ON a.fk_variable_code = b.variable_code
WHERE grain = 'person-period'
GROUP BY fk_variable_code, short_name, variable_code
ORDER BY variable_code DESC;
