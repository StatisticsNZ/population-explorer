
/*
This is a port to SQL of the SAS code by the SIA at https://github.com/nz-social-investment-agency/mha_data_definition

To run this, you need access to the following IDI_Clean schemas:
* data
* moh_clean
* msd_clean

The substance of the SIA original is in https://github.com/nz-social-investment-agency/mha_data_definition/blob/master/sasprogs/create_mha_events.sas
It was written by  V Benny and C MacCormick; Adapted from MoH_mh_aod_events.sas created by 
S Johnston and M Cronin (MOH) and adapted by Rissa Ota (MSD).

This port to SQL was done by Peter Ellis (Stats NZ) on 1 November 2017.

The strategy here is to create five separate datasets, all in the same shape, showing mental health service events ie interaction with an arm of the government 
in a way that indicates a mental health issue.  The five ways are

* Diagnosis of a mental health disorder in PRIMHD database
* Diagnosis of a mental health issue when discharaged from a public hospital
* Purchase of a pharmaceutical that is usually associated with mental illness, as recorded in the PHARMAC records
* Two or more lab tests within four months with test code BM2, which indicates a test for a mood disorder
* MSD recorded as incapacity for work based on mental retardation, affective psychoses, other psych conditions, or drug abuse

These five datasets are then combined into a single dataset.

Unlike the SIA original, we only create that dataset for individuals on the IDI spine, to be consistent with the overall strategy of the Population Explorer.

The SIA original creates a table called `moh_diagnosis`.  In our version, the final table is instead called `mha_events`.

The SIA version uses hard coded SAS formats to match the MSD benefits codes to meaningful names (eg 'mental retardation', which I think is an old DSM 4 diagnosis).  The code
below instead joins to the relevant table in  IDI_Metadata.  Note that there are at least 5 tables in metadata matching MSD incapacity codes to names - it looks
like higher numbers mean more recent, better refined sets of codes.

Takes about 40 minutes to run.

*/

IF OBJECT_ID('IDI_Sandpit.intermediate.mha_events ') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.mha_events ;
	
IF OBJECT_ID('tempdb..#primhd_team') IS NOT NULL
	DROP TABLE #primhd_team;

IF OBJECT_ID('tempdb..#hosp_events') IS NOT NULL
	DROP TABLE #hosp_events;

IF OBJECT_ID('tempdb..#diag') IS NOT NULL
	DROP TABLE #diag;

IF OBJECT_ID('tempdb..#nmds_mental_health') IS NOT NULL
	DROP TABLE #nmds_mental_health;



IF OBJECT_ID('tempdb..#labs_mental_health') IS NOT NULL
	DROP TABLE #labs_mental_health;


IF OBJECT_ID('tempdb..#pharmac') IS NOT NULL
	DROP TABLE #pharmac;

IF OBJECT_ID('tempdb..#msd_inc_mha_events') IS NOT NULL
	DROP TABLE 	#msd_inc_mha_events;

GO

/********************************************************************************
(1) Programme for the Integration of Mental Health Data (PRIMHD) 
********************************************************************************/

-- This table is basically purely for mental health data so is straightforward to get into the shape we need:

SELECT 
	primhd.snz_uid,
	'MOH'												AS department,
	'PRIMHD'											AS datamart,
	'MH'												AS subject_area,
	CAST(primhd.moh_mhd_activity_start_date AS DATE)	AS start_date,
	CAST(primhd.moh_mhd_activity_end_date AS DATE)		AS end_date,
	CASE 
		WHEN primhd.moh_mhd_activity_type_code = 'T09' THEN 'Psychotic'
		WHEN team.team_type = '16' THEN 'Eating'
		WHEN team.team_type = '12' THEN 'Intellectual'
		WHEN team.team_type in ('03','10','11','21','23') OR 
			primhd.moh_mhd_activity_type_code IN ('T16','T17','T18','T19','T20') 
			THEN 'Substance use'
		WHEN primhd.moh_mhd_activity_type_code <> '' THEN 'Other MH'
	END AS event_type,
	primhd.moh_mhd_activity_type_code					AS event_type_2,
	team.team_type										AS event_type_3
INTO #primhd_team
FROM IDI_Clean.moh_clean.primhd primhd	
LEFT JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.moh_primhd_team_code   AS team
	ON primhd.moh_mhd_team_code = team.team_code
INNER JOIN IDI_Clean.data.personal_detail pd
	ON primhd.snz_uid = pd.snz_uid
WHERE pd.snz_spine_ind = 1;

GO

/**************************************************************************************************
(2) National Minimum Dataset (NMDS) - Public Hospital Discharges
**************************************************************************************************/

