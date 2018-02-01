/*
This script 
1. copies over synthesised data that has been previously manually imported into dbo.dim_person and  and dbo.fact_rollup_year
via the "tasks" option on right mouse clicking the database in Management Studio.

2. adds indexes and foreign keys that would be on all the core tables if they had been created one variable at a time, up to
just before the pivot stage

3. deletes rows from the dim_explorer_variable and dim_explorer_value_year tables that relate to variables that weren't synthesised

Peter Ellis 8 December 2017
*/
----------------------------1. inserting data--------------------
USE IDI_Sandpit

INSERT INTO IDI_Sandpit.pop_exp_synth.fact_rollup_year (fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	CAST(fk_date_period_ending AS DATE),
    CAST(fk_snz_uid AS INT),
    CAST(fk_variable_code AS INT),
    CAST(value AS INT),
    CAST(fk_value_code AS INT)
  FROM IDI_Sandpit.dbo.fact_rollup_year


INSERT INTO IDI_Sandpit.pop_exp_synth.dim_person (snz_uid, sex, born_nz, birth_year_nbr, birth_month_nbr, 
												europ, maori, pacif, asian, melaa, other, 
												number_known_parents, parents_income_birth_year, seed)
SELECT
	CAST(snz_uid AS INT),
	CAST(sex AS VARCHAR(10)),
	CAST(born_nz AS VARCHAR(25)),
	CAST(birth_year_nbr AS SMALLINT),
	CAST(birth_month_nbr AS TINYINT),
	CAST(europ AS NVARCHAR(25)),
	CAST(maori AS NVARCHAR(25)),
	CAST(pacif AS NVARCHAR(25)),
	CAST(asian AS NVARCHAR(25)),
	CAST(melaa AS NVARCHAR(25)),
	CAST(other AS NVARCHAR(25)),
	CAST(number_known_parents AS TINYINT),
	CAST(parents_income_birth_year AS NUMERIC(15,0)),
	seed
FROM IDI_Sandpit.dbo.dim_person

ALTER TABLE IDI_Sandpit.pop_exp_synth.dim_person ADD PRIMARY KEY(snz_uid);
EXECUTE IDI_Sandpit.lib.add_cs_ind 'pop_exp_synth', 'dim_person'
GO

-------------------------2. Indexing-----------------------
-- Add in the indexes and foreign keys that would be there normally if we'd developed pop_exp_synth the
-- same way we develop pop_exp_alpha etc.  We *don't* add any indexes or keys that in the usual development
-- cycle only come during the "04-pivot" stage.

ALTER TABLE pop_exp_synth.dim_explorer_variable ADD PRIMARY KEY (variable_code);
CREATE NONCLUSTERED INDEX nc_var_name ON pop_exp_synth.dim_explorer_variable(short_name);
CREATE NONCLUSTERED INDEX nc_var_type ON pop_exp_synth.dim_explorer_variable(var_type);

ALTER TABLE pop_exp_synth.dim_explorer_value_year ADD PRIMARY KEY (value_code);
CREATE NONCLUSTERED INDEX nc_val_name ON pop_exp_synth.dim_explorer_value_year(short_name);
CREATE NONCLUSTERED INDEX nc_var_cod ON pop_exp_synth.dim_explorer_value_year(fk_variable_code);

ALTER TABLE pop_exp_synth.dim_date ADD PRIMARY KEY (date_dt);
EXECUTE lib.add_cs_ind 'pop_exp_synth', 'dim_date'

-- connecting the value and variable tables together
ALTER TABLE pop_exp_synth.dim_explorer_value_year
	ADD CONSTRAINT fk_value_var_yr
	FOREIGN KEY (fk_variable_code) REFERENCES pop_exp_synth.dim_explorer_variable(variable_code);
GO

---------------------------3. deleting rows relating to un-synthesised variables-------------------


DECLARE @used_vars TABLE (variable_code INT)

INSERT @used_vars (variable_code)
	SELECT DISTINCT(fk_variable_code) 
	FROM pop_exp_synth.fact_rollup_year;

INSERT @used_vars (variable_code)
	SELECT variable_code
	FROM pop_exp_synth.dim_explorer_variable
	WHERE short_name = 'Generic'
	

DELETE FROM pop_exp_synth.dim_explorer_value_year
WHERE fk_variable_code NOT IN (SELECT variable_code FROM @used_vars) 
	

DELETE FROM pop_exp_synth.dim_explorer_variable
WHERE variable_code NOT IN (SELECT variable_code FROM @used_vars) 
GO

UPDATE pop_exp_synth.dim_explorer_variable
SET spine_to_sample_ratio = NULL

UPDATE pop_exp_synth.dim_explorer_variable
SET date_built = NULL

UPDATE pop_exp_synth.dim_explorer_variable
SET observations_in_front_end = NULL

UPDATE pop_exp_synth.dim_explorer_variable
SET number_observations = NULL


UPDATE pop_exp_synth.dim_explorer_variable
SET loaded_into_wide_table = NULL


	