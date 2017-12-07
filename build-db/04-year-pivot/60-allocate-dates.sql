/*
This script adds values to the "earliest_data" column of the variable dimension, where there hasn't already been 
such a date added when the variable was first created.  The strategy is simple: get the earliest dated data for
each variable from the main fact table, then cycle through the variable dimension table and replace any NULLs with
the appropriate date.

3 November 2017, Peter Ellis
*/

IF OBJECT_ID('tempdb..#earliest_dates') IS NOT NULL
	DROP TABLE #earliest_dates

SELECT MIN(fk_date_period_ending) as earliest_data, fk_variable_code
INTO #earliest_dates
FROM IDI_Sandpit.pop_exp_dev.fact_rollup_year
GROUP BY fk_variable_code;

DECLARE @i INT = 1;
DECLARE @the_date DATE;
WHILE @i < (SELECT MAX(variable_code) FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable)
BEGIN
	SET @the_date = (SELECT earliest_data FROM #earliest_dates WHERE fk_variable_code = @i)
	print @the_date
	UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	SET earliest_data = @the_date
	WHERE variable_code = @i AND earliest_data IS NULL
	SET @i = @i + 1
END