-- All the relevant hospital discharges:
SELECT
	hde.snz_uid,
	snz_moh_uid				AS moh_uid,
    moh_evt_event_id_nbr	AS event_id,
    moh_evt_evst_date		AS start_date,
    moh_evt_even_date		AS end_date
INTO #hosp_events
FROM IDI_Clean.moh_clean.pub_fund_hosp_discharges_event hde
INNER JOIN IDI_Clean.data.personal_detail pd
	ON hde.snz_uid = pd.snz_uid
WHERE pd.snz_spine_ind = 1;



-- Classify diagnoses by mental health type if applicable:
WITH diag_cte AS
	(SELECT
		moh_dia_event_id_nbr		AS event_id, 
		moh_dia_clinical_sys_code, 
		moh_dia_clinical_code		AS code
	FROM IDI_Clean.moh_clean.pub_fund_hosp_discharges_diag
	WHERE moh_dia_submitted_system_code = moh_dia_clinical_sys_code)
SELECT DISTINCT 
	event_id,
	code,
	CASE
		-- Hospitalisations 1999 to 2014
		WHEN SUBSTRING(code, 1, 4) = 'F900'										THEN 'ADHD'
		WHEN SUBSTRING(code, 1, 3) >= 'F40' AND SUBSTRING(code, 1, 3) <= 'F48'	THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 3) = 'F84'										THEN 'Autism'
		WHEN SUBSTRING(code, 1, 3) >= 'F00' AND SUBSTRING(code, 1, 3) <= 'F03'	THEN 'Dementia'
		WHEN SUBSTRING(code, 1, 3) = 'F50'										THEN 'Eating'
		WHEN SUBSTRING(code, 1, 4) IN ('F640', 'F642', 'F648', 'F649')			THEN 'Gender identity'
		WHEN SUBSTRING(code, 1, 3) >= 'F30' AND SUBSTRING(code, 1, 3) <= 'F39'	THEN 'Mood'
		WHEN SUBSTRING(code, 1, 3) >= 'F70' AND SUBSTRING(code, 1, 3) <= 'F79'	THEN 'Intellectual'
		WHEN SUBSTRING(code, 1, 3) >= 'F04' AND SUBSTRING(code, 1, 3) <= 'F09'	THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 3) >= 'F51' AND SUBSTRING(code, 1, 3) <= 'F53'	THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 3) IN ('F59', 'F63', 'F68', 'F69', 'F99')		THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 4) IN ('F930', 'F931', 'F932')					THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 3) >= 'F60' AND SUBSTRING(code, 1, 3) <= 'F62'	THEN 'Personality'
		WHEN SUBSTRING(code, 1, 3) >= 'F20' AND SUBSTRING(code, 1, 3) <= 'F29'	THEN 'Psychotic'
		WHEN SUBSTRING(code, 1, 3) >= 'F10' AND SUBSTRING(code, 1, 3) <= 'F16'	THEN 'Substance use'
		WHEN SUBSTRING(code, 1, 3) >= 'F18' AND SUBSTRING(code, 1, 3) <= 'F19'	THEN 'Substance use'
		WHEN SUBSTRING(code, 1, 3) IN ('F55')									THEN 'Substance use'

		-- Hospitalisations 1988 to 1999, which had an older coding system
		WHEN SUBSTRING(code, 1, 5) IN ('31400', '31401')												THEN 'ADHD'
		WHEN SUBSTRING(code, 1, 5) >= '30000' AND SUBSTRING(code, 1, 5) <= '30015'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 4) IN ('3002', '3003')													THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 4) >= '3005' AND SUBSTRING(code, 1, 4) <= '3009'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 4) >= '3060' AND SUBSTRING(code, 1, 4) <= '3064'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 5) IN ('30650', '30652', '30653', '30659', '30780', '30789', '30989')	THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 4) >= '3066' AND SUBSTRING(code, 1, 4) <= '3069'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 4) >= '3080' AND SUBSTRING(code, 1, 4) <= '3091'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 5) >= '30922' AND SUBSTRING(code, 1, 5) <= '30982'						THEN 'Anxiety'
		WHEN SUBSTRING(code, 1, 5) IN ('29900', '29901', '29910')								THEN 'Autism'
		WHEN SUBSTRING(code, 1, 3) = '290'														THEN 'Dementia'
		WHEN SUBSTRING(code, 1, 4) = '2941'														THEN 'Dementia'
		WHEN SUBSTRING(code, 1, 4) = '3071'														THEN 'Eating'
		WHEN SUBSTRING(code, 1, 5) IN ('30750', '30751', '30754', '30759')						THEN 'Eating'
		WHEN SUBSTRING(code, 1, 4) = '3026'														THEN 'Gender identity'
		WHEN SUBSTRING(code, 1, 5) IN ('30250', '30251', '30252', '30253', '30285')				THEN 'Gender identity'
		WHEN SUBSTRING(code, 1, 3) IN ('296', '311')											THEN 'Mood'
		WHEN SUBSTRING(code, 1, 4) = '3004'														THEN 'Mood'
		WHEN SUBSTRING(code, 1, 5) = '30113'													THEN 'Mood'
		WHEN SUBSTRING(code, 1, 3) >= '317' AND SUBSTRING(code, 1, 3) <= '319'					THEN 'Intellectual'
		WHEN SUBSTRING(code, 1, 4) >= '2930' AND SUBSTRING(code, 1, 4) <= '2940'				THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 4) IN ('2948', '2949', '3027', '3074', '3123', '3130', '3131')	THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 5) >= '29911' AND SUBSTRING(code, 1, 5) <= '29991'				THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 5) IN ('30016', '30019', '30151', '30651', '30921')				THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 3) IN ('310')													THEN 'Other MH'
		WHEN SUBSTRING(code, 1, 4) = '3010'														THEN 'Personality'
		WHEN SUBSTRING(code, 1, 5) IN ('30110', '30111', '30112', '30159')						THEN 'Personality'
		WHEN SUBSTRING(code, 1, 5) >= '30120' AND SUBSTRING(code, 1, 5) <= '30150'				THEN 'Personality'
		WHEN SUBSTRING(code, 1, 4) >= '3016' AND SUBSTRING(code, 1, 4) <= '3019'				THEN 'Personality'
		WHEN SUBSTRING(code, 1, 4) >= '2950' AND SUBSTRING(code, 1, 4) <= '2959'				THEN 'Psychotic'
		WHEN SUBSTRING(code, 1, 4) >= '2970' AND SUBSTRING(code, 1, 4) <= '2989'				THEN 'Psychotic'
		WHEN SUBSTRING(code, 1, 3) IN ('291', '292')											THEN 'Substance use'
		WHEN SUBSTRING(code, 1, 4) >= '3030' AND SUBSTRING(code, 1, 4) <= '3050'				THEN 'Substance use'
		WHEN SUBSTRING(code, 1, 4) >= '3052' AND SUBSTRING(code, 1, 4) <= '3059'				THEN 'Substance use'

	END AS event_type
