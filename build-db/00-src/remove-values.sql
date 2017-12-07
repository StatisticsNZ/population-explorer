/*
Procedure to remove value and variable from the value and variable schemas while not touching the fact table.
Motivation is to clean up variables like "sex" and "europ" which are not in the fact table, hence no need
to waste time on it.  This is only used in development (and not much then)


Peter Ellis, November 2017
*/


use IDI_Sandpit

IF OBJECT_id('lib.remove_var') IS NOT NULL
	DROP PROCEDURE lib.remove_var
GO

CREATE PROCEDURE lib.remove_var (@var_name VARCHAR(50), @schema_name VARCHAR(50))
AS
BEGIN

	DECLARE @query VARCHAR(1000);
	SET @query = 

	'DECLARE @var_code INT
	SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.' + @schema_name + '.dim_explorer_variable
		WHERE short_name = ''' + @var_name + ''');

	DELETE  
	FROM IDI_Sandpit.' + @schema_name + '.dim_explorer_value_year
	WHERE fk_variable_code = @var_code;

	DELETE  
	FROM IDI_Sandpit.' + @schema_name + '.dim_explorer_variable
	WHERE variable_code = @var_code;'

	EXECUTE (@query)

END