/*
Add age on 30 June to the fact table.
 
Choosing 30 June because it is mid way through a year ending December.

Takes about 38 minutes

Peter Ellis 
26 September 2017 - created
16 October 2017   - updated and debugged given the presence of monthly date estimates in dervied.age_end_month
9 November 2017 - updated and debugged properly now ! - writing up the full_description made me realise one year out.
*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Age';
USE IDI_Sandpit
EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';


----------------add variable to the variable table-------------------
--DECLARE @var_name VARCHAR(15) = 'Age';
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
		units,
		date_built) 
	VALUES   
		(@var_name,
		'Age on 30 September',
		'Good',
		'DIA',
		'continuous',
		'person-period',
		'The ages of everyone on the spine on the last day of each month, back to 1990 and assuming everyone was born on the 
		15th of their birth month, are stored in intermediate.age_end_month.  For annual data, the age on 30 June of year Y is taken as 
		the average age of an individual in Year Ending December Y.',
		'What is the person''s age in the middle of a given time period?',
		'intermediate.age_end_month, IDI_Clean.dia_clean.deaths, IDI_Clean.dia_clean.births',
		'years',
		(SELECT CONVERT(date, GETDATE())));

--select * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable;

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);
		


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
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

-- select * from IDI_Sandpit.pop_exp_dev.dim_explorer_value

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;
----------------add facts to the fact table-------------------------

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
		d.ye_dec_date,
		age AS age,
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
	FROM IDI_Sandpit.intermediate.age_end_month			AS a
	INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date			AS d
	ON a.month_end_date = d.date_dt
	WHERE d.month_nbr = 6 and d.day_of_month = 30) ages
	LEFT JOIN #value_codes v
	ON ages.age_cat = v.value_category;
