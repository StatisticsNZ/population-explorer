/*
This program calculates days in education per snz_uid per year-month.

Strategy is:
- create a table with snz_uid, startdate, enddate, group_var (all same) of all education spells (education includes primary and secondary school, tertiary, industry training and targeted training placements)
- use remove_spell_overlaps table-valued-function on above table to remove overlaps (update: function too slow, have just written in script)
- aggregate up the results by snz_uid and year-month and return number of days in education per year-month

33 mins to run

Miriam Tankersley 8/11/2017
====================================

To check: 

* student_enrolment (primary/secondary enrolments) where enddate = NULL, have used moe_esi_extrtn_date as proxy date ie. are still enrolled.
* spell startdate > enddate (c. 11,000 of them, almost all tertiary enrolments). I have just removed these for now - think they are just withdrawls before course start.

*/

IF OBJECT_ID('tempdb..#edu_spells_raw') IS NOT NULL 
	DROP TABLE #edu_spells_raw

SELECT 
	a.snz_uid,
	startdate, 
    enddate,
	group_var
INTO #edu_spells_raw
FROM
	(
		-- Primary and secondary school enrolments
	SELECT 
		snz_uid,
		moe_esi_start_date AS startdate, 
		COALESCE(moe_esi_end_date, moe_esi_extrtn_date) AS enddate,
		1 AS group_var
	FROM IDI_Clean.moe_clean.student_enrol

	UNION ALL

		-- Tertiary enrolments
	SELECT 
		snz_uid,
		moe_crs_start_date AS startdate, 
		COALESCE(moe_crs_withdrawal_date, moe_crs_end_date) AS enddate,
		2 AS group_var
	FROM IDI_Clean.moe_clean.course

	UNION ALL

		-- Industry Training placements
	SELECT 
		snz_uid,
		moe_itl_start_date AS startdate,
		COALESCE(moe_itl_end_date, DATEFROMPARTS(moe_itl_year_nbr,12,31)) AS enddate, -- moe_itl_end_date = NULL implies no exit date for that year, so in this case, enddate = end of year
		3 AS group_var
	FROM IDI_Clean.moe_clean.tec_it_learner

		UNION ALL

		-- Targeted Training placements
	SELECT 
		snz_uid,
		moe_ttr_placement_start_date AS startdate,
		moe_ttr_placement_end_date AS enddate,
		4 AS group_var
	FROM IDI_Clean.moe_clean.targeted_training
	) AS a

LEFT JOIN IDI_Clean.data.personal_detail AS b
ON a.snz_uid = b.snz_uid
WHERE snz_spine_ind = 1


IF OBJECT_ID('tempdb..#edu_spells_nulls') IS NOT NULL
	DROP TABLE #edu_spells_nulls

-- move anything with null values into a temp table for checking
SELECT *
INTO #edu_spells_nulls
FROM #edu_spells_raw
WHERE snz_uid IS NULL OR startdate IS NULL OR enddate IS NULL OR group_var IS NULL

DELETE FROM #edu_spells_raw
WHERE snz_uid IS NULL OR startdate IS NULL OR enddate IS NULL OR group_var IS NULL

/*
checks for when in interactive development mode:
	-- check the nulls are gone!
	SELECT TOP 100 *
	FROM #edu_spells_raw
	WHERE snz_uid IS NULL OR startdate IS NULL OR enddate IS NULL OR group_var IS NULL

	-- check if any spells with enddate < startdate
	SELECT group_var, COUNT(*) AS count_oddspells
	FROM #edu_spells_raw
	WHERE startdate > enddate
	GROUP BY group_var
*/

-- remove spells with enddate < startdate
DELETE FROM #edu_spells_raw
WHERE startdate > enddate

-- set all group_var to 1 (we don't need to seperate these out when we remove overlapping spells)
UPDATE #edu_spells_raw
SET group_var = 1


---- Use function remove_spell_overlaps to remove overlapping spells
--USE IDI_Sandpit

--DECLARE @eduspells AS lib.overlapping_spells_table
--INSERT INTO @eduspells
--SELECT snz_uid, startdate, enddate, group_var FROM #edu_spells_raw

--SELECT * 
--INTO IDI_Sandpit.intermediate.spells_education 
--FROM lib.remove_spell_overlaps(@eduspells)


-- Function too slow - do without function
--=======================================================================


/**** Remove spell overlaps (within the same snz_uid and group_var) ****
********************************************************************************************/ 

-- Delete duplicates (same snz_uid, startdate, enddate, group_var) NOTE: Only the first row is retained

IF OBJECT_ID('tempdb..#edu_spells1') IS NOT NULL
       DROP TABLE #edu_spells1
GO

USE IDI_Sandpit

SELECT *
INTO #edu_spells1
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY snz_uid, startdate, enddate, group_var ORDER BY snz_uid, startdate, enddate, group_var) AS row_num
              FROM #edu_spells_raw) AS t1

DELETE FROM #edu_spells1
WHERE row_num > 1


-- Remove spells where startdate > last start date and end date <= last end date (complete overlap)

IF OBJECT_ID('tempdb..#edu_spells2') IS NOT NULL
       DROP TABLE #edu_spells2
