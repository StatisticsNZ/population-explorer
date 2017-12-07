/*
This code provides enduring highest NQF (National Qualification Framework) qualification, per person, per year.

Qualifications are taken from the primary and secondary school student qualifications dataset (IDI_Clean.moe_clean.student_qualification),
the tertiary qualification completions dataset (IDI_Clean.moe_clean.completion), and the industry training education dataset (IDI_Clean.moe_clean.tec_it_learner).
The targeted training dataset was not used, as this doesn't contain a qualification completion field.

Subsequent years are filled in with the highest qualification received. eg. if someone obtains a NQF level 3 qualification in 2007 and does no further study, 
their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards. 
Likewise, qualifications completed that are lower in level than previous qualifications completed will not count towards the highest qualification. 
eg. if someone obtains a NQF level 3 qualification in 2007 and obtains an NQF level 1 qualification in 2008, their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards.  


Miriam Tankersley, updated 24/11/2017

----------------------

To check: what is NQF (moe_sql_nqf_level_code) level 0?? there are ~8000 obs.

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Qualifications'
USE IDI_Sandpit
EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';


----------------add variable to the variable table-------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		(short_name, 
		long_name,
		quality,
		origin,
		var_type,
		grain,
		measured_variable_description,
		target_variable_description,
		origin_tables,
		date_built,
		variable_class) 
	VALUES   
		(@var_name,
		'Highest NQF level qualification',
		'Good',
		'MoE',
		'category',
		'person-period',
		'Enduring highest NQF (National Qualification Framework) qualification, per person, per year.
		Subsequent years are filled in with the highest qualification received. eg. if someone obtains a NQF level 3 qualification in 2007 and does no further study, 
		their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards. 
		Likewise, qualifications completed that are lower in level than previous qualifications completed will not count towards the highest qualification. 
		eg. if someone obtains a NQF level 3 qualification in 2007 and obtains an NQF level 1 qualification in 2008, 
		their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards.',
		'What is the highest level of education successfully completed in NZ by this person, cumulatively?',
		'IDI_Sandpit.intermediate.highest_qualification, IDI_Clean.moe_clean.student_qualification, IDI_Clean.moe_clean.completion, IDI_Clean.moe_clean.tec_it_learner',
		(SELECT CONVERT(date, GETDATE())),
		'Education and training')


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('NQF Level 0', @var_code, 0), 
		 ('Certificate or NCEA level 1', @var_code, 1), 
		 ('Certificate or NCEA level 2', @var_code, 2),
		 ('Certificate or NCEA level 3', @var_code, 3),
		 ('Other tertiary qualification', @var_code, 4),
		 ('Certificate level 4', @var_code, 5),
		 ('Certificate or diploma level 5', @var_code, 6),
		 ('Certificate or diploma level 6', @var_code, 7),
		 ('Bachelors degree, graduate diploma or certificate level 7', @var_code, 8),
		 ('Bachelors honours degree, postgraduate diploma or certificate level 8', @var_code, 9),
		 ('Masters degree', @var_code, 10),	 
		 ('Doctoral degree', @var_code, 11),	 
		 ('Unknown', @var_code, 99)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code


----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code AS fk_variable_code,
	highest_qual AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		DATEFROMPARTS(year_nbr,12,31) AS fk_date_period_ending,
		hz.snz_uid AS fk_snz_uid,
		@var_code AS fk_variable_code,
		highest_qual,
		CASE 
			WHEN highest_qual = 0 THEN 'NQF Level 0'
			WHEN highest_qual = 1 THEN 'Certificate or NCEA level 1'
			WHEN highest_qual = 2 THEN 'Certificate or NCEA level 2'
			WHEN highest_qual = 3 THEN 'Certificate or NCEA level 3'
			WHEN highest_qual = 3.5 THEN 'Other tertiary qualification'
			WHEN highest_qual = 4 THEN 'Certificate level 4'
			WHEN highest_qual = 5 THEN 'Certificate or diploma level 5'
			WHEN highest_qual = 6 THEN 'Certificate or diploma level 6'
			WHEN highest_qual = 7 THEN 'Bachelors degree, graduate diploma or certificate level 7'
			WHEN highest_qual = 8 THEN 'Bachelors honours degree, postgraduate diploma or certificate level 8'
			WHEN highest_qual = 9 THEN 'Masters degree'
			WHEN highest_qual = 10 THEN 'Doctoral degree'
			ELSE 'Unknown'
		END AS hq_cat
	 FROM IDI_Sandpit.intermediate.highest_qualification AS hz
	 -- we join to our dimension table, even though highest_qualification si already only people on the spine,
	 -- for consistency in case we ever want to run this with a cut-down dim_person (eg as a sampling process):
	 INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		ON hz.snz_uid = p.snz_uid
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.hq_cat = vc.value_category
