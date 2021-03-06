/*
This program creates an activity status per person, per month, for the purpose of calculating NEET spells.

Strategy is:
1. Create a table with every person on spine, with one row for every month of life, during the period all data is available (currently 2003-2016).

2. Populate above table with days per month engaged in the following activities: education (includes training), employment, overseas.
NOTE: "in custody" will be considered as an activity if relevant at a later stage.

3. Using the following heirarchy, determine what main activity each individual was engaged in per month.
	1. If overseas for 15 or more days in month, then "Overseas"
	2. If in education for 15 or more days in month, then "In education"
	3. If in employment for 15 or more days in month then "In employment"
	4. If none of the above, then "NEET"

------------------------------------------------------------
Things to consider:
 - People in custody, using data from corrections
 - Combined activities in any one month. eg. 14 days overseas, and 14 days in education will show up as NEET in that month, but realistically is probably not NEET. 
 Should we add another activity called 'mixed activity' = 15 days or more in any of overseas, education or employment??

Miriam Tankersley 27/11/2017
====================================
*/


-- 1. Create a table with every person on spine, with one row for every month of life, during the period all data is available (currently 2003-2016).

-- Create table of earliest and latest dates for data for each data source in NEET.

IF OBJECT_ID('tempdb..#data_dates') IS NOT NULL
DROP TABLE #data_dates;
GO

USE IDI_Clean

SELECT *
INTO #data_dates
FROM
	(
		SELECT  'MOE' AS ds_schema
				,'Tertiary enrolments' AS ds_name
				,MIN(moe_enr_year_nbr) AS min_year
				,MAX(moe_enr_year_nbr) AS max_year
		FROM moe_clean.enrolment
	UNION ALL
		SELECT  'MOE' AS ds_schema
				,'Industry training' AS ds_name
				,MIN(moe_itl_year_nbr) AS min_year
				,MAX(moe_itl_year_nbr) AS max_year
		FROM moe_clean.tec_it_learner
	UNION ALL
		SELECT  'MOE' AS ds_schema
				,'School enrolments' AS ds_name
				,MIN(DATEPART(YEAR,moe_esi_start_date)) AS min_year
				,MAX(DATEPART(YEAR,moe_esi_start_date)) AS max_year
		FROM  moe_clean.student_enrol
	UNION ALL		
		SELECT	'MOE' AS ds_schema
				,'Targeted training' AS ds_name
				,MIN(moe_ttr_year_nbr) AS min_year
				,MAX(moe_ttr_year_nbr) AS max_year
		FROM moe_clean.targeted_training
	UNION ALL
		SELECT  'Data IR' AS ds_schema
				,'Income calendar year' AS ds_name
				,MIN(inc_cal_yr_year_nbr) AS min_year
				,MAX(inc_cal_yr_year_nbr) AS max_year
		FROM data.income_cal_yr
	UNION ALL
		SELECT  'Data IR' AS ds_schema
				,'Income tax year summary' AS ds_name
				,MIN(inc_tax_yr_sum_year_nbr) AS min_year
				,MAX(inc_tax_yr_sum_year_nbr) AS max_year
		FROM data.income_tax_yr_summary
	UNION ALL
		SELECT  'DOL' AS ds_schema
				,'Border movements' AS ds_name
				,MIN(DATEPART(YEAR,dol_mov_carrier_date)) AS min_year
				,MAX(DATEPART(YEAR,dol_mov_carrier_date)) AS max_year
		FROM dol_clean.movements
	) AS dates

GO

/*  Using intermediate.spells-in-nz table, create table of everyone on spine with every month beginning the latest of:
		- the earliest month we have data for all of immigration, education and employment
		- birth
		- first arrival in NZ
	and month ending the earliest of:
		- the latest month we have data for all of immigration, education and employment
		- the current date
		- death
*/


IF OBJECT_ID('tempdb..#spine_months') IS NOT NULL
DROP TABLE #spine_months
GO

SELECT  snz_uid,
		month_end_date
