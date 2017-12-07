/*
Add average age of each quarter to the fact table.

Needs to be run after the annual version is finished because it uses the variable code from there.
 
Peter Ellis 
*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Age';

USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = pop_exp_dev;


-- grab back from the table the code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);
		


------------------add categorical values to the value table------------------------
-- For age, these value categories are the same for quarterly as annual, but this isn't the case
-- for all other variables.  Still, we need to include them in value_qtr anyway.
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('0-9', @var_code, 1), 
		 ('10-19', @var_code, 2),
		 ('20-29', @var_code, 3),
		 ('30-39', @var_code, 4),
		 ('40-49', @var_code, 5),
		 ('50-59', @var_code, 6),
		 ('60-69', @var_code, 7),
		 ('70-79', @var_code, 8),
		 ('80+', @var_code, 9);


-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	
----------------add facts to the fact table-------------------------
-- this next chunk feels clunky, might be able to make it quicker and simpler.
-- The strategy is, find the average age by quarter; cut that up into bands; convert the bands to value codes; insert into fact table.
-- The need to get the average first is an extra step compared to the simpler annual script.

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	ye_dec_date								AS fk_date_period_ending,
	snz_uid									AS fk_snz_uid,
	@var_code								AS fk_variable_code,
	CASE WHEN age < 0 THEN 0 ELSE age END	AS value,
	value_code								AS fk_value_code
FROM
	(SELECT
	   snz_uid,
	   qtr_end_date,
	   age,
	   CASE WHEN age <10 THEN '0-9'
			WHEN age >=10 and age < 20 THEN '10-19'
			WHEN age >=20 and age < 30 THEN '20-29'
			WHEN age >=30 and age < 40 THEN '30-39'
			WHEN age >=40 and age < 50 THEN '40-49'
			WHEN age >=50 and age < 60 THEN '50-59'
			WHEN age >=60 and age < 70 THEN '60-69'
			WHEN age >=70 and age < 80 THEN '70-79'
			WHEN age >=80 THEN '80+'
		END AS age_cat
	FROM
		(SELECT 
			a.snz_uid,       
			d.qtr_end_date,
			AVG(age) AS age
		FROM IDI_Sandpit.intermediate.age_end_month			AS a
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON a.snz_uid = p.snz_uid
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date			AS d
			ON a.month_end_date = d.date_dt
		GROUP BY qtr_end_date, a.snz_uid) AS ages ) AS ages_codes
	LEFT JOIN #value_codes v
	ON ages_codes.age_cat = v.value_category;
