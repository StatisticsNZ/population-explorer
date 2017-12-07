/*
Resident population
For now, will just look at it they were in the resident pop in the June that was 6 months into the 12 month period of the YE December.

This is quite a metaphysical concept.  The code that creates the Estimated Resident Population (ERP) looks to see if people were out
of the country for more than six months, and if there is some kidn of other evidence for residence in addition (eg paid income tax).
It's probably better for our purposes to use the more direct measure of "days in NZ" during the period in question.

The "value" in this case might in the future be the weight of the person so totals add up to the "correct" total for NZ, by various dimensions.  
For now we will make that 1.

Running time depends on how much other data is in the database and what else is up.  
- 5 minutes on 26 September on wprdsql36
- 15 minutes on 11 October on wtstsql35

26 September 2017 Peter Ellis, created
18 October 2017 Peter Ellis, added 'grain' field to dim_explorer_variable
17 November PE changed to reflect YE december not march and simplified a bit while here
*/


IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;

GO 


DECLARE @var_name VARCHAR(15) = 'Resident';
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
		date_built,
		variable_class,
		has_numeric_value) 
	VALUES   
		(@var_name,
		'Resident on 30 June',
		'Moderate',
		'SNZ',
		'category',
		'person-period',
		'This is the "estimated resident population on 30 June" estimates in IDI_Clean.data.snz_res_pop, for the 30 June that occurs in the given period.  No additional transformations have been made
		to the data in the original table.  The original table is based on estimates of time spent in New Zealand and demonstrable activity (income, education, etc) in the previous 12(??)
		months leading up to the 30 June. ',
		'Was this person a New Zealand resident in a given period?',
		'IDI_Clean.data.snz_res_pop',
		(SELECT CONVERT(date, GETDATE())),
		'Residency, housing and transport',
		'No numeric value');

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;

SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);
		


------------------add categorical values to the value table------------------------
-- there's only one possible value for this variable.  If they're not resident they don't show up.
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Resident on 30 June', @var_code, 1);

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;
----------------add facts to the fact table-------------------------

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	DATEFROMPARTS(YEAR(srp_ref_date), 12, 31)	AS fk_date_period_ending,
	r.snz_uid									AS fk_snz_uid,
	@var_code									AS fk_variable_code,
	1											AS value,
	value_code									AS fk_value_code
FROM IDI_Clean.data.snz_res_pop AS r
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
	ON r.snz_uid = p.snz_uid
LEFT JOIN #value_codes vc
	ON vc.value_category = 'Resident on 30 June'


