/*
Program creates the dim_person table as part of the Population Explorer reporting schema.

Peter Ellis, 7 September 2017

Modified 13 October so it uses the permanent random seed from the "derived" schema.
Modified early November to have a more careful definition of the column types and to include
parents' birth year, income in birth year, etc

TODO - there's some interesting additional things we could add eg parents' income in birth year + 1, + 2, etc.
Also, some of the variables whose natural grain is person-period could have a person grain snapshot such as
"number of CFY abuse events in first five years of life", "parent 1's highest qualification".  These should 
probably be added later in the build process, so they can use the fact tables as already prepared.  However,
this poses another question - if we're going to have a lot of these, do we need a separate fact table, rather
than just keeping adding attributes to this dimension table?  And do we need to carefully have code as well
as numeric versions for each (surely the answer is yes)?

About 10 minutes.

*/

-- Drop the any previous version of the table we are making if necessary
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.dim_person', 'U') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.dim_person;
IF OBJECT_ID('tempdb..#tmp') IS NOT NULL DROP TABLE #tmp;
IF OBJECT_ID('tempdb..#nzclass') IS NOT NULL DROP TABLE #nzclass;
GO




	  
-- Start by making a temporary table that is basically what we want except with some columns being codes rather than text.
-- We need to use distinct because there are [REDACTED] people listed twice in the births table.
-- Note that, as always with this reporting schema, only people on the spine are included, but this includes
-- people who are not resident population:
SELECT DISTINCT
	a.snz_uid, 
	snz_sex_code, 
	snz_birth_year_nbr,
	snz_birth_month_nbr,
	d.descriptor_text AS iwi,
	-- Note that from October 2017 the ethnicity in the personal_detail table is the "good" multiple-source ethnicity so we can take it from there:
	CASE WHEN snz_ethnicity_grp1_nbr = 1  THEN 'European'			ELSE 'Not European' END			AS europ,
	CASE WHEN snz_ethnicity_grp2_nbr = 1  THEN N'Māori'				ELSE N'Not Māori' END			AS maori,
	CASE WHEN snz_ethnicity_grp3_nbr = 1  THEN 'Pacific Peoples'	ELSE 'Not Pacific Peoples' END	AS pacif,
	CASE WHEN snz_ethnicity_grp4_nbr = 1  THEN 'Asian'				ELSE 'Not Asian' END			AS asian,
	CASE WHEN snz_ethnicity_grp5_nbr = 1  THEN 'MELAA'				ELSE 'Not MELAA' END			AS melaa,
	CASE WHEN snz_ethnicity_grp6_nbr = 1  THEN 'Other ethnicity'	ELSE 'Not other ethnicity' END	AS other,
	e.seed,
	CASE WHEN b.snz_uid IS NULL THEN 1 ELSE 0 END AS nzborn_code,
	ISNULL(number_parents, 0) AS number_known_parents,
	parents_income_birth_year
INTO #tmp
FROM IDI_Clean.data.personal_detail  AS a
LEFT JOIN IDI_Clean.dia_clean.births AS b
	ON a.snz_uid = b.snz_uid
LEFT JOIN IDI_Clean.cen_clean.census_individual AS c
	ON a.snz_uid = c.snz_uid
LEFT JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI AS d
	ON c.cen_ind_iwi1_code = d.cat_code
LEFT JOIN IDI_Sandpit.intermediate.permanent_seed AS e
	ON a.snz_uid = e.snz_uid
LEFT JOIN 
		(SELECT
			child_uid			AS snz_uid,
			COUNT(1)			AS number_parents,
			SUM(parent_income)	AS parents_income_birth_year
		 FROM IDI_Sandpit.intermediate.child_parent
		 GROUP BY child_uid) AS f
	ON a.snz_uid = f.snz_uid
WHERE a.snz_spine_ind = 1;




-- We need temporary classification table to convert the 0 and 1 into text for born_nz:
CREATE TABLE #nzclass (
	nzborn_code INT NOT NULL, 
	born_nz		VARCHAR(25) NOT NULL);

INSERT INTO #nzclass
		(nzborn_code, 
		born_nz) 
	VALUES   (0, 'Birth recorded by DIA'),
			 (1, 'Birth not recorded by DIA'); 


/*******************************************************/
-- Now we write the table in its actual format to the Sandpit.

CREATE TABLE IDI_Sandpit.pop_exp_dev.dim_person
	(
	snz_uid						INT NOT NULL,
	sex							VARCHAR(10) NOT NULL,
	born_nz						VARCHAR(25) NOT NULL,
	birth_year_nbr				SMALLINT,
	birth_month_nbr				TINYINT,	
	europ						NVARCHAR(25),
	maori						NVARCHAR(25),
	pacif						NVARCHAR(25),
	asian						NVARCHAR(25),
	melaa						NVARCHAR(25),
	other						NVARCHAR(25),
	iwi							NVARCHAR(254),
	number_known_parents		TINYINT NOT NULL,
	parents_income_birth_year	NUMERIC(15),
	seed						FLOAT
	);

INSERT IDI_Sandpit.pop_exp_dev.dim_person
SELECT
	snz_uid									 AS snz_uid,
	ISNULL(s.descriptor_text, 'Not known')   AS sex,
	ISNULL(n.born_nz, 'Not known')           AS born_nz,
	snz_birth_year_nbr						 AS birth_year_nbr,
	snz_birth_month_nbr						 AS birth_month_nbr,
	europ, 
	maori, 
	pacif, 
	asian, 
	melaa, 
	other,
	ISNULL(iwi, 'None')						 AS iwi,
	number_known_parents,
	parents_income_birth_year,
	seed        							 AS seed 
FROM #tmp AS a
LEFT JOIN IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_SEX AS s
ON a.snz_sex_code = s.cat_code
LEFT JOIN #nzclass AS n
ON a.nzborn_code = n.nzborn_code;

DROP TABLE #nzclass;
DROP TABLE #tmp;
GO

ALTER TABLE IDI_Sandpit.pop_exp_dev.dim_person ADD PRIMARY KEY (snz_uid);

-- note - if we are going to add more attribute columns later to this table, we have to put off building the columnstore index
-- (or remove it when we want to add data, and rebuild it afterwards, which is probably better as dim_person is used a lot
-- in subsequent build steps):
CREATE COLUMNSTORE INDEX col_dim_person ON IDI_Sandpit.pop_exp_dev.dim_person
(snz_uid, sex, born_nz, birth_year_nbr, birth_month_nbr, iwi, europ, maori, pacif, asian, melaa, other, number_known_parents, parents_income_birth_year, seed);

GO

