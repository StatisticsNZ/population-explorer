/*
Identify which meshblock people lived in on the 15th day of each month.  This can then be used
to roll up to pick the TA or Region they lived in most in any month, quarter or year.

Peter Ellis 13 October 2017

Timings:

100,000 people 5 seconds
1 million people 3 minutes
2 million people 12 minutes 50
3 million people 13:13

So expecting 2+ hours

1 hour 40 minutes running the whole thing in down time.

*/

-- clear the decks:
IF OBJECT_ID('TempDB..#selected_days') IS NOT NULL
	DROP TABLE #selected_days;
IF OBJECT_ID('IDI_Sandpit.intermediate.address_mid_month', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.address_mid_month;
GO

-- First, we want the dates of 12 days per year which we will sample where people are living at those times
SELECT date_dt, ye_mar_nbr 
INTO #selected_days
FROM IDI_Sandpit.pop_exp_dev.dim_date
WHERE day_of_month = 15 AND
year_nbr >= 1990 AND
year_nbr < 2018; 

/*
Strategy for this next bit is to:
* identify people on the spine
* cross join with the 12 dates per year so we have about 1.5 billion (spine * 12 * 12 years) rows of person - date combinations
* cross join that again with the address notifications and then filter down to just those occasions where the #selected_days 
  date is between the beginning and the end of the address notification


*/



SELECT 
	spine.snz_uid,
	ant_meshblock_code,
	date_dt AS mid_month_date
INTO IDI_Sandpit.intermediate.address_mid_month
FROM 
	(SELECT  snz_uid
	FROM IDI_Clean.data.personal_detail
	WHERE snz_spine_ind = 1) as spine

	CROSS JOIN

	#selected_days

	CROSS JOIN

	(SELECT [snz_uid]
    ,[ant_notification_date]
    ,[ant_replacement_date]
    ,[ant_meshblock_code]
    FROM [IDI_Clean].[data].[address_notification]) addresses

	WHERE addresses.snz_uid = spine.snz_uid
	AND addresses.ant_notification_date < #selected_days.date_dt 
	AND #selected_days.date_dt < addresses.ant_replacement_date
	AND ant_meshblock_code IS NOT NULL;
-- it should be impossible for ant_meshblock_code to be NULL if there is an SNZ IDI address id but this is not the case; 
-- has been referred to the IDI team for investigation.
GO

ALTER TABLE IDI_Sandpit.intermediate.address_mid_month ALTER COLUMN mid_month_date DATE NOT NULL;	
ALTER TABLE IDI_Sandpit.intermediate.address_mid_month ADD PRIMARY KEY (snz_uid, mid_month_date);

-- This next index would be nice to have but takes up 30GB I can't spare
-- CREATE NONCLUSTERED INDEX idx1 ON IDI_Sandpit.intermediate.address_mid_month (ant_meshblock_code);

DROP TABLE #selected_days;
GO  

-------------------------------add foreign keys etc--------
-- This is here as an integrity check.  It shouldn't be possible for this table to have any meshblock
-- codes that don't also exist in dim_meshblock, which was made from the same source table.
ALTER TABLE IDI_Sandpit.intermediate.address_mid_month
	ADD CONSTRAINT intermediate_address_fk1 
	FOREIGN KEY (ant_meshblock_code) REFERENCES IDI_Sandpit.intermediate.dim_meshblock(ant_meshblock_code);

