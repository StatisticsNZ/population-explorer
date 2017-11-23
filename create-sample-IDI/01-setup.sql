/*
Set up for creating a 1/100 sample of the IDI

This script creates the data schema and a cut-down version of data.personal_detail 
with 100,000 people on the spine and 500,000 people who aren't.  This is then used
as the basis for creating our samples of other tables that have snz_uid in them.

It is assumed you have an empty database called IDI_Sample, and access to the actual IDI_Clean

Peter Ellis, 1 November 2017
*/

USE IDI_Sample;
go

-----------identify a sample of snz_uids------------------
-- let's say 100,000 from the spine and 500,000 not on the spine

-- create the data schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'data')
	EXECUTE('CREATE SCHEMA data;')
GO



IF OBJECT_ID('IDI_Sample.data.personal_detail') IS NOT NULL
	DROP TABLE IDI_Sample.data.personal_detail;

SELECT TOP 100000 *
INTO IDI_Sample.data.personal_detail
FROM IDI_Clean.data.personal_detail AS pd
WHERE pd.snz_spine_ind = 1
ORDER BY RAND(pd.snz_uid);

INSERT IDI_Sample.data.personal_detail
SELECT TOP 500000 *
FROM IDI_Clean.data.personal_detail AS pd
WHERE pd.snz_spine_ind != 1
ORDER BY RAND(pd.snz_uid);

ALTER TABLE IDI_Sample.data.personal_detail ADD PRIMARY KEY(snz_uid);


-- check - should have 500,000 off the spine and 100,000 who are on it
-- select count(1), snz_spine_ind from IDI_Sample.data.personal_detail group by snz_spine_ind