/*
This script is an intermediate step between the creation of the intermediate.address_mid_month_table (part of the persistent 
intermediate tables) and putting meshblock by year ending december into the star schema

First, we make a temporary table that has for each person how many months (roughly) they lived in each meshblock.
This uses the massive IDI_Sandpit.intermediate.address_mid_month table and takes a while to run (c 40 minutes).

This script is nearly identical to 43 which does it for region (this script is for territorial authority).

October 2017, Peter Ellis
*/

-----------------Annual version------------------------
IF OBJECT_ID('IDI_Sandpit.intermediate.meshblock_lived_in_ye_dec') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.meshblock_lived_in_ye_dec
IF OBJECT_ID('tempdb..#month_counts') IS NOT NULL
	DROP TABLE #month_counts


SELECT 
	snz_uid,
	ye_dec_date,
	ant_meshblock_code,
	COUNT(1)   + RAND(CAST(ant_meshblock_code AS INT) + snz_uid) / 10 AS months_in_meshblock
INTO #month_counts
FROM IDI_Sandpit.intermediate.address_mid_month AS a
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON a.mid_month_date = d.date_dt
GROUP BY snz_uid, ye_dec_date, ant_meshblock_code;



---------
/*
Identify the max months resided in any meshblock as a sub query then join that back to the main
#month_counts temp table to get the meshblock that was in.  So we now know for each person-year combination,
what meshblock they were mostly living in that year.

This step is faster than the previous but still takes 10 minutes or so.
*/
SELECT 
	max_month.snz_uid, 
	max_month.ye_dec_date, 
	ant_meshblock_code as meshblock_most_lived_in
INTO IDI_Sandpit.intermediate.meshblock_lived_in_ye_dec
FROM
	(SELECT snz_uid, ye_dec_date, max(months_in_meshblock) AS months_in_meshblock
	FROM #month_counts	
	GROUP BY snz_uid, ye_dec_date) as max_month

	LEFT JOIN

	#month_counts AS mc
	 on max_month.snz_uid = mc.snz_uid 
	 AND max_month.ye_dec_date = mc.ye_dec_date
	 AND max_month.months_in_meshblock = mc.months_in_meshblock;

ALTER TABLE IDI_Sandpit.intermediate.meshblock_lived_in_ye_dec 	ADD PRIMARY KEY (snz_uid, ye_dec_date);
CREATE COLUMNSTORE INDEX idx1 on IDI_Sandpit.intermediate.meshblock_lived_in_ye_dec(snz_uid, ye_dec_date, meshblock_most_lived_in);
  
  
DROP TABLE #month_counts;


