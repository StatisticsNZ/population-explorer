/*
Add days spent in New Zealand to the fact table.  This is now a familiar routine... it depends on the
existence of intermediate.days_in_nz which does all the work, the rest is just the usual matching against 
codes and putting in the database.
 

Takes about 30 - 50 minutes

Peter Ellis 
16 October 2017 - created

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Days_NZ';
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
		units,
		measured_variable_description,
		target_variable_description,
		origin_tables,
		earliest_data,
		date_built) 
	VALUES   
		(@var_name,
		'Days spent in New Zealand',
		'Good',
		'SNZ',
		'count',
		'person-period',
		'number of days',
		'This is a rolled up version of the intermediate.spells_in_nz table, which aims to have spells in New Zealand for two arrival types
		(birth and border crossing) and three "departure" types (death, border crossing, and "still in the country" at time of latest movements 
		data).  There are problems in the movements data eg with people who appear to have departed twice in a row without arriving in between.
		These problems have been dealt with in the simplest way; an arrival is treated as "in the country" until the next departure, so the 
		second departure is effectively ignored.  This means an underestimate of days in the country in a small number of cases.  Births and 
		deaths have also been de-duplicated, and the problem of a very small number of spine individuals with multiple births or deaths referred
		to the IDI team.',
		'How many days did this person spend in New Zealand each time period?',
		'IDI_Clean.dia_clean.births, IDI_Clean.dia_clean.deaths, IDI_Clean.dol_clean.movements',
		(SELECT MIN(start_date) FROM IDI_Sandpit.intermediate.spells_in_nz),
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
		 ('1 to 90 days', @var_code, 1), 
		 ('91 to 182 days', @var_code, 2),
		 ('183 or more days', @var_code, 3);


-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	

----------------add facts to the fact table-------------------------

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT
	fk_date_period_ending,
	fk_snz_uid,
	@var_code   AS fk_variable_code,
	value,
	value_code  AS fk_value_code
FROM		
	(SELECT
		ye_dec_date AS fk_date_period_ending,
		snz_uid     AS fk_snz_uid,
		days_in_nz  AS value,
		CASE
			WHEN days_in_nz <= 90						THEN '1 to 90 days'
			WHEN days_in_nz > 90 AND days_in_nz <=182	THEN '91 to 182 days'
			WHEN days_in_nz > 182						THEN '183 or more days'
		END AS days_cat
	FROM
		(SELECT 
			snz_uid,
			sum(days_in_nz) AS days_in_nz,
			ye_dec_date
		FROM IDI_Sandpit.intermediate.days_in_nz AS a
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
			ON a.month_end_date = d.date_dt
		GROUP BY snz_uid, ye_dec_date) AS cons) AS uncoded
LEFT JOIN #value_codes v
ON uncoded.days_cat = v.value_category;


DROP TABLE #value_codes;
GO

 