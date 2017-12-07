/* 
This script creates a table of ages for every person on the spine from 1990 to 2017.

Timings for creating #births, #deaths and #ages, with limitations on number of people in #births

During dev, if you want to run this on a subset of people it's best to limit them at
the time of creating the #births table.

Timings:
100,000 people 3 minutes (back to 1990)
100,000 people 2:18 minutes (back to 2000)
200,000 people 4:18 (back to 2000)
200,000 people 2:49     (back to 2008)

3 hours 45 minutes to 2000 running in down time.  Expect 8+ hours for back to 1990

TODO - redo as a stored procedure that does one year at a time rather than trying to do it all at once.

Peter Ellis, 13 October 2017
*/

IF OBJECT_ID('IDI_Sandpit.intermediate.age_end_month', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.age_end_month;
 IF OBJECT_ID('TempDB..#births') IS NOT NULL DROP TABLE #births;
IF OBJECT_ID('TempDB..#deaths') IS NOT NULL DROP TABLE #deaths;
GO 



-- make some rough birthdays (everyone born on the 15th of the month) and save in #births table:
-- takes only 7 seconds with the full set of people on the spine, writes 9.4 million rows
SELECT 
	snz_uid,
	DATEFROMPARTS(snz_birth_year_nbr, snz_birth_month_nbr, 15) AS birthday
INTO #births
FROM IDI_Clean.data.personal_detail 
WHERE snz_birth_year_nbr IS NOT NULL AND snz_spine_ind = 1;

-- this is a good reminder that some people go all the way back to 1800!
-- select top 1000 * from #births order by birthday 

-- takes 6 seconds, 2.6million rows.  Note we use the latest death date for the 40 or so people with multiple deaths.
-- No particular reason to use the latest, just need to pick one... SNZ are working on fixing the duplicates at source
SELECT 
	snz_uid,
	MAX(DATEFROMPARTS(dia_dth_death_year_nbr, dia_dth_death_month_nbr, 16)) AS deathday
INTO #deaths
FROM IDI_Clean.dia_clean.deaths
WHERE dia_dth_death_year_nbr IS NOT NULL
GROUP BY snz_uid;

-- the next query which creates #ages is slow to run, so I define a primary key (and hence clustered index)
-- on snz_uid in the hope that it makes things faster to execute.
ALTER TABLE #births ADD PRIMARY KEY (snz_uid);
ALTER TABLE #deaths ADD PRIMARY KEY (snz_uid);

SELECT 
	b.snz_uid,
	--birthday, -- during dev it was useful to look at birthday to check things are working, but don't include in the final table, to save space
	date_dt as month_end_date,
	CAST(ROUND(DATEDIFF(month, birthday, date_dt) / 12, 0) AS INT) AS age	
INTO IDI_Sandpit.intermediate.age_end_month
FROM
	(SELECT date_dt 
	FROM IDI_Sandpit.pop_exp_dev.dim_date 
	-- Restrict the data to just the years 2000 onwards as otherwise it's just too big:
	-- Also, we only want the snapshots for each year ending 31 March:
	WHERE end_mth = 'Last day of month' AND year_nbr >= 1990 AND year_nbr < 2018) dates
CROSS JOIN #births b
LEFT JOIN #deaths d
ON b.snz_uid = d.snz_uid
WHERE (birthday <= date_dt)	AND 
	(deathday >= date_dt OR deathday IS NULL) AND
	-- maximum plausible age is 120:
	DATEDIFF(year, birthday, date_dt) < 121;
GO
	
ALTER TABLE IDI_Sandpit.intermediate.age_end_month  ALTER COLUMN age INT NOT NULL;
--select top 1000 * from IDI_Sandpit.intermediate.age_end_month order by snz_uid, age
GO

ALTER TABLE IDI_Sandpit.intermediate.age_end_month ADD PRIMARY KEY(snz_uid, month_end_date);

