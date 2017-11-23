/*
This script deletes all tables from a previous version of 'IDI_Sample' ie the small random sample
version of the IDI, as part of clearing the decks for creating a new version.  Needs to be run
first in any clean rebuild. 


Peter Ellis, 15 November 2017
*/


USE IDI_Sample


------------------------Drop all the tables *except* data.personal_detail--------------
IF OBJECT_ID('tempdb..#tables') IS NOT NULL
	DROP TABLE #tables

-- all tables that have an snz_uid column:
SELECT 
	t.table_schema,
	t.table_name
INTO #tables
FROM IDI_Sample.INFORMATION_SCHEMA.TABLES AS t
WHERE t.table_type = 'BASE TABLE' AND
	 NOT t.table_schema in('dbo', 'adhoc_clean', 'metadata', 'utility') AND
	 t.table_name <> 'personal_detail';

-- add an id column with the row number, which we will use to cycle through them all:
ALTER TABLE #tables ADD id INT IDENTITY;
GO

-- cycle through all the tables and drop them all:
DECLARE @i INT, @j INT, @schema VARCHAR(200), @tab VARCHAR(200);
DECLARE @query VARCHAR(1000);

SET @i = 1
 

WHILE @i <= (SELECT MAX(id) FROM #tables)
BEGIN
	SET @schema = (SELECT table_schema FROM #tables WHERE id = @i);
	SET @tab = (SELECT table_name FROM #tables WHERE id = @i);
	SET @query = 'DROP TABLE ' + @schema + '.' + @tab

	EXECUTE (@query);
	SET @i = @i + 1
END
GO
-----------*now* we can drop the personal_detail table-------
-- could not drop it before because all those other tables had foreign key constraints to it

IF OBJECT_ID('IDI_Sample.data.personal_detail') IS NOT NULL
	DROP TABLE IDI_Sample.data.personal_detail;