INTO #spine_months
FROM 
   (SELECT  snz_uid,
			EOMONTH(date_dt) AS month_end_date
	FROM IDI_Sandpit.pop_exp_dev.dim_date AS dat
		LEFT JOIN 
		( SELECT snz_uid,
				 MIN(start_date) AS date_start,
				 CASE WHEN MAX(end_type) = 2 THEN MAX(end_date) -- end_type = 2 is deceased
					  ELSE GETDATE() -- end_type = 1 is still overseas, 3 is still in NZ
				 END AS date_end
		  FROM IDI_Sandpit.intermediate.spells_in_nz
		  GROUP BY snz_uid
		) AS ss
	   ON date_dt >= ss.date_start AND date_dt <= ss.date_end
	WHERE year_nbr >= (SELECT MAX(min_year) FROM #data_dates) AND year_nbr <= (SELECT MIN(max_year) FROM #data_dates) -- restrict to data dates only
   ) AS sd
GROUP BY snz_uid, month_end_date

-- 2. Populate above table with days per month engaged in the following activities: education (includes training), employment, overseas.

IF OBJECT_ID('IDI_Sandpit.intermediate.days_by_activity') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.days_by_activity
GO

SELECT  sp.snz_uid 
		,sp.month_end_date
		,DAY(EOMONTH(sp.month_end_date)) - COALESCE(days_in_nz,0) AS days_overseas
		,COALESCE(days_in_education, 0) AS days_in_education
		,COALESCE(days_in_employment, 0) AS days_in_employment
INTO IDI_Sandpit.intermediate.days_by_activity
FROM #spine_months AS sp
	LEFT JOIN IDI_Sandpit.intermediate.days_in_nz AS nz
		ON sp.snz_uid = nz.snz_uid AND sp.month_end_date = nz.month_end_date
	LEFT JOIN IDI_Sandpit.intermediate.days_in_education AS edu
		ON sp.snz_uid = edu.snz_uid AND sp.month_end_date = edu.month_end_date
	LEFT JOIN IDI_Sandpit.intermediate.days_in_employment AS emp
		ON sp.snz_uid = emp.snz_uid AND sp.month_end_date = emp.month_end_date
GO

/* 3. Using the following hierarchy, determine what main activity each individual was engaged in per month.
	1. If overseas for 15 or more days in month, then "Overseas"
	2. If in education for 15 or more days in month, then "In education"
	3. If in employment for 15 or more days in month then "In employment"
	4. If none of the above, then "NEET"
*/

IF OBJECT_ID('IDI_Sandpit.intermediate.monthly_activity') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.monthly_activity

SELECT snz_uid,
		month_end_date,
		CASE WHEN days_overseas >= 15 THEN 'overseas'
			 WHEN days_in_education >= 15 THEN 'education'
			 WHEN days_in_employment >= 15 THEN 'employment'
			 ELSE 'neet'
		END AS activity
INTO IDI_Sandpit.intermediate.monthly_activity
FROM IDI_Sandpit.intermediate.days_by_activity
GO

-- need to batch up the NOT NULL alter (including with GO) so it registers before we make it part of the primary key
ALTER TABLE IDI_Sandpit.intermediate.days_by_activity ALTER COLUMN month_end_date DATE NOT NULL
ALTER TABLE IDI_Sandpit.intermediate.monthly_activity ALTER COLUMN month_end_date DATE NOT NULL
ALTER TABLE IDI_Sandpit.intermediate.days_by_activity ALTER COLUMN snz_uid INT NOT NULL;
ALTER TABLE IDI_Sandpit.intermediate.monthly_activity ALTER COLUMN snz_uid INT NOT NULL;
GO 

-- If these don't work it is because there are some duplicates ie people with more than one entry for person-month:
ALTER TABLE IDI_Sandpit.intermediate.days_by_activity ADD PRIMARY KEY (snz_uid, month_end_date);
EXECUTE IDI_Sandpit.lib.add_cs_ind 'intermediate', 'days_by_activity'

ALTER TABLE IDI_Sandpit.intermediate.monthly_activity ADD PRIMARY KEY (snz_uid, month_end_date);
EXECUTE IDI_Sandpit.lib.add_cs_ind 'intermediate', 'monthly_activity'
GO