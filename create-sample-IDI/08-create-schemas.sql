/*
This script creates all the necessary schemas (other than the data schema, created earlier) for the sample IDI.

It works out what schemas are necessary by looking at IDI_Clean, and just excepting some we won't be using.

We need to create these schemas first before we start adding tables to them.

Peter Ellis, 1 November 2017
*/


USE IDI_Sample

IF OBJECT_ID('tempdb..#schemas') IS NOT NULL
	DROP TABLE #schemas

SELECT 
	DISTINCT(table_schema)
INTO #schemas
FROM IDI_Clean.INFORMATION_SCHEMA.TABLES 
WHERE table_type = 'BASE TABLE' AND
	 NOT table_schema in('dbo', 'adhoc_clean', 'data') 

ALTER TABLE #schemas ADD id INT IDENTITY;

DECLARE @i INT, @schema VARCHAR(200), @create_query VARCHAR(300);
SET @i = 1;

WHILE @i <= (select max(id) from #schemas)
	BEGIN
		SET @schema = (SELECT table_schema FROM #schemas WHERE id = @i);
		
		
		SET @create_query = 
			'IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = ''' + @schema +''')
				EXECUTE(''CREATE SCHEMA ' + @schema + ''')'
				
		EXECUTE(@create_query)
		
		SET @i = @i + 1
	END

	