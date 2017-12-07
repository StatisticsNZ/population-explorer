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

EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name)
		


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('<$250', @var_code, 1), 
		 ('$250-$1,250', @var_code, 2),
		 ('$1,250-$2,500', @var_code, 3),
		 ('>$2,500', @var_code, 4)

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code
	

----------------add facts to the fact table-------------------------
-- aggregate benefits over all three tiers:
SELECT
	b.snz_uid,
	b.qtr_end_date,
	SUM(net_amt) AS net_benefit
INTO #benefits
FROM IDI_Sandpit.intermediate.days_on_benefits AS b
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON b.qtr_end_date = d.date_dt
-- we only want people in our dimension table:
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
	ON p.snz_uid = b.snz_uid
GROUP BY b.snz_uid, b.qtr_end_date

-- put into the fact table:
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	qtr_end_date	AS fk_date_period_ending,
	snz_uid			AS fk_snz_uid,
	@var_code		AS fk_variable_code,
	net_benefit		AS value,
	value_code		AS fk_value_code
FROM
	(SELECT 
		a.snz_uid,
		qtr_end_date,
		net_benefit,
		CASE WHEN net_benefit < 250 THEN '<$250'
			 WHEN net_benefit >= 250 and net_benefit < 1250 THEN '$250-$1,250'
			 WHEN net_benefit >= 1250 and net_benefit < 2500 THEN '$1,250-$2,500'
			 WHEN net_benefit >= 2500  THEN '>$2,500'
		END AS ben_cat
	FROM 
		#benefits AS a) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes AS v
ON with_cats.ben_cat = v.value_category

 
