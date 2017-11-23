/*
This procedure cleans out old rows from the fact tables (x 2 - annual and quarterly), 
dim_explorer_variable, and dim_explorer_value (x 2) tables related to a variable.

@var_name is a variable name like "Income"
@schema is one of 'pop_exp' or 'pop_exp_dev'

*/

use IDI_Sandpit;

IF (object_id('lib.clean_out_all')) IS NOT NULL
	DROP PROCEDURE lib.clean_out_all;
GO


CREATE PROCEDURE lib.clean_out_all (@var_name VARCHAR(20), @schema VARCHAR(50))
AS
BEGIN
	DECLARE @query VARCHAR(2000);
	SET @query =
	'DECLARE @var_code INT;
	SET @var_code =	(
		SELECT variable_code
			FROM IDI_Sandpit.' + @schema + '.dim_explorer_variable
			WHERE short_name = ''' + @var_name + ''')

	DELETE  
	FROM IDI_Sandpit.' + @schema + '.dim_explorer_value
	WHERE fk_variable_code = @var_code

	DELETE  
	FROM IDI_Sandpit.' + @schema + '.dim_explorer_value_qtr
	WHERE fk_variable_code = @var_code


	-- deleting previous versions of the facts can take a few minutes:
	DELETE  
	FROM IDI_Sandpit.' + @schema + '.fact_rollup_year
	WHERE fk_variable_code = @var_code

	DELETE  
	FROM IDI_Sandpit.' + @schema + '.fact_rollup_qtr
	WHERE fk_variable_code = @var_code

	DELETE  
	FROM IDI_Sandpit.' + @schema + '.dim_explorer_variable
	WHERE variable_code = @var_code;'

	EXECUTE(@query)
END
