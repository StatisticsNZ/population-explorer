/*
Add region most lived in, from the table made in script 7a, to the fact table.



Peter Ellis 
12 September 2017 created
16 October adapted to adjust for the changes in the intermediate tables so we have monthly meshblock
30 October added the detailed description.
*/




IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Region';
USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';

-- grab back from the variable dimension table the code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr(short_name, fk_variable_code, var_val_sequence)
SELECT DISTINCT
	region_name			as short_name,
	@var_code			as fk_variable_code,
	ant_region_code		as var_val_sequence
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
			qtr_end_date AS fk_date_period_ending, 
			fk_snz_uid, 
			value = 0,
			fk_variable_code = @var_code,
			value_code AS fk_value_code
		FROM
				
		(SELECT
			snz_uid                           AS fk_snz_uid,
			qtr_end_date,
			region_most_lived_in
			
		FROM 
			IDI_Sandpit.intermediate.region_lived_in_qtr
		) a
		LEFT JOIN #value_codes 
		ON a.region_most_lived_in = #value_codes.value_category;




