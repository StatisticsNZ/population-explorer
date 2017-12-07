/*
Adds student loan outstanding balance per quarter to the fact table. 


*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Student_loan'
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
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code
	
----------------add facts to the fact table-------------------------
-- we need a little reference table of each quarter that is in each year, so
-- we can right join our annual data to it and get (duplicate) four rows of data for each:
SELECT DISTINCT	ye_dec_nbr, qtr_end_date
INTO #year_quarters
FROM IDI_Sandpit.pop_exp_dev.dim_date

INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT   
		fk_date,
		fk_snz_uid,
		fk_variable_code,
		value,
		value_code as fk_value_code
FROM
	(SELECT 
			fk_snz_uid, 
			qtr_end_date AS fk_date, 
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
		
		RIGHT JOIN #year_quarters AS yq
				ON a.year_nbr = yq.ye_dec_nbr
			

	) AS with_cats
	-- we want to covert the categories back from categories to codes
	LEFT JOIN #value_codes vc
	ON with_cats.value_category = vc.value_category
	ORDER BY fk_snz_uid



