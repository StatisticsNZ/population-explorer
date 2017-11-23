
/*
This script makes a table of spells in New Zealand.  The data sources are 

- data.personal_relationship (limit to just people on the spine)
- dol_clean.movements        (for border movements)
_ dia_clean.births and dia_clean.deaths

(unlike data.person_overseas_spell which is spells *outside* New Zealand)

Includes:
* people who arrive or born and then depart or die
* people who arrive or were born but never depart or die (for whom end date is NULL)
* people who arrive/born multiple times and have departed at least once but are still in the country.

Might also want to add some additional fact columns, and de-duplication - all to take inspiration from the MBIE spells database.
MBIE spells SAS code has somewhat extensive de-duplication but it's not obvious from the simple verion of the data this is really need

Two new dimension classifications are created here

end_type 1 = depart,  2 = deceased, 3 = still here when MBIE's data finish
start_type 1 = arrive, 2 = born

I think this could probably be re-factored.  It seems to have a lot of temporary copies of the data, are they all needed?

I also think there's still a problem with the final verison of the data having overlapping spells - eg people who have left the country twice without being observed coming back...

*/


-- First, we have a problem in the current refresh with some people born and dying twice so we make unique subsets of births and deaths.  
-- Clean up:
 IF OBJECT_ID('TempDB..#unique_spine_births') IS NOT NULL DROP TABLE #unique_spine_births;
IF OBJECT_ID('TempDB..#unique_spine_deaths') IS NOT NULL DROP TABLE #unique_spine_deaths;

-- 18 seconds:
SELECT DISTINCT	
	b.snz_uid, 
	dia_bir_birth_month_nbr, 
	dia_bir_birth_year_nbr
INTO #unique_spine_births
FROM IDI_Clean.dia_clean.births a
INNER JOIN IDI_Clean.data.personal_detail b
ON a.snz_uid = b.snz_uid
WHERE b.snz_spine_ind = 1;

-- Unique deaths - only 7 seconds:
SELECT DISTINCT	
	b.snz_uid, 
	dia_dth_death_month_nbr, 
	dia_dth_death_year_nbr
INTO #unique_spine_deaths
FROM IDI_Clean.dia_clean.deaths a
INNER JOIN IDI_Clean.data.personal_detail b
ON a.snz_uid = b.snz_uid
WHERE b.snz_spine_ind = 1;


-- Clean up before the main sequence.  We're going to use four more temporary tables and make one output table.
IF OBJECT_ID('TempDB..#arrivals') IS NOT NULL DROP TABLE #arrivals;
IF OBJECT_ID('TempDB..#departures') IS NOT NULL DROP TABLE #departures;
IF OBJECT_ID('TempDB..#spells_in_nz') IS NOT NULL DROP TABLE #spells_in_nz;
IF OBJECT_ID('TempDB..#movements') IS NOT NULL DROP TABLE #movements;
IF OBJECT_ID('IDI_Sandpit.intermediate.temp_movements') IS NOT NULL DROP TABLE IDI_Sandpit.intermediate.temp_movements;
IF OBJECT_ID('IDI_Sandpit.intermediate.temp_arrivals') IS NOT NULL DROP TABLE IDI_Sandpit.intermediate.temp_arrivals;
IF OBJECT_ID('IDI_Sandpit.intermediate.temp_departures') IS NOT NULL DROP TABLE IDI_Sandpit.intermediate.temp_departures;
IF OBJECT_ID('IDI_Sandpit.intermediate.temp_spells_in_nz') IS NOT NULL DROP TABLE IDI_Sandpit.intermediate.temp_spells_in_nz;
IF OBJECT_ID('IDI_Sandpit.intermediate.spells_in_nz') IS NOT NULL DROP TABLE IDI_Sandpit.intermediate.spells_in_nz;
go

-- This idea of using a temp table #movements was used during dev to assess how it will scale up.  But it is also probably is 
-- a good thing to have a thin version of only the bits we need of it rather than the whole wide table, and this is where
-- we need to de-dupe people who leave the country multiple times on the same plane at the same time (impossible...).
-- Just doing the de-dupe and copy into #movements takes 3 minutes when done with the full dataset.
--
-- The full sequence from here to the end of the script takes a while (ie hours)

-- 3-4 minutes
SELECT distinct  
	m.snz_uid, 
	dol_mov_carrier_datetime, 
	dol_mov_movement_ind
