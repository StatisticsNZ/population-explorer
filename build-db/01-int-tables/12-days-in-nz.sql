/*

Aim is to turn the spells_in_nz table into a big fact table representing each person how many days per month 
they were alive in New Zealand.  

As this inolves a full cartesian join of the large spells_in_nz table with aboutt 10,000 days of interest (all days from
1990 onwards), we'll see if the infrastructure can handle this!


A procedure to take peoples' spells in New Zealand and cross join them with a range of possible days, returning a fact table
with four columns, for person, year, month, and number of days in the country.  This table will be big! eg
5 million people for 12 months is 60 million rows for one year's worth, so 20 years is 1.2 billion rows.
So we only execute this only one year's worth at a time, hence the use of a stored procedure with year as a parameter.

The procedure first subsets the spells data to just those spells that finished after the beginning of the year, and began 
before the end of the year; then subsets the dates data to just the days in our year; then cross joins them and filters
down to where the day fits within the spell.

This whole program takes about 10 hours to run.  So take care.

Peter Ellis 12 October 2017
*/

use IDI_Sandpit;

--------------set up and define target table----------------------
IF (object_id('IDI_Sandpit.intermediate.days_in_nz')) IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.days_in_nz;
GO


IF (object_id('intermediate.estimate_days')) IS NOT NULL
	DROP PROCEDURE intermediate.estimate_days;
GO


-------------------------define PROCEDURE that populates table one year at a time-------------
CREATE PROCEDURE intermediate.estimate_days (@yr INT)
AS
BEGIN
	SET NOCOUNT ON

	IF (object_id('IDI_Sandpit.intermediate.days_in_nz')) IS NULL
	CREATE TABLE IDI_Sandpit.intermediate.days_in_nz
		(
		snz_uid INT NOT NULL,
		month_end_date DATE NOT NULL,
		days_in_nz INT NOT NULL
		);
	
	INSERT intermediate.days_in_nz(snz_uid, month_end_date, days_in_nz)
	SELECT
		snz_uid,
		month_end_date,
		count(1) AS days_in_nz
	FROM 
		(SELECT snz_uid, start_date, end_date
		FROM IDI_Sandpit.intermediate.spells_in_nz
		WHERE end_date >= CONVERT(DATETIME, CAST(@yr AS VARCHAR(4)) + '0101') AND
				start_date <= CONVERT(DATETIME, CAST(@yr AS VARCHAR(4)) + '1231')) AS s
	CROSS JOIN 
		(SELECT 
		date_dt, month_end_date
		FROM IDI_Sandpit.pop_exp_dev.dim_date 
		WHERE year_nbr = @yr) AS d
	WHERE date_dt >= start_date AND date_dt <= end_date
	GROUP BY month_end_date, snz_uid;
END
GO


--------------------------------populate table------------------------
-- Takes about 8 minutes to do this for 3 months of data; 20 minutes for each full year
-- So allow 7+ hours for doing it all.  I think it seems to take longer as the table 
-- gets bigger, even though it isn't indexed until it is populated.
--	
EXECUTE intermediate.estimate_days @yr = 2017; -- 8 minutes
Go

EXECUTE intermediate.estimate_days @yr = 2016;
EXECUTE intermediate.estimate_days @yr = 2015;
EXECUTE intermediate.estimate_days @yr = 2014;
EXECUTE intermediate.estimate_days @yr = 2013;
Go

EXECUTE intermediate.estimate_days @yr = 2012;
EXECUTE intermediate.estimate_days @yr = 2011;
EXECUTE intermediate.estimate_days @yr = 2010;
Go

EXECUTE intermediate.estimate_days @yr = 2009;
EXECUTE intermediate.estimate_days @yr = 2008;
EXECUTE intermediate.estimate_days @yr = 2007;
Go

EXECUTE intermediate.estimate_days @yr = 2006;
EXECUTE intermediate.estimate_days @yr = 2005;
EXECUTE intermediate.estimate_days @yr = 2004;
Go

EXECUTE intermediate.estimate_days @yr = 2003;
EXECUTE intermediate.estimate_days @yr = 2002;
EXECUTE intermediate.estimate_days @yr = 2001;
Go

EXECUTE intermediate.estimate_days @yr = 2000;
EXECUTE intermediate.estimate_days @yr = 1999;
Go


EXECUTE intermediate.estimate_days @yr = 1998;
EXECUTE intermediate.estimate_days @yr = 1997;
EXECUTE intermediate.estimate_days @yr = 1996;
Go
-- executed up to here


EXECUTE intermediate.estimate_days @yr = 1995;
EXECUTE intermediate.estimate_days @yr = 1994;
EXECUTE intermediate.estimate_days @yr = 1993;
Go

EXECUTE intermediate.estimate_days @yr = 1992;
EXECUTE intermediate.estimate_days @yr = 1991;
EXECUTE intermediate.estimate_days @yr = 1990;
Go
-- executing



/*
-- this could all be done with a loop like this but the problem is if you get interrupted.
DECLARE @the_year INT = 2018;
WHILE @the_year > 1990
BEGIN
	EXECUTE pop_exp_dev.estimate_days @yr = @the_year
	SET @the_year = @the_year - 1
END
*/

-- setting this primary key is a biggish job but should be much faster than getting the data in
ALTER TABLE IDI_Sandpit.intermediate.days_in_nz ADD PRIMARY KEY (snz_uid, month_end_date);


