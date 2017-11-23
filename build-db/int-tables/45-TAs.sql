/*
This script is an intermediate step between the creation of the intermediate.address_mid_month_table (part of the persistent 
intermediate tables) and putting TA by quarter into the star schema (script 15)

First, we make a temporary table that has for each person how many months (roughly) they lived in each TA.
This uses the massive IDI_Sandpit.intermediate.address_mid_month table and takes a while to run (c 40 minutes).

This script is nearly identical to 44 which does it for region (this script is for territorial authority).

October 2017, Peter Ellis
*/

-----------------Quarterly version------------------------
IF OBJECT_ID('IDI_Sandpit.intermediate.ta_lived_in_qtr') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.ta_lived_in_qtr
IF OBJECT_ID('tempdb..#month_counts') IS NOT NULL
	DROP TABLE #month_counts


SELECT 
	snz_uid,
	d.qtr_end_date,
	territorial_authority_name,
	COUNT(1)   + RAND(CAST(ant_ta_code AS INT) + snz_uid) / 10 AS months_in_ta
INTO #month_counts
FROM IDI_Sandpit.intermediate.address_mid_month AS a
INNER JOIN IDI_Sandpit.intermediate.dim_meshblock AS m
	ON a.ant_meshblock_code = m.ant_meshblock_code
INNER JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON a.mid_month_date = d.date_dt
GROUP BY snz_uid, qtr_end_date, territorial_authority_name, ant_ta_code;



---------
/*
Identify the max months resided in any TA as a sub query then join that back to the main
#month_counts temp table to get the TA that was in.  So we now know for each person-qtr combination,
what TA they were mostly living in that quarter.

This step is faster than the previous but still takes 10 minutes or so.
*/
SELECT 
	max_month.snz_uid, 
	max_month.qtr_end_date, 
	territorial_authority_name as ta_most_lived_in
INTO IDI_Sandpit.intermediate.ta_lived_in_qtr
FROM
	(SELECT snz_uid, qtr_end_date, max(months_in_ta) AS months_in_ta
	FROM #month_counts	
	GROUP BY snz_uid, qtr_end_date) as max_month

	LEFT JOIN

	#month_counts AS mc
	 on max_month.snz_uid = mc.snz_uid 
	 AND max_month.qtr_end_date = mc.qtr_end_date
	 AND max_month.months_in_ta = mc.months_in_ta;

ALTER TABLE IDI_Sandpit.intermediate.ta_lived_in_qtr 	ADD PRIMARY KEY (snz_uid, qtr_end_date);
CREATE COLUMNSTORE INDEX idx1 on IDI_Sandpit.intermediate.ta_lived_in_qtr(snz_uid, qtr_end_date, ta_most_lived_in);
  
  
DROP TABLE #month_counts;


