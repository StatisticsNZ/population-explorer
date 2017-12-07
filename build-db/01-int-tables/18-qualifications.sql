/*
This code provides enduring highest NQF (National Qualification Framework) qualification, per person, per year.

Subsequent years are filled in with the highest qualification received. eg. if someone obtains a NQF level 3 qualification in 2007 and does no further study, 
their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards. 
Likewise, qualifications completed that are lower in level than previous qualifications completed will not count towards the highest qualification. 
eg. if someone obtains a NQF level 3 qualification in 2007 and obtains an NQF level 1 qualification in 2008, their "highest qualification" will still be recorded as NQF level 3 for 2008 onwards.  

Qualifications are taken from the primary and secondary school student qualifications dataset (IDI_Clean.moe_clean.student_qualification),
the tertiary qualification completions dataset (IDI_Clean.moe_clean.completion), and the industry training education dataset (IDI_Clean.moe_clean.tec_it_learner).
The targeted training dataset was not used, as this doesn't contain a qualification completion field.

Highest qualification is NQF levels as described follows:
0 = 'NQF level 0'
1 = 'Certificate or NCEA level 1'
2 = 'Certificate or NCEA level 2'
3 = 'Certificate or NCEA level 3'
3.5 = 'Other tertiary qualification' **see issues below
4 = 'Certificate level 4'
5 = 'Certificate or diploma level 5'
6 = 'Certificate or diploma level 6'
7 = 'Bachelors degree, graduate diploma or certificate level 7'
8 = 'Bachelors honours degree or postgraduate diploma or certificate level 8'
9 = 'Masters degree'
10 = 'Doctoral degree'


Miriam Tankersley 24/11/2017
====================================

** ISSUES **
There are approx. 15,000 instances in moe_clean.completion where moe_com_qual_level_code is NULL. 
These are mainly National diploma/ national certificate levels 5-7, New Zealand diploma, Professional association certificate, or National certificate levels 1-3.
I have grouped these into another category - "Other tertiary qualification" for now. This will sit between level 3 and level 4 in rank ie. 3.5.

====================================
*/


-- Get highest qualifications per year per snz_uid

IF OBJECT_ID('tempdb..#all_quals') IS NOT NULL 
	DROP TABLE #all_quals

SELECT	quals.snz_uid
		,year_nbr
		,MAX(qual) AS highest_qual
INTO #all_quals
FROM (
	-- Primary and secondary school qualifications
		SELECT
			sq.snz_uid
			,moe_sql_attained_year_nbr AS year_nbr
			,moe_sql_nqf_level_code AS qual
		 FROM IDI_Clean.moe_clean.student_qualification AS sq
UNION ALL
	--Tertiary qualifications
		SELECT
			snz_uid
			,moe_com_year_nbr AS year_nbr
			,COALESCE(moe_com_qual_level_code, CAST(3.5 AS numeric(3,1))) AS qual -- if null, group into "Other tertiary qualification" which sits between level 3 and level 4
		 FROM IDI_Clean.moe_clean.completion
UNION ALL
	--Industry training qualifications
		SELECT 
			snz_uid
			,year_nbr
			,qual
		FROM 
			(SELECT snz_uid
			  ,YEAR(moe_itl_end_date) AS year_nbr
			  ,moe_itl_level1_qual_awarded_nbr AS [1]
			  ,moe_itl_level2_qual_awarded_nbr AS [2]
			  ,moe_itl_level3_qual_awarded_nbr AS [3]
			  ,moe_itl_level4_qual_awarded_nbr AS [4]
			  ,moe_itl_level5_qual_awarded_nbr AS [5]
			  ,moe_itl_level6_qual_awarded_nbr AS [6]
			  ,moe_itl_level7_qual_awarded_nbr AS [7]
			  ,moe_itl_level8_qual_awarded_nbr AS [8]
			  FROM IDI_Clean.moe_clean.tec_it_learner
			 ) AS pvt
			UNPIVOT
			 (qual FOR quals IN ([1],[2],[3],[4],[5],[6],[7],[8])
			 ) AS unpvt
		WHERE year_nbr IS NOT NULL AND qual > 0
	) AS quals
	--Spine only
INNER JOIN IDI_Clean.data.personal_detail AS spine
ON quals.snz_uid = spine.snz_uid
WHERE snz_spine_ind = 1
GROUP BY quals.snz_uid, year_nbr


-- Create table with every year from earliest qualification recorded to current year per snz_uid

IF OBJECT_ID('tempdb..#qual_years') IS NOT NULL 
	DROP TABLE #qual_years

SELECT  q.snz_uid
		,d.year_nbr
INTO #qual_years
FROM  IDI_Sandpit.pop_exp_dev.dim_date AS d
	INNER JOIN 
	(SELECT snz_uid, MIN(year_nbr) AS year_nbr
	FROM #all_quals
	GROUP BY snz_uid) AS q
	ON d.year_nbr >= q.year_nbr AND d.year_nbr <= YEAR(GETDATE())
GROUP BY q.snz_uid, d.year_nbr
ORDER BY snz_uid, year_nbr


-- join the tables into one, with enduring highest qualification

IF OBJECT_ID('IDI_Sandpit.intermediate.highest_qualification') IS NOT NULL
       DROP TABLE IDI_Sandpit.intermediate.highest_qualification
GO

SELECT y.snz_uid, y.year_nbr, MAX(q.highest_qual) AS highest_qual
INTO IDI_Sandpit.intermediate.highest_qualification
FROM #qual_years AS y
	INNER JOIN #all_quals AS q
	ON y.snz_uid = q.snz_uid AND y.year_nbr >= q.year_nbr
GROUP BY y.snz_uid, y.year_nbr