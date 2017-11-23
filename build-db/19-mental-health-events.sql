/*
Add number of mental health occurrences to the fact table and relevant dimensions to the dimension tables.
Counts one offence per mental health incident, per person, per march ye.  

Incidents come from the previously created intermediate.mha_events table, which has mental-health-related
interactions with pharamceuticals, lab tests, hospitals, MSD (reason for incapacity), and PRIMHD

Peter Ellis 3 November 2017 

*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Mental_health'
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
		'Number of mental health and addictions interactions with services',
		'Good',
		'MOH and MSD',
		'count',
		'person-period',
		'Counts each known interaction with a service with evidence that it was related to mental health and addictions,
		 based on a particular list of pharamceuticals, lab tests, hospitals, MSD (reason for incapacity), and PRIMHD.  Note that we are counting
		 very different things here, so the number of interactions should be treated only as indicative. The definition used for each of the five
		 is that published by the Social Investment Agency in mid 2017.  The pharmaceutical list used includes those marked by SIA as "potential inclusion".
		 See https://github.com/nz-social-investment-agency/mha_data_definition for the original definition.  There will be a better way of converting
		 the simple recording of the five types of events into estimates of type or degree of mental health and addictions challenge, suggestions welcomed.',
		 'What is the mental health status of this person each time period?',
		'IDI_Sandpit.intermediate.mha_events, IDI_Clean.moh_clean.primhd, IDI_Clean.moh_clean.pub_fund_hosp_discharges_event, IDI_Clean.moh_clean.pub_fund_hosp_discharges, 
		IDI_Clean.moh_clean.pharmaceutical, IDI_Clean.moh_clean.lab_claims, IDI_Clean.msd_clean.msd_incapacity',
		'number of interactions',
		(SELECT MIN(start_date) FROM IDI_Sandpit.intermediate.mha_events),
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
		 ('Two to ten', @var_code, 2),
		 ('Eleven to 100', @var_code, 3),
		 ('101 or more', @var_code, 4)

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
			WHEN occurences > 1 AND occurences <= 10	THEN 'Two to ten'	
			WHEN occurences > 10 AND occurences <= 100	THEN 'Eleven to 100'	
			WHEN occurences > 100						THEN '101 or more'	
		END AS mha_cat
	
	FROM
		(SELECT
			snz_uid  AS fk_snz_uid,
			COUNT(1) AS occurences,
			ye_dec_date
		FROM IDI_Sandpit.intermediate.mha_events	AS m
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date	AS d1
			ON m.start_date = d1.date_dt
		GROUP BY d1.ye_dec_date, snz_uid) AS orig )			AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
	ON with_cats.mha_cat = vc.value_category;