INTO #diag
FROM diag_cte;

-- match the diagnosis to the discharges and save for later:
SELECT 
	'MOH'		AS department,
	'NMDS'		AS datamart,
	'MH'		AS subject_area,
	a.moh_uid,
	a.snz_uid,
	a.start_date,
	a.end_date,
	b.event_type ,
	b.code		AS event_type_2,
	NULL		AS event_type_3
INTO #nmds_mental_health
FROM #hosp_events AS a 
INNER JOIN #diag  AS b 
ON a.event_id = b.event_id
WHERE b.event_type IS NOT NULL;

DROP TABLE #diag;
DROP table #hosp_events;

GO

/**************************************************************************************************
(3) PHARMACEUTICALS
**************************************************************************************************/

-- Extract PHARMAC records for the drugs we are interested in:


WITH pharmac1 AS (
	SELECT
		pharm.snz_uid						AS snz_uid, 
		pharm.moh_pha_dispensed_date		AS start_date, 
		pharm.moh_pha_dispensed_date		AS end_date, 
		CAST(form.CHEMICAL_ID AS CHAR(4))	AS code
	FROM IDI_Clean.moh_clean.pharmaceutical AS pharm
	INNER JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.moh_dim_form_pack_subsidy_code AS form 
		ON pharm.moh_pha_dim_form_pack_code = form.DIM_FORM_PACK_SUBSIDY_KEY
	INNER JOIN IDI_Clean.data.personal_detail pd
		ON pharm.snz_uid = pd.snz_uid
	WHERE pd.snz_spine_ind = 1 AND
	      form.CHEMICAL_ID in 
					(
						3887,1809,3880,
						1166,6006,1780,
						3750,3923,
						1069,1193,1437,1438,1642,2466,3753,1824,1125,2285,1955,2301,3901,
						1080,1729,1731,2295,
						3884,3878,1078,1532,2820,1732,1990,1994,2255,2260,
						2367,1432,3793,
						2632,1315,3926,2636,1533,1535,1760,2638,1140,1911,6009,1950,1183,1011,3927,
						1030,1180,3785,3873										
						/*potential inclusion*/
						,1007,1013,1059,1111,1190,1226,1252,1273,1283,1316,1379,1389,1397,1578,1583,
						1730,1799,1841,1865,1876,1956,2224,2298,2436,2530,2539,3248,3248,3722,3735,
						3803,3892,3898,3920,3935,3940,3950,4025,4037,6007,8792,1795,2484
						/* additional post moh feedback */
						,1002,1217,2166
					)
				)
