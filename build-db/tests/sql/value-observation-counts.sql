

SELECT
	COUNT(1) AS observations,
	a.value_code,
	a.short_name
FROM IDI_Sandpit.pop_exp_test.dim_explorer_value_year AS a
LEFT JOIN IDI_Sandpit.pop_exp_test.fact_rollup_year AS b
ON a.value_code = b.fk_value_code
LEFT JOIN IDI_Sandpit.pop_exp_test.dim_explorer_variable AS c
ON a.fk_variable_code = c.variable_code
WHERE c.grain <> 'person'
GROUP BY a.value_code, a.short_name
ORDER BY observations 