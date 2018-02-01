/*
Add net benefits received (all of Tier 1, 2 and 3)

Takes anywhere between about 1 and 60 minutes

Peter Ellis 27 September 2017
Miriam Tankersley 24 October 2017, Updates to align with new dim_date table:
Peter Ellis 9 November 2017 Adjusted to handle the intermediate.benefits_ye_XXX now including tier information


*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 



DECLARE @var_name VARCHAR(15) = 'Benefits'

USE IDI_Sandpit

EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';


----------------add variable to the variable table-------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		(short_name, 
		long_name,
		quality,
		origin,
		var_type,
		measured_variable_description,
		target_variable_description,
		origin_tables,
		grain,
		units,
		date_built,
		variable_class,
		data_type) 
	VALUES   
		(@var_name,
		'Net Tier 1, 2 and 3 Benefits',
		'Good',
		'MSD',
		'continuous',
		'Combined Tier 1, Tier 2 and Tier 3 benefits for the period.  No duplications or overlapping spells have been removed.
		No adjustments have been made for family relationships - benefits are allocated to individuals, as per the summary tables
		in the msd_clean schema eg IDI_Clean.msd_clean.msd_first_tier_expenditure.',
		'What is the total sum of benefits receive by the person each time period?',
		'IDI_Clean.msd_clean.msd_first_tier_expenditure, IDI_Clean.msd_clean.msd_second_tier_expenditure, IDI_Clean.msd_clean.msd_third_tier_expenditure',
		'person-period',
		'dollars',
		(SELECT CONVERT(date, GETDATE())),
		'Income and employment',
		'INT'); -- alternative data type could be NUMERIC(15,2), if the fact table has been defined to allow them

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name)
		


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('<$1,000', @var_code, 1), 
		 ('$1,000-$5,000', @var_code, 2),
		 ('$5,000-$10,000', @var_code, 3),
		 ('>$10,000', @var_code, 4)

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes
----------------add facts to the fact table-------------------------
-- aggregate benefits over all three tiers, from quarterly into calendar year data:
SELECT
	b.snz_uid,
	ye_dec_date,
	SUM(net_amt) AS net_benefit
INTO #benefits
FROM IDI_Sandpit.intermediate.days_on_benefits AS b
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON b.qtr_end_date = d.date_dt
-- we only want people in our dimension table:
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
	ON b.snz_uid = p.snz_uid
GROUP BY b.snz_uid, ye_dec_date

-- put into the fact table:
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	ye_dec_date		AS fk_date_period_ending,
	snz_uid			AS fk_snz_uid,
	@var_code		AS fk_variable_code,
	net_benefit	AS value,
	value_code		AS fk_value_code
FROM
	(SELECT 
		a.snz_uid,
		ye_dec_date,
		net_benefit,
		CASE WHEN net_benefit <1000 THEN '<$1,000'
			 WHEN net_benefit >=1000 and net_benefit < 5000 THEN '$1,000-$5,000'
			 WHEN net_benefit >=5000 and net_benefit < 10000 THEN '$5,000-$10,000'
			 WHEN net_benefit >=10000  THEN '>$10,000'
		END AS ben_cat
	FROM #benefits AS a) AS with_cats
			
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes AS v
ON with_cats.ben_cat = v.value_category

 
