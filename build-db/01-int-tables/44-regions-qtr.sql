/*
This script is an intermediate step between the creation of the intermediate.address_mid_month_table (part of the persistent 
intermediate tables) and putting region by quarter into the star schema (script 7 in main build-db/qtr-facts/ folder)

First, we make a temporary table that has for each person how many months (roughly) they lived in each region.
This uses the massive IDI_Sandpit.intermediate.address_mid_month table and takes a while to run (c 40 minutes).
*/


--------------------------------------Quarterly version-----------------------------------

IF OBJECT_ID('IDI_Sandpit.intermediate.region_lived_in_qtr') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.region_lived_in_qtr
IF OBJECT_ID('tempdb..#month_counts') IS NOT NULL
	DROP TABLE #month_counts


SELECT 
	snz_uid,
	qtr_end_date,
	region_name,
	COUNT(1)   + RAND(CAST(ant_region_code AS INT) + snz_uid) / 10 AS months_in_region
INTO #month_counts
FROM IDI_Sandpit.intermediate.address_mid_month AS a
INNER JOIN IDI_Sandpit.intermediate.dim_meshblock AS m
	ON a.ant_meshblock_code = m.ant_meshblock_code
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON a.mid_month_date = d.date_dt
GROUP BY snz_uid, qtr_end_date, region_name, ant_region_code;





---------
/*
Identify the max months resided in any region as a sub query then join that back to the main
#month_counts temp table to get the region that was in.  So we now know for each person-qtr combination,
what region they were mostly living in that qtr.

This step is much faster than the previous
*/
SELECT 
	max_month.snz_uid, 
	max_month.qtr_end_date, 
	region_name as region_most_lived_in
INTO IDI_Sandpit.intermediate.region_lived_in_qtr
FROM
	(SELECT snz_uid, qtr_end_date, max(months_in_region) AS months_in_region
	FROM #month_counts	
	GROUP BY snz_uid, qtr_end_date) as max_month

	LEFT JOIN

	#month_counts AS mc
	 on max_month.snz_uid = mc.snz_uid 
	 AND max_month.qtr_end_date = mc.qtr_end_date
	 AND max_month.months_in_region = mc.months_in_region;

ALTER TABLE IDI_Sandpit.intermediate.region_lived_in_qtr 	ALTER COLUMN qtr_end_date DATE NOT NULL;
GO 
ALTER TABLE IDI_Sandpit.intermediate.region_lived_in_qtr 	ADD PRIMARY KEY (snz_uid, qtr_end_date);
GO 

CREATE COLUMNSTORE INDEX idx1 on IDI_Sandpit.intermediate.region_lived_in_qtr(snz_uid, qtr_end_date, region_most_lived_in); 
  
  
DROP TABLE #month_counts;


