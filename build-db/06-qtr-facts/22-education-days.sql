/*
Adds days spent in education per quarter to the fact table. 


*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Education'
USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('No days in education', @var_code, 0),
		 ('1 to 30 days', @var_code, 1), 
		 ('31 to 60 days', @var_code, 2),
		 ('61 or more days', @var_code, 3)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code


----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code AS fk_variable_code,
	education_days AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		qtr_end_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		education_days,
		CASE 
			WHEN education_days <= 0							THEN 'No days in education'
			WHEN education_days <= 30 AND education_days > 0	THEN '1 to 30 days'
			WHEN education_days > 30 AND education_days <= 60	THEN '31 to 60 days'
			WHEN education_days >= 61							THEN '61 or more days'
		END AS edu_cat
	FROM
		(SELECT
			SUM(days_in_education) AS education_days
			,e.snz_uid AS fk_snz_uid
			,d.qtr_end_date
		 FROM IDI_Sandpit.intermediate.days_in_education AS e
	 						-- we only want people in our dimension table:
		 INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		 ON e.snz_uid = p.snz_uid
		 LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
						-- we want to roll up by quarter
		 ON e.month_end_date = d.date_dt
		 GROUP BY e.snz_uid, d.qtr_end_date
		) AS by_qtr
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.edu_cat = vc.value_category



