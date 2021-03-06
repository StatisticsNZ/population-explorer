/*
This program calculates days in employment per snz_uid per year-month.

Strategy is:
- create a table (IDI_Sandpit.intermediate.monthly_was_income) with employment income (wages and salary, self employment, income from investments) 
per year-month per snz_uid
	NOTE: self-employed and investment income that is recorded annually is divided equally across the months in that tax year.
- create temp table of minimum wages per year-month (minimum wages taken from https://www.employment.govt.nz/hours-and-wages/pay/minimum-wage/previous-rates/ from 1997, and http://www.nzlii.org/nz/legis/num_reg/ pre-1997)
- calculate days in employment per year-month (IDI_Sandpit.intermediate.days_in_employment) using income earned and min wage table. 
	days in employment = income / daily min wage (to a maximum of the number of days in the month)

* I have used the starting out/new entrant/youth rate for all to begin with.


Employment types
--------------------

W&S = Wages and salary as an employee of a company

Company director/partner/sole trader (self-employment) income that is recorded monthly
----------------------------------------------------------------------------------------
C01 = Company director/shareholder receiving PAYE deducted income
C02 = Company director/shareholder receiving WHT deducted income
P01 = Partner receiving PAYE deducted income
P02 = Partner receiving WHT deducted income
S01 = Sole Trader receiving PAYE deducted income
S02 = Sole Trader receiving WHT deducted income

Self-employment and investment income that is recorded annually
-------------------------------------------------------------------
P00 = Partnership income from the IR20
C00 = Director/shareholder income from the IR4S
S00 = Sole Trader income from the IR3
S03 = Rental income from the IR3



---------------------------------------------------

Miriam Tankersley 8/11/2017
====================================

*/


-- Get monthly employment income (W&S, C01, C02, P01, P02, S01, S02)

IF OBJECT_ID('tempdb..#employment_income1') IS NOT NULL
	DROP TABLE #employment_income1

SELECT  snz_uid,
		DATEFROMPARTS(year_nbr,month_nbr,1) AS month_start_date,
		EOMONTH(DATEFROMPARTS(year_nbr,month_nbr,1)) AS month_end_date,
		SUM(income) AS income
INTO #employment_income1
FROM (
	SELECT
		   inc_cal_yr_year_nbr AS year_nbr
		  ,inc.snz_uid
		  ,inc_cal_yr_mth_01_amt AS '1'
		  ,inc_cal_yr_mth_02_amt AS '2'
		  ,inc_cal_yr_mth_03_amt AS '3'
		  ,inc_cal_yr_mth_04_amt AS '4'
		  ,inc_cal_yr_mth_05_amt AS '5'
		  ,inc_cal_yr_mth_06_amt AS '6'
		  ,inc_cal_yr_mth_07_amt AS '7'
		  ,inc_cal_yr_mth_08_amt AS '8'
		  ,inc_cal_yr_mth_09_amt AS '9'
		  ,inc_cal_yr_mth_10_amt AS '10'
		  ,inc_cal_yr_mth_11_amt AS '11'
		  ,inc_cal_yr_mth_12_amt AS '12'
	FROM IDI_Clean.data.income_cal_yr AS inc
	INNER JOIN IDI_Clean.data.personal_detail AS pd
			ON inc.snz_uid = pd.snz_uid
	WHERE inc_cal_yr_income_source_code = 'W&S'
		   OR inc_cal_yr_income_source_code = 'C01'
		   OR inc_cal_yr_income_source_code = 'C02'
		   OR inc_cal_yr_income_source_code = 'P01'
		   OR inc_cal_yr_income_source_code = 'P02'
		   OR inc_cal_yr_income_source_code = 'S01'
		   OR inc_cal_yr_income_source_code = 'S02' 
		   AND snz_spine_ind = 1
		) AS pvt
UNPIVOT
	(income FOR month_nbr IN
		([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])
	) AS unpvt
GROUP BY snz_uid, year_nbr, month_nbr
HAVING SUM(income) > 0 -- remove zero income rows
ORDER BY snz_uid, year_nbr


--  Get annual (non-monthly) employment income (P00,C00,S00,S03), divide by 12 to convert to monthly average and allocate to appropriate months

IF OBJECT_ID('tempdb..#employment_income2') IS NOT NULL
	DROP TABLE #employment_income2

SELECT  i.snz_uid,
		month_start_date,
		month_end_date,  
		SUM (inc_tax_yr_sum_C00_tot_amt + inc_tax_yr_sum_P00_tot_amt + inc_tax_yr_sum_S00_tot_amt + inc_tax_yr_sum_S03_tot_amt) / 12 AS income
INTO #employment_income2
FROM IDI_Clean.data.income_tax_yr_summary AS i
	INNER JOIN IDI_Clean.data.personal_detail AS pd
		ON i.snz_uid = pd.snz_uid
	INNER JOIN (
		SELECT ye_mar_nbr,
				month_start_date,
				month_end_date
		FROM IDI_Sandpit.pop_exp_dev.dim_date
		GROUP BY ye_mar_nbr, month_start_date, month_end_date
				) AS d
	ON i.inc_tax_yr_sum_year_nbr = d.ye_mar_nbr
WHERE pd.snz_spine_ind = 1 AND
	  (inc_tax_yr_sum_C00_tot_amt + inc_tax_yr_sum_P00_tot_amt + inc_tax_yr_sum_S00_tot_amt + inc_tax_yr_sum_S03_tot_amt) > 0 -- remove zero income rows
GROUP BY i.snz_uid, month_start_date, month_end_date


