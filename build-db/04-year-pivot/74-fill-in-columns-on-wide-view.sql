/*
This script fills in the columns in the big wide "view", which used to be a view, then it was a result of a pivot,
then it was a bunch of SUM(CASE(WHEN))) statements that took 36 hours to run and crashed 75% of the time due to 
server problems.  Now it is set up so if it fails, the columns that it has done will stay completed, and it can be 
re-run and automagically take up from where it left off.  It also has many less variable names hard-coded into the script than
it used to, which will make it much easier to maintain.  

Some columns in the dim_explorer_variable table are crucial for this to work, in particular
* loaded_into_wide_table for tracking which variables have successfully been loaded
* has_numeric_value for letting us know which variables don't have a numeric value and hence only get a go in the xxx_code column of the main table

Peter Ellis, 26 November 2017

*/
USE IDI_Sandpit
GO

IF OBJECT_ID('pop_exp_dev.populate_columns') IS NOT NULL
	DROP PROCEDURE pop_exp_dev.populate_columns
GO


CREATE PROCEDURE pop_exp_dev.populate_columns
AS
BEGIN
	IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.vars_to_do') IS NOT NULL
		DROP TABLE IDI_Sandpit.pop_exp_dev.vars_to_do
	
	SELECT short_name 
	INTO IDI_Sandpit.pop_exp_dev.vars_to_do
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE grain = 'person-period' AND use_in_front_end = 'Use' AND loaded_into_wide_table IS NULL

	ALTER TABLE IDI_Sandpit.pop_exp_dev.vars_to_do ADD id INT IDENTITY;
	
	DECLARE @i INT = 1

	DECLARE @this_var VARCHAR(50)
	DECLARE @numeric_value VARCHAR(30)
	DECLARE @query1 VARCHAR(2000)
	DECLARE @query2 VARCHAR(2000)

	WHILE @i <= (SELECT MAX(id) FROM IDI_Sandpit.pop_exp_dev.vars_to_do )
	BEGIN
		SET @this_var = (SELECT short_name FROM pop_exp_dev.vars_to_do WHERE id = @i);

		print @this_var;

		SET @numeric_value = (SELECT has_numeric_value FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable WHERE short_name = @this_var)

		IF @numeric_value = 'No numeric value'
			SET @query1 =
			'UPDATE IDI_Sandpit.pop_exp_dev.vw_year_wide
			SET IDI_Sandpit.pop_exp_dev.vw_year_wide.' + @this_var + '_code = b.fk_value_code
			FROM  IDI_Sandpit.pop_exp_dev.vw_year_wide AS a
			INNER JOIN IDI_Sandpit.pop_exp_dev.fact_rollup_year AS b
				ON a.snz_uid = b.fk_snz_uid AND a.date_period_ending = b.fk_date_period_ending
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable AS c
				on b.fk_variable_code = c.variable_code
			WHERE c.short_name = ''' + @this_var + '''

			UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
			SET loaded_into_wide_table = ''Loaded''
			WHERE short_name = ''' + @this_var + '''';
		ELSE
			SET @query1 =
			'UPDATE IDI_Sandpit.pop_exp_dev.vw_year_wide
			SET IDI_Sandpit.pop_exp_dev.vw_year_wide.' + @this_var + '= b.value,
				IDI_Sandpit.pop_exp_dev.vw_year_wide.' + @this_var + '_code = b.fk_value_code
			FROM  IDI_Sandpit.pop_exp_dev.vw_year_wide AS a
			INNER JOIN IDI_Sandpit.pop_exp_dev.fact_rollup_year AS b
				ON a.snz_uid = b.fk_snz_uid AND a.date_period_ending = b.fk_date_period_ending
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable AS c
				on b.fk_variable_code = c.variable_code
			WHERE c.short_name = ''' + @this_var + '''

			UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
			SET loaded_into_wide_table = ''Loaded''
			WHERE short_name = ''' + @this_var + '''';
	
		EXECUTE(@query1)

		-- query2 is to convert all values of NULL in a _code column to a meaningful code
		SET @query2 = 
		'DECLARE @no_data_code INT;	 
			SET @no_data_code =	(
				SELECT value_code
					FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
					WHERE short_name = ''No data'');

		 UPDATE IDI_Sandpit.pop_exp_dev.vw_year_wide
		 SET ' + @this_var + '_code = @no_data_code
		 WHERE ' + @this_var + '_code IS NULL'
		EXECUTE(@query2)

		SET @i = @i + 1
	END

	DROP TABLE IDI_Sandpit.pop_exp_dev.vars_to_do
END
GO 

EXECUTE pop_exp_dev.populate_columns

DROP PROCEDURE pop_exp_dev.populate_columns
GO


