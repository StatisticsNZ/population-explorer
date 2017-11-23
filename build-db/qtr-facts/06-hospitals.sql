/*
Add number of hospital discharges, to the fact table.


This quarterly version needs to be run after the annual version

note it refers to the pop_exp_test version of the dim_date table, need to change

TODO - how to clean out old versions from the quarterly fact and dim_value tables

Peter Ellis 15 September 2017


*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 

-- Declare variable name 
DECLARE @var_name VARCHAR(15) = 'Hospital'

USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = pop_exp_dev;


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name)


------------------add categorical values to the value table------------------------
-- there might be a better way to categorise these
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('one discharge', @var_code, 1),
		 ('two to five discharges', @var_code, 2),
		 ('six or more discharges', @var_code, 3);

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;

----------------add facts to the fact table-------------------------

-- Need to check which date to use, options are even_date (event end date) and evst_date (event start date). Currently using even_date.

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	fk_variable_code,
	value,
	value_code AS fk_value_code
FROM
	(SELECT
		qtr_end_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		value,
		CASE WHEN value = 1 THEN 'one discharge'
			 WHEN value > 1 AND value < 6 THEN 'two to five discharges'
			 WHEN value >= 6 THEN 'six or more discharges'
		END AS value_char
	FROM 
		(SELECT  
			COUNT(*) as value,
			h.snz_uid as fk_snz_uid,
			d.qtr_end_date
		FROM IDI_Clean.moh_clean.pub_fund_hosp_discharges_event AS h
					-- we only want people in our dimension table:
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		ON h.snz_uid = p.snz_uid
		LEFT JOIN IDI_Sandpit.pop_exp_test.dim_date AS d
					-- we want to roll up by quarter
		ON h.moh_evt_even_date = d.date_dt
		GROUP BY h.snz_uid, d.qtr_end_date
		) AS by_qtr
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.value_char = vc.value_category

 