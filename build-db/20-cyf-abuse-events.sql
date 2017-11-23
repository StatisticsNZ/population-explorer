/*
Add number of CYF (Child Youth and Family) abuse events to the main fact table.

For now, we are just counting all the events.  Down the track we're likely to want to replace (or add to)
this with something a bit more nuanced eg substantiated events, events of a certain seriousness, etc.

Peter Ellis 3 November 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Abuse_events'
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
		'Number of child, youth and family abuse events',
		'Good',
		'CYF',
		'count',
		'person-period',
		'Simple count of all recorded abuse events.  No attempt has been made at this stage to remove duplicates,
		 limit to particular types of abuse or any other filtering.',
		 'How much has this person been abused each time period?',
		'IDI_Clean.cyf_abuse_event',
		'number of events',
		(SELECT MIN(cyf_abe_event_from_date_wid_date) FROM IDI_Clean.cyf_clean.cyf_abuse_event),
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
		 ('One', @var_code, 1), 
		 ('Two to five', @var_code, 2),
		 ('Six or more', @var_code, 3)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value 
	WHERE fk_variable_code = @var_code


----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code	AS fk_variable_code,
	occurences	AS value,
	value_code	AS fk_value_code
FROM
	(SELECT 
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		occurences,
		CASE
			WHEN occurences = 1							THEN 'One'
			WHEN occurences > 1 AND occurences <= 5		THEN 'Two to five'	
			WHEN occurences > 5							THEN 'Six or more'	
		END AS cyf_cat
	
	FROM
		(SELECT
			c.snz_uid  AS fk_snz_uid,
			COUNT(1) AS occurences,
			ye_dec_date
		FROM IDI_Clean.cyf_clean.cyf_abuse_event AS c
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date	AS d1
			ON c.cyf_abe_event_from_date_wid_date = d1.date_dt
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON p.snz_uid = c.snz_uid
		GROUP BY d1.ye_dec_date, c.snz_uid) AS orig )			AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
	ON with_cats.cyf_cat = vc.value_category;


