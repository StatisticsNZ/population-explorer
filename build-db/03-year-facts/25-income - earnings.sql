/*
This is an alternative view of income compared to 05, because it only consists of a subset of codes.
The approach is based on Taylor Winter's income estimates as used in the Regional Economic Activity Report


These are the Self-Employed Income codes: ('C00','C01','C02','P00','P01','P02','S00','S01','S02'). They exclude rent.  Some of these codes (all?) are only available annually
And total income (Taylor's measure) = SEI (defined above) + WS + PEN + BEN + CLM + PPL.  It excludes rent (S03?) and student loans (STU)

SELECT top 50
	snz_uid,
	SUM(inc_tax_yr_tot_yr_amt) as income2,
	inc_tax_yr_year_nbr
FROM IDI_Clean.data.income_tax_yr
WHERE inc_tax_yr_income_source_code in ('C00','C01','C02','P00','P01','P02','S00','S01','S02', 
			'W&S', 'PEN', 'BEN', 'CLM', 'PPL')
GROUP BY snz_uid, inc_tax_yr_year_nbr

This variable shares value bands with 'Income' and hence has a slightly simplified loading script.

14 November 2017, Pete Ellis

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Income2';

use IDI_Sandpit
execute lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';


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
		date_built,
		variable_class,
		data_type) 
	VALUES   
		(@var_name,
		'Income other than from rent and student loans',
		'Good',
		'IRD',
		'continuous',
		'person-period',
		'dollars',
		'From the income source codes C00,C01,C02,P00,P01,P02,S00,S01,S02 (which are self-employed income), 
		  and W&S, PEN, BEN, CLM, PPL which are wages and salaries, pensions, benefits, claimants compensation,
		  paid parental leave.  Rent and student loans are excluded for consistency with the definition applied 
		  by Labour market publications from Stats NZ.',
		  'How much active (?) income did the person receive each time period?',
		'IDI_Clean.data.income_tax_yr',
		 (SELECT CONVERT(date, GETDATE())),
		 'Income and employment',
		 'NUMERIC(15)');

-- grab back from the table the code for our newly added variable
DECLARE @var_code INT;	 
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable 
		WHERE short_name = @var_name);

------------------add categorical values to the value table------------------------
-- First we grab the ones we used earlier for income, and put them back with a new variable code:
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year	(short_name, fk_variable_code, var_val_sequence)
SELECT a.short_name, @var_code AS fk_variable_code, var_val_sequence
FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year     AS a
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_explorer_variable AS b
ON a.fk_variable_code = b.variable_code
WHERE b.short_name = 'Income'

-- and grab  back the mini-lookup table with just our value codes
SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code;


	
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
			SUM(inc_tax_yr_tot_yr_amt)		    AS value,
			inc_tax_yr_year_nbr			        AS year_nbr		
		FROM 
			IDI_Clean.data.income_tax_yr AS i
			-- we only want people in our dimension table:
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS s
			ON i.snz_uid = s.snz_uid
		WHERE inc_tax_yr_income_source_code in ('C00','C01','C02','P00','P01','P02','S00','S01','S02', 
													'W&S', 'PEN', 'BEN', 'CLM', 'PPL')
		GROUP BY i.snz_uid, inc_tax_yr_year_nbr) AS a
		) AS with_cats
	-- we want to covert the categories back from categories to codes
	LEFT JOIN #value_codes vc
	ON with_cats.value_category = vc.value_category
	ORDER BY fk_snz_uid;


drop table #value_codes;


