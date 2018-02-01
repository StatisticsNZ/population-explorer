/*
Script for adding all indexes and foreign keys to a copy of the database that is a heap, eg having just been copied over from dev to test or prod.

Peter Ellis
7 December 2017

*/

USE IDI_Pop_Explorer
GO



------------------reusable procedure for making columnstore indexes---------
IF OBJECT_ID('add_cs_ind') IS NOT NULL
	DROP PROCEDURE add_cs_ind
GO

CREATE PROCEDURE add_cs_ind (@tab_schema VARCHAR(100), @tab_name VARCHAR(100))
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ts VARCHAR(100) = @tab_schema
	DECLARE @tn VARCHAR(100) = @tab_name
	DECLARE @cols TABLE(id INT NOT NULL IDENTITY PRIMARY KEY, col_name VARCHAR(256))

	-- Get all the column names
	INSERT INTO @cols(col_name)
	SELECT 
		c.name AS col_name
	FROM sys.columns		AS c
	INNER JOIN sys.tables   AS t
		ON  c.object_id = t.object_id
	INNER JOIN sys.schemas   AS s
		ON  s.schema_id = t.schema_id
	WHERE s.name = @ts AND t.name = @tn

	-- Paste together the column names
	DECLARE @i INT = 2
	DECLARE @vars VARCHAR(MAX) = (SELECT col_name FROM @cols WHERE id = 1) -- some tables have many columns hence VARCHAR(MAX)
	WHILE @i <= (SELECT MAX(id) FROM @cols)
	BEGIN
		SET @vars = @vars + ', ' + (SELECT col_name FROM @cols WHERE id = @i)
		SET @i = @i + 1
	END
	
	-- Create the actual query that will create the index with those column names
	DECLARE @query VARCHAR(MAX)
	SET @query = 'CREATE NONCLUSTERED COLUMNSTORE INDEX xcsi_' + @tn +
		' ON ' + @ts + '.' + @tn + ' (' + @VARS + ')'
	
	-- Drop existing index with this identical name, which has probably been made by us
	DECLARE @drop_sql VARCHAR(1000)
	SET @drop_sql = 'IF EXISTS(SELECT * FROM SYS.INDEXES WHERE object_id = OBJECT_ID(''' + @ts + '.' + @tn + ''') AND name =''xcsi_' + @tn +
                            ''')   DROP INDEX xcsi_' + @tn + ' ON ' + @ts + '.' + @tn
    EXECUTE(@drop_sql)
	
	-- Execute our query to actually make the index
	EXECUTE(@query)
	SET NOCOUNT OFF
END
GO

-----------------Indexes----------------------

-- big and long:
ALTER TABLE pop_exp_charlie.fact_rollup_year ADD PRIMARY KEY (fk_snz_uid, fk_date_period_ending, fk_variable_code);
CREATE NONCLUSTERED INDEX n_val_var ON pop_exp_charlie.fact_rollup_year(fk_value_code, fk_variable_code)
EXECUTE add_cs_ind 'pop_exp_charlie', 'fact_rollup_year'

-- wide table - long to build, but doesn't take much extra space:
ALTER TABLE pop_exp_charlie.vw_year_wide ADD PRIMARY KEY (snz_uid, date_period_ending, year_nbr);
EXECUTE add_cs_ind 'pop_exp_charlie', 'vw_year_wide'

-- medium:
ALTER TABLE pop_exp_charlie.dim_person ADD PRIMARY KEY (snz_uid);
EXECUTE add_cs_ind 'pop_exp_charlie', 'dim_person'


-- small:
ALTER TABLE pop_exp_charlie.dim_explorer_variable ADD PRIMARY KEY (variable_code);
CREATE NONCLUSTERED INDEX nc_var_name ON pop_exp_charlie.dim_explorer_variable(short_name);
CREATE NONCLUSTERED INDEX nc_var_type ON pop_exp_charlie.dim_explorer_variable(var_type);
ALTER TABLE pop_exp_charlie.dim_explorer_variable ADD CONSTRAINT unq_var_sn UNIQUE(short_name)
ALTER TABLE pop_exp_charlie.dim_explorer_variable ADD CONSTRAINT unq_var_ln UNIQUE(long_name)
EXECUTE add_cs_ind 'pop_exp_charlie', 'dim_explorer_variable'

-- small/medium:
ALTER TABLE pop_exp_charlie.dim_explorer_value_year ADD PRIMARY KEY (value_code);
CREATE NONCLUSTERED INDEX nc_val_name_y ON pop_exp_charlie.dim_explorer_value_year(short_name);
CREATE NONCLUSTERED INDEX nc_var_cod_y ON pop_exp_charlie.dim_explorer_value_year(fk_variable_code);
EXECUTE add_cs_ind 'pop_exp_charlie', 'dim_explorer_value_year'

