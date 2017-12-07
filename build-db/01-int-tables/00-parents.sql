/*
Table of children and their parents, from the data.personal_detail table (not data.personal_relationship, which has too many relationships)
Basically people will be in here as parents if we know about it from dia_births.

We're storing this as a table because it takes a while to make and we will want to use it multiple times if we are to add attributes
to the dim_person dimension like "parents' highest qualificationb"


13 November 2017 Peter Ellis (separated out from the dim_person script).
*/


-- There's a table data.personal_relationship that already does this but it has some people with many many parents.
-- I'm presuming that the parent1 and parent2 in data.personal_detail are best to use instead.
IF OBJECT_ID('IDI_Sandpit.intermediate.child_parent') IS NOT NULL
	DROP TABLE IDI_Sandpit.intermediate.child_parent;
GO

SELECT 
	a.snz_uid							AS child_uid,
	snz_parent1_uid						AS parent_uid,
	1									AS parent_number,
	inc_tax_yr_sum_all_srces_tot_amt	AS parent_income
INTO IDI_Sandpit.intermediate.child_parent
FROM IDI_Clean.data.personal_detail AS a
LEFT JOIN IDI_Clean.data.income_tax_yr_summary  AS b
	ON a.snz_parent1_uid = b.snz_uid 
		AND a.snz_birth_year_nbr = b.inc_tax_yr_sum_year_nbr
WHERE snz_parent1_uid	 IS NOT NULL 
	  AND snz_spine_ind = 1

INSERT IDI_Sandpit.intermediate.child_parent
SELECT 
	a.snz_uid							AS child_uid,
	snz_parent2_uid						AS parent_uid,
	2									AS parent_number,
	inc_tax_yr_sum_all_srces_tot_amt	AS parent_income
FROM IDI_Clean.data.personal_detail AS a
LEFT JOIN IDI_Clean.data.income_tax_yr_summary  AS b
	ON a.snz_parent2_uid = b.snz_uid 
		AND a.snz_birth_year_nbr = b.inc_tax_yr_sum_year_nbr
WHERE snz_parent2_uid	 IS NOT NULL 
	  AND snz_spine_ind = 1


CREATE CLUSTERED INDEX idx1 ON IDI_Sandpit.intermediate.child_parent(child_uid, parent_uid);
