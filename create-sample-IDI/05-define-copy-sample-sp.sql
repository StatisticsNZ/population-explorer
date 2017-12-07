/*
Defines a stored procedure to make a copy of a sample of a table

The strategy here is to take the schema name and table name as arguments from the user, then just
insert these into SQL that checks for such a table already existing (in which case it deletes it),
and creates a new version by joining the original IDI_Clean full data to our sampled subset of snz_uid
that was created in the previous script.

We also add a non-clustered index to snz_uid (as it will be certainly used for lots of joins) and a foreign key
constraint guaranteeing that all of our values of snz_uid in these tables match individuals in IDI_Sample.data.personal_detail.

Peter Ellis 1 November 2017

*/

USE IDI_Sample;
GO


IF OBJECT_ID('IDI_Sample.dbo.copy_sample') IS NOT NULL
	DROP PROCEDURE dbo.copy_sample
GO



CREATE PROCEDURE dbo.copy_sample (@schema VARCHAR(200), @tab VARCHAR(200))
AS
BEGIN
	IF OBJECT_ID('IDI_Sample.' + @schema + '.' + @tab, N'U') IS NOT NULL
	BEGIN
		DECLARE @drop_query VARCHAR(100);
		SET @drop_query = 'DROP TABLE IDI_Sample.' + @schema +'.' + @tab;
		EXECUTE(@drop_query);
	END
					
	DECLARE @create_query VARCHAR(1000);
	SET @create_query =
	'SELECT a.*
	INTO IDI_Sample.' + @schema +'.' + @tab + '
	FROM IDI_Clean.' + @schema +'.' + @tab + ' AS a
	INNER JOIN (SELECT snz_uid FROM IDI_Sample.data.personal_detail) AS b
	ON a.snz_uid = b.snz_uid

	--CREATE NONCLUSTERED INDEX i1 ON IDI_Sample.' + @schema +'.' + @tab + '(snz_uid);
	ALTER TABLE IDI_Sample.' + @schema +'.' + @tab + ' ADD FOREIGN KEY (snz_uid) REFERENCES IDI_Sample.data.personal_detail(snz_uid);'

	EXECUTE(@create_query)

END
GO



