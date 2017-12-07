/*

Procedure to create a column store index for a table with all of its columns in it
columnstore indexes work well with all columns in them you are ever likely to use for queries; see
https://blogs.technet.microsoft.com/dataplatforminsider/2011/08/04/columnstore-indexes-a-new-feature-in-sql-server-known-as-project-apollo/
so we might as well have a stored procedure that programmatically creates such an index.

Note that this will fail if you already have a column store index on the table, unless it was created by this same procedure and 
hence has the expected name.

Peter Ellis 20 November 2017, adapted some of it from https://stackoverflow.com/questions/34651617/stored-procedure-to-create-non-clustered-columnstore-index

EXECUTE dbo.add_cs_ind 'gss_clean', 'gss_household_2012'

*/

USE IDI_Sample
GO


IF OBJECT_ID('dbo.add_cs_ind') IS NOT NULL
	DROP PROCEDURE dbo.add_cs_ind
GO

CREATE PROCEDURE dbo.add_cs_ind (@tab_schema VARCHAR(100), @tab_name VARCHAR(100))
AS
BEGIN
	SET NOCOUNT ON
	DECLARE @ts VARCHAR(100) = @tab_schema
	DECLARE @tn VARCHAR(100) = @tab_name
	DECLARE @cols TABLE(id INT NOT NULL IDENTITY PRIMARY KEY, col_name VARCHAR(256))

	-- Get all the column names
	INSERT INTO @cols(col_name)
	SELECT 
		c.name AS col_name
	FROM sys.columns		AS c
	INNER JOIN sys.tables   AS t
		ON  c.object_id = t.object_id
	INNER JOIN sys.schemas   AS s
		ON  s.schema_id = t.schema_id
	WHERE s.name = @ts AND t.name = @tn

	-- Paste together the column names
	DECLARE @i INT = 2
	DECLARE @vars VARCHAR(MAX) = (SELECT col_name FROM @cols WHERE id = 1) -- some tables have many columns hence VARCHAR(MAX)
	WHILE @i <= (SELECT MAX(id) FROM @cols)
	BEGIN
		SET @vars = @vars + ', ' + (SELECT col_name FROM @cols WHERE id = @i)
		SET @i = @i + 1
	END
	
	-- Create the actual query that will create the index with those column names
	DECLARE @query VARCHAR(MAX)
	SET @query = 'CREATE NONCLUSTERED COLUMNSTORE INDEX xcsi_' + @tn +
		' ON ' + @ts + '.' + @tn + ' (' + @VARS + ')'
	
	-- Drop existing index with this identical name, which has probably been made by us
	DECLARE @drop_sql VARCHAR(1000)
	SET @drop_sql = 'IF EXISTS(SELECT * FROM SYS.INDEXES WHERE object_id = OBJECT_ID(''' + @ts + '.' + @tn + ''') AND name =''xcsi_' + @tn +
                            ''')   DROP INDEX xcsi_' + @tn + ' ON ' + @ts + '.' + @tn
    EXECUTE(@drop_sql)
	
	-- Execute our query to actually make the index
	EXECUTE(@query)
	SET NOCOUNT OFF
END