-- Combine the two tables to get total employment income per month

IF OBJECT_ID('IDI_Sandpit.intermediate.monthly_empl_income') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.monthly_empl_income

SELECT snz_uid,
	   month_start_date,
	   month_end_date,
	   SUM(income) AS income
INTO IDI_Sandpit.intermediate.monthly_empl_income
FROM (
		SELECT *
		FROM #employment_income1
	 UNION ALL 
		SELECT *
		FROM #employment_income2
	 ) AS combined
GROUP BY snz_uid, month_start_date, month_end_date


-- Get min wage table

IF OBJECT_ID('tempdb..#minwage') IS NOT NULL
	DROP TABLE #minwage

CREATE TABLE #minwage (date_start DATE NOT NULL,
					date_end DATE NOT NULL,
					adult NUMERIC(12,2),
					youth NUMERIC(12,2),
					training NUMERIC(12,2))

INSERT INTO #minwage (date_start, date_end, adult, youth, training) -- *youth = starting out, new entrant or youth
VALUES 
('2017-04-01',GETDATE(),15.75,12.6,12.6),
('2016-04-01','2017-03-31',15.25,12.2,12.2),
('2015-04-01','2016-03-31',14.75,11.8,11.8),
('2014-04-01','2015-03-31',14.25,11.4,11.4),
('2013-04-01','2014-03-31',13.75,11,11),
('2012-04-01','2013-03-31',13.5,10.8,10.8),
('2011-04-01','2012-03-31',13,10.4,10.4),
('2010-04-01','2011-03-31',12.75,10.2,10.2),
('2009-04-01','2010-03-31',12.5,10,10),
('2008-04-01','2009-03-31',12,9.6,9.6),
('2007-04-01','2008-03-31',11.25,9,9),
('2006-03-27','2007-03-31',10.25,8.2,8.2),
('2005-03-21','2006-03-26',9.5,7.6,7.6),
('2004-04-01','2005-03-20',9,7.2,7.2),
('2003-03-24','2004-03-31',8.5,6.8,6.8),
('2002-03-18','2003-03-23',8,6.4,NULL),
('2001-03-05','2002-03-17',7.7,5.4,NULL),
('2000-03-06','2001-03-04',7.55,4.55,NULL),
('1997-03-01','2000-03-05',7,4.2,NULL),
('1997-03-01','1997-02-28',7,4.2,NULL),
('1996-03-18','1997-02-28',6.38,3.83,NULL),
('1995-03-22','1996-03-17',6.25,3.75,NULL),
('1994-03-31','1995-03-21',6.13,3.68,NULL),
('1990-09-17','1994-03-30',6.13,3.68,NULL) -- NOTE: Youth rates didn't come into effect until 1994 - I've just copied these back to 1990.

-- Extrapolate to a table of months with average daily minimum wages

IF OBJECT_ID('tempdb..#minwage_daily') IS NOT NULL
DROP TABLE #minwage_daily

SELECT  month_start_date,
		month_end_date,
		DAY(month_end_date) AS days_in_month,
		AVG(adult_daily) AS adult_daily_avg,
		AVG(youth_daily) AS youth_daily_avg,
		AVG(training_daily) AS training_daily_avg
INTO #minwage_daily
FROM (
	SELECT  
		DATEFROMPARTS(YEAR(date_dt),MONTH(date_dt),1) AS month_start_date,
		EOMONTH(date_dt) AS month_end_date,
		adult * 8 AS adult_daily,
		youth * 8 AS youth_daily,
		training * 8 AS training_daily
	FROM IDI_Sandpit.pop_exp_dev.dim_date AS dat
		LEFT JOIN #minwage AS mw
		ON date_dt >= mw.date_start AND date_dt <= mw.date_end
	WHERE year_nbr >= (SELECT MIN(YEAR(month_start_date)) FROM IDI_Sandpit.intermediate.monthly_empl_income)
		AND	year_nbr <= (SELECT MAX(YEAR(month_end_date)) FROM IDI_Sandpit.intermediate.monthly_empl_income)
	) AS mwd
GROUP BY month_start_date, month_end_date


-- Calculate number of days in employment per month from income per month table. 
-- Days in employment = income / daily min wage (to max number of days in month)

IF OBJECT_ID('IDI_Sandpit.intermediate.days_in_employment') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.days_in_employment

SELECT  snz_uid,
		mwd.month_end_date,
		IIF(FLOOR(income/youth_daily_avg) < days_in_month, FLOOR(income/youth_daily_avg), days_in_month) AS days_in_employment
INTO IDI_Sandpit.intermediate.days_in_employment
FROM IDI_Sandpit.intermediate.monthly_empl_income AS inc
	 LEFT JOIN #minwage_daily AS mwd
	 ON inc.month_start_date = mwd.month_start_date
GO

-- days_in_employment defaults to numeric(38,0) - no decimal points - might as well turn it into an INT
-- to save space and allow a columnstore index to be added

ALTER TABLE IDI_Sandpit.intermediate.days_in_employment ALTER COLUMN month_end_date DATE NOT NULL;
ALTER TABLE IDI_Sandpit.intermediate.days_in_employment ALTER COLUMN days_in_employment INT NOT NULL;
GO

-- This next line doesn't work because there are some duplicates.  Is this possible, or does it indicate a problem?
ALTER TABLE IDI_Sandpit.intermediate.days_in_employment ADD PRIMARY KEY(snz_uid, month_end_date);
EXECUTE IDI_Sandpit.lib.add_cs_ind 'intermediate', 'days_in_employment';



