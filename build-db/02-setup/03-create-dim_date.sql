
/*
Stored procedure to create a dimension table holding date information

This is rather narrower than most date dimension tables

Peter Ellis, Miriam Tankersley September-October 2017

--------------------------------------------------------------------------

UPDATE 11/12/17 - Fixed month_end_date and end_mth to account for 29 Feb in leap years.

*/

use IDI_Sandpit;
GO



IF (object_id('pop_exp_dev.create_dim_date')) IS NOT NULL
	DROP PROCEDURE pop_exp_dev.create_dim_date;
GO

CREATE PROCEDURE pop_exp_dev.create_dim_date 
AS
BEGIN
	SET NOCOUNT ON

	CREATE TABLE IDI_Sandpit.pop_exp_dev.dim_date (
		date_dt DATE PRIMARY KEY,
		day_of_month TINYINT NOT NULL,
		month_nbr TINYINT NOT NULL,
		year_nbr SMALLINT NOT NULL,
		ye_mar_nbr SMALLINT NOT NULL,
		ye_jun_nbr SMALLINT NOT NULL,
		ye_sep_nbr SMALLINT NOT NULL,
		ye_dec_nbr SMALLINT NOT NULL,
		ye_mar_date DATE NOT NULL,
		ye_jun_date DATE NOT NULL,
		ye_sep_date DATE NOT NULL,
		ye_dec_date DATE NOT NULL,
		month_start_date DATE NOT NULL,
		month_end_date DATE NOT NULL,
		end_qtr VARCHAR(23),
		end_mth VARCHAR(23),
		qtr_nbr TINYINT,
		qtr_start_date DATE,
		qtr_mid_date DATE,
		qtr_end_date DATE,
		nz_holiday VARCHAR(23)
		);

	-- empty skeleton of the first four columns and set up as @tmp
	DECLARE @tmp TABLE
	(
		date_dt DATE,
		day_of_month TINYINT,
		month_nbr TINYINT,
		year_nbr SMALLINT
	)

		
	DECLARE @StartDate DATETIME = '01/01/1900';
	DECLARE @EndDate DATETIME = '01/01/2100';
	DECLARE @CurrentDate  AS DATETIME = @StartDate;

	
	-- make the first FOUR columns and store them in @tmp
	WHILE @CurrentDate < @EndDate
	BEGIN
		INSERT INTO @tmp
			(date_dt, day_of_month, month_nbr, year_nbr)
			VALUES(@CurrentDate, DAY(@CurrentDate), month(@CurrentDate), year(@CurrentDate));

		SET @CurrentDate = DATEADD(DD, 1, @CurrentDate)
	END;
	
	INSERT IDI_Sandpit.pop_exp_dev.dim_date(date_dt, day_of_month, month_nbr, year_nbr, 
											ye_mar_nbr, ye_jun_nbr, ye_sep_nbr, ye_dec_nbr, 
											ye_mar_date, ye_jun_date, ye_sep_date, ye_dec_date, month_start_date,
											month_end_date, end_qtr, end_mth, qtr_nbr, qtr_start_date, qtr_mid_date, qtr_end_date)
	SELECT
			date_dt, 
			day_of_month, 
			month_nbr, 
			year_nbr,
			ye_mar_nbr,
			ye_jun_nbr,
			ye_sep_nbr,
			ye_dec_nbr,
			DATEFROMPARTS(ye_mar_nbr,3,31)			AS ye_mar_date,
			DATEFROMPARTS(ye_jun_nbr,6,30)			AS ye_jun_date,
			DATEFROMPARTS(ye_sep_nbr,9,30)			AS ye_sep_date,		
			DATEFROMPARTS(ye_dec_nbr,12,31)			AS ye_dec_date,
			DATEFROMPARTS(ye_dec_nbr, month_nbr, 1) AS month_start_date,
			EOMONTH(date_dt) AS month_end_date,
			end_qtr,
			end_mth,
			CASE
				WHEN month_nbr IN (1,2,3) THEN 1
				WHEN month_nbr IN (4,5,6) THEN 2
				WHEN month_nbr IN (7,8,9) THEN 3
				WHEN month_nbr IN (10,11,12) THEN 4
			END AS qtr_nbr,
			CASE
				WHEN month_nbr IN (1,2,3) THEN DATEFROMPARTS(ye_dec_nbr, 1, 1)
				WHEN month_nbr IN (4,5,6) THEN DATEFROMPARTS(ye_dec_nbr, 4, 1)
				WHEN month_nbr IN (7,8,9) THEN DATEFROMPARTS(ye_dec_nbr, 7, 1)
				WHEN month_nbr IN (10,11,12) THEN DATEFROMPARTS(ye_dec_nbr, 10, 1)
			END  AS qtr_start_date,
			CASE
				WHEN month_nbr IN (1,2,3) THEN DATEFROMPARTS(ye_dec_nbr, 2, 14)
				WHEN month_nbr IN (4,5,6) THEN DATEFROMPARTS(ye_dec_nbr, 5, 15)
				WHEN month_nbr IN (7,8,9) THEN DATEFROMPARTS(ye_dec_nbr, 8, 15)
				WHEN month_nbr IN (10,11,12) THEN DATEFROMPARTS(ye_dec_nbr, 11, 15)
			END  AS qtr_mid_date,
			CASE
				WHEN month_nbr IN (1,2,3) THEN DATEFROMPARTS(ye_dec_nbr,3,31)
				WHEN month_nbr IN (4,5,6) THEN DATEFROMPARTS(ye_dec_nbr,6,30)
				WHEN month_nbr IN (7,8,9) THEN DATEFROMPARTS(ye_dec_nbr,9,30)
				WHEN month_nbr IN (10,11,12) THEN DATEFROMPARTS(ye_dec_nbr,12,31)
			END  AS qtr_end_date
	FROM (
		SELECT
			date_dt, day_of_month, month_nbr, year_nbr,
			CASE WHEN month_nbr < 4 THEN year_nbr
				WHEN month_nbr >= 4 THEN year_nbr + 1
			END AS	ye_mar_nbr,
			CASE WHEN month_nbr < 7 THEN year_nbr
				WHEN month_nbr >= 7 THEN year_nbr + 1
			END AS	ye_jun_nbr,
			CASE WHEN month_nbr < 10 THEN year_nbr
				WHEN month_nbr >= 10 THEN year_nbr + 1
			END AS	ye_sep_nbr,
			year_nbr AS	ye_dec_nbr,
			CASE WHEN (month_nbr = 3 AND day_of_month = 31) OR
						(month_nbr = 6 AND day_of_month = 30) OR
						(month_nbr = 9 AND day_of_month = 30) OR
						(month_nbr = 12 AND day_of_month = 31) 
						THEN 'Last day of quarter'
					ELSE 'Not last day of quarter'
			END AS end_qtr,
			CASE WHEN date_dt = EOMONTH(date_dt) THEN 'Last day of month'
				 ELSE 'Not last day of month'
			END AS end_mth
		FROM @tmp) AS a;

	CREATE NONCLUSTERED INDEX nc_day ON IDI_Sandpit.pop_exp_dev.dim_date(day_of_month);
	CREATE NONCLUSTERED INDEX nc_month ON IDI_Sandpit.pop_exp_dev.dim_date(month_nbr);
	CREATE NONCLUSTERED INDEX nc_year ON IDI_Sandpit.pop_exp_dev.dim_date(year_nbr);
	CREATE NONCLUSTERED INDEX nc_end_qtr ON IDI_Sandpit.pop_exp_dev.dim_date(end_qtr);
	CREATE NONCLUSTERED INDEX nc_end_mth ON IDI_Sandpit.pop_exp_dev.dim_date(end_mth);

END
GO



IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_date', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_date;

GO

EXECUTE IDI_Sandpit.pop_exp_dev.create_dim_date;

-- columnstore index:
EXECUTE lib.add_cs_ind 'pop_exp_dev', 'dim_date'
