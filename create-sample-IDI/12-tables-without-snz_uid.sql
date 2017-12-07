/*
Adds in up to 1 million rows each of tables that don't have snz_uid.

For tables that don't have an snz_uid, it's not directly apparent how to sample from them in a way that mimics the overall IDI.
Some of these tables are basically dimension information or concordances eg data.more_provider; some have real facts in them, just
at one remove from snz_uid eg hnz_clean.transfer_applications.  Some of these tables are very large, the biggest being
moh_clean.pub_fund_hosp_discharges_diag with about 160 million rows.

For now, I'm just taking up to 1 million rows from each of these tables.  This increases the sample database size to 14 GB.  It means we
have a full set of all the concordance-like tables, and a not very useful subset of the more meaningful ones like bond lodgement.

I'm not very happy with this approach.  The better approach would be to join these tables to tables that *do* have snz_uid
columns, then inner join them to IDI_Sample.data.personal_detail so we have the correct subsample of all the data.  But 
that's a few days work I think to find a good way to programmatically do this - requires working out from column names
which tables should be linked to which until we get back to one with snz-uid on it.

Peter Ellis, 1 November 2017
*/

USE IDI_Sample
IF OBJECT_ID('build_problem_tables') IS NOT NULL
		DROP PROCEDURE build_problem_tables;
GO

IF OBJECT_ID('tempdb..#problem_tables') IS NOT NULL
	DROP TABLE #problem_tables
GO 

CREATE PROCEDURE build_problem_tables AS
BEGIN
SET NOCOUNT ON
	

	SELECT
		t.table_schema,
		t.table_name
	INTO #problem_tables
	FROM IDI_Clean.INFORMATION_SCHEMA.TABLES AS t
	LEFT JOIN
		(SELECT DISTINCT table_schema, table_name
		FROM IDI_Clean.INFORMATION_SCHEMA.COLUMNS
		WHERE column_name = 'snz_uid') AS with_snz_uid
	ON t.table_name = with_snz_uid.table_name AND 
		t.table_schema = with_snz_uid.table_schema
	WHERE with_snz_uid.TABLE_NAME IS NULL AND
		NOT t.table_schema in('adhoc_clean', 'metadata', 'utility', 'security') AND
		t.table_type = 'BASE TABLE' AND
		 t.table_name NOT LIKE '%20%'
	ORDER BY table_schema;

	ALTER TABLE #problem_tables ADD id INT IDENTITY;

	/*
	-- row counts for these problematic tables:
	SELECT full_name, id, count_nbr
	FROM
		IDI_Clean.utility.table_row_counts rc
	INNER JOIN
		(SELECT 	id, table_schema + '.' + table_name AS full_name FROM #problem_tables) pt
	ON rc.full_table_name_text = pt.full_name
	ORDER BY count_nbr DESC
	*/
	---------------------copy just the top n rows of each table---------------
	DECLARE @i INT, @full_name VARCHAR(300);
	SET @i = 1

	WHILE @i <= (SELECT MAX(id) FROM #problem_tables)
	BEGIN
		SET @full_name = (SELECT fn = table_schema + '.' + table_name FROM #problem_tables WHERE id = @i);
		print @full_name

		IF OBJECT_ID('IDI_Sample.' + @full_name, N'U') IS NOT NULL
		BEGIN
			DECLARE @drop_query VARCHAR(100);
			SET @drop_query = 'DROP TABLE IDI_Sample.' + @full_name;
			EXECUTE(@drop_query);
		END
	
		DECLARE @copy_query VARCHAR(300);
		SET @copy_query = '
		SELECT TOP 1000000 *
		INTO IDI_Sample.' + @full_name + 
		' FROM IDI_Clean.' + @full_name +
		' ORDER BY NEWID()'
	
		EXECUTE(@copy_query)

		SET @i = @i + 1
	END
END
GO


EXECUTE build_problem_tables;

DROP PROCEDURE build_problem_tables;

