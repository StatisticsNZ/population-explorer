/*
Creates a wide version of all the data with:
- persistent infomration on individuals as codes that link to dim_explorer_value_years, from link_person_extended
- changing information on individuals as continuous values in the natural names Income, Hospital, etc
- changing information on individuals as codes (ie doubling up the continuous values) with names like Income_code, Hospital_code, etc.

This is likely to be the main view used by reporting tools and mostly just needs to be linked to dim_explorer_value_years
for instant usefulness.

This was originally going to be a view (hence beginning with "vw_") but we will probably leave it as a materialized table.
It is very fast and simple that way and doesn't seem to take up too much space, when done with a columnstore index.


I know it seems a bit awkward with both year and date_period_ending in there, but date_period_ending is very useful in the next step for 
joining with the fact table; and year is useful for end users

Perhaps 20% of the cost in time of making this big wide table is in this script 73, which creates the actual table and makes it the right size,
but with all the person-period columns as NULL


*/

use IDI_Sandpit
IF OBJECT_ID ('pop_exp_dev.vw_year_wide') IS NOT NULL
	DROP TABLE pop_exp_dev.vw_year_wide;
GO

-------------------------define the left half of the table -----------------------------------
CREATE TABLE pop_exp_dev.vw_year_wide
	(snz_uid INT NOT NULL,
	date_period_ending DATE NOT NULL, 
	year_nbr SMALLINT NOT NULL,
	sex_code INT, 
	born_nz_code INT, 
	birth_year_nbr INT,
	iwi_code INT,
	europ_code INT, 
	maori_code INT, 
	pacif_code INT, 
	asian_code INT, 
	melaa_code INT, 
	other_code INT,
	number_known_parents TINYINT,
	parents_income_birth_year NUMERIC(13),
	seed FLOAT,
	
	number_observations INT)
GO

----------------------------add columns for variables with person-period grain--------------------
IF OBJECT_ID('pop_exp_dev.add_var_columns') IS NOT NULL
	DROP PROCEDURE pop_exp_dev.add_var_columns;
GO 

CREATE PROCEDURE pop_exp_dev.add_var_columns AS
BEGIN
	SET NOCOUNT ON
	DECLARE @var_names TABLE(
		short_name			VARCHAR(30),
		data_type			VARCHAR(30),
		has_numeric_value	VARCHAR(30),
		id					INT IDENTITY)

	INSERT @var_names
	SELECT short_name, data_type, has_numeric_value 
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable 
	WHERE grain = 'person-period' AND use_in_front_end = 'Use'


	DECLARE	@i		INT = 1
	DECLARE @query	VARCHAR(200)
	WHILE @i <= (SELECT MAX(id) FROM @var_names)
	BEGIN
		SET @query = 'ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD ' + 
					(SELECT LOWER(short_name) FROM @var_names WHERE id = @i) + ' ' +
					(SELECT data_type FROM @var_names WHERE id = @i)
		IF (SELECT has_numeric_value FROM @var_names WHERE id = @i) = 'Has numeric value'
			EXECUTE(@query);
	
		SET @query = 'ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD ' + 
					(SELECT LOWER(short_name) FROM @var_names WHERE id = @i) + '_code INT'
			EXECUTE(@query);
	
		SET @i = @i + 1

	END
END
GO

EXECUTE pop_exp_dev.add_var_columns

DROP PROCEDURE pop_exp_dev.add_var_columns	
GO


-------------------------------populate the left half of the table---------------------------------
-- This is all the repeated, redundant values of person and year

INSERT pop_exp_dev.vw_year_wide(snz_uid, date_period_ending, year_nbr, sex_code, born_nz_code, birth_year_nbr, iwi_code,
		europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code, number_known_parents, parents_income_birth_year,
		seed)
SELECT 
	b.snz_uid, 
	fk_date_period_ending, 
	YEAR(fk_date_period_ending) AS year_nbr,
	sex_code, 
	born_nz_code, 
	birth_year_nbr,
	iwi_code,
	europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code,
	number_known_parents,
	parents_income_birth_year,
	seed

FROM 
	(SELECT DISTINCT fk_snz_uid, fk_date_period_ending 
	 FROM IDI_Sandpit.pop_exp_dev.fact_rollup_year
	 WHERE   fk_date_period_ending > CAST('19891231' AS DATE) )   AS a
-- next left join is because we want the redundant person-grained variables to be repeated for each person-year combination:
LEFT JOIN IDI_Sandpit.pop_exp_dev.link_person_extended			AS b
	ON a.fk_snz_uid = b.snz_uid



-- iff all the above went well, we can record that these variables were loaded:
UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
SET loaded_into_wide_table = 'Loaded'
WHERE short_name in ('Sex', 'Born_NZ', 'birth_year_nbr', 'iwi', 
		'Europ', N'Māori', 'Pacif', 'Asian', 'Melaa', 'Other', 
		'number_known_parents', 'parents_income_birth_year');

GO

-- I know that year_nbr and date_period_ending are redundant but I want year_nbr in the clustered index and end use,
-- and date_period_ending in it for the next step of filling in other columns:
ALTER TABLE IDI_Sandpit.pop_exp_dev.vw_year_wide ADD PRIMARY KEY (snz_uid, date_period_ending, year_nbr);