SELECT
	pharmac1.snz_uid, 
	'PHARM'		AS datamart,
	'MOH'		AS department,
	start_date,
	end_date,
	'MHA' AS subject_area,
	CASE
		WHEN code in ('3887','1809','3880')														THEN 'ADHD'
		WHEN code in ('1166','6006','1780')														THEN 'Anxiety'
		WHEN code in ('3750','3923')															THEN 'Dementia'
		WHEN code in ('1069','1437','1438','2466','3753','1824','1125','2285','1955','2301', '3901', '2636','6009') THEN 'Mood'
		WHEN code in ('1193')																	THEN 'Citalopram' -- used for both mood-anxiety and dementia
		WHEN code in ('3884','3878','1078','1532','2820','1732','1990','1994','2255','2260')	THEN 'Pyschotic'
		WHEN code in ('2367','1432','3793')														THEN 'Substance use'
		WHEN code in ('2632','3926','1760','2638','3927','1030','1180','3785')					THEN 'Mood anxiety'
		WHEN code in ('1080','1729','1731','2295')												THEN 'Other MH'
		WHEN code in ('1315','1533','1535','1140','1911','1950','1183','1011','3873','1642')	THEN 'Other MH'
			/* Added 1795 Methadone into the potentials list */
			/* Added 1002 lamotrigine, 1217 carbamazepine, 2166 sodium valporate based on MOH feedback */
			/* Added 2484 Zopiclone from Other MH to Potentials based on MoJ feedback*/
		WHEN code in ('1007','1013','1059','1111','1190','1226','1252','1273','1283','1316',
				'1379','1389','1397','1578','1583','1730','1799','1841','1865','1876',
				'1956','2224','2298','2436','2530','2539','3248','3248','3722','3735',
				'3803','3892','3898','3920','3935','3940','3950','4025','4037','6007','8792', 
				'1795','1002','1217','2166','2484')												THEN 'Potential MH'
	END		AS event_type,
	code	AS event_type_2,
	NULL	AS event_type_3
INTO #pharmac
FROM pharmac1;
	
GO


/**************************************************************************************************
(4) LAB Data 
**************************************************************************************************/

-- Extract labs claims data for the population cohort:

SELECT 
	lc.snz_uid,
	snz_moh_uid			AS mast_enc,
	moh_lab_test_code	AS test_code,
	moh_lab_visit_date	AS start_date
INTO #lab_mast
FROM IDI_Clean.moh_clean.lab_claims lc
INNER JOIN IDI_Clean.data.personal_detail pd
	ON lc.snz_uid = pd.snz_uid
WHERE pd.snz_spine_ind = 1 AND
		moh_lab_test_code = 'BM2'
ORDER BY mast_enc, start_date;

ALTER TABLE #lab_mast ADD id INT IDENTITY;

-- The business rule is we only include people and their tests if they have two tests within four months:

SELECT DISTINCT test_id
INTO #multiple_episodes
FROM
	(SELECT 
		a.id			AS test_id_a,
		b.id			AS test_id_b
	FROM #lab_mast			AS a
	CROSS JOIN #lab_mast	AS b
	WHERE 
		a.snz_uid = b.snz_uid AND
		b.start_date > a.start_date AND
		DATEDIFF(day, a.start_date, b.start_date) <= 120) AS tests
UNPIVOT 
	(test_id FOR sequence IN (test_id_a, test_id_b)) AS long;

-- Restrict the main labs dataset to just these people and their episodes (where number of tests greater than two) 

SELECT
	snz_uid,
	start_date,
	start_date	AS end_date,
	'MOH'		AS department,
	'LAB'		AS datamart,
	'MHA'		AS subject_area,
	'Mood'		AS event_type,
	'BM2'		AS event_type_2,
	NULL		AS event_type_3
INTO #labs_mental_health
FROM #lab_mast					AS a
INNER JOIN #multiple_episodes	AS b
ON a.id = b.test_id;

DROP TABLE #lab_mast;
DROP TABLE #multiple_episodes;

GO
/**************************************************************************************************
(5) MSD Incapacity
**************************************************************************************************/

