/* 
Aim of this somewhat awkward script is to make an version of the person dimension that instead of having meaningful
text for the various attributes, the attributes are mapped to values in the value dimension.

This is so all the categorical characteristics of someone, whether they are unchanging (sex, ethnicity) or changing (income, education)
are all linked to dim_explorer_value to make things easier for the reporting tool.

The table created by this script doesn't hang around for long.  It's just a temporary measure before we create vw_ye_mar_wide (or its equivalent),
which has all codes in it, linked to dim_explorer_value, including the redundant information in multiple versions (each year) for the variables
that have only a "person" grain, not just those with "person-period"; then the temporary link table made in this script should get cleaned up.

TODO - add more information on the full description of the variables here.

October 2017 Peter Ellis
*/


-----------------------clean up previous dimensions associated with this variable--------
-- this chunk should be a stored procedure with @var_name as a parameter, because it will be the same for every variable we add

IF OBJECT_ID('tempdb..#sex_value_codes') IS NOT NULL DROP TABLE #sex_value_codes;
IF OBJECT_ID('tempdb..#born_nz_value_codes') IS NOT NULL DROP TABLE #born_nz_value_codes;
IF OBJECT_ID('tempdb..#ethnicity_codes') IS NOT NULL DROP TABLE #ethnicity_codes;
IF OBJECT_ID('tempdb..#iwi_value_codes') IS NOT NULL DROP TABLE #iwi_value_codes;
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.link_person_extended') IS NOT NULL 
	DROP TABLE IDI_Sandpit.pop_exp_dev.link_person_extended;
GO

USE IDI_Sandpit
GO

DECLARE @already_there AS INT
SET @already_there =
	(SELECT COUNT(1) AS freq
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name IN ('Sex', 'Born_NZ', 'Iwi', 'Europ', 'Maori', 'Asian', 'Pacif', 'MELAA',
							'Other', 'Birth_year_nbr', 'Birth-month_nbr', 'Number_known_parents', 
							'Parents_income_birth_year'));


IF @already_there > 0
BEGIN
	-- This next chunk doesn't work when being executed via ODBC by the RStudio server for some reason.
	-- However, when the whole database is being built sequentially, it doesn't matter.  This just cleans
	-- up old attemtps at running this script/
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Sex', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Born_NZ', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Iwi', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Europ', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = N'Māori', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Asian', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Pacif', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'MELAA', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Other', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Birth_year_nbr', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Birth_month_nbr', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Number_known_parents', @schema_name = 'pop_exp_dev';
	EXECUTE IDI_Sandpit.lib.remove_var @var_name = 'Parents_income_birth_year', @schema_name = 'pop_exp_dev';
END

----------------add variables to the variable table-------------------
DECLARE @eth_exp NVARCHAR(1000) = 
			'Ethnicity from the best of the multiple sources available ie 2013 Census if available, followed by DIA, Ministry of Health, Ministry of Education,
			ACC, Ministry of Social Development, and other data sources.  See http://www.stats.govt.nz/methods/research-papers/topss/comp-ethnic-admin-data-census.aspx
			for more information on ethnicity data in the IDI'


INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		(short_name, long_name, quality, origin, var_type, grain, origin_tables, date_built, measured_variable_description, target_variable_description) 
	VALUES   
		('Sex', 'Sex', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())), 
				'The information to populate this field is from the Department of Internal Affair’s (DIA) birth, death, and marriage registrations. 
				As DIA is the official register of these event, where the identity cannot be found in the DIA, the most commonly reported value 
				across all data sources in the IDI is used.',
				'What is the person''s sex?'),
		
		('Born_NZ', 'Born in New Zealand', 'Good', 'DIA', 'category', 'person', 'IDI_Clean.dia_clean.births', (SELECT CONVERT(date, GETDATE())),
			'Is the birth recorded by DIA?  If yes, this usually means born in New Zealand, sometimes it means adopted',
			'Is the person born in New Zealand?'),
		
		('Iwi', 'Iwi', 'Moderate', 'Census', 'category', 'person', 
			'IDI_Clean.cen_clean.census_individual , IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI', (SELECT CONVERT(date, GETDATE())),
			'Self-identified Iwi from the 2013 census, the only currently available information in the IDI.',
			 'What is the person''s Iwi?'),
		
		('Europ', 'European ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, 'Is the person''s ethnicity European?'),
		
		(N'Māori', N'Māori ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, N'Is the person''s ethnicity Māori?'),
		
		('Pacif', 'Pacific Peoples ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, 'Is the person''s ethnicity Pacific Peoples?'),
		
		('Asian', 'Asian ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, 'Is the person''s ethnicity Asian?'),
		
		('MELAA', 'Middle Eastern/Latin American/African ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, 'Is the person''s ethnicity Middle Eastern, Latin American, or African?'),
		
		('Other', 'Other ethnicity', 'Good', 'SNZ', 'category', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			@eth_exp, 'Is the person''s ethnicity "other ethnicity"?'),
		
		('Birth_year_nbr', 'Birth year number', 'Moderate', 'SNZ', 'count', 'person', 'IDI_Clean.data.personal_detail, IDI_Clean.dia_clean.births', (SELECT CONVERT(date, GETDATE())),
			'From the Department of Internal Affair’s (DIA) birth, death, and marriage registrations. 
			As DIA is the official register of these event, where the identity cannot be found in the DIA, the most commonly reported value 
			across all data sources in the IDI is used.',
			'What is the person''s year of birth?'),
		
		('Birth_month_nbr', 'Birth month number', 'Moderate', 'SNZ', 'count', 'person', 'IDI_Clean.data.personal_detail', (SELECT CONVERT(date, GETDATE())),
			'From the Department of Internal Affair’s (DIA) birth, death, and marriage registrations. 
			As DIA is the official register of these event, here the identity cannot be found in the DIA, the most commonly reported value 
			across all data sources in the IDI is used.',
			'What is the person''s month of birth?'),

		('Number_known_parents', 'Number of parents recorded in the database', 'Poor', 'SNZ', 'count', 'person', 
			'IDI_Clean.data.personal_detail, IDI_Clean.dia_clean.births', (SELECT CONVERT(date, GETDATE())),
			'Number of parents known and recorded in the IDI, as per the data.personal_detail table, which draws this information from DIA birth 
			registration dataset.  Note that alternative ways of estimating parents	give very different results (including high numbers of parent per person).',
			'How adequately is this person''s parentage represented in the IDI?'),

		('Parents_income_birth_year', 'Income of parents in the year of birth', 'Poor', 'SNZ', 'continuous', 'person',
			'IDI_Clean.data.personal_detail, IDI_Clean.data.income_tax_yr_summary, IDI_Clean.dia_clean.births', (SELECT CONVERT(date, GETDATE())),
			'Simple combination of the parents identified in data.personal_detail (identified by DIA birth registration) with the tax year summary data.  
			Note that if identifying the parents was poor quality, adding income information must be even poorer quality.',
			'What was this person''s parents'' income when this person was born?');

--select * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable;

------------------add categorical values to the value table------------------------
DECLARE @var_code INT;

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'Sex');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Female', @var_code, 1), 
		 ('Male', @var_code, 2),
		 ('Not known', @var_code, 3);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #sex_value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #sex_value_codes;

-- born_nz
--DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'Born_NZ');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Birth recorded by DIA', @var_code, 1), 
		 ('Birth not recorded by DIA', @var_code, 2),
		 ('Not known', @var_code, 3);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #born_nz_value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #born_nz_value_codes;

-- Iwi
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'Iwi');
		
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value(short_name, fk_variable_code, var_val_sequence)
SELECT
	DISTINCT(descriptor_text)   AS short_name,
	@VAR_CODE					AS fk_variable_code,
	NULL						AS var_val_sequence
FROM IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI;

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #iwi_value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;


-- ethnicities
--DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'Europ');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('European', @var_code, 1), 
		 ('Not European', @var_code, 2);

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = N'Māori');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 (N'Māori', @var_code, 1), 
		 (N'Not Māori', @var_code, 2);

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'pacif');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Pacific Peoples', @var_code, 1), 
		 ('Not Pacific Peoples', @var_code, 2);

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'asian');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Asian', @var_code, 1), 
		 ('Not Asian', @var_code, 2);

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'melaa');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('MELAA', @var_code, 1), 
		 ('Not MELAA', @var_code, 2);

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = 'other');
		
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Other ethnicity', @var_code, 1), 
		 ('Not other ethnicity', @var_code, 2);

SELECT
	value_code, 
	fk_variable_code,
	short_name
INTO #ethnicity_codes
FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value
WHERE short_name IN ('European', 'Not European', N'Māori', N'Not Māori', 'Pacific Peoples', 'Not Pacific Peoples', 
					'Asian', 'Not Asian', 'MELAA', 'Not MELAA', 'Other ethnicity', 'Not other ethnicity');


------------create actual table - a coded version of dim_person - with all those codes----------------------------------
DECLARE @no_data_code INT;	 
SET @no_data_code =	(
	SELECT value_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value
		WHERE short_name = 'No data');

SELECT 
	p.snz_uid,
	ISNULL(k.value_code, @no_data_code) AS sex_code,
	ISNULL(j.value_code, @no_data_code) AS born_nz_code,
	ISNULL(l.value_code, @no_data_code)   AS iwi_code,
	p.birth_year_nbr,
	p.birth_month_nbr,
	c.value_code AS europ_code,
	d.value_code AS maori_code,
	e.value_code AS pacif_code,
	f.value_code AS asian_code,
	g.value_code AS melaa_code,
	h.value_code AS other_code,
	number_known_parents,
	parents_income_birth_year,
	p.seed,
	round(p.seed, 0) AS rounded_seed
INTO IDI_Sandpit.pop_exp_dev.link_person_extended
FROM IDI_Sandpit.pop_exp_dev.dim_person p
	LEFT JOIN #ethnicity_codes c
	ON p.europ = c.short_name
	LEFT JOIN #ethnicity_codes d
	ON p.maori = d.short_name
	LEFT JOIN #ethnicity_codes e
	ON p.pacif = e.short_name
	LEFT JOIN #ethnicity_codes f
	ON p.asian = f.short_name
	LEFT JOIN #ethnicity_codes g
	ON p.melaa = g.short_name
	LEFT JOIN #ethnicity_codes h
	ON p.other = h.short_name
	LEFT JOIN #born_nz_value_codes j
	on j.value_category   = p.born_nz
	LEFT JOIN #sex_value_codes k 
	on k.value_category = p.sex
	LEFT JOIN #iwi_value_codes l 
	on l.value_category = p.iwi;

ALTER TABLE IDI_Sandpit.pop_exp_dev.link_person_extended ADD PRIMARY KEY (snz_uid);

CREATE COLUMNSTORE INDEX col_dim_person_ext ON IDI_Sandpit.pop_exp_dev.link_person_extended
(snz_uid, sex_code, born_nz_code, iwi_code, birth_year_nbr, birth_month_nbr, 
	europ_code, maori_code, pacif_code, asian_code, melaa_code, other_code, number_known_parents, 
	parents_income_birth_year, seed, rounded_seed);


