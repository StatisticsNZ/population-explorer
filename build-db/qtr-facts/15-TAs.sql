/*
Add TA most lived in, from the table made in script 15a, to the fact table.

See description in script 7.  Both this script and those draw on assets saved
in the derived schema intermediate.address_mid_month and intermediate.dim_meshblock which have
information on where people were living on 15th of each motnh.

Peter Ellis 
16 October created
*/




IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'TA';

USE IDI_Sandpit

EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';

-- grab back from the table the code for our variable and store as a temp table @var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr(short_name, fk_variable_code, var_val_sequence)
SELECT DISTINCT
	territorial_authority_name			as short_name,
	@var_code							as fk_variable_code,
	CAST(ant_ta_code AS INT)			as var_val_sequence
FROM IDI_Sandpit.intermediate.dim_meshblock;

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code;
	
	
----------------add facts to the fact table-------------------------
-- value has to be NOT NULL so we make it zero.  

INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, value, fk_variable_code, fk_value_code)
	SELECT 
			qtr_end_date as fk_date_period_ending, 
			fk_snz_uid, 
			value = 0,
			fk_variable_code = @var_code,
			value_code as fk_value_code
	FROM
		(SELECT
			snz_uid                           AS fk_snz_uid,
			qtr_end_date,
			ta_most_lived_in
		FROM 
			IDI_Sandpit.intermediate.ta_lived_in_qtr
		) AS a
	LEFT JOIN #value_codes 
		ON a.ta_most_lived_in = #value_codes.value_category;