SELECT 
	inc.snz_uid,
	'MSD'							AS department,
	'ICP'							AS datamart,
	'ICP'							AS subject_area,
	msd_incp_incp_from_date			AS start_date,
	msd_incp_incp_to_date			AS end_date,
	0.00							AS cost,
	CASE
		-- Renamed the following to align with the health tables' diagnoses:
		WHEN classification = 'Mental retardation'							THEN 'Intellectual'
		WHEN classification  = 'Affective psychoses'						THEN 'Psychotic'
		WHEN classification = 'Other psychological/psychiatric'				THEN 'Other MH'
		WHEN classification = 'Drug abuse'									THEN 'Substance use'
	END AS event_type,
	classification AS event_type_2,
	NULL AS event_type_3
INTO #msd_inc_mha_events
FROM  IDI_Clean.msd_clean.msd_incapacity	AS inc
INNER JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.msd_incapacity_reason_code_4 AS md
	ON inc.msd_incp_incapacity_code = md.Code
INNER JOIN IDI_Clean.data.personal_detail	AS pd
	ON inc.snz_uid = pd.snz_uid
WHERE pd.snz_spine_ind = 1 AND
      md.classification IN ('Mental retardation', 'Drug abuse', 
					'Other psychological/psychiatric', 'Affective psychoses')
ORDER BY
	snz_uid, 		
	start_date, 
	end_date;

GO

/**************************************************************************************************
(6) Combining data and creating final event_type datasets 
**************************************************************************************************/

/* Combine mental health event_types from all data sources */


 
SELECT snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area 
INTO IDI_Sandpit.intermediate.mha_events 
FROM #nmds_mental_health;


ALTER TABLE IDI_Sandpit.intermediate.mha_events ALTER COLUMN event_type VARCHAR(20);
ALTER TABLE IDI_Sandpit.intermediate.mha_events ALTER COLUMN event_type_2 VARCHAR(50);
ALTER TABLE IDI_Sandpit.intermediate.mha_events ALTER COLUMN event_type_3 VARCHAR(20);
ALTER TABLE IDI_Sandpit.intermediate.mha_events ALTER COLUMN datamart VARCHAR(10);
ALTER TABLE IDI_Sandpit.intermediate.mha_events ALTER COLUMN subject_area VARCHAR(3);


INSERT IDI_Sandpit.intermediate.mha_events (snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area)
SELECT snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area FROM #labs_mental_health;

INSERT IDI_Sandpit.intermediate.mha_events (snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area)
SELECT snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area FROM #pharmac;

INSERT IDI_Sandpit.intermediate.mha_events (snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area)
SELECT snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area FROM #primhd_team;

INSERT IDI_Sandpit.intermediate.mha_events (snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area)
SELECT snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3, subject_area FROM #msd_inc_mha_events;



/***************************************************************************************************
7. The 'Citalopram conflict' is resolved in the following section. 

A small subset of Citalopram users are allocated to Dementia, and the rest are allocated to 
Mood disorder

***************************************************************************************************/

UPDATE IDI_Sandpit.intermediate.mha_events SET event_type = 'Dementia'
FROM IDI_Sandpit.intermediate.mha_events AS mhd 
INNER JOIN 
	(SELECT b.snz_uid, b.department, b.datamart, b.subject_area, b.start_date, b.end_date, 
			'Dementia' AS event_type, b.event_type_2, b.event_type_3
		FROM (SELECT *  FROM IDI_Sandpit.intermediate.mha_events where event_type = 'Citalopram') AS b 
		WHERE EXISTS 
			(SELECT 1 FROM IDI_Sandpit.intermediate.mha_events AS a 
				WHERE a.event_type='Dementia' 
					AND a.snz_uid=b.snz_uid AND a.start_date <= b.start_date)
	) AS a ON(     mhd.snz_uid			= a.snz_uid 
			AND mhd.department		= a.department
			AND mhd.datamart		= a.datamart
			AND mhd.subject_area	= a.subject_area
			AND mhd.start_date		= a.start_date 
			AND mhd.end_date		= a.end_date
			AND mhd.event_type		= 'Citalopram'
			AND mhd.event_type_2	= a.event_type_2
			AND mhd.event_type_3	= a.event_type_3 );


UPDATE IDI_Sandpit.intermediate.mha_events SET event_type = 'Mood anxiety'
WHERE event_type = 'Citalopram'


/***************************************************************************************************
8. Indexing
***************************************************************************************************/


CREATE CLUSTERED INDEX idx1 ON IDI_Sandpit.intermediate.mha_events(snz_uid, start_date, datamart);
CREATE COLUMNSTORE INDEX idx2 ON IDI_Sandpit.intermediate.mha_events
	(snz_uid, datamart, department, start_date, end_date, event_type, event_type_2, event_type_3);
