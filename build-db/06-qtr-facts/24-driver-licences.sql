/*
This program identifies holders of full driver licences per quarter
- Can be any NZ full driver licence (eg. car, motorbike, medium or heavy vehicles)
- Does not include learners or restricted licences
- Only identified as a holder if the status recorded is "current" eg. those with expired or disqualifed licences will not appear as holders.


Miriam Tankersley 15/11/2017

*/

----------------get driver licence dates----------------

IF OBJECT_ID('tempdb..#licences_raw') IS NOT NULL
	DROP TABLE #licences_raw
GO

SELECT snz_uid
	  ,MIN(ye_dec_date) AS licence_date
INTO #licences_raw
FROM (
	SELECT a.snz_uid
	  ,d.ye_dec_date
	FROM IDI_Clean.nzta_clean.drivers_licence_register AS a
	LEFT JOIN IDI_Sandpit.pop_exp_dev.dim_date AS d
	ON COALESCE(nzta_dlr_licence_issue_date,nzta_dlr_lic_class_start_date) = d.date_dt
						-- we only want full "current" licences
	WHERE		nzta_dlr_licence_stage_text = 'FULL'
		AND	nzta_dlr_licence_type_text <> 'PSEUDO LICENCE'
		AND nzta_dlr_licence_status_text = 'CURRENT'
		AND nzta_dlr_class_status_text = 'CURRENT'
		AND a.snz_uid IN (SELECT snz_uid FROM IDI_Sandpit.pop_exp_dev.dim_person) -- we only want people in our dimension table
	) AS licences
GROUP BY snz_uid

----------------create reference temp table with quarter end dates----------------

IF OBJECT_ID('tempdb..#quarters') IS NOT NULL
DROP TABLE #quarters

SELECT DISTINCT qtr_end_date 
INTO #quarters
FROM IDI_Sandpit.pop_exp_dev.dim_date
WHERE qtr_end_date  >= (SELECT MIN(licence_date) FROM  #licences_raw)
  AND qtr_end_date  <= DATEADD(YEAR,1,GETDATE())


----------------get variable from the variable table-------------------
IF OBJECT_ID('TempDB..#value_codes') IS NOT NULL DROP TABLE #value_codes
GO 

DECLARE @var_name VARCHAR(15) = 'Driver_licence'
USE IDI_Sandpit
EXECUTE lib.clean_out_qtr @var_name = @var_name, @schema = 'pop_exp_dev';


-- grab back from the table the new code for our variable and store as a temp table #var_code			 
DECLARE @var_code INT
SET @var_code =	(
	SELECT variable_code
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	WHERE short_name = @var_name)

------------------add categorical values to the value table------------------------
INSERT INTO IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr
			(short_name, fk_variable_code, var_val_sequence)
		VALUES
		 ('Full drivers licence', @var_code, 1)

-- and grab back the mini-lookup table with just our value codes

SELECT value_code, short_name AS value_category
	INTO #value_codes
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_value_qtr 
	WHERE fk_variable_code = @var_code



----------------join the two temp tables to populate all quarters post-licence issue, and add facts to the fact table----------------

INSERT  IDI_Sandpit.pop_exp_dev.fact_rollup_qtr(fk_date_period_ending, fk_snz_uid, fk_variable_code, value, fk_value_code)
SELECT   
		fk_date,
		fk_snz_uid,
		fk_variable_code,
		value,
		value_code AS fk_value_code
FROM
	(SELECT 
			snz_uid							AS fk_snz_uid, 
			qtr_end_date					AS fk_date, 
			1								AS value, 
			@var_code						AS fk_variable_code,
			'Full drivers licence'			AS value_category
		FROM #quarters INNER JOIN #licences_raw 
		ON qtr_end_date >= licence_date
		) AS with_cats
	-- we want to covert the categories back from categories to codes
	LEFT JOIN #value_codes vc
	ON with_cats.value_category = vc.value_category
	ORDER BY fk_snz_uid