INTO IDI_Sandpit.intermediate.temp_movements
FROM IDI_Clean.dol_clean.movements AS m
LEFT JOIN IDI_Clean.data.personal_detail AS d
ON m.snz_uid = d.snz_uid
WHERE d.snz_spine_ind = 1
GO

-- Strategy is to make one table of #arrivals (including births), one of #departures (including deaths), 
-- join them together for all common snz_uid and work out which departures are the most immediate
-- after each arrival.

-- Start with just the border movements.
-- start_type 1 is an arrival
SELECT 
	snz_uid, 
	dol_mov_carrier_datetime    AS start_date,
	1					    	AS start_type
into IDI_Sandpit.intermediate.temp_arrivals
FROM IDI_Sandpit.intermediate.temp_movements
WHERE dol_mov_movement_ind = 'A';



-- Add in the births as a particular type of "arrival".
-- start_type 2 is a birth - assuming each is at beginning of the month for this purpose 
-- (to cover case of an infant who leaves same month they are born):
INSERT IDI_Sandpit.intermediate.temp_arrivals(snz_uid, start_date, start_type)
SELECT 
	snz_uid,
	DATEFROMPARTS(dia_bir_birth_year_nbr , dia_bir_birth_month_nbr, 1) AS start_date,
	2			 AS start_type
FROM #unique_spine_births;

-- Add a unique identifier for #arrivals.  We need this later.  This next chunk takes 30+ minutes, probably because of the indexing.
ALTER TABLE IDI_Sandpit.intermediate.temp_arrivals 
	ADD arrival_id INT IDENTITY 
	CONSTRAINT pk_arrivals PRIMARY KEY CLUSTERED;
GO	

-- departures from border movements
SELECT 
	snz_uid,
	dol_mov_carrier_datetime AS end_date,
	1                        AS end_type
INTO IDI_Sandpit.intermediate.temp_departures
FROM IDI_Sandpit.intermediate.temp_movements
WHERE dol_mov_movement_ind = 'D';


-- add in deaths which are end_type = 2
INSERT IDI_Sandpit.intermediate.temp_departures(snz_uid, end_date, end_type)
SELECT 
	snz_uid,
	DATEFROMPARTS(dia_dth_death_year_nbr, dia_dth_death_month_nbr, 1) AS end_date,
	2			 AS end_type
FROM #unique_spine_deaths;
GO



  -- next table will be a bit shorter than the shorter of #arrivals and #departures, but while it's creating the table
  -- it does a full outer join of the two so it is pretty memory-intensive
  -- This creates a table of spells for people who have arrived or been born AND departed or died
  -- drop table IDI_Sandpit.intermediate.temp_departures
  -- go
  SELECT 
	a.snz_uid, 
	start_date, 
	MIN(end_date) AS end_date, -- ie the earliest date for each combination of person-arrival
	start_type,
	DATEDIFF(day, start_date, MIN(end_date)) AS  days_in_country,
	arrival_id
  INTO IDI_Sandpit.intermediate.temp_spells_in_nz
  FROM IDI_Sandpit.intermediate.temp_arrivals a
  FULL OUTER JOIN IDI_Sandpit.intermediate.temp_departures d
  ON a.snz_uid = d.snz_uid
  WHERE end_date > start_date -- ie to make sure we consider only departures after the arrival
  GROUP BY a.snz_uid, start_date, start_type, arrival_id;


-- add in people who arrived or were born without ever departing or dying
-- This is done with an anti-join ie it finds out of events listed in #arrivals
-- (which now includes births) any which have not been paired up with a departure
-- in #spells_in_nz.
-- Danger - note the magic constant of the date of when the data finished.  Probably best
-- to determine this programmatically (it's just one day after the max value of date in the 
-- original "DOL" ie MBIE movements table)
INSERT IDI_Sandpit.intermediate.temp_spells_in_nz (snz_uid, start_date, end_date, start_type, days_in_country, arrival_id)
SELECT 
	a.snz_uid,
	a.start_date,
	CAST('2017-05-01' AS DATETIME)  AS end_date,
	a.start_type,
	DATEDIFF(day, a.start_date, CAST('2017-05-01' AS DATETIME)) AS days_in_country,
	a.arrival_id
FROM IDI_Sandpit.intermediate.temp_arrivals        a 
LEFT JOIN IDI_Sandpit.intermediate.temp_spells_in_nz s 
ON a.arrival_id = s.arrival_id 
WHERE s.arrival_id IS NULL;



