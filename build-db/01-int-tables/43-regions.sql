/*
This script is an intermediate step between the creation of the intermediate.address_mid_month_table (part of the persistent 
intermediate tables) and putting region by year ending december into the star schema (script 7 in main build-db folder)

First, we make a temporary table that has for each person how many months (roughly) they lived in each region.
This uses the massive IDI_Sandpit.intermediate.address_mid_month table and takes a while to run (c 40 minutes).
*/


--------------------------------------Annual version-----------------------------------

IF OBJECT_ID('IDI_Sandpit.intermediate.region_lived_in_ye_dec') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.region_lived_in_ye_dec
IF OBJECT_ID('tempdb..#month_counts') IS NOT NULL
	DROP TABLE #month_counts


SELECT 
	snz_uid,
	ye_dec_date,
	region_name,
	COUNT(1)   + RAND(CAST(ant_region_code AS INT) + snz_uid) / 10 AS months_in_region
INTO #month_counts
FROM IDI_Sandpit.intermediate.address_mid_month AS a
INNER JOIN IDI_Sandpit.intermediate.dim_meshblock AS m
ON a.ant_meshblock_code = m.ant_meshblock_code
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
ON a.mid_month_date = d.date_dt
GROUP BY snz_uid, ye_dec_date, region_name, ant_region_code;



---------
/*
Identify the max months resided in any region as a sub query then join that back to the main
#month_counts temp table to get the region that was in.  So we now know for each person-year combination,
what region they were mostly living in that year.

This step is much faster than the previous
*/
SELECT 
	max_month.snz_uid, 
	max_month.ye_dec_date, 
	region_name as region_most_lived_in
INTO IDI_Sandpit.intermediate.region_lived_in_ye_dec
FROM
	(SELECT snz_uid, ye_dec_date, max(months_in_region) AS months_in_region
	FROM #month_counts	
	GROUP BY snz_uid, ye_dec_date) as max_month

	LEFT JOIN

	#month_counts AS mc
	 on max_month.snz_uid = mc.snz_uid 
	 AND max_month.ye_dec_date = mc.ye_dec_date
	 AND max_month.months_in_region = mc.months_in_region;

ALTER TABLE IDI_Sandpit.intermediate.region_lived_in_ye_dec 	ADD PRIMARY KEY (snz_uid, ye_dec_date);
CREATE COLUMNSTORE INDEX idx1 on IDI_Sandpit.intermediate.region_lived_in_ye_dec(snz_uid, ye_dec_date, region_most_lived_in); 
  
  
DROP TABLE #month_counts;


