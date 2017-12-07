
/*
Define a table function that will take a table with snz_uid, startdate, enddate, grouping and
returns a table with the same structure, having:
a) removed duplicates
b) removed fully enveloped spells
c) changed the start date of partially overlapping spells that the start date is one day after the previous spell's end date

2 November 2017, Peter Ellis and Miriam Tankersley.  Adapted (down a wayward path) from a SAS original from Treasury

This function performs very slowly and in practice we aren't using it.  TODO - find out why.

*/


USE IDI_Sandpit

IF OBJECT_ID('lib.remove_spell_overlaps') IS NOT NULL
	DROP FUNCTION lib.remove_spell_overlaps;
GO

IF TYPE_ID(N'lib.overlapping_spells_table') IS NOT NULL
	DROP TYPE lib.overlapping_spells_table;
GO

CREATE TYPE lib.overlapping_spells_table AS TABLE
(
	snz_uid INT,
	startdate DATE,
	enddate DATE,
	group_var VARCHAR(50) 
);
GO

CREATE FUNCTION lib.remove_spell_overlaps ( @orig_tab overlapping_spells_table READONLY)
RETURNS @out_tab TABLE
(
	snz_uid INT,
	startdate DATE,
	enddate DATE,
	group_var VARCHAR(50) 
)
AS
BEGIN
	DECLARE @int_spells1 AS TABLE (snz_uid INT, startdate DATE, enddate DATE, group_var VARCHAR(50), row INT)

	INSERT INTO @int_spells1(snz_uid, startdate, enddate, group_var, row)
	SELECT *
	FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY snz_uid, startdate, enddate, group_var ORDER BY snz_uid, startdate, enddate, group_var) AS row
				  FROM @orig_tab) AS t1

	DELETE FROM @int_spells1
	WHERE row > 1


	-- Remove spells where startdate > last start date and end date <= last end date (complete overlap)

       DECLARE @int_spells2 AS TABLE (snz_uid INT, startdate DATE, enddate DATE, group_var VARCHAR(50))


	   INSERT @int_spells2  (snz_uid, startdate, enddate, group_var)
		SELECT t1.snz_uid, t1.startdate, t1.enddate, t1.group_var
		FROM @int_spells1 AS t1
		WHERE NOT EXISTS (    SELECT *
                                    FROM @int_spells1 AS t2
                                    WHERE  (t1.startdate > t2.startdate AND t1.enddate <= t2.enddate AND t1.snz_uid = t2.snz_uid AND t1.group_var = t2.group_var
                                                  AND (startdate <> t2.startdate OR t1.enddate <> t2.startdate)))

		-- Where spells have a with partial overlap, change startdate to enddate of overlap spell + 1 day

	   DECLARE @int_spells3 AS TABLE (snz_uid INT, startdate DATE, enddate DATE, group_var VARCHAR(50), laststart DATE, lastend DATE)

		INSERT @int_spells3 (snz_uid, startdate, enddate, group_var, laststart, lastend)
		SELECT *
		FROM (SELECT  *
                             ,LAG(startdate,1,NULL) OVER(PARTITION BY snz_uid, group_var ORDER BY snz_uid, startdate, enddate) AS laststart
                             ,LAG(enddate,1,NULL) OVER(PARTITION BY snz_uid, group_var ORDER BY snz_uid, startdate, enddate) AS lastend
              FROM @int_spells2) AS t1
		ORDER BY snz_uid

		UPDATE @int_spells3
		SET startdate = DATEADD(DAY,1,lastend)
		WHERE startdate <= lastend

		INSERT @out_tab
		SELECT snz_uid, startdate, enddate, group_var
		FROM @int_spells3

	RETURN
END

GO

/*
DECLARE @test AS overlapping_spells_table
INSERT INTO @test
SELECT snz_uid, startdate, enddate, interv_grp AS group_var FROM #interventions

SELECT * INTO #results FROM remove_spell_overlaps(@test)


SELECT * FROM #results order by snz_uid
*/


