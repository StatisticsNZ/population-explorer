/*
Adds copies to the IDI_Sample database of all tables that have snz_uid in them.

This uses the stored procedure defined in a previous script.  So all we need to do
is know the names of the schema.table combinations and feed them to the stored procedure.

We do this by defining a procedure to do the whole thing, executing the procedure, then dropping it.
This may seem a little odd, but makes the execution more stable when it is being run over ODBC ie from R.
There is an odd phenomenon where R is calling a script with a WHILE loop, where it stops after 28 iterations.
Silently of course... So wrapping any moderately complicated things in a procedure and executing the procedure
seems to be the way to go.

Adding all these tables makes the database about 15GB

Peter Ellis, 1 November 2017
*/


USE IDI_Sample

IF OBJECT_ID('build_tables') IS NOT NULL
		DROP PROCEDURE build_tables;
GO


IF OBJECT_ID('tempdb..#tables') IS NOT NULL
	DROP TABLE #tables
GO 

CREATE PROCEDURE build_tables AS
BEGIN
SET NOCOUNT ON
	-- all tables that have an snz_uid column:
	SELECT 
		t.table_schema,
		t.table_name
	INTO #tables
	FROM IDI_Clean.INFORMATION_SCHEMA.TABLES AS t
	INNER JOIN IDI_Clean.INFORMATION_SCHEMA.COLUMNS AS c
	ON t.table_name = c.table_name AND 
		t.table_schema = c.table_schema
	WHERE t.table_type = 'BASE TABLE' AND
		 NOT t.table_schema in('dbo', 'adhoc_clean', 'metadata', 'utility') AND
		 t.table_name <> 'personal_detail' AND
		 c.column_name = 'snz_uid';

	-- add an id column with the row number, which we will use to cycle through them all:
	ALTER TABLE #tables ADD id INT IDENTITY;
	 
	-- cycle through all the tables and create a copy of them in IDI_Sample:
	DECLARE @i INT, @j INT, @schema VARCHAR(200), @tab VARCHAR(200);
	SET @i = 1
	SET @j = (SELECT MAX(id) FROM #tables)

	WHILE @i <= @j
	BEGIN
		SET @schema = (SELECT table_schema FROM #tables WHERE id = @i);
		SET @tab = (SELECT table_name FROM #tables WHERE id = @i);

		EXECUTE data.copy_sample @schema = @schema, @tab = @tab;
		SET @i = @i + 1
	END
END
GO 

EXECUTE build_tables;

DROP PROCEDURE build_tables;
