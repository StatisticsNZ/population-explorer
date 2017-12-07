
/*
We don't have a copy of IDI_Metadata yet on our development server, so to save doing cross-server joins (which confuses ODBC)
we make a copy of the tables we need.  Action is under way to properly copy all of IDI_Metadata over.

Peter Ellis, October 2017
*/

USE IDI_Sandpit;
GO
/*
CREATE SCHEMA clean_read_CLASSIFICATIONS;



SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI
FROM [WPRDSQL36\ILEED].IDI_Metadata.[clean_read_CLASSIFICATIONS].[CEN_IWI];

ALTER TABLE IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI	ALTER COLUMN cat_code CHAR(4) NOT NULL
ALTER TABLE IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_IWI	 ADD PRIMARY KEY (cat_code);

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_REGC13
FROM [WPRDSQL36\ILEED].IDI_Metadata.clean_read_CLASSIFICATIONS.CEN_REGC13;

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_TA13
FROM [WPRDSQL36\ILEED].IDI_Metadata.clean_read_CLASSIFICATIONS.CEN_TA13;

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.CEN_SEX
FROM [WPRDSQL36\ILEED].IDI_Metadata.clean_read_CLASSIFICATIONS.CEN_SEX;

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.msd_incapacity_reason_code_4
FROM [wprdsql36\ileed].IDI_Metadata.clean_read_CLASSIFICATIONS.msd_incapacity_reason_code_4;

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.moh_primhd_team_code
FROM [wprdsql36\ileed].IDI_Metadata.clean_read_CLASSIFICATIONS.moh_primhd_team_code;  

SELECT *
INTO IDI_Sandpit.clean_read_CLASSIFICATIONS.moh_dim_form_pack_subsidy_code
FROM [wprdsql36\ileed].IDI_Metadata.clean_read_CLASSIFICATIONS.moh_dim_form_pack_subsidy_code;  

*/