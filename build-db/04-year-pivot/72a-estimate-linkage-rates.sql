/*
This script:

1. creates a "bridge" table connecting the dim_explorer_variable dimension to the dim_idi_tables dimension.  It does this
by reading the tables listed in the dim_explorer_variable.origin_tables column, splitting them by commas into a row each, stripping out
all spaces, tabs and line breaks, and converting them to the table_code number from the intermediate.dim_idi_tables table.

2. Uses that bridge to estimate an "total linkage rate" and total snz_uid on the spine which gives a rough indication of what proportion 
of the data in the source tables for each variable has been successfully matched to the spine - and hence a rough idea of the completion
and quality of data for each variable.  These "totals" could maybe be the cumulative products of the individual tables' linkage rates.  Why?  Because
consider if we can successfully link 50% of people to their parents, and 100% of parents to their income, we have a total linkage rate of
only 0.5 * 1.0 = 0.5, not mean(0.5, 1.0) = 0.75.  But this is too aggressive, so am just going with max().

Note that

13 November 2017, Peter Ellis
*/

IF OBJECT_ID('tempdb..#vars') IS NOT NULL
	DROP TABLE #vars

IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
	DROP TABLE #tmp


IF OBJECT_ID('tempdb..#bridge') IS NOT NULL
	DROP TABLE #bridge

-- old version:
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.br_variable_tables') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.br_variable_tables;
GO

-- new named version:
IF OBJECT_ID('IDI_Sandpit.pop_exp_dev.bridge_variable_tables') IS NOT NULL
	DROP TABLE IDI_Sandpit.pop_exp_dev.bridge_variable_tables;
GO

SELECT 
	variable_code,
	origin_tables
INTO #vars
FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable


CREATE TABLE #bridge
	(
		fk_variable_code		INT ,
		idi_table VARCHAR(500)		

	);

DECLARE @idi_tabs VARCHAR(8000);
DECLARE @i INT = 1;

WHILE @i <= (SELECT MAX(variable_code) FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable)
BEGIN
	SET NOCOUNT ON
	SET @idi_tabs = (SELECT origin_tables FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable WHERE variable_code = @i);
	
	INSERT #bridge(fk_variable_code, idi_table)
	SELECT 
		@i						AS fk_variable_code,
		IDI_Sandpit.lib.string_strip(item)  AS idi_table
	FROM IDI_Sandpit.lib.string_split(@idi_tabs, ',');

	SET @i = @i + 1
END


SELECT
	 fk_variable_code,
	 table_code as fk_table_code
INTO IDI_Sandpit.pop_exp_dev.bridge_variable_tables
FROM #bridge AS b
LEFT JOIN
	(SELECT
		'IDI_Clean.' + table_schema + '.' + table_name AS idi_table,
		*
	FROM IDI_Sandpit.intermediate.dim_idi_tables) AS t
ON b.idi_table = t.idi_table
WHERE b.idi_table IS NOT NULL

ALTER TABLE IDI_Sandpit.pop_exp_dev.bridge_variable_tables
   ADD var_tab_code INT NOT NULL IDENTITY (1,1),
   CONSTRAINT var_tab_code PRIMARY KEY CLUSTERED (var_tab_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.bridge_variable_tables
	ADD FOREIGN KEY (fk_variable_code) REFERENCES IDI_Sandpit.pop_exp_dev.dim_explorer_variable(variable_code);

ALTER TABLE IDI_Sandpit.pop_exp_dev.bridge_variable_tables
	ADD FOREIGN KEY (fk_table_code) REFERENCES IDI_Sandpit.intermediate.dim_idi_tables(table_code);


/*
Now we calculate the linkage rates for each variable and add them back to the dim_explorer_variable
table as additional attributes

*/

-- Then we make a partial copy of the target table, including the empty columns and the original key.

SELECT
	variable_code,
	MIN(proportion_rows_on_spine) AS data_linked_to_spine,
	MIN(proportion_snz_uid_on_spine) AS snz_uid_linked_to_spine
INTO #tmp
FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable		AS a
INNER JOIN IDI_Sandpit.pop_exp_dev.bridge_variable_tables	AS b
ON a.variable_code = b.fk_variable_code
INNER JOIN IDI_Sandpit.intermediate.dim_idi_tables		AS c
ON b.fk_table_code = c.table_code
GROUP BY variable_code

-- Now we update the original target table's empty column with the new values
UPDATE IDI_Sandpit.pop_exp_dev.dim_explorer_variable
	SET data_linked_to_spine = b.data_linked_to_spine,
		snz_uid_linked_to_spine = b.snz_uid_linked_to_spine
	FROM IDI_Sandpit.pop_exp_dev.dim_explorer_variable AS a
	INNER JOIN #tmp AS b
	ON a.variable_code = b.variable_code
	