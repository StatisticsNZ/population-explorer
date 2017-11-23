/*
Adds days spent in education per march_ye to the fact table. 

Aggregates IDI_Sandpit.intermediate.days_in_education table (days in education per snz_uid per year-month) to days per march_ye.
"Education" includes any spells identified in primary and secondary school, tertiary, industry training and targeted training placement data.

See int-tables/22_days_in_education (intermediate table code) for more information.

Miriam Tankersley 8 November 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Education'
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
		'Days in education',
		'Good',
		'MoE',
		'count',
		'person-period',
		'Calculates days spent in education per time period. "Education" includes any spells identified in primary and secondary school, tertiary, 
		industry training and targeted training placement data.',
		'How long has this person spent in education and training each time period?',
		'IDI_Sandpit.intermediate.days_in_education, 
		IDI_Clean.moe_clean.student_enrol, IDI_Clean.moe_clean.course, IDI_Clean.moe_clean.tec_it_learner, IDI_Clean.moe_clean.targeted_training',
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
		 ('No days in education', @var_code, 0),
		 ('1 to 90 days', @var_code, 1), 
		 ('91 to 182 days', @var_code, 2),
		 ('183 or more days', @var_code, 3)

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
	education_days AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		education_days,
		CASE 
			WHEN education_days <= 0							THEN 'No days in education'
			WHEN education_days <= 90							THEN '1 to 90 days'
			WHEN education_days > 90 AND education_days <=182	THEN '91 to 182 days'
			WHEN education_days > 182							THEN '183 or more days'
		END AS edu_cat
	FROM
		(SELECT
			SUM(days_in_education) AS education_days
			,e.snz_uid AS fk_snz_uid
			,d.ye_dec_date
		 FROM IDI_Sandpit.intermediate.days_in_education AS e
	 						-- we only want people in our dimension table:
		 INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		 ON e.snz_uid = p.snz_uid
		 LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
						-- we want to roll up by ye_march
		 ON e.month_end_date = d.date_dt
		 GROUP BY e.snz_uid, d.ye_dec_date
		) AS by_year
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.edu_cat = vc.value_category



