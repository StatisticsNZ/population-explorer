/*
Add number of crime victimisations to the fact table and relevant dimensions to the dimension tables
 

Takes about 3 minutes in total

Peter Ellis 26 September 2017

Miriam Tankersley 16 October 2017, 
Updates to align with new dim_date table:

NOTE: uses date offence is REPORTED, not date it OCCURRED.

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Victimisations'
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
		 ('One', @var_code, 1), 
		 ('More than one', @var_code, 2)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes

----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code AS fk_variable_code,
	victimisations AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		qtr_end_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		victimisations,
		CASE WHEN victimisations = 1 THEN 'One'
			 ELSE 'More than one'
		END AS vict_cat
	FROM 
		(SELECT
			COUNT(*) AS victimisations,
			v.snz_uid AS fk_snz_uid,
			d.qtr_end_date
		FROM IDI_Clean.pol_clean.post_count_victimisations AS v
					-- we only want people in our dimension table:
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		ON v.snz_uid = p.snz_uid
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date d
					-- we want to roll up by quarter
		ON v.pol_pov_reported_date = d.date_dt
		GROUP BY v.snz_uid, d.qtr_end_date
		) AS by_qtr
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.vict_cat = vc.value_category

 