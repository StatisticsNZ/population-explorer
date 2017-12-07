/*
Add number of hospital discharges, to the fact table.


This program takes about 45 seconds to run on a good day, 6 minutes on a bad one.

TODO - there is also a file of private hospital discharge events are we interested in this?

Peter Ellis 8 September 2017

Miriam Tankersley 16 October 2017, 
Updates to align with new dim_date table:
- removed temp table #hosp (no longer needed). incorporated join to dim_date table into one query instead.

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 

-- Declare variable name and clean out any old efforts with it
DECLARE @var_name VARCHAR(15) = 'Hospital'
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
		units,
		measured_variable_description,
		target_variable_description,
		origin_tables,
		date_built,
		variable_class) 
	VALUES   
		(@var_name,
		'Discharges from a public hospital',
		'Good',
		'MOH',
		'count',
		'person-period',
		'number of discharges',
		'The total number of recorded discharges from a public hospital in the designated period.  
		Note that the same patient may be discharaged multiple times in a period, sometimes multiple times in a day.
		No filtering is done to limit the count to "serious" issues or to try to aggregate "common" events
		into a single one.',
		'How many times was this person in hospital this period?',
		'IDI_Clean.moh_clean.pub_fund_hosp_discharges_event',
		 (SELECT CONVERT(date, GETDATE())),
		 'Health and wellbeing');

-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
		FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
		WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
-- there might be a better way to categorise these
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('one discharge', @var_code, 1),
		 ('two to five discharges', @var_code, 2),
		 ('six or more discharges', @var_code, 3);

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name as value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes;

----------------add facts to the fact table-------------------------

-- Need to check which date to use, options are even_date (event end date) and evst_date (event start date). Currently using even_date.

INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	fk_variable_code,
	value,
	value_code AS fk_value_code
FROM
	(SELECT
		ye_dec_date AS fk_date_period_ending,
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
			d.ye_dec_date
		FROM IDI_Clean.moh_clean.pub_fund_hosp_discharges_event AS h
					-- we only want people in our dimension table:
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
		ON h.snz_uid = p.snz_uid
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
					-- we want to roll up by ye_december
		ON h.moh_evt_even_date = d.date_dt
		GROUP BY h.snz_uid, d.ye_dec_date
		) AS by_year
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.value_char = vc.value_category

 