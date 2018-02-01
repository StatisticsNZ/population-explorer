/*
Count the number of observations that actually made it to the pivotted wide table.  This is less than
that in the main fact table because
a) wide table only has 1990 onwards
b) wide table only has people estimated to spend at least 1 day in New Zealand


*/
USE IDI_Sandpit

IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.add_wide_obs_numbers') IS NOT NULL
		DROP PROCEDURE pop_exp_dev.add_wide_obs_numbers;
GO

CREATE PROCEDURE pop_exp_dev.add_wide_obs_numbers AS
BEGIN
	SET NOCOUNT ON
	IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.temp_vars') IS NOT NULL
		DROP TABLE IDI_Sandpit.pop_exp_dev.temp_vars;
 
	CREATE TABLE IDI_Sandpit.pop_exp_dev.temp_vars
		(
		var_name VARCHAR(30),
		column_name VARCHAR(30),
		id INT IDENTITY PRIMARY KEY,
		obs INT
		)


	INSERT INTO IDI_Sandpit.pop_exp_dev.temp_vars (var_name, column_name)
	SELECT 
		short_name,
		CAST(LOWER(short_name) + '_code' AS VARCHAR(30)) AS column_name
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE use_in_front_end = 'Use'
		AND grain = 'person-period'



	DECLARE @i INT = 1
	DECLARE @query VARCHAR(1000)
	DECLARE @obs INT
	DECLARE @this_var VARCHAR(100)
	DECLARE @no_data_code INT = (SELECT value_code FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year WHERE short_name = 'No data')

	WHILE @i <= (SELECT MAX(id) FROM IDI_Sandpit.pop_exp_dev.temp_vars)
	BEGIN
		SET @this_var = (SELECT column_name FROM IDI_Sandpit.pop_exp_dev.temp_vars WHERE id = @i)

		SET @query =
			'UPDATE IDI_Sandpit.pop_exp_dev.temp_vars
			 SET obs = (SELECT COUNT(1) AS obs
						FROM IDI_Sandpit.pop_exp_dev.vw_year_wide
						WHERE ' + @this_var + ' != ' + CAST(@no_data_code AS VARCHAR(10)) + ')
			WHERE column_name = ''' + @this_var + ''''
		print(@query)
		EXECUTE(@query)

		SET @i = @i + 1
	END


	UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	SET observations_in_front_end =  a.obs
		FROM IDI_Sandpit.pop_exp_dev.temp_vars AS a
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable  AS b
		ON a.var_name = b.short_name;

	DROP TABLE IDI_Sandpit.pop_exp_dev.temp_vars
END
GO

EXECUTE pop_exp_dev.add_wide_obs_numbers;
DROP PROCEDURE pop_exp_dev.add_wide_obs_numbers;
GO

-- Now we can add the column index to the variable table as it is finished at last
EXECUTE lib.add_cs_ind 'pop_exp_dev', 'dim_explorer_variable'
