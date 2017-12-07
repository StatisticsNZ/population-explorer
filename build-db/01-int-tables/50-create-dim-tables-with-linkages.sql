/*
This procedure creates a table where each row represents a table in the IDI, and columns
indicate how much of each original IDI table's data is successfully linked to the spine.

There is a row for every table in the IDI that has a column named snz_uid.

The purpose is to get a slightly more finely grained view of linkage success rates than
in the data quality report that comes with the IDI refresh process.

Takes about 70 minutes to run on all 293 tables

9 November 2017, Peter Ellis
*/

USE IDI_Sandpit
IF OBJECT_ID('intermediate.get_linkage_rates') IS NOT NULL
	DROP PROCEDURE intermediate.get_linkage_rates
GO

CREATE PROCEDURE intermediate.get_linkage_rates AS
BEGIN
SET NOCOUNT ON 
	IF OBJECT_ID('tempdb..#tables') IS NOT NULL
		DROP TABLE #tables;
	IF OBJECT_ID('tempdb..#temp2') IS NOT NULL
		DROP TABLE #temp2;
	IF OBJECT_ID('tempdb..#temp1') IS NOT NULL
		DROP TABLE #temp1;
	IF OBJECT_ID('IDI_Sandpit.intermediate.dim_idi_tables') IS NOT NULL
		DROP TABLE IDI_Sandpit.intermediate.dim_idi_tables;
	
	CREATE TABLE #temp1 (
		table_code					INT NOT NULL IDENTITY PRIMARY KEY, 
		table_schema				VARCHAR(30),
		table_name					VARCHAR(100),
		number_rows					INT,
		number_rows_on_spine		INT,
		number_rows_off_spine		INT,
		proportion_rows_on_spine	FLOAT
		);
	
	CREATE TABLE #temp2 (
		table_code					INT NOT NULL IDENTITY PRIMARY KEY, 
		number_snz_uid				INT,
		number_snz_uid_on_spine		INT,
		number_snz_uid_off_spine	INT,
		proportion_snz_uid_on_spine	FLOAT
		);


	-- all tables that have an snz_uid column:
	SELECT 
		t.table_schema,
		t.table_name,
		RANK() OVER (ORDER BY t.table_schema, t.table_name) AS ID 
	INTO #tables
	FROM IDI_Clean.INFORMATION_SCHEMA.TABLES AS t
	INNER JOIN IDI_Clean.INFORMATION_SCHEMA.COLUMNS AS c
	ON t.table_name = c.table_name AND 
		t.table_schema = c.table_schema
	WHERE t.table_type = 'BASE TABLE' AND
		 NOT t.table_schema in('dbo', 'adhoc_clean', 'metadata', 'utility') AND
		 c.column_name = 'snz_uid'
	ORDER by t.table_schema, t.table_name;

	DECLARE @i INT = 1

	WHILE @i <=	(SELECT MAX(id) FROM #tables)
	BEGIN
		SET NOCOUNT ON;
	
		DECLARE @ts VARCHAR(100);
		DECLARE @tn VARCHAR(100);
		SET @ts = (SELECT table_schema FROM #tables WHERE id = @i);
		SET @tn = (SELECT table_name FROM #tables WHERE id = @i)

		DECLARE @query VARCHAR(1000);
		SET @query = 
		'INSERT #temp1(table_schema, table_name, number_rows, 
						number_rows_on_spine, number_rows_off_spine, 
						proportion_rows_on_spine)
		SELECT
			''' + @ts + ''',
			''' + @tn + ''',
			number_rows,
			number_on_spine,
			number_off_spine,
			CAST(number_on_spine AS NUMERIC(13)) / number_rows AS proportion_on_spine
		FROM
			(SELECT 
				COUNT(1)										   AS number_rows,
				SUM(CASE WHEN b.snz_spine_ind = 1 THEN 1 ELSE 0 END) AS number_on_spine,
				SUM(CASE WHEN b.snz_spine_ind = 1 THEN 0 ELSE 1 END) AS number_off_spine
			FROM IDI_Clean.' + @ts + '.' + @tn + '	   AS a
			LEFT JOIN IDI_Clean.data.personal_detail  AS b
				ON a.snz_uid = b.snz_uid) AS c';
	
		EXECUTE(@query);
	
		SET @query = 
		'INSERT #temp2(number_snz_uid, 
						number_snz_uid_on_spine, number_snz_uid_off_spine, 
						proportion_snz_uid_on_spine)
		SELECT
			number_rows,
			number_on_spine,
			number_off_spine,
			CAST(number_on_spine AS NUMERIC(13)) / number_rows AS proportion_on_spine
		FROM
			(SELECT 
				COUNT(1)										   AS number_rows,
				SUM(CASE WHEN b.snz_spine_ind = 1 THEN 1 ELSE 0 END) AS number_on_spine,
				SUM(CASE WHEN b.snz_spine_ind = 1 THEN 0 ELSE 1 END) AS number_off_spine
			FROM (SELECT DISTINCT snz_uid FROM IDI_Clean.' + @ts + '.' + @tn + ')	   AS a
			LEFT JOIN IDI_Clean.data.personal_detail  AS b
				ON a.snz_uid = b.snz_uid) AS c';
	
		EXECUTE(@query);
	
	
		SET @i = @i + 1;

	END
	-----------------------merge the two tables into one---------------------------------------
	SELECT
		a.*,
		b.number_snz_uid, 
		b.number_snz_uid_on_spine, 
		b.number_snz_uid_off_spine, 
		b.proportion_snz_uid_on_spine
	INTO IDI_Sandpit.intermediate.dim_idi_tables 
	FROM #temp1 AS a
	LEFT JOIN #temp2 AS b
		ON a.table_code = b.table_code

	DROP TABLE #temp1
	DROP TABLE #temp2
END
GO


EXECUTE intermediate.get_linkage_rates;

ALTER  TABLE IDI_Sandpit.intermediate.dim_idi_tables
	ADD PRIMARY KEY(table_code)
