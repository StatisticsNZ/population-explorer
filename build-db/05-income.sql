/*
Add annual income, from the tax summary information, to the fact table.

This was my first go at a general pattern.  We do the following:

- add the variable name to the variable dimension table, letting it auto increment the code
- grab back what that code is now going to be for our variable and save it as @var_code so we know what code this variable is
- add the categories that lump continuous things to the value table, letting it auto increment to create their codes
- grab back a mini table of those categories which we will use in assigning categories to peoples' values
- get the original data we want from the IDI in the shape we need, lump it (ie calculate the categorical values we need), 
    join it to that mini look up table to convert the lumped categories to numbers
- insert it into the main fact table.

This program takes a while to run (about 3-6 minutes on one run, 30(!) minutes on another), with nearly all the cost 
being in the final INSERT statement

Peter Ellis 7 September 2017

Miriam Tankersley 12 October 2017, 
Updates to align with new dim_date table:
- replaced datecode with date
- removed join to date table (as no longer need to look up datecode), and replaced with DATEFROMPARTS(year_nbr,3,31) as fk_date

PE 17 November - change to "year minus 1" as best overlap with calendar year as part of general move to YE December for most variables.

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Income';

use IDI_Sandpit
execute lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';



----------------add variable to the variable table-------------------

--select top 5 * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable
--select top 5 * from IDI_Sandpit.pop_exp_dev.fact_rollup_year

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
		date_built) 
	VALUES   
		(@var_name,
		'Income all sources',
		'Good',
		'IRD',
		'continuous',
		'person-period',
		'dollars',
		'This is just the "income from all sources" from the IDI_Clean.data.income_tax_yr_summary table, which ultimately comes from IRD''s tax data.',
		'What is the total income for the person each period?',
		'IDI_Clean.data.income_tax_yr_summary',
		 (SELECT CONVERT(date, GETDATE())));

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
		 ('loss', @var_code, 1),
		 ('$0 - $5,000', @var_code, 2),
		 ('$5,001 - $10,000', @var_code, 3),
		 ('$10,001 - $20,000', @var_code, 4),
		 ('$20,001 - $30,000', @var_code, 5),
		 ('$30,001 - $40,000', @var_code, 6),
		 ('$40,001 - $50,000', @var_code, 7),
		 ('$50,001 - $70,000', @var_code, 8),
		 ('$70,001 - $100,000', @var_code, 9),
		 ('$100,001 - $150,000', @var_code, 10),
		 ('$150,001+', @var_code, 11);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	-- WHERE fk_variable_code = 1; -- used during debugging instead of the line above

	-- if interested in our look up table check out:
	-- select * from #value_codes;
----------------add facts to the fact table-------------------------


INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT   
		fk_date,
		fk_snz_uid,
		fk_variable_code,
		value,
		value_code as fk_value_code
FROM
	(SELECT 
			fk_snz_uid, 
			-- we use year_nbr minus 1 in the below because if (for example) the income is to YE March 2013, 3/4 of it was paid in 2012:
			DATEFROMPARTS(year_nbr - 1, 12, 31) as fk_date, 
			value, 
			fk_variable_code = @var_code,
			CASE 
			 WHEN value < 0 THEN 'loss'
			 WHEN value >= 0 AND value <= 5000 THEN '$0 - $5,000'
			 WHEN value > 5000 AND value <= 10000 THEN '$5,001 - $10,000'
			 WHEN value > 10000 AND value <= 20000 THEN '$10,001 - $20,000'
			 WHEN value > 20000 AND value <= 30000 THEN '$20,001 - $30,000'
			 WHEN value > 30000 AND value <= 40000 THEN '$30,001 - $40,000'
			 WHEN value > 40000 AND value <= 50000 THEN '$40,001 - $50,000'
			 WHEN value > 50000 AND value <= 70000 THEN '$50,001 - $70,000'
			 WHEN value > 70000 AND value <= 100000 THEN '$70,001 - $100,000'
			 WHEN value > 100000 AND value <= 150000 THEN '$100,001 - $150,000'
			 WHEN value > 150000					THEN '$150,001+'
			END as value_category
		FROM
		(SELECT 
			i.snz_uid                           AS fk_snz_uid,
			inc_tax_yr_sum_all_srces_tot_amt    AS value,
			inc_tax_yr_sum_year_nbr             AS year_nbr		
		FROM 
			IDI_Clean.data.income_tax_yr_summary AS i
			-- we only want people in our dimension table:
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS s
			ON i.snz_uid = s.snz_uid) AS a
		) AS with_cats
	-- we want to covert the categories back from categories to codes
	LEFT JOIN #value_codes vc
	ON with_cats.value_category = vc.value_category
	ORDER BY fk_snz_uid;



drop table #value_codes;