-- small/medium:
ALTER TABLE pop_exp_charlie.dim_explorer_value_qtr ADD PRIMARY KEY (value_code);
CREATE NONCLUSTERED INDEX nc_val_name_q ON pop_exp_charlie.dim_explorer_value_qtr(short_name);
CREATE NONCLUSTERED INDEX nc_var_cod_q ON pop_exp_charlie.dim_explorer_value_qtr(fk_variable_code);
EXECUTE add_cs_ind 'pop_exp_charlie', 'dim_explorer_value_qtr'

-- small:
ALTER TABLE pop_exp_charlie.dim_date ADD PRIMARY KEY (date_dt);
EXECUTE add_cs_ind 'pop_exp_charlie', 'dim_date'
GO

CREATE NONCLUSTERED INDEX nc_day ON pop_exp_charlie.dim_date(day_of_month);
CREATE NONCLUSTERED INDEX nc_month ON pop_exp_charlie.dim_date(month_nbr);
CREATE NONCLUSTERED INDEX nc_year ON pop_exp_charlie.dim_date(year_nbr);
CREATE NONCLUSTERED INDEX nc_end_qtr ON pop_exp_charlie.dim_date(end_qtr);
CREATE NONCLUSTERED INDEX nc_end_mth ON pop_exp_charlie.dim_date(end_mth);
GO

ALTER TABLE pop_exp_charlie.bridge_variable_tables 
   ADD CONSTRAINT var_tab_code PRIMARY KEY CLUSTERED (var_tab_code);
GO

-----------------------foreign keys-----------------
-- connecting the fact table to the dimension tables

ALTER TABLE pop_exp_charlie.fact_rollup_year
	ADD CONSTRAINT fk1_y 
	FOREIGN KEY (fk_date_period_ending) REFERENCES pop_exp_charlie.dim_date(date_dt);

ALTER TABLE pop_exp_charlie.fact_rollup_year
	ADD  CONSTRAINT fk2_y
	FOREIGN KEY (fk_variable_code) REFERENCES pop_exp_charlie.dim_explorer_variable(variable_code);

ALTER TABLE pop_exp_charlie.fact_rollup_year
	ADD  CONSTRAINT fk3_y 
	FOREIGN KEY (fk_value_code) REFERENCES pop_exp_charlie.dim_explorer_value_year(value_code);

ALTER TABLE pop_exp_charlie.fact_rollup_year
	ADD  CONSTRAINT fk4_y
	FOREIGN KEY (fk_snz_uid) REFERENCES pop_exp_charlie.dim_person(snz_uid);
GO

-- connecting the value and variable tables together
ALTER TABLE pop_exp_charlie.dim_explorer_value_year
	ADD CONSTRAINT fk_value_var_yr
	FOREIGN KEY (fk_variable_code) REFERENCES pop_exp_charlie.dim_explorer_variable(variable_code);

ALTER TABLE pop_exp_charlie.dim_explorer_value_qtr
	ADD CONSTRAINT fk_value_var_qtr
	FOREIGN KEY (fk_variable_code) REFERENCES pop_exp_charlie.dim_explorer_variable(variable_code);
GO
	
-- snz_uid back to the person dimension for the big wide table---------------------
ALTER TABLE pop_exp_charlie.vw_year_wide 
	ADD CONSTRAINT fk_person_y
	FOREIGN KEY (snz_uid) REFERENCES pop_exp_charlie.dim_person(snz_uid);

-- connecting the big wide view to the value dimension
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
	FROM pop_exp_charlie.dim_explorer_variable
	WHERE loaded_into_wide_table = 'Loaded' and
		short_name NOT IN ('birth_year_nbr', 'number_known_parents', 'parents_income_birth_year')



	DECLARE @i INT = 1
	DECLARE @query VARCHAR(1000)
	WHILE @i <= (SELECT MAX(id) FROM @vars)
	BEGIN
		SET @query = 'ALTER TABLE pop_exp_charlie.vw_year_wide ADD CONSTRAINT fk_view_code_' + 
					(SELECT short_name FROM @vars WHERE id = @i) + 
					' FOREIGN KEY (' +
					(SELECT short_name FROM @vars WHERE id = @i) + 
						'_code) REFERENCES pop_exp_charlie.dim_explorer_value_year(value_code);'
		EXECUTE (@query)
		SET @i = @i + 1
	END
END
GO

EXECUTE add_foreign_keys
GO

DROP PROCEDURE add_foreign_keys
GO

