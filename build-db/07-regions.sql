/*
Add region most lived in, from the table made in script 7a, to the fact table.



The continuous [value] in the main fact table is going to be 0 for this variable; it only gets a categorical [value_code].
Conceptually, we could put a number in [value] like "number of months in this region" but that would turn the variable into
a sort of combination value - dimension combo (with a category of "region" and a value of "months in there") which would break
the pattern and probably the reporting layer.

Running time: 11+ minutes

Peter Ellis 
12 September 2017 created
16 October adapted to adjust for the changes in the intermediate tables so we have monthly meshblock
30 October added the detailed description.
*/




IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes;
GO 


DECLARE @var_name VARCHAR(15) = 'Region';
USE IDI_Sandpit
EXECUTE lib.clean_out_all @var_name = @var_name, @schema = 'pop_exp_dev';

----------------add variable to the variable table-------------------

--select top 5 * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable
--select top 5 * from IDI_Sandpit.pop_exp_dev.fact_rollup_year

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
		date_built) 
	VALUES   
		(@var_name,
		'Region most lived in',
		'Good',
		'notifications',
		'category',
		'person-period',
'Address notifications have been used to estimate the meshblock at which each person on the spine was living on the 15th of each month, and this is stored 
as IDI_Sandpit.intermediate.address_mid_month.  These meshblock locations are joined to regions (ie Regional Councils) and aggregated by time period, and the region each individual
lived longest in during the time period is recorded.  In the event of ties (eg six months each in two regions, if the period is a year) a region is chosen at random from the top 
regions.  There is no continuous version of this variable, only the categorical value of the region.',
'In which region did the person live in most, in a given period?',
'IDI_Clean.data.address_notification, IDI_Sandpit.intermediate.address_mid_month, IDI_Sandpit.derived.dim_meshblock, 
IDI_Metadata.clean_read_CLASSIFICATIONS.CEN_REGC13',
			(SELECT CONVERT(date, GETDATE())));

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT;
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name);


------------------add categorical values to the value table------------------------
INSERT IDI_Sandpit.pop_exp_dev.dim_explorer_value(short_name, fk_variable_code, var_val_sequence)
SELECT DISTINCT
	region_name			as short_name,
	@var_code			as fk_variable_code,
	ant_region_code		as var_val_sequence
FROM IDI_Sandpit.intermediate.dim_meshblock;

-- and grab  back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code;
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;
	-- select * from IDI_Sandpit.pop_exp_dev.dim_explorer_value; 
	-- select * from IDI_Sandpit.pop_exp_dev.dim_explorer_variable;
	
----------------add facts to the fact table-------------------------
-- value has to be NOT NULL so we make it zero.  

INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, value, fk_variable_code, fk_value_code)
	SELECT 
			ye_dec_date as fk_date_period_ending, 
			fk_snz_uid, 
			value = 0,
			fk_variable_code = @var_code,
			value_code as fk_value_code
		FROM
				
		(SELECT
			snz_uid                           as fk_snz_uid,
			ye_dec_date,
			region_most_lived_in
			
		FROM 
			IDI_Sandpit.intermediate.region_lived_in_ye_dec
		) a
		LEFT JOIN #value_codes 
		ON a.region_most_lived_in = #value_codes.value_category;


--DROP TABLE #value_codes;