GO

SELECT t1.*
INTO #edu_spells2
FROM #edu_spells1 AS t1
WHERE NOT EXISTS (SELECT *
                  FROM #edu_spells1 AS t2
                  WHERE  (t1.startdate > t2.startdate AND t1.enddate <= t2.enddate AND t1.snz_uid = t2.snz_uid AND t1.group_var = t2.group_var
                          AND (startdate <> t2.startdate OR t1.enddate <> t2.startdate)))

-- Where spells have a with partial overlap, change startdate to enddate of overlap spell + 1 day

IF OBJECT_ID('tempdb..#edu_spells_or') IS NOT NULL
       DROP TABLE #edu_spells_or
GO

SELECT *
INTO #edu_spells_or
FROM (SELECT *
			,LAG(startdate,1,NULL) OVER(PARTITION BY snz_uid, group_var ORDER BY snz_uid, startdate, enddate) AS laststart
			,LAG(enddate,1,NULL) OVER(PARTITION BY snz_uid, group_var ORDER BY snz_uid, startdate, enddate) AS lastend
      FROM #edu_spells2) AS t1
ORDER BY snz_uid

UPDATE #edu_spells_or
SET startdate = DATEADD(DAY,1,lastend)
WHERE startdate <= lastend

-- Drop unused columns

ALTER TABLE #edu_spells_or
DROP COLUMN  row_num, laststart, lastend

-- Insert into permanent table

IF OBJECT_ID('IDI_Sandpit.intermediate.spells_education') IS NOT NULL 
	DROP TABLE IDI_Sandpit.intermediate.spells_education

SELECT *
INTO IDI_Sandpit.intermediate.spells_education
FROM #edu_spells_or
GO

ALTER TABLE IDI_Sandpit.intermediate.spells_education ALTER COLUMN startdate DATE NOT NULL;
GO 
ALTER TABLE IDI_Sandpit.intermediate.spells_education ADD PRIMARY KEY (snz_uid, startdate);

/****  Sum days per year-month  ****
*************************************/

-- Create reference temp table #yearmonths with years and months by start date and end date

IF OBJECT_ID('tempdb..#yearmonths') IS NOT NULL
    DROP TABLE #yearmonths

SELECT  
	year_nbr AS year,
	month_nbr AS month,
	MIN(CASE WHEN day_of_month = 1 THEN date_dt END) AS month_start,
	MIN(CASE WHEN end_mth = 'Last day of month' THEN date_dt END) AS month_end
INTO #yearmonths
FROM IDI_Sandpit.pop_exp_dev.dim_date
WHERE year_nbr >= (SELECT MIN(YEAR(startdate)) FROM IDI_Sandpit.intermediate.spells_education) AND
		year_nbr <= (SELECT MAX(YEAR(enddate)) FROM IDI_Sandpit.intermediate.spells_education) AND
		date_dt <= GETDATE() -- otherwise some people are assumed to be in education forever...
GROUP BY year_nbr, month_nbr
ORDER BY year, month



-- Use yearmonth reference table to aggregate by yearmonth

IF OBJECT_ID('IDI_Sandpit.intermediate.days_in_education') IS NOT NULL
       DROP TABLE IDI_Sandpit.intermediate.days_in_education
GO

SELECT snz_uid
	   ,month_end AS month_end_date
       ,SUM(edu_days) AS days_in_education
INTO  IDI_Sandpit.intermediate.days_in_education
FROM (
       SELECT a.snz_uid
			  ,ym.month_end
              ,CASE	WHEN startdate >= month_start AND enddate <= month_end THEN DATEDIFF(DAY, startdate, enddate) + 1  -- spell all within one month
					WHEN startdate >= month_start AND enddate > month_end THEN DATEDIFF(DAY, startdate, month_end) + 1 -- starting month of spell that spans more than one month
					WHEN startdate < month_start AND enddate <= month_end THEN DATEDIFF(DAY, month_start, enddate) + 1 -- ending month of spell that spans more than one month
					WHEN startdate < month_start AND enddate > month_end THEN DATEDIFF(DAY, month_start, month_end) + 1 -- spell spans the entire month
					ELSE 0
               END	AS edu_days
        FROM IDI_Sandpit.intermediate.spells_education AS a INNER JOIN #yearmonths AS ym
              ON	(startdate >= month_start AND startdate <= month_end) -- start month of spell
				 OR (enddate >= month_start AND enddate <= month_end) -- end month of spell
				 OR (startdate < month_start AND enddate > month_end) -- all the months in middle of spell
       ) AS t1
GROUP BY snz_uid, month_end
ORDER BY snz_uid, month_end
GO

-- need to batch up the NOT NULL alter (including with GO) so it registers before we make it part of the primary key
ALTER TABLE IDI_Sandpit.intermediate.days_in_education ALTER COLUMN month_end_date DATE NOT NULL;
GO 


ALTER TABLE IDI_Sandpit.intermediate.days_in_education ADD PRIMARY KEY (snz_uid, month_end_date);
EXECUTE IDI_Sandpit.lib.add_cs_ind 'intermediate', 'days_in_education';