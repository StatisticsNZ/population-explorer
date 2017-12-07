/*
Script adds a column store index to all tables in the IDI except for a small number that have columns with
too much numeric precision to allow a columnstore index (and probably should be fixed separately)

Depends on the stored procedures dbo.add_cs_ind, defined in the "add-columnstore-index.sql" file

Peter Ellis
 20 November 2017

*/

USE IDI_Sample -- change to IDI_Clean if doing for real
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'all_columnstore_indexes')
	DROP PROCEDURE	dbo.all_columnstore_indexes;
GO

CREATE PROCEDURE dbo.all_columnstore_indexes
AS
BEGIN
	SET NOCOUNT ON


	DECLARE @tables TABLE (id INT IDENTITY, table_schema VARCHAR(200), table_name VARCHAR(200))

	IF OBJECT_ID('dbo.cl_log') IS NULL
		CREATE TABLE dbo.cl_log (id INT, ts VARCHAR(200), tn VARCHAR(200))

	INSERT INTO @tables(table_schema, table_name)
	SELECT 
		t.table_schema,
		t.table_name
	FROM INFORMATION_SCHEMA.TABLES AS t
	WHERE t.table_type = 'BASE TABLE' AND
			NOT t.table_schema in('dbo', 'adhoc_clean', 'metadata', 'utility');

	DECLARE @i INT = 1;
	DECLARE @ts VARCHAR(100);
	DECLARE @tn VARCHAR(100);

	WHILE @i <= (SELECT MAX(id) FROM @tables)
	BEGIN
		SET @ts = (SELECT table_schema FROM @tables WHERE id = @i)
		SET @tn = (SELECT table_name FROM @tables WHERE id = @i)
		print CAST(@i AS CHAR(4)) + ' - ' + @ts + '.' + @tn
		-- some tables in sofie (first 3 listed below), pol_clean (remaining 4) have too much numeric precision so we skip them:
		IF @tn NOT IN ('person_waves', 'hq_id', 'labour_market', 'wave_income',
			 'pre_count_victimisations', 'post_count_victimisations', 'pre_count_offenders', 'post_count_offenders') 
			EXECUTE dbo.add_cs_ind @ts, @tn;
		
		INSERT INTO dbo.cl_log (id, ts, tn)
		VALUES(@i, @ts, @tn);
	
		SET @i = @i + 1

	END
END
GO

EXECUTE all_columnstore_indexes;
