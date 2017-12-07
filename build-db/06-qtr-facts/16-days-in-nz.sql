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
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';

-- grab back from the variable table the code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);
		


------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('1 to 30 days', @var_code, 1), 
		 ('31 to 60 days', @var_code, 2),
		 ('61 or more days', @var_code, 3);


-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code;
	

----------------add facts to the fact table-------------------------

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT
	fk_date_period_ending,
	fk_snz_uid,
	@var_code   AS fk_variable_code,
	value,
	value_code  AS fk_value_code
FROM		
	(SELECT
		qtr_end_date AS fk_date_period_ending,
		snz_uid      AS fk_snz_uid,
		days_in_nz   AS value,
		CASE
			WHEN days_in_nz <= 30						THEN '1 to 30 days'
			WHEN days_in_nz > 30 AND days_in_nz <= 60	THEN '31 to 60 days'
			WHEN days_in_nz > 60						THEN '61 or more days'
		END AS days_cat
	FROM
		(SELECT 
			a.snz_uid,
			sum(days_in_nz) AS days_in_nz,
			qtr_end_date
		FROM IDI_Sandpit.intermediate.days_in_nz AS a
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON a.snz_uid = p.snz_uid
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
			ON a.month_end_date = d.date_dt
		GROUP BY a.snz_uid, qtr_end_date) AS cons) AS uncoded
LEFT JOIN #value_codes v
ON uncoded.days_cat = v.value_category;


DROP TABLE #value_codes;
GO

 