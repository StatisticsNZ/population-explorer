/*
Adds highest secondary school NQF (National Qualification Framework) levels to the fact table and relevant dimensions to the dimension tables.

IDEAL:
Counts highest NQF qualification (moe_sql_nqf_level_code) recorded in student_qualification table, per person, per march ye. 
Subsequent years are filled in with the highest qualification received. eg. if someone obtains a NQF level 3 qualification in 2007 and does no further study, 
their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards. 
Likewise, qualifications completed that are lower in level than previous qualifications completed will not count towards the highest qualification. 
eg. if someone obtains a NQF level 3 qualification in 2007 and obtains an NQF level 1 qualification in 2008, their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards.  

WHAT I HAVE STARTED WITH:
Due to complexity of adding in unpopulated years post qualifications only, have decided to start with highest qualification obtained IN THAT YEAR (March YE).
Counts highest NQF qualification (moe_sql_nqf_level_code) recorded in secondary school, per person, per march ye.
It currently does not take into account any qualifications obtained in previous years, eg. someone could have achieved Level 3 in one year, and Level 2 the next year.
Nor does it populate any post secondary school years, ie. someone who is no longer in school will not any current records. The only records available will be for the years they completed qualifications in secondary school.

NOTE: currently only contains secondary school data (not tertiary)

Miriam Tankersley 1 November 2017 

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
		date_built) 
	VALUES   
		(@var_name,
		'Highest NQF level qualification',
		'Good',
		'MoE',
		'category',
		'person-period',
		'Counts highest NQF qualification (moe_sql_nqf_level_code) recorded in secondary school, per person, per march ye.
		It currently does not take into account any qualifications obtained in previous years, eg. someone could have achieved Level 3 in one year, and Level 2 the next year.
		Nor does it populate any post secondary school years, ie. someone who is no longer in school will not have any current records. The only records currently 
		showing will be for the years they completed qualifications in secondary school',
		'What is the highest level of education successfully completed by this person, cumulatively?',
		'IDI_Clean.moe_clean.student_qualification',
		(SELECT CONVERT(date, GETDATE())))


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('NQF Level 0', @var_code, 0), 
		 ('Certificate or NCEA level 1', @var_code, 1), 
		 ('Certificate or NCEA level 2', @var_code, 2),
		 ('Certificate or NCEA level 3', @var_code, 3),
		 ('Certificate level 4', @var_code, 4),
		 ('Certificate or diploma level 5', @var_code, 5),
		 ('Certificate or diploma level 6', @var_code, 6),
		 ('Diploma level 7 or above', @var_code, 7)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
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
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		highest_qual,
		CASE 
			WHEN highest_qual = 0 THEN 'NQF Level 0'
			WHEN highest_qual = 1 THEN 'Certificate or NCEA level 1'
			WHEN highest_qual = 2 THEN 'Certificate or NCEA level 2'
			WHEN highest_qual = 3 THEN 'Certificate or NCEA level 3'
			WHEN highest_qual = 4 THEN 'Certificate level 4'
			WHEN highest_qual = 5 THEN 'Certificate or diploma level 5'
			WHEN highest_qual = 6 THEN 'Certificate or diploma level 6'
			ELSE 'Diploma level 7 or above'
		END AS hq_cat
	FROM
		(SELECT
			MAX(moe_sql_nqf_level_code) AS highest_qual
			,q.snz_uid AS fk_snz_uid
			,d.ye_dec_date
		 FROM IDI_Clean.moe_clean.student_qualification AS q
	 						-- we only want people in our dimension table:
		 INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		 ON q.snz_uid = p.snz_uid
		 LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
						-- we want to roll up by ye_march
		 ON q.moe_sql_nzqa_comp_date = d.date_dt
		 GROUP BY q.snz_uid, d.ye_dec_date
		) AS by_year
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.hq_cat = vc.value_category



