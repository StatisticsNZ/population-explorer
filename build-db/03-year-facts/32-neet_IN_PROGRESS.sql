/*
Adds months as NEET per year to the fact table.

Aggregates IDI_Sandpit.intermediate.monthly_activity table (activity per snz_uid per year-month) to NEET months per year.

See int-tables/32_neet (intermediate table code) for more information.

Miriam Tankersley 8 December 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'NEET'
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
		'Months NEET',
		'Good',
		'SNZ',
		'count',
		'person-period',
		'Calculates number of months as NEET (not in education or training, employment, overseas for 15 or more days per month) per time period. ',
		'How long has this person spent as NEET in each time period?',
		'IDI_Sandpit.intermediate.monthly_activity, 
		IDI_Sandpit.intermediate.days_in_nz,
		IDI_Sandpit.intermediate.days_in_education,
		IDI_Sandpit.intermediate.days_in_employment',
		(SELECT CONVERT(date, GETDATE())),
		'Education and training, Income and employment')

---- FINISHED HERE 8/12/17

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
		 ('1 month or less', @var_code, 1),
		 ('2 to 3 months', @var_code, 2), 
		 ('4 to 6 months', @var_code, 3),
		 ('7 to 9 months', @var_code, 4),
		 ('10 months or more', @var_code, 5)

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
	education_days AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		neet_months,
		CASE 
			WHEN neet_months <= 1		THEN '1 month or less'
			WHEN neet_months IN (2,3)	THEN '2 to 3 months'
			WHEN neet_months IN (4,5,6)	THEN '4 to 6 months'
			WHEN neet_months IN (7,8,9) THEN '7 to 9 months'
			ELSE '10 months or more'
		END AS neet_cat
	FROM
		(SELECT 
			SUM(CASE WHEN activity = 'neet' THEN 1 END) AS neet_months
			,a.snz_uid AS fk_snz_uid
			,d.ye_dec_date
		 FROM IDI_Sandpit.intermediate.monthly_activity AS a
	 						-- we only want people in our dimension table:
		 INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		 ON a.snz_uid = p.snz_uid
		 LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
						-- we want to roll up by ye_december
		 ON a.month_end_date = d.date_dt
		 GROUP BY a.snz_uid, d.ye_dec_date
		) AS by_year
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.neet_cat = vc.value_category



