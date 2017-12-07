/*
Add number of crime offence occurrences to the fact table and relevant dimensions to the dimension tables.
Counts one offence per criminal incident ("occurence") for which there were court or non-court proceedings, per person, per march ye.

This differs from crime_victims, as it uses pre-count data "occurrences" instead of "offences". "Occurrences" are single incidents and can contain multiple "offences".
The reasoning behind using occurences rather than offences is that the post-count for offenders only counts one offence per day (even if there were multiple offences or occurences). 
We also wouldn't want to count all pre-count offences, as there can be multiple offences associated with one occurence.
Counting occurences seems like a more precise way of counting. In this case, each criminal incident is considered one offence.

Note: uses date offender was proceeded against by Police, not neccessarily the date the incident occurred.

Miriam Tankersley 27 October 2017 


*/

IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 


DECLARE @var_name VARCHAR(15) = 'Offences'
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
		date_built,
		variable_class) 
	VALUES   
		(@var_name,
		'Number of criminal offences',
		'Good',
		'Pol',
		'count',
		'person-period',
		'Counts one offence per criminal incident ("occurence") for which there were court or non-court proceedings, per person, per march ye. 
		This differs from crime_victims, as it uses pre-count data "occurrences" instead of "offences". "Occurrences" are single incidents and can contain multiple "offences".
		The reasoning behind using occurences rather than offences is that the post-count for offenders only counts one offence per day (even if there were multiple offences or occurences). 
		We also would not want to count all pre-count offences, as there can be multiple offences associated with one occurence.
		Counting occurences seems like a more precise way of counting. In this case, each criminal incident is considered one offence.
		Note: uses date offender was proceeded against by Police, not neccessarily the date the incident occurred.',
		'How many crimes did this person commit in a time period?',
		'IDI_Clean.pol_clean.pre_count_offenders',
		'number of offences',
		(SELECT CONVERT(date, GETDATE())),
		'Justice')


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_year
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('One', @var_code, 1), 
		 ('More than one', @var_code, 2)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_year 
	WHERE fk_variable_code = @var_code
	
	-- if interested in our look up table check out:
	-- select * from #value_codes

----------------add facts to the fact table-------------------------
INSERT IDI_Sandpit.pop_exp_dev.fact_rollup_year(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT 
	fk_date_period_ending,
	fk_snz_uid,
	@var_code AS fk_variable_code,
	occurences AS value,
	value_code AS fk_value_code
FROM
	(SELECT 
		ye_dec_date AS fk_date_period_ending,
		fk_snz_uid,
		@var_code AS fk_variable_code,
		occurences,
		CASE WHEN occurences = 1 THEN 'One'
			 ELSE 'More than one'
		END AS off_cat
	FROM 
		(SELECT 
			COUNT(DISTINCT snz_pol_occurrence_uid) AS occurences,
			o.snz_uid AS fk_snz_uid,
			d.ye_dec_date
		FROM IDI_Clean.pol_clean.pre_count_offenders AS o
					-- we only want people in our dimension table:
		INNER JOIN IDI_Sandpit.pop_exp_dev.dim_person AS p
			ON o.snz_uid = p.snz_uid
		LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date d
					-- we want to roll up by ye_march
			ON o.pol_pro_proceeding_date = d.date_dt
		GROUP BY o.snz_uid, d.ye_dec_date
		) AS by_year
	) AS with_cats
-- we want to covert the categories back from categories to codes
LEFT JOIN #value_codes vc
ON with_cats.off_cat = vc.value_category




