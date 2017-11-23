/*
Adds student loan outstanding balance per march_ye to the fact table. 

Takes ir_fin_loan_bal_effective_date_amt from sla_clan.ird_loan_financial and adds it to appropriate March ye in fact table.

Miriam Tankersley 13 November 2017 

-------------------------------------------

UPDATE 17-11-17: Sum student loan amounts for multiple records (same snz_uid and ye_march). 
Have assumed these records are legitimate eg. an individual can have multiple concurrent student loan records.

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Student_loan'
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
		measured_variable_description,
		target_variable_description,
		origin_tables,
		units,
		earliest_data,
		date_built) 
	VALUES   
		(@var_name,
		'Student loan balance',
		'Good',
		'SLA-IRD',
		'continuous',
		'person-period',
		'Shows the IR record of student loan amount outstanding for March ye (ir_fin_loan_bal_effective_date_amt).
		 Where multiple records exist for the same March ye, these have been summed together.',
		 'What is the student loan balance of this person each period?',
		'IDI_Clean.sla_clean.ird_loan_financial',
		'dollars',
		(SELECT MIN(DATEFROMPARTS(ir_fin_return_year_nbr, 1, 1)) FROM IDI_Clean.sla_clean.ird_loan_financial),
		(SELECT CONVERT(date, GETDATE())))

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('negative', @var_code, 0),
		 ('$0 - $1,000', @var_code, 1),
		 ('$1,001 - $5,000', @var_code, 2),
		 ('$5,001 - $10,000', @var_code, 3),
		 ('$10,001 - $20,000', @var_code, 4),
		 ('$20,001 - $40,000', @var_code, 5),
		 ('$40,001+', @var_code, 6)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes

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
			DATEFROMPARTS(year_nbr, 12, 31) as fk_date, 
			value, 
			fk_variable_code = @var_code,
			CASE 
			 WHEN value < 0 THEN 'negative'
			 WHEN value >= 0 AND value <= 1000		THEN '$0 - $1,000'
			 WHEN value > 1000 AND value <= 5000	THEN '$1,001 - $5,000'
			 WHEN value > 5000 AND value <= 10000	THEN '$5,001 - $10,000'
			 WHEN value > 10000 AND value <= 20000	THEN '$10,001 - $20,000'
			 WHEN value > 20000 AND value <= 40000	THEN '$20,001 - $40,000'
			 WHEN value > 40000						THEN '$40,001+'
			END as value_category
		FROM
		(SELECT 
			i.snz_uid									AS fk_snz_uid,
			SUM(ir_fin_loan_bal_effective_date_amt)		AS value,
			ir_fin_return_year_nbr						AS year_nbr	
		FROM 
			IDI_Clean.sla_clean.ird_loan_financial AS i
			-- we only want people in our dimension table:
			INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS s
				ON i.snz_uid = s.snz_uid
			GROUP BY i.snz_uid, ir_fin_return_year_nbr
		) AS a

	) AS with_cats
	-- we want to covert the categories back from categories to codes
	LEFT JOIN #value_codes vc
	ON with_cats.value_category = vc.value_category
	ORDER BY fk_snz_uid