-- save final copy, merging with departures along the way to get the departure type and add in type 3
-- which is people still in the country at the end.  This final operation is a bit expensive because of
-- the join, which has to be left join so we get NULL when there's no match in departure and we can
-- set end_type to be 3.
SELECT 
	s.snz_uid,
	start_date,
	s.end_date,
	days_in_country,
	start_type,
	CASE WHEN end_type IS NULL THEN 3 ELSE end_type END AS end_type
INTO IDI_Sandpit.intermediate.spells_in_nz
FROM IDI_Sandpit.intermediate.temp_spells_in_nz s
LEFT JOIN IDI_Sandpit.intermediate.temp_departures d
ON s.snz_uid = d.snz_uid AND s.end_date = d.end_date;


-- These tables aren't needed so should be deleted, but only when you're sure you've got the spells table nicely sorted!
DROP TABLE IDI_Sandpit.intermediate.temp_arrivals
DROP TABLE IDI_Sandpit.intermediate.temp_departures
DROP TABLE IDI_Sandpit.intermediate.temp_movements
DROP TABLE IDI_Sandpit.intermediate.temp_spells_in_nz


-- The combination of snz_uid and the starting datetime of the spell should be unique, so for performance
-- and for an integrity check we make it a primary key
ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz ALTER COLUMN snz_uid INTEGER NOT NULL;
ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz ALTER COLUMN start_date DATETIME NOT NULL;
GO
ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz ADD CONSTRAINT pk_spells PRIMARY KEY (snz_uid, start_date);

CREATE NONCLUSTERED INDEX idx1 ON IDI_Sandpit.intermediate.spells_in_nz(start_date);
CREATE NONCLUSTERED INDEX idx2 ON IDI_Sandpit.intermediate.spells_in_nz(end_date);

-- During dev there were lots of times we found duplicates of people leaving the country at the same time.  The problems
-- turned out to be people who were born twice, died twice, or left the country twice on the same people
-- next line is used to trouble shoot this problem by finding some example IDs
-- select top 5 count(1) as freq, snz_uid, start_date from IDI_Sandpit.intermediate.spells_in_nz group by snz_uid, start_date order by freq desc
-- select * from IDI_Clean.dol_clean.movements where snz_uid = XXXXX
/*
select 
	count(1)						AS freq, 
	CASE end_type 
		WHEN 1 THEN 'Departed'
		WHEN 2 THEN 'Deceased'
		WHEN 3 THEN 'Still here'
		END							AS end_type_desc
from IDI_Sandpit.intermediate.spells_in_nz 
group by end_type;
*/


-------------------Accompanying dimension tables-------------------
IF OBJECT_ID('IDI_Sandpit.intermediate.dim_spell_start') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.dim_spell_start;
IF OBJECT_ID('IDI_Sandpit.intermediate.dim_spell_end') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.dim_spell_end;


CREATE TABLE IDI_Sandpit.intermediate.dim_spell_start (
	start_type TINYINT NOT NULL PRIMARY KEY,
	description VARCHAR(200),
	data_origin VARCHAR(2000)
)
INSERT IDI_Sandpit.intermediate.dim_spell_start(start_type, description, data_origin) VALUES
	(1, 'cross-border arrival', 'IDI_Clean.dol_clean.movements'),
	(2, 'birth', 'IDI_Clean.dia_clean.births');


CREATE TABLE IDI_Sandpit.intermediate.dim_spell_end (
	end_type TINYINT NOT NULL PRIMARY KEY,
	description VARCHAR(200),
	data_origin VARCHAR(2000)
)
INSERT IDI_Sandpit.intermediate.dim_spell_end(end_type, description, data_origin) VALUES
	(1, 'cross-border departure', 'IDI_Clean.dol_clean.movements'),
	(2, 'death', 'IDI_Clean.dia_clean.deaths'),
	(3, 'still in New Zealand', NULL);

ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz ALTER COLUMN start_type TINYINT NOT NULL;
ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz ALTER COLUMN end_type TINYINT NOT NULL;

ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz
	ADD CONSTRAINT spells_nz_fk1 
	FOREIGN KEY (start_type) REFERENCES IDI_Sandpit.intermediate.dim_spell_start(start_type);

ALTER TABLE IDI_Sandpit.intermediate.spells_in_nz
	ADD CONSTRAINT spells_nz_fk2 
	FOREIGN KEY (end_type) REFERENCES IDI_Sandpit.intermediate.dim_spell_end(end_type);
