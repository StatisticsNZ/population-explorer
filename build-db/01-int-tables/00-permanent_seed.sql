/*
Creates a seed for everyone in the IDI based on a hierarchy of their uid values.  These persist even though
snz_uid doesn't.

This takes about 3-4 minutes to run

Peter Ellis September 2017, then re-written on 27 November 2017 to use a lookup table of random integers
rather than use RAND(uid), which is very highly correlated with uid eg check out:
SELECT RAND(12345), RAND(12346).
Re-worked again early December for better more persistent uids.

*/


IF OBJECT_ID('IDI_Sandpit.intermediate.permanent_seed', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.permanent_seed;
GO

CREATE TABLE IDI_Sandpit.intermediate.permanent_seed
(snz_uid INT NOT NULL,
 seed   FLOAT NOT NULL
 );




-- First we get ourselves a set of persistent ids
DECLARE @uids TABLE (snz_uid INT,	persistent_uid INT)

INSERT INTO @uids
SELECT 
	snz_uid,
	CASE
		WHEN snz_ird_uid IS NOT NULL THEN snz_ird_uid
		WHEN snz_ird_uid IS NULL AND snz_dol_uid IS NOT NULL THEN snz_dol_uid
		WHEN snz_ird_uid IS NULL AND snz_dol_uid IS NOT NULL AND snz_dia_uid IS NOT NULL THEN snz_dia_uid
		WHEN snz_ird_uid IS NULL AND snz_dol_uid IS NOT NULL AND snz_dia_uid IS NOT NULL AND snz_moh_uid IS NOT NULL THEN snz_moh_uid
		WHEN snz_ird_uid IS NULL AND snz_dol_uid IS NOT NULL AND snz_dia_uid IS NOT NULL AND snz_moh_uid IS NOT NULL AND snz_moe_uid IS NOT NULL THEN snz_moe_uid
		WHEN snz_ird_uid IS NULL AND snz_dol_uid IS NOT NULL AND snz_dia_uid IS NOT NULL AND snz_moh_uid IS NOT NULL AND snz_moe_uid IS NOT NULL AND snz_msd_uid IS NOT NULL THEN snz_msd_uid
		ELSE snz_uid
	END AS persistent_uid
FROM IDI_Clean.security.concordance

/*
When we get to the second refresh of Population Explorer we will need to handle a situtation where someone had an snz_ird_uid
in December 2017 (first version of pop_exp) and then a different one in May 2018 (second version).  Similarly for MSD.  So
we will need to add to the above code a step that checks if a previous snz_ird_uid attached to this person already has been in this table,
in which case they use that original one  for seed purposes, not the new one.  This may be a bit fiddly to implement.

*/



-- Then we take their last six digits and join them to our look up table
INSERT INTO IDI_Sandpit.intermediate.permanent_seed(snz_uid, seed)
SELECT
	snz_uid,
	random_number / 300.0 AS seed
FROM 
	(SELECT 
		snz_uid,
		persistent_uid,
		CAST(RIGHT(CAST(persistent_uid AS VARCHAR(10)), 6) AS INT) AS six_digit_nuid
	FROM @uids) AS a
	LEFT JOIN IDI_Sandpit.dbo.random_numbers AS b
		ON a.six_digit_nuid = b.six_digit_nuid


----------------------Indexing-----------------------

ALTER TABLE IDI_Sandpit.intermediate.permanent_seed ADD PRIMARY KEY(snz_uid);

