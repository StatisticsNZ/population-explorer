-- foreign key constraints from all the code variables to dim_explorer_value_year should help the query optimizer; and it also works as an
-- integrity check.  These foreign key constraints take about 20 minutes to add in.  

IF OBJECT_ID('add_foreign_keys') IS NOT NULL
	DROP PROCEDURE add_foreign_keys;
GO

CREATE PROCEDURE add_foreign_keys
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @vars TABLE (short_name VARCHAR(30), id INT IDENTITY)

	INSERT INTO @vars
	SELECT short_name
	FROM pop_exp_dev.dim_explorer_variable
	WHERE loaded_into_wide_table = 'Loaded' and
		short_name NOT IN ('birth_year_nbr', 'number_known_parents', 'parents_income_birth_year')



	DECLARE @i INT = 1
	DECLARE @query VARCHAR(1000)
	WHILE @i <= (SELECT MAX(id) FROM @vars)
	BEGIN
		SET @query = 'ALTER TABLE pop_exp_dev.vw_year_wide ADD CONSTRAINT fk_view_code_' + 
					(SELECT short_name FROM @vars WHERE id = @i) + 
					' FOREIGN KEY (' +
					(SELECT short_name FROM @vars WHERE id = @i) + 
						'_code) REFERENCES pop_exp_dev.dim_explorer_value_year(value_code);'
		EXECUTE (@query)
		SET @i = @i + 1
	END
END
GO


EXECUTE add_foreign_keys
GO

DROP PROCEDURE add_foreign_keys
GO

------------------------Final key from snz_uid back to the person dimension---------------------
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide 
	ADD CONSTRAINT fk_person_y
	FOREIGN KEY (snz_uid) REFERENCES IDI_Sandpit.pop_exp_dev.dim_person(snz_uid);
