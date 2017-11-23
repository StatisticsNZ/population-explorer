/*
This script populates the column with number of observations for each of the person-period grain variables.
This is likely to be useful for all sorts of purposes.

14 November 2017
*/

IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
	DROP TABLE #tmp
GO

-- Make a tmp table with the counts we want.  This is adapted from one of the standard test scripts.
SELECT 
  COUNT(1) AS observations, 
  fk_variable_code, 
  variable_code, 
  short_name
INTO #tmp
FROM IDI_Sandpit.pop_exp_dev.fact_rollup_year AS a
RIGHT JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable AS b
  ON a.fk_variable_code = b.variable_code
WHERE grain = 'person-period'
GROUP BY fk_variable_code, short_name, variable_code
ORDER BY variable_code DESC;


-- update the dimension table with the correct values
UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable 
SET number_observations = a.observations
	FROM #tmp AS a
	INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable  AS b
	ON a.variable_code = b.variable_code;

	