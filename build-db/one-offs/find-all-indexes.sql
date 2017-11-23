USE IDI_Sandpit

SELECT 
     schema_name = s.name,
	 table_name = t.name,
     index_name = ind.name,
     index_id = ind.index_id,
     column_id = ic.index_column_id,
     column_name = col.name
FROM 
     sys.indexes ind 
INNER JOIN sys.index_columns AS ic 
	ON  ind.object_id = ic.object_id and ind.index_id = ic.index_id 
INNER JOIN sys.columns AS col 
	ON ic.object_id = col.object_id and ic.column_id = col.column_id 
INNER JOIN sys.tables AS t 
	ON ind.object_id = t.object_id 
INNER JOIN	sys.schemas AS s
	ON t.schema_id = s.schema_id
WHERE 
     ind.is_primary_key = 0 
     AND ind.is_unique = 0 
     AND ind.is_unique_constraint = 0 
     AND t.is_ms_shipped = 0 
ORDER BY 
     schema_name, t.name, ind.name, ind.index_id, ic.index_column_id;